part of '../spatial_confetti.dart';

/// 单次模拟效果的终止原因。
enum ConfettiCompletion {
  /// 发射结束且所属粒子均已退出。
  completed,

  /// 效果被主动取消，或所属模拟器被清空、销毁。
  cancelled,
}

/// 仅控制一个效果的句柄；停止发射后，已有粒子继续自然退出。
/// 多个句柄可共享同一个模拟器，本句柄不会取消其他效果。
class ConfettiPlayback {
  ConfettiPlayback._(this._simulation, this._id);
  ConfettiSimulation? _simulation;
  final int _id;
  final _completion = Completer<ConfettiCompletion>();

  /// 效果完全退出或被取消时完成，返回终止原因。
  Future<ConfettiCompletion> get done => _completion.future;

  /// 是否已结束；结束后再次停止发射或取消均无副作用。
  bool get isComplete => _completion.isCompleted;

  /// 停止本次效果的所有待出生粒子，包括延迟批次与持续发射。
  /// 已有粒子保留，完全退出后以 completed 结束。
  void stopEmission() => _simulation?._stop(_id);

  /// 立即移除本次效果的粒子，并以 cancelled 结束。
  void cancel() => _simulation?._cancel(_id);
  void _finish(ConfettiCompletion reason) {
    _simulation = null;
    if (!_completion.isCompleted) _completion.complete(reason);
  }
}

/// 模拟器当前资源占用与累计诊断计数的不可变快照。
/// 累计计数从模拟器创建起计算，clear 不会重置。
@immutable
class ConfettiStats {
  /// 从当前资源量与累计计数创建统计值，不包含粒子几何副本。
  const ConfettiStats({
    required this.particles,
    required this.livingParticles,
    required this.ribbonSegments,
    required this.droppedParticles,
    required this.playbacks,
    this.paperTriangles = 0,
    this.streakParticles = 0,
    this.capacityRejections = 0,
    this.workLimitRejections = 0,
    this.invalidParticles = 0,
    this.birthAttempts = 0,
  });

  /// 当前保留的粒子数，只包含寿命内的粒子。
  final int particles;

  /// 当前仍在寿命内、继续进行物理模拟的粒子数。
  final int livingParticles;

  /// 当前仍在寿命内的独立光迹数，包含暂时未超过可见速度门限的光迹。
  final int streakParticles;

  /// 当前保留粒子占用的彩带分段总数。
  final int ribbonSegments;

  /// 当前纸片保留的规范三角形数，受 paperTriangles 预算约束。
  final int paperTriangles;

  /// 累计丢弃数：容量拒绝、出生计算额度拒绝与运动数值异常清理之和。
  final int droppedParticles;

  /// 当前尚未结束的效果数，包含等待延迟发射或粒子退出的效果。
  final int playbacks;

  /// 累计因粒子或材料几何容量不足而拒绝的出生数。
  final int capacityRejections;

  /// 累计因当前模拟步出生尝试额度耗尽而拒绝的出生数。
  final int workLimitRejections;

  /// 累计因位置或速度非有限而被防御性移除的粒子数。
  final int invalidParticles;

  /// 累计进入候选生成处理的出生尝试数，包含尝试后才发现容量不足的请求。
  /// 不包含在循环外批量拒绝的请求。
  final int birthAttempts;
}

// 仅用整数混合种子，每一步限制到 32 位，约束 VM、JS 与 Wasm 上的运算范围。
int _mixBirthSeed(int value) {
  value = value.toUnsigned(32);
  value = (value + 0x7ed55d16 + (value << 12)).toUnsigned(32);
  value = ((value ^ 0xc761c23c) ^ (value >>> 19)).toUnsigned(32);
  value = (value + 0x165667b1 + (value << 5)).toUnsigned(32);
  value = ((value + 0xd3a2646c) ^ (value << 9)).toUnsigned(32);
  value = (value + 0xfd7046c5 + (value << 3)).toUnsigned(32);
  return ((value ^ 0xb55a4f09) ^ (value >>> 16)).toUnsigned(32);
}

/// 一个发射源的运行进度、累计权重与独立出生序号。
class _EmitterRun {
  _EmitterRun(this.emitter, int seed)
    : seed = _mixBirthSeed(seed),
      cumulativeWeights = Float64List(emitter.particles.length) {
    var sum = 0.0;
    for (var i = 0; i < emitter.particles.length; i++) {
      sum += emitter.particles[i].weight;
      cumulativeWeights[i] = sum;
    }
  }
  final ConfettiEmitter emitter;
  final int seed;
  final Float64List cumulativeWeights;
  int birthOrdinal = 0;
  bool burstEmitted = false;
  int streamEmitted = 0;
  bool finished = false;

