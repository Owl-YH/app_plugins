part of '../spatial_confetti.dart';

/// 一次临时覆盖层播放的控制状态；终止原因见 [ConfettiOverlayPlayback.done]。
enum ConfettiOverlayStatus {
  /// 正在播放；宿主仍可能因进入后台或 TickerMode 而自动暂停推进。
  playing,

  /// 通过播放句柄主动暂停。
  paused,

  /// 已终止，包括正常完成、取消、替换与宿主销毁等情况。
  completed,
}

/// 临时覆盖层播放的终止原因。
enum ConfettiOverlayCompletion {
  /// 粒子自然退出，或调用 finish 主动正常结束。
  completed,

  /// 调用方取消或底层效果被取消。
  cancelled,

  /// 同一 Overlay 中的新请求替换了本次播放。
  replaced,

  /// 覆盖层宿主卸载，无法继续显示。
  hostDisposed,

  /// 因尊重系统的减少动态效果设置而跳过或结束播放。
  reducedMotion,
}

/// 仅控制一次临时 Overlay 请求及其时钟的句柄。
/// 结束后的操作不影响后续请求，也不会重新启动本次播放。
class ConfettiOverlayPlayback {
  ConfettiOverlayPlayback._();
  _OverlaySession? _session;
  final _completion = Completer<ConfettiOverlayCompletion>();
  ConfettiOverlayStatus _status = ConfettiOverlayStatus.playing;

  /// 当前控制状态，不单独反映宿主自动暂停的原因。
  ConfettiOverlayStatus get status => _status;

  /// 是否已经以任意终止原因结束。
  bool get isComplete => _completion.isCompleted;

  /// 本次请求终止时完成，并返回具体原因；最多完成一次。
  Future<ConfettiOverlayCompletion> get done => _completion.future;

  /// 暂停本次请求的模拟时钟，保留当前粒子。
  void pause() {
    if (isComplete) return;
    _session?.controller.pause();
    _status = ConfettiOverlayStatus.paused;
  }

  /// 解除本次请求的主动暂停，继续遵守宿主的生命周期限制。
  void resume() {
    if (isComplete) return;
    _session?.controller.resume();
    _status = ConfettiOverlayStatus.playing;
  }

  /// 停止所有后续出生，让已有粒子自然结束。
  void stopEmission() => _session?.emission?.stopEmission();

  /// 立即正常结束并安排清理覆盖层，done 的原因是 completed。
  void finish() => _session?.finish(ConfettiOverlayCompletion.completed);

  /// 立即取消并安排清理覆盖层，done 的原因是 cancelled。
  void cancel() => _session?.finish(ConfettiOverlayCompletion.cancelled);

  void _complete(ConfettiOverlayCompletion reason) {
    if (isComplete) return;
    _session = null;
    _status = ConfettiOverlayStatus.completed;
    _completion.complete(reason);
  }
}

/// 在最近的已布局 Overlay 上显示临时粒子装饰的入口。
/// 同一 Overlay 的新请求替换旧请求，不同 Overlay 彼此独立。
abstract final class Confetti {
  static final _sessions = Expando<_OverlaySession>();

  /// 发射 [effect] 并返回本次播放句柄，终止时自动释放临时宿主与控制器。
  ///
  /// [context] 用于查找最近的 Overlay 与减少动态效果设置；Overlay 必须
  /// 已完成非空布局，否则抛出 [StateError]。
  /// [camera] 用于全覆盖层投影，应与计算起点时使用的反投影相机一致。
  /// [gravity] 使用世界坐标的米/秒²；[wind] 为 null 时使用静止空气。
  /// [limits] 限制本次请求的模拟资源，非法配置抛出 [ArgumentError]。
  /// [respectReducedMotion] 为 true 且系统要求减少动画时，返回已结束句柄。
  ///
  /// 构建阶段触发结束时，时钟立即停止，覆盖层移除与资源释放延迟到帧结束。
  static ConfettiOverlayPlayback launch(
    BuildContext context, {
    required ConfettiEffect effect,
    ConfettiCamera camera = const ConfettiCamera(),
    Vec3 gravity = const Vec3(0, 9.81, 0),
    WindField? wind,
    ConfettiLimits limits = const ConfettiLimits(),
    bool respectReducedMotion = true,
  }) {
    final overlay = Overlay.maybeOf(context);
    final render = overlay?.context.findRenderObject();
    if (overlay == null ||
        !overlay.mounted ||
        render is! RenderBox ||
        !render.hasSize ||
        render.size.isEmpty) {
      throw StateError('Confetti requires a laid-out Overlay.');
    }
    camera._validate();
    final controller = ConfettiController(
      gravity: gravity,
      wind: wind,
      limits: limits,
    );
    final handle = ConfettiOverlayPlayback._();
    _sessions[overlay]?.finish(ConfettiOverlayCompletion.replaced);
    if (respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      controller.dispose();
      handle._complete(ConfettiOverlayCompletion.reducedMotion);
      return handle;
    }
    final session = _OverlaySession(
      overlay,
      controller,
      camera,
      handle,
      respectReducedMotion,
    );
    handle._session = session;
    _sessions[overlay] = session;
    try {
      overlay.insert(session.entry);
      session.inserted = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // 入口首次构建前就卸载时，没有子 State 可以报告销毁，
        // 因此在帧结束时兜底结束请求，避免遗留运行中的时钟。
        if (!handle.isComplete &&
            (!overlay.mounted || !session.entry.mounted)) {
          session.finish(ConfettiOverlayCompletion.hostDisposed);
        }
      });
      final emission = session.emission = controller.emit(effect);
      unawaited(
        emission.done.then((reason) {
          session.finish(
            reason == ConfettiCompletion.completed
                ? ConfettiOverlayCompletion.completed
                : ConfettiOverlayCompletion.cancelled,
          );
        }),
      );
    } catch (_) {
      session.finish(ConfettiOverlayCompletion.cancelled);
      rethrow;
    }
    return handle;
  }
}

/// 拥有一次请求的入口、控制器和句柄，统一处理幂等清理。
class _OverlaySession {
  _OverlaySession(
    this.overlay,
    this.controller,
    this.camera,
    this.handle,
    this.respectReducedMotion,
  );
  final OverlayState overlay;
  final ConfettiController controller;
  final ConfettiCamera camera;
  final ConfettiOverlayPlayback handle;
  final bool respectReducedMotion;
  ConfettiPlayback? emission;
  bool inserted = false;
  late final entry = OverlayEntry(
    builder: (_) => Positioned.fill(child: _OverlayContent(session: this)),
  );

  void finish(ConfettiOverlayCompletion reason) {
    if (handle.isComplete) return;
    handle._complete(reason);
    if (identical(Confetti._sessions[overlay], this)) {
      Confetti._sessions[overlay] = null;
    }
    // 依赖更新或销毁回调中，入口移除可能必须延迟到当前帧构建结束，
    // 但模拟时钟先立即停止。
    controller.pause();
    void release() {
      if (inserted) entry.remove();
      entry.dispose();
      controller.dispose();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => release());
    } else {
      release();
    }
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent({required this.session});
  final _OverlaySession session;
  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.session.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      widget.session.finish(ConfettiOverlayCompletion.reducedMotion);
    }
  }

  @override
  Widget build(BuildContext context) => ConfettiView(
    controller: widget.session.controller,
    camera: widget.session.camera,
    respectReducedMotion: widget.session.respectReducedMotion,
  );

  @override
  void dispose() {
    widget.session.finish(ConfettiOverlayCompletion.hostDisposed);
    super.dispose();
  }
}
