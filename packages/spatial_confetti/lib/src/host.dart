part of '../spatial_confetti.dart';

/// 拥有一个模拟实例的控制器，同一时刻只能连接一个 [ConfettiView]。
/// 由创建者调用 [dispose] 释放；视图卸载只清空播放，不销毁控制器。
class ConfettiController extends ChangeNotifier {
  /// 创建模拟器；[gravity] 使用米/秒²，默认向下，null [wind] 表示静止空气。
  /// [limits] 指定本控制器共享的资源预算。
  ConfettiController({
    Vec3 gravity = const Vec3(0, 9.81, 0),
    WindField? wind,
    ConfettiLimits limits = const ConfettiLimits(),
  }) : simulation = ConfettiSimulation(
         gravity: gravity,
         wind: wind,
         limits: limits,
       ) {
    simulation._onChange = _changed;
  }

  /// 控制器拥有的模拟实例；由视图推进时，不应再由外部时钟重复推进。
  final ConfettiSimulation simulation;
  bool _paused = false;
  bool _suppressed = false;
  bool _disposed = false;
  Object? _host;

  /// 是否由 [pause] 主动暂停；不包含后台、TickerMode 等宿主自动暂停原因。
  bool get isPaused => _paused;

  /// 是否没有待发射效果、保留粒子或活动阵风。
  bool get isIdle => simulation.isIdle;

  /// 当前模拟资源与累计拒绝数量，读取时不复制粒子几何数据。
  ConfettiStats get stats => simulation.stats;

  /// 开始一个 [effect]，返回仅控制本次效果的句柄。
  ///
  /// 减少动态效果设置生效时，返回已取消的句柄；并行效果超限时抛出
  /// [StateError]。未连接视图时不会自动推进时间。
  ConfettiPlayback emit(ConfettiEffect effect) {
    _checkDisposed();
    if (_suppressed) {
      final playback = ConfettiPlayback._(null, -1);
      playback._finish(ConfettiCompletion.cancelled);
      return playback;
    }
    return simulation.emit(effect);
  }

  /// 暂停视图时钟并保留当前粒子；不会阻止外部直接调用 simulation.advance。
  void pause() {
    _checkDisposed();
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  /// 解除主动暂停；视图仍会遵守后台、TickerMode 与减少动态效果设置。
  void resume() {
    _checkDisposed();
    if (!_paused) return;
    _paused = false;
    notifyListeners();
  }

  /// 取消全部播放，移除粒子和阵风；保留模拟时间与基础风场。
  void clear() {
    _checkDisposed();
    simulation.clear();
  }

  /// 将基础风场切换到 [wind]，同时影响已有粒子。
  /// [transition] 为模拟时长，范围 Duration.zero～5 秒；零时长立即切换。
  void setWind(
    WindField wind, {
    Duration transition = const Duration(milliseconds: 300),
  }) {
    _checkDisposed();
    simulation.setWind(wind, transition: transition);
  }

  /// 从当前模拟时间开始叠加阵风；减少动态效果生效时忽略请求。
  /// 同时最多保留 16 个阵风，超出时抛出 [StateError]。
  void gust(WindGust gust) {
    _checkDisposed();
    if (!_suppressed) simulation.gust(gust);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _attach(Object host) {
    _checkDisposed();
    if (_host != null && !identical(_host, host)) {
      throw StateError(
        'One ConfettiController can attach to only one ConfettiView',
      );
    }
    _host = host;
  }

  void _detach(Object host) {
    if (!identical(_host, host)) return;
    _host = null;
    _suppressed = false;
    if (!_disposed) simulation.clear();
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('ConfettiController has been disposed');
  }

  /// 取消播放、停止关联视图时钟并释放模拟器；可重复调用。
  /// 销毁后不能再发射、暂停、清空或修改风场。
  @override
  void dispose() {
    if (_disposed) return;
    // 在控制器仍能通知监听者时，让关联视图先停止帧回调。
    _paused = true;
    simulation.clear();
    notifyListeners();
    _disposed = true;
    simulation.dispose();
    super.dispose();
  }
}

/// 透明且忽略指针事件的粒子宿主，父组件须提供有限的宽高约束。
///
/// 后台或 TickerMode 禁用时暂停模拟，恢复后不补算暂停期间的时间。
/// 减少动态效果设置生效时清空现有播放并取消新请求；卸载时清空控制器，
/// 控制器本身仍由调用方释放。粒子绘制在 [child] 前方。
class ConfettiView extends StatefulWidget {
  /// 绑定调用方拥有的 [controller]；[key] 用于 Flutter 组件身份识别。
  const ConfettiView({
    super.key,
    required this.controller,
    this.camera = const ConfettiCamera(),
    this.showNodes = false,
    this.respectReducedMotion = true,
    this.child,
  });

  /// 本视图独占绑定的控制器，不能同时绑定其他 ConfettiView。
  final ConfettiController controller;

  /// 将世界坐标投影到当前视图的相机；应与计算发射起点的反投影相机一致。
  final ConfettiCamera camera;

  /// 是否绘制彩带真实物理节点的调试标记，不改变物理运动。
  final bool showNodes;

  /// 是否遵守 MediaQuery.disableAnimations，默认开启。
  final bool respectReducedMotion;

  /// 位于粒子下方的可选子组件；为空时尝试填满父约束。
  /// 整个宿主都忽略指针事件，包括此子组件。
  final Widget? child;

  /// 创建管理模拟时钟、生命周期和绘制器的内部状态。
  @override
  State<ConfettiView> createState() => _ConfettiViewState();
}

class _ConfettiViewState extends State<ConfettiView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late ConfettiPainter _painter;
  ConfettiPainter _createPainter() => ConfettiPainter(
    simulation: widget.controller.simulation,
    camera: widget.camera,
    showNodes: widget.showNodes,
    repaint: widget.controller,
  );
  Duration? _lastElapsed;
  bool _tickerMode = true;
  bool _foreground = true;
  bool _reduced = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _ticker = createTicker(_tick);
    _painter = _createPainter();
    widget.controller._attach(this);
    widget.controller.addListener(_syncTicker);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    _reduced =
        widget.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _ready = true;
    widget.controller._suppressed = _reduced;
    if (_reduced && !widget.controller.isIdle) widget.controller.clear();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ConfettiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.camera != widget.camera ||
        oldWidget.showNodes != widget.showNodes) {
      _painter = _createPainter();
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_syncTicker);
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
      widget.controller.addListener(_syncTicker);
    }
    _reduced =
        widget.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    widget.controller._suppressed = _reduced;
    if (_reduced && !widget.controller.isIdle) widget.controller.clear();
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  /// 仅在前台、允许动画、未暂停且有工作时运行时钟，空闲时停止帧回调。
  void _syncTicker() {
    if (!_ready) return;
    final shouldRun =
        _tickerMode &&
        _foreground &&
        !_reduced &&
        !widget.controller.isPaused &&
        !widget.controller.isIdle &&
        !widget.controller._disposed;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  /// 按两帧差值推进模拟，每帧最多补算 0.1 秒；恢复后的首帧仅重设基准。
  void _tick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;
    final delta = elapsed - previous;
    const maximumCatchUp = Duration(milliseconds: 100);
    widget.controller.simulation.advance(
      delta > maximumCatchUp ? maximumCatchUp : delta,
    );
    widget.controller._changed();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(
        foregroundPainter: _painter,
        child: widget.child ?? const SizedBox.expand(),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncTicker);
    _ticker.dispose();
    widget.controller._detach(this);
    super.dispose();
  }
}