  /// 按出生序号派生随机流，避免先前候选的采样次数影响后续候选。
  math.Random birthRandom() =>
      math.Random(_mixBirthSeed(seed ^ _mixBirthSeed(birthOrdinal++)));

  /// 在累计权重上二分查找，让候选按配置权重被选中。
  ParticleChoice choose(math.Random random) {
    final value = random.nextDouble() * cumulativeWeights.last;
    var low = 0;
    var high = cumulativeWeights.length - 1;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (value < cumulativeWeights[middle]) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return emitter.particles[low];
  }
}

class _EffectRun {
  _EffectRun(this.id, this.start, this.handle, ConfettiEffect effect)
    : emitters = [
        for (var i = 0; i < effect.emitters.length; i++)
          _EmitterRun(effect.emitters[i], effect.seed + i * 104729),
      ];
  final int id;
  final double start;
  final ConfettiPlayback handle;
  final List<_EmitterRun> emitters;
  bool get finishedEmitting => emitters.every((emitter) => emitter.finished);
}

/// 使用固定步长的模拟器，可独立于 Flutter 帧回调进行离线推进。
///
/// [advance] 按 1/120 秒步长消耗输入时间；相同实现、SDK、种子、初始状态
/// 和时间基准下可复现。实时宿主应限制卡顿后的补算量；[ConfettiView]
/// 每帧最多补算 0.1 秒，离线调用方可显式推进更长时间。
class ConfettiSimulation {
  /// 创建模拟器并校验 [gravity] 与 [limits]。
  /// [gravity] 使用米/秒²，默认沿 Y 正方向；null [wind] 表示静止空气。
  ConfettiSimulation({
    Vec3 gravity = const Vec3(0, 9.81, 0),
    WindField? wind,
    this.limits = const ConfettiLimits(),
  }) : _gravity = gravity,
       _wind = wind ?? WindField() {
    _vector('gravity', gravity);
    limits._validate();
  }

  /// 每模拟秒的固定物理步数；120 Hz 的单步无法用整数微秒精确表达。
  static const stepsPerSecond = 120;
  static const _stepSeconds = 1 / stepsPerSecond;

  /// 模拟实例整个生命周期内共享的不可变资源预算。
  final ConfettiLimits limits;
  Vec3 _gravity;

  /// 当前世界重力加速度，单位米/秒²；零向量关闭重力。
  Vec3 get gravity => _gravity;

  /// 更新重力，后续模拟步立即使用；允许任意有限方向或零向量。
  /// 向量模长须不超过 10000，否则抛出 [ArgumentError]。
  set gravity(Vec3 value) {
    _checkDisposed();
    _vector('gravity', value);
    _gravity = value;
    _onChange?.call();
  }

  WindField _wind;
  List<(WindField, double)> _previousWind = [];
  double _windStart = 0;
  double _windDuration = 0;
  final List<_ActiveGust> _gusts = [];
  final List<_Body> _bodies = [];
  final Map<int, _EffectRun> _effects = {};
  int _ticks = 0;
  int _remainderUnits = 0;
  int _nextEffect = 0;
  int _nextParticle = 0;
  int _ribbonSegments = 0;
  int _paperTriangles = 0;
  int _dropped = 0;
  int _capacityRejections = 0;
  int _workLimitRejections = 0;
  int _invalidParticles = 0;
  int _birthAttempts = 0;
  int _stepBirthAttempts = 0;
  bool _disposed = false;
  VoidCallback? _onChange;

  /// 已执行完整模拟步的时刻，舍入到最近微秒；不含不足一步的输入余量。
  /// clear 保留此时钟，需要从零重播时应创建新模拟器。
  Duration get time => _asDuration(_timeSeconds);
  double get _timeSeconds => _ticks * _stepSeconds;

  /// 是否没有效果、保留粒子或阵风；基础风场本身不会使模拟器保持忙碌。
  bool get isIdle => _effects.isEmpty && _bodies.isEmpty && _gusts.isEmpty;

