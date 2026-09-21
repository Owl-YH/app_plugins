import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spatial_confetti/spatial_confetti.dart';

void main() => runApp(const ConfettiExample());

class ConfettiExample extends StatelessWidget {
  const ConfettiExample({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Spatial Confetti',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff9be6ce),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff11151c),
      useMaterial3: true,
    ),
    home: const ConfettiLab(),
  );
}

enum ParticleMode { mixed, paper, ribbon, streak }

class ConfettiLab extends StatefulWidget {
  const ConfettiLab({super.key});
  @override
  State<ConfettiLab> createState() => _ConfettiLabState();
}

class _ConfettiLabState extends State<ConfettiLab> {
  var _controller = ConfettiController();
  final _camera = const ConfettiCamera(viewHeight: 4.5);
  late final Timer _metricsTimer;
  ConfettiPlayback? _stream;
  ParticleMode _mode = ParticleMode.mixed;
  static final _paperShapes = <(String, PaperShape)>[
    ('矩形', const PaperShape.rectangle()),
    ('圆形', const PaperShape.circle()),
    ('三角形', const PaperShape.triangle()),
    ('星形', const PaperShape.star()),
    ('心形', const PaperShape.heart()),
    (
      '自定义',
      PaperShape.polygon(
        vertices: const [
          Offset(0, 0),
          Offset(1, 0),
          Offset(.4, .5),
          Offset(1, 1),
          Offset(0, 1),
        ],
      ),
    ),
  ];
  int _paperShape = -1;
  double _paperDrag = .35, _paperFriction = .02;
  bool _paperNoBend = true;
  double _paperBending = .00002, _paperDamping = 1.5, _paperMaximumBend = .02;
  bool _withStreaks = true;
  bool _nodes = false;
  bool _secondWind = false;
  double _windX = .8, _windY = 0, _windZ = .4, _turbulence = .35;
  double _speed = 11, _count = 64, _ribbonLength = 1.2, _ribbonSegments = 20;
  Duration _fadeIn = Duration.zero,
      _fadeOut = const Duration(milliseconds: 350);
  int _seed = 41, _living = 0, _streakParticles = 0, _dropped = 0;
  bool _idle = true;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _updateWind();
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final stats = _controller.stats;
      if (_living != stats.livingParticles ||
          _streakParticles != stats.streakParticles ||
          _dropped != stats.droppedParticles ||
          _idle != _controller.isIdle) {
        setState(() {
          _living = stats.livingParticles;
          _streakParticles = stats.streakParticles;
          _dropped = stats.droppedParticles;
          _idle = _controller.isIdle;
        });
      }
    });
  }

  void _updateWind() => _controller.setWind(
    WindField(
      sources: [
        WindSource.global(velocity: Vec3(_windX, _windY, _windZ)),
        if (_secondWind)
          WindSource.local(
            velocity: Vec3(-_windX * .6, -.5, 1.8),
            center: const Vec3(1, 0, 0),
            radius: 1.8,
          ),
      ],
      turbulence: _turbulence,
      seed: 8,
    ),
  );

  PaperParticle _paper({
    required PaperShape shape,
    required PaperSize size,
    double massPerArea = .08,
    required double dragCoefficient,
    required double surfaceFriction,
    NumberRange angularSpeed = const NumberRange(-5, 5),
  }) => _paperNoBend
      ? PaperParticle.noBend(
          shape: shape,
          size: size,
          massPerArea: massPerArea,
          dragCoefficient: dragCoefficient,
          surfaceFriction: surfaceFriction,
          angularSpeed: angularSpeed,
        )
      : PaperParticle.bend(
          shape: shape,
          size: size,
          massPerArea: massPerArea,
          dragCoefficient: dragCoefficient,
          surfaceFriction: surfaceFriction,
          angularSpeed: angularSpeed,
          bendingStiffness: _paperBending,
          maximumBendRatio: _paperMaximumBend,
          damping: _paperDamping,
        );

  List<ParticleChoice> _particles({bool singleRibbon = false}) => [
    if (!singleRibbon &&
        (_mode == ParticleMode.paper || _mode == ParticleMode.mixed))
      for (final item
          in _paperShape < 0 ? _paperShapes : [_paperShapes[_paperShape]])
        ParticleChoice(
          weight: _paperShape < 0 ? 3 / _paperShapes.length : 3,
          particle: _paper(
            shape: item.$2,
            size: const PaperSize.proportional(NumberRange(.065, .12)),
            massPerArea: .16,
            dragCoefficient: _paperDrag,
            surfaceFriction: _paperFriction,
          ),
        ),
    if (singleRibbon ||
        _mode == ParticleMode.ribbon ||
        _mode == ParticleMode.mixed)
      ParticleChoice(
        weight: 1,
        particle: RibbonParticle(
          width: singleRibbon
              ? const NumberRange.fixed(.055)
              : const NumberRange(.022, .035),
          length: singleRibbon
              ? NumberRange.fixed(_ribbonLength)
              : const NumberRange(.4, .8),
          segments: _ribbonSegments.round(),
          massPerArea: .12,
          dragCoefficient: .6,
        ),
      ),
    if (!singleRibbon && _mode == ParticleMode.streak)
      ParticleChoice(particle: const StreakParticle()),
  ];

  void _emit({Vec3? origin, bool repeat = false, bool singleRibbon = false}) {
    if (repeat) {
      // A fresh clock also restores the time-dependent wind phase.
      final previous = _controller;
      _controller = ConfettiController();
      _stream = null;
      _updateWind();
      previous.dispose();
    } else if (singleRibbon) {
      _controller.clear();
    }
    if (!repeat) _seed++;
    _controller.resume();
    _controller.emit(
      ConfettiEffect(
        seed: _seed,
        emitters: [
          ConfettiEmitter.burst(
            particles: _particles(singleRibbon: singleRibbon),
            origin:
                origin ??
                (singleRibbon
                    ? const Vec3(-.7, .9, 0)
                    : const Vec3(-1.1, 1.8, 0)),
            direction: const Vec3(.3, -1, .12),
            speed: singleRibbon
                ? NumberRange.fixed(_speed)
                : NumberRange(_speed * .8, _speed * 1.2),
            spread: singleRibbon ? 0 : .55,
            burstCount: singleRibbon ? 1 : _count.round(),
            lifetime: ParticleLifetime(
              fadeIn: _fadeIn,
              fadeOut: _fadeOut,
              duration: _mode == ParticleMode.streak && !singleRibbon
                  ? const DurationRange.fixed(Duration(milliseconds: 260))
                  : singleRibbon
                  ? const DurationRange.fixed(Duration(seconds: 7))
                  : const DurationRange(
                      Duration(seconds: 4),
                      Duration(seconds: 6),
                    ),
            ),
          ),
          if (_mode == ParticleMode.mixed && _withStreaks && !singleRibbon)
            ConfettiEmitter.burst(
              origin: origin ?? const Vec3(-1.1, 1.8, 0),
              direction: const Vec3(.3, -1, .12),
              speed: NumberRange(_speed * 1.8, _speed * 2.4),
              spread: .22,
              burstCount: 6,
              lifetime: const ParticleLifetime(
                duration: DurationRange.fixed(Duration(milliseconds: 260)),
                fadeOut: Duration(milliseconds: 100),
              ),
              particles: [ParticleChoice(particle: const StreakParticle())],
            ),
        ],
      ),
    );
    setState(() {});
  }

  void _dropPaper() {
    _controller.clear();
    _stream = null;
    _controller.resume();
    _controller.emit(
      ConfettiEffect(
        seed: ++_seed,
        emitters: [
          ConfettiEmitter.burst(
            origin: const Vec3(0, -1.5, 0),
            speed: const NumberRange.fixed(0),
            spread: 0,
            burstCount: 1,
            lifetime: ParticleLifetime(
              duration: const DurationRange.fixed(Duration(seconds: 7)),
              fadeIn: _fadeIn,
              fadeOut: _fadeOut,
            ),
            particles: [
              ParticleChoice(
                particle: _paper(
                  shape: _paperShapes[_paperShape < 0 ? 0 : _paperShape].$2,
                  size: const PaperSize.proportional(NumberRange.fixed(.3)),
                  dragCoefficient: _paperDrag,
                  surfaceFriction: _paperFriction,
                  angularSpeed: const NumberRange.fixed(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    setState(() {});
  }

  void _toggleStream() {
    if (_stream != null && !_stream!.isComplete) {
      _stream!.stopEmission();
      _stream = null;
    } else {
      _controller.resume();
      _stream = _controller.emit(
        ConfettiEffect(
          seed: ++_seed,
          emitters: [
            ConfettiEmitter.stream(
              particles: _particles(),
              origin: const Vec3(-1.1, 1.8, -.4),
              direction: const Vec3(.4, -1, .2),
              speed: NumberRange(_speed * .8, _speed * 1.2),
              spread: .5,
              burstCount: 0,
              rate: 14,
              duration: const Duration(seconds: 20),
              lifetime: ParticleLifetime(
                duration: _mode == ParticleMode.streak
                    ? const DurationRange.fixed(Duration(milliseconds: 260))
                    : const DurationRange(
                        Duration(seconds: 4),
                        Duration(seconds: 6),
                      ),
                fadeIn: _fadeIn,
                fadeOut: _fadeOut,
              ),
            ),
          ],
        ),
      );
      final playback = _stream;
      playback!.done.then((_) {
        if (mounted && identical(_stream, playback))
          setState(() => _stream = null);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xff9be6ce),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spatial confetti',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '纸片 · 柔性彩带 · 三维风场',
                        style: TextStyle(color: Color(0xffa1adb9)),
                      ),
                    ],
                  ),
                ),
                Text(
                  _idle
                      ? '静止'
                      : _controller.isPaused
                      ? '已暂停'
                      : '运行中',
                  style: const TextStyle(color: Color(0xff9be6ce)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _stage()),
                        const SizedBox(width: 20),
                        SizedBox(width: 320, child: _controls()),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: _stage()),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: constraints.maxHeight * .43,
                        child: _controls(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stage() => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff171e28),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff2e3947)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (event) => _emit(
              origin: _camera.unproject(event.localPosition, _viewport),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 20,
                  left: 20,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '让风决定下一瞬间。',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '点击画布，从这里发射',
                          style: TextStyle(color: Color(0xffa1adb9)),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ConfettiView(
                    controller: _controller,
                    camera: _camera,
                    showNodes: _nodes,
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 5,
                      children: [
                        Text(
                          '粒子 $_living',
                          style: const TextStyle(color: Color(0xffa1adb9)),
                        ),
                        Text(
                          '光迹 $_streakParticles',
                          style: const TextStyle(color: Color(0xffa1adb9)),
                        ),
                        Text(
                          '种子 $_seed',
                          style: const TextStyle(color: Color(0xffa1adb9)),
                        ),
                        if (_dropped > 0)
                          Text(
                            '预算丢弃 $_dropped',
                            style: const TextStyle(color: Color(0xffffbf69)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _controls() => ListView(
    padding: const EdgeInsets.only(right: 4, bottom: 10),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _emit(),
            icon: const Icon(Icons.north_east),
            label: const Text('发射一批'),
          ),
          OutlinedButton(
            onPressed: _toggleStream,
            child: Text(_stream == null ? '持续发射' : '停止生成'),
          ),
          OutlinedButton(
            onPressed: () => _emit(singleRibbon: true),
            child: const Text('观察单条彩带'),
          ),
          OutlinedButton(onPressed: _dropPaper, child: const Text('静止释放单张纸片')),
          TextButton(
            onPressed: () => _emit(repeat: true),
            child: const Text('重播同一种子'),
          ),
        ],
      ),
      Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              if (_controller.isPaused) {
                _controller.resume();
              } else {
                _controller.pause();
              }
            }),
            icon: Icon(_controller.isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(_controller.isPaused ? '继续' : '暂停'),
          ),
          TextButton.icon(
            onPressed: () {
              _controller.clear();
              setState(() => _stream = null);
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('清空'),
          ),
        ],
      ),
      const Divider(height: 28),
      const Text(
        '粒子与发射',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      SegmentedButton<ParticleMode>(
        segments: const [
          ButtonSegment(value: ParticleMode.mixed, label: Text('混合')),
          ButtonSegment(value: ParticleMode.paper, label: Text('纸片')),
          ButtonSegment(value: ParticleMode.ribbon, label: Text('彩带')),
          ButtonSegment(value: ParticleMode.streak, label: Text('光迹')),
        ],
        selected: {_mode},
        onSelectionChanged: (values) => setState(() => _mode = values.single),
      ),
      if (_mode == ParticleMode.paper || _mode == ParticleMode.mixed) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('全部形状'),
              selected: _paperShape == -1,
              onSelected: (_) => setState(() => _paperShape = -1),
            ),
            for (var i = 0; i < _paperShapes.length; i++)
              ChoiceChip(
                label: Text(_paperShapes[i].$1),
                selected: _paperShape == i,
                onSelected: (_) => setState(() => _paperShape = i),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('纸片不弯曲'),
          value: _paperNoBend,
          onChanged: (value) => setState(() => _paperNoBend = value),
        ),
        if (!_paperNoBend) ...[
          Wrap(
            spacing: 6,
            children: [
              for (final item in [
                ('柔软', .000002),
                ('标准', .00002),
                ('挺括', .002),
              ])
                ChoiceChip(
                  label: Text(item.$1),
                  selected: _paperBending == item.$2,
                  onSelected: (_) => setState(() => _paperBending = item.$2),
                ),
            ],
          ),
          Text('抗弯刚度 ${_paperBending.toStringAsExponential(1)} N·m'),
          _slider(
            '长边最大弓高',
            _paperMaximumBend * 100,
            0,
            5,
            (value) => setState(() => _paperMaximumBend = value / 100),
            unit: '%',
          ),
          _slider(
            '纸片内部阻尼',
            _paperDamping,
            0,
            20,
            (value) => setState(() => _paperDamping = value),
            unit: '1/s',
          ),
        ],
        _slider(
          '纸片压力气动',
          _paperDrag,
          0,
          4,
          (value) => setState(() => _paperDrag = value),
        ),
        _slider(
          '纸片切向摩擦',
          _paperFriction,
          0,
          1,
          (value) => setState(() => _paperFriction = value),
        ),
      ],
      _slider(
        '每批数量',
        _count,
        1,
        160,
        (value) => setState(() => _count = value),
        unit: '个',
        decimals: 0,
      ),
      _slider(
        '发射速度',
        _speed,
        2,
        16,
        (value) => setState(() => _speed = value),
        unit: 'm/s',
      ),
      _slider(
        '淡入',
        _fadeIn.inMilliseconds.toDouble(),
        0,
        2000,
        (value) =>
            setState(() => _fadeIn = Duration(milliseconds: value.round())),
        unit: 'ms',
        decimals: 0,
      ),
      _slider(
        '淡出',
        _fadeOut.inMilliseconds.toDouble(),
        0,
        2000,
        (value) =>
            setState(() => _fadeOut = Duration(milliseconds: value.round())),
        unit: 'ms',
        decimals: 0,
      ),
      const Text(
        '淡入淡出包含在寿命内，调整作用于随后出生的粒子。',
        style: TextStyle(color: Color(0xffa1adb9)),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('混合发射加入开场光迹'),
        subtitle: const Text('高速时出现，减速后收短淡出'),
        value: _withStreaks,
        onChanged: (value) => setState(() => _withStreaks = value),
      ),
      const Text(
        '粒子参数作用于下一次发射。单张观察使用 30 cm 纸片、零初始速度和角速度，沿用当前形状、气动和风场。',
        style: TextStyle(fontSize: 12, color: Color(0xffa1adb9)),
      ),
      const Divider(height: 28),
      const Text(
        '风场 · 实时生效',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      _windSlider('X · 向右', _windX, (value) => _windX = value),
      _windSlider('Y · 向下', _windY, (value) => _windY = value),
      _windSlider('Z · 朝镜头', _windZ, (value) => _windZ = value),
      _slider('气流起伏', _turbulence, 0, 2, (value) {
        setState(() => _turbulence = value);
        _updateWind();
      }),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('叠加局部风源'),
        subtitle: const Text('画面右侧向上、朝镜头吹动'),
        value: _secondWind,
        onChanged: (value) {
          setState(() => _secondWind = value);
          _updateWind();
        },
      ),
      OutlinedButton.icon(
        onPressed: () {
          try {
            _controller.gust(
              WindGust.global(
                velocity: Vec3(3 + _windX, -1, 1 + _windZ),
                duration: const Duration(milliseconds: 2500),
              ),
            );
          } on StateError {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('请等待已有阵风结束')));
          }
        },
        icon: const Icon(Icons.air),
        label: const Text('让一阵风经过'),
      ),
      const Divider(height: 28),
      const Text(
        '彩带形变',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('显示物理节点'),
        subtitle: const Text('节点负责受力，表面独立平滑细分'),
        value: _nodes,
        onChanged: (value) => setState(() => _nodes = value),
      ),
      _slider(
        '单条长度',
        _ribbonLength,
        .2,
        3,
        (value) => setState(() => _ribbonLength = value),
        unit: 'm',
      ),
      _slider(
        '物理段数',
        _ribbonSegments,
        4,
        32,
        (value) => setState(() => _ribbonSegments = value.roundToDouble()),
      ),
    ],
  );

  Widget _windSlider(String label, double value, ValueChanged<double> assign) =>
      _slider(label, value, -5, 5, (next) {
        setState(() => assign(next));
        _updateWind();
      }, unit: 'm/s');

  Widget _slider(
    String label,
    double value,
    double minimum,
    double maximum,
    ValueChanged<double> onChanged, {
    String unit = '',
    int decimals = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value.toStringAsFixed(decimals) + (unit.isEmpty ? '' : ' $unit'),
              style: const TextStyle(color: Color(0xff9be6ce)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: minimum,
          max: maximum,
          semanticFormatterCallback: (number) =>
              number.toStringAsFixed(decimals) + ' $unit',
          onChanged: onChanged,
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _metricsTimer.cancel();
    _controller.dispose();
    super.dispose();
  }
}