  /// 按需复制全部保留粒子的不可变诊断快照，包含节点与光迹长度。
  /// 每次读取都会分配数据，适用于调试，不适合替代绘制器的逐帧数据访问。
  List<ParticleSnapshot> get snapshot => List.unmodifiable(
    _bodies.map((body) => ParticleSnapshot._(body, _timeSeconds)),
  );

  /// 读取当前资源量与累计计数，不复制节点坐标。
  ConfettiStats get stats => ConfettiStats(
    particles: _bodies.length,
    livingParticles: _bodies.where((body) => body.alive).length,
    ribbonSegments: _ribbonSegments,
    paperTriangles: _paperTriangles,
    streakParticles: _bodies.whereType<_StreakBody>().length,
    droppedParticles: _dropped,
    playbacks: _effects.length,
    capacityRejections: _capacityRejections,
    workLimitRejections: _workLimitRejections,
    invalidParticles: _invalidParticles,
    birthAttempts: _birthAttempts,
  );

  /// 以当前 [time] 为起点启动 [effect]，立即处理零延迟的批量出生。
  ///
  /// 多个效果共享资源预算，返回句柄仅控制本次效果。
  /// 并行效果数达到上限或模拟器已销毁时抛出 [StateError]；
  /// 单个粒子出生超限则直接丢弃并计数，不排队等待容量恢复。
  ConfettiPlayback emit(ConfettiEffect effect) {
    _checkDisposed();
    if (_effects.length >= limits.playbacks) {
      throw StateError('Confetti playback capacity reached');
    }
    final id = _nextEffect++;
    final handle = ConfettiPlayback._(this, id);
    final run = _EffectRun(id, _timeSeconds, handle, effect);
    _effects[id] = run;
    _emitDue(run);
    _finishEffects();
    _onChange?.call();
    return handle;
  }

  /// 将基础风场切换为 [wind]，已有粒子从后续模拟步开始响应。
  ///
  /// [transition] 为过渡模拟时长，范围 Duration.zero～5 秒，零时长立即切换。
  /// 过渡中再次切换会从当前混合状态衔接，最多保留八个历史风场分量。
  /// 独立阵风继续叠加，不随基础风场替换而取消。
  void setWind(
    WindField wind, {
    Duration transition = const Duration(milliseconds: 300),
  }) {
    _checkDisposed();
    _validateDuration(
      'wind transition',
      transition,
      Duration.zero,
      const Duration(seconds: 5),
    );
    final progress = _windDuration == 0
        ? 1.0
        : _smooth((_timeSeconds - _windStart) / _windDuration);
    final previous = <(WindField, double)>[
      for (final entry in _previousWind)
        if (entry.$2 * (1 - progress) > 1e-5)
          (entry.$1, entry.$2 * (1 - progress)),
      (_wind, progress),
    ];
    // 频繁拖动风场滑块时只保留有限个主要分量，避免递归混合树无限增长。
    previous.sort((a, b) => b.$2.compareTo(a.$2));
    _previousWind = previous.take(8).toList();
    final total = _previousWind.fold(0.0, (sum, entry) => sum + entry.$2);
    if (total > 0) {
      _previousWind = _previousWind
          .map((entry) => (entry.$1, entry.$2 / total))
          .toList();
    }
    _wind = wind;
    _windStart = _timeSeconds;
    _windDuration = _seconds(transition);
    if (transition == Duration.zero) _previousWind.clear();
    _onChange?.call();
  }

  /// 从当前 [time] 开始叠加 [gust]，经过其持续时长后自动移除。
  /// 同时最多存在 16 个阵风，超出时抛出 [StateError]。
  void gust(WindGust gust) {
    _checkDisposed();
    if (_gusts.length >= 16) throw StateError('At most 16 simultaneous gusts');
    _gusts.add(_ActiveGust(gust, _timeSeconds));
    _onChange?.call();
  }

  /// 合成当前基础风场、过渡分量和活动阵风，返回当地空气速度。
  Vec3 _airAt(Vec3 position, {double offset = 0}) {
    final sampleTime = _timeSeconds + offset;
    final progress = _windDuration == 0
        ? 1.0
        : _smooth((sampleTime - _windStart) / _windDuration);
    var air = _wind._velocityAt(position, sampleTime) * progress;
    for (final entry in _previousWind) {
      air +=
          entry.$1._velocityAt(position, sampleTime) *
          (entry.$2 * (1 - progress));
    }
    for (final gust in _gusts) {
      air += gust.sample(position, sampleTime);
    }
    return air;
  }

  /// 同步推进 [elapsed] 时长，允许范围 Duration.zero～60 秒。
  ///
  /// 不足一个固定步长的余量留待下次调用；不会创建时钟或自动请求重绘。
  /// 离线调用可分多次推进更长时间，实时调用应自行限制卡顿补算量。
  /// 非法时间抛出 [ArgumentError]，销毁后调用抛出 [StateError]。
  void advance(Duration elapsed) {
    _checkDisposed();
    _validateDuration(
      'elapsed',
      elapsed,
      Duration.zero,
      const Duration(seconds: 60),
    );
    // 输入按微秒累计，物理步按精确 1/120 秒求解；分割输入不会损失余量。
    _remainderUnits += elapsed.inMicroseconds * stepsPerSecond;
    while (_remainderUnits >= Duration.microsecondsPerSecond) {
      _remainderUnits -= Duration.microsecondsPerSecond;
      _step();
    }
  }

  /// 推进一个固定步：更新并回收旧粒子、生成到期粒子、完成已退出效果。
  void _step() {
    _ticks++;
    _stepBirthAttempts = 0;
    if (_windDuration > 0 && _timeSeconds - _windStart >= _windDuration) {
      _previousWind.clear();
      _windDuration = 0;
    }
    _gusts.removeWhere(
      (gust) => _timeSeconds - gust.start >= gust.gust._durationSeconds,
    );
    for (final body in _bodies) {
      if (body.alive && _timeSeconds - body.birth < body.lifetime - 1e-9) {
        body.step(this, _stepSeconds);
        if (!body.center.isFinite || !body.velocity.isFinite) {
          // 防止自定义曲线或求解数值异常把非有限坐标传给 Canvas。
          body.alive = false;
          _dropped++;
          _invalidParticles++;
        }
      } else {
        body.alive = false;
      }
    }
    _bodies.removeWhere((body) {
      if (body.alive) return false;
      _release(body);
      return true;
    });
    // 先积分旧粒子，再在当前边界生成新粒子。
    // 新粒子立即可见，但不会提前计算出生之前的运动。
    for (final run in _effects.values) {
      _emitDue(run);
    }
    _finishEffects();
  }

  /// 按效果年龄处理延迟批次和累计持续出生量，避免帧率改变发射总数。
  void _emitDue(_EffectRun effect) {
    final age = _timeSeconds - effect.start;
    for (final run in effect.emitters) {
      if (run.finished || age + 1e-9 < run.emitter._delaySeconds) continue;
      final emitter = run.emitter;
      if (!run.burstEmitted) {
        _spawnDue(effect.id, run, emitter.burstCount);
        run.burstEmitted = true;
      }
      final elapsed = math.min(
        math.max(0.0, age - emitter._delaySeconds),
        emitter._durationSeconds,
      );
      final expected = (elapsed * emitter.rate + 1e-8).floor();
      _spawnDue(effect.id, run, expected - run.streamEmitted);
      run.streamEmitted = expected;
      if (emitter.rate == 0 ||
          age - emitter._delaySeconds + 1e-9 >= emitter._durationSeconds) {
        run.finished = true;
      }
    }
  }

  /// 在当前步共享额度内尝试出生；超额部分批量计数并推进出生序号。
  /// 不补发被丢弃的请求，防止积压或大量无效循环。
  void _spawnDue(int owner, _EmitterRun run, int count) {
    var remaining = count;
    while (remaining > 0 &&
        _stepBirthAttempts < limits.birthAttemptsPerStep &&
        _bodies.length < limits.particles) {
      _stepBirthAttempts++;
      _birthAttempts++;
      _spawn(owner, run);
      remaining--;
    }
    if (remaining <= 0) return;
    if (_bodies.length >= limits.particles) {
      _capacityRejections += remaining;
    } else {
      _workLimitRejections += remaining;
    }
    _dropped += remaining;
    run.birthOrdinal += remaining;
    _nextParticle += remaining;
  }

  /// 先选择配方并检查材料几何预算，再采样尺寸、颜色、方向和寿命。
  void _spawn(int owner, _EmitterRun run) {
    final random = run.birthRandom();
    final emitter = run.emitter;
    final choice = run.choose(random);
    final recipe = choice.particle;
    final segmentCost = recipe is RibbonParticle ? recipe.segments : 0;
    final geometry = recipe is PaperParticle ? recipe.shape._geometry : null;
    final paperCost = geometry?.triangleCount ?? 0;
    final id = _nextParticle++;
    if (_bodies.length >= limits.particles ||
        _ribbonSegments + segmentCost > limits.ribbonSegments ||
        _paperTriangles + paperCost > limits.paperTriangles) {
      _dropped++;
      _capacityRejections++;
      return;
    }
    final direction = _coneDirection(random, emitter.direction, emitter.spread);
    final origin =
        emitter.origin +
        _randomDirection(random) *
            (math.pow(random.nextDouble(), 1 / 3).toDouble() * emitter.radius);
    final velocity = direction * emitter.speed.sample(random);
    final lifetime = _seconds(emitter.lifetime.duration.sample(random));
    final dimensions = recipe is PaperParticle
        ? recipe.size._sample(random, geometry!)
        : null;
    final width = switch (recipe) {
      RibbonParticle() => recipe.width.sample(random),
      StreakParticle() => recipe.width.sample(random),
      PaperParticle() => dimensions!.width,
    };
    final color = choice.colors[random.nextInt(choice.colors.length)];
    final _Body body = switch (recipe) {
      PaperParticle() => _PaperBody(
        id: id,
        owner: owner,
        recipe: recipe,
        color: color,
        birth: _timeSeconds,
        lifetime: lifetime,
        lifetimeSettings: emitter.lifetime,
        geometry: geometry!,
        dimensions: dimensions!,
        position: origin,
        speed: velocity,
        random: random,
      ),
      StreakParticle() => _StreakBody(
        id: id,
        owner: owner,
        recipe: recipe,
        color: color,
        birth: _timeSeconds,
        lifetime: lifetime,
        lifetimeSettings: emitter.lifetime,
        width: width,
        position: origin,
        speed: velocity,
      ),
      RibbonParticle() => _RibbonBody(
        id: id,
        owner: owner,
        recipe: recipe,
        color: color,
        birth: _timeSeconds,
        lifetime: lifetime,
        lifetimeSettings: emitter.lifetime,
        width: width,
        length: recipe.length.sample(random),
        origin: origin,
        initialVelocity: velocity,
        direction: direction,
        random: random,
      ),
    };
    _bodies.add(body);
    _ribbonSegments += segmentCost;
    _paperTriangles += paperCost;
  }

  /// 粒子退出后释放其材料几何额度。
  void _release(_Body body) {
    _ribbonSegments -= body.segmentCost;
    _paperTriangles -= body.paperCost;
  }

  /// 只有发射全部结束且所属粒子都已退出，才正常完成播放句柄。
  void _finishEffects() {
    final activeOwners = _bodies.map((body) => body.owner).toSet();
    final finished = _effects.values
        .where((run) => run.finishedEmitting && !activeOwners.contains(run.id))
        .toList();
    for (final run in finished) {
      _effects.remove(run.id);
      run.handle._finish(ConfettiCompletion.completed);
    }
  }

  void _stop(int id) {
    final effect = _effects[id];
    if (effect == null) return;
    for (final emitter in effect.emitters) {
      emitter.finished = true;
    }
    _finishEffects();
    _onChange?.call();
  }

  void _cancel(int id) {
    final effect = _effects.remove(id);
    if (effect == null) return;
    _bodies.removeWhere((body) {
      if (body.owner != id) return false;
      _release(body);
      return true;
    });
    effect.handle._finish(ConfettiCompletion.cancelled);
    _onChange?.call();
  }

  /// 取消所有效果并移除粒子与阵风，释放资源占用。
  ///
  /// 保留模拟时间、重力、基础风场及其过渡状态、累计统计和当前步出生额度；
  /// 不足一步的时间余量归零。需要完全重置时应重新创建模拟器。
  void clear() {
    _checkDisposed();
    for (final effect in _effects.values) {
      effect.handle._finish(ConfettiCompletion.cancelled);
    }
    _effects.clear();
    _bodies.clear();
    _gusts.clear();
    _ribbonSegments = 0;
    _paperTriangles = 0;
    _remainderUnits = 0;
    _onChange?.call();
  }

  /// 清空全部效果并释放变化回调；可重复调用，之后不能再推进或修改模拟。
  void dispose() {
    if (_disposed) return;
    clear();
    _onChange = null;
    _disposed = true;
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('ConfettiSimulation has been disposed');
  }
}
