import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";

const _maxItemCount = 64;
const _maxInstanceCount = 512;

/// A continuously repeating, noninteractive presentation of a small collection.
///
/// The movement axis needs a finite maximum constraint. The cross axis follows
/// tight constraints or shrinks to the items' natural sizes. Builders must
/// produce repeatable, finite-sized content without sharing GlobalKeys between
/// copies. At most 64 original items and 512 total item instances are supported.
///
/// Omit [semanticsLabel] for decoration. Informational content requires both a
/// complete localized label and [reducedMotionChild], whose content must remain
/// readable or manually reachable when system animations are disabled.
class OwlMarquee extends StatefulWidget {
  OwlMarquee({
    required this.itemCount,
    required this.itemBuilder,
    this.direction = AxisDirection.left,
    this.speed = 24,
    this.spacing = 0,
    this.paused = false,
    this.semanticsLabel,
    this.reducedMotionChild,
    super.key,
  }) {
    if (itemCount < 0 || itemCount > _maxItemCount) {
      throw ArgumentError.value(
        itemCount,
        "itemCount",
        "Must be between 0 and $_maxItemCount.",
      );
    }
    if (!speed.isFinite || speed < 0) {
      throw ArgumentError.value(
        speed,
        "speed",
        "Must be finite and nonnegative.",
      );
    }
    if (!spacing.isFinite || spacing < 0) {
      throw ArgumentError.value(
        spacing,
        "spacing",
        "Must be finite and nonnegative.",
      );
    }
    if (semanticsLabel != null &&
        (semanticsLabel!.trim().isEmpty || reducedMotionChild == null)) {
      throw ArgumentError(
        "A nonblank semanticsLabel requires reducedMotionChild.",
      );
    }
  }

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Physical movement direction, independent of text direction.
  final AxisDirection direction;

  /// Logical pixels per second. Zero freezes the current position.
  final double speed;

  /// Logical pixels between items, including the last-to-first seam.
  final double spacing;
  final bool paused;
  final String? semanticsLabel;

  /// Replaces the track only for reduced motion, retaining its own semantics.
  /// The caller owns its layout, scrolling and information completeness.
  final Widget? reducedMotionChild;

  @override
  State<OwlMarquee> createState() => _OwlMarqueeState();
}

class _OwlMarqueeState extends State<OwlMarquee>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  ValueListenable<TickerModeData>? _tickerMode;
  AppLifecycleState? _lifecycle;
  bool _active = true;
  bool _reducedMotion = false;
  bool _hasLayout = false;
  double _cycleExtent = 0;
  double? _playingVelocity;
  double? _playingExtent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _subscribeTickerMode();
    if (_reducedMotion && widget.reducedMotionChild != null) _hasLayout = false;
    _updatePlayback();
  }

  @override
  void didUpdateWidget(OwlMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (axisDirectionToAxis(oldWidget.direction) !=
        axisDirectionToAxis(widget.direction)) {
      _hasLayout = false;
      _controller.value = 0;
    }
    if (_reducedMotion && widget.reducedMotionChild != null) _hasLayout = false;
    _updatePlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _updatePlayback();
  }

  @override
  void deactivate() {
    _active = false;
    _hasLayout = false;
    _updatePlayback();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _subscribeTickerMode();
    _updatePlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerMode?.removeListener(_updatePlayback);
    _controller.dispose();
    super.dispose();
  }

  void _subscribeTickerMode() {
    final notifier = TickerMode.getValuesNotifier(context);
    if (notifier == _tickerMode) return;
    _tickerMode?.removeListener(_updatePlayback);
    _tickerMode = notifier..addListener(_updatePlayback);
  }

  void _didLayout(double cycleExtent, bool hasArea) {
    _cycleExtent = cycleExtent;
    _hasLayout = hasArea && cycleExtent > 0;
    _updatePlayback();
  }

  void _updatePlayback() {
    final enabled =
        _active &&
        _hasLayout &&
        !_reducedMotion &&
        !widget.paused &&
        widget.speed > 0 &&
        widget.itemCount > 0 &&
        (_tickerMode?.value.enabled ?? true) &&
        (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
    if (!enabled) {
      _controller.stop();
      _playingVelocity = null;
      _playingExtent = null;
      return;
    }
    final velocity = switch (widget.direction) {
      AxisDirection.left || AxisDirection.up => -widget.speed,
      AxisDirection.right || AxisDirection.down => widget.speed,
    };
    if (_controller.isAnimating &&
        _playingVelocity == velocity &&
        _playingExtent == _cycleExtent) {
      return;
    }
    _playingVelocity = velocity;
    _playingExtent = _cycleExtent;
    // The controller samples framework elapsed time; suspended time is never
    // included in a new simulation. The simulation keeps its offset bounded.
    unawaited(
      _controller.animateWith(
        _MarqueeMotion(_controller.value, velocity, _cycleExtent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion && widget.reducedMotionChild != null) {
      return widget.reducedMotionChild!;
    }
    final track = ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(
          child: _MarqueeViewport(
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
            direction: widget.direction,
            spacing: widget.spacing,
            animation: _controller,
            onLayout: _didLayout,
          ),
        ),
      ),
    );
    return widget.semanticsLabel == null
        ? track
        : Semantics(
            container: true,
            label: widget.semanticsLabel,
            child: track,
          );
  }
}

class _MarqueeMotion extends Simulation {
  _MarqueeMotion(double offset, this.velocity, this.extent)
    : offset = offset % extent,
      period = extent / velocity.abs() {
    if (period == 0) {
      throw FlutterError("OwlMarquee speed is too large for its cycle extent.");
    }
  }

  final double offset;
  final double velocity;
  final double extent;
  final double period;

  @override
  double x(double time) {
    final travel =
        ((period.isFinite ? time % period : time) * velocity) % extent;
    // Avoid adding two potentially large positive values before wrapping.
    return travel >= extent - offset
        ? travel - (extent - offset)
        : offset + travel;
  }

  @override
  double dx(double time) => velocity;

  @override
  bool isDone(double time) => false;
}

class _MarqueeViewport extends RenderObjectWidget {
  const _MarqueeViewport({
    required this.itemCount,
    required this.itemBuilder,
    required this.direction,
    required this.spacing,
    required this.animation,
    required this.onLayout,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final AxisDirection direction;
  final double spacing;
  final Animation<double> animation;
  final void Function(double cycleExtent, bool hasArea) onLayout;

  @override
  RenderObjectElement createElement() => _MarqueeElement(this);

  @override
  _RenderMarquee createRenderObject(BuildContext context) =>
      _RenderMarquee(this);

  @override
  void updateRenderObject(BuildContext context, _RenderMarquee renderObject) {
    renderObject.update(this);
  }
}

class _MarqueeElement extends RenderObjectElement {
  _MarqueeElement(_MarqueeViewport super.widget);

  final Map<int, Element> _children = {};
  bool _needsBuild = true;
  int? _itemCount;

  @override
  _RenderMarquee get renderObject => super.renderObject as _RenderMarquee;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject.element = this;
  }

  @override
  void update(_MarqueeViewport newWidget) {
    final previous = widget as _MarqueeViewport;
    super.update(newWidget);
    if (previous.itemCount != newWidget.itemCount ||
        previous.itemBuilder != newWidget.itemBuilder) {
      _needsBuild = true;
      renderObject.scheduleLayoutCallback();
    }
  }

  @override
  void performRebuild() {
    _needsBuild = true;
    renderObject.scheduleLayoutCallback();
    super.performRebuild();
  }

  void _buildItems() {
    owner!.buildScope(this, () {
      final current = widget as _MarqueeViewport;
      if (_itemCount != current.itemCount) {
        _trim(0);
        _itemCount = current.itemCount;
      }
      final count = math.max(current.itemCount, _children.length);
      for (var index = 0; index < count; index++) {
        if (_needsBuild || !_children.containsKey(index)) _buildItem(index);
      }
      _needsBuild = false;
    });
  }

  void _setInstanceCount(int count) {
    owner!.buildScope(this, () {
      _trim(count);
      for (var index = 0; index < count; index++) {
        if (!_children.containsKey(index)) _buildItem(index);
      }
    });
  }

  void _trim(int count) {
    for (final index
        in _children.keys.where((index) => index >= count).toList().reversed) {
      updateChild(_children.remove(index), null, index);
    }
  }

  void _buildItem(int index) {
    final current = widget as _MarqueeViewport;
    Widget built;
    try {
      built = current.itemBuilder(this, index % current.itemCount);
    } catch (error, stack) {
      final details = FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: "OwlMarquee",
        context: ErrorDescription("building item ${index % current.itemCount}"),
      );
      FlutterError.reportError(details);
      built = ErrorWidget.builder(details);
    }
    _children[index] = updateChild(
      _children[index],
      KeyedSubtree(
        key: ValueKey((index ~/ current.itemCount, index % current.itemCount)),
        child: RepaintBoundary(child: built),
      ),
      index,
    )!;
  }

  RenderBox? _before(int index) =>
      index == 0 ? null : _children[index - 1]?.renderObject as RenderBox?;

  @override
  void insertRenderObjectChild(RenderBox child, int slot) {
    renderObject.insert(child, after: _before(slot));
  }

  @override
  void moveRenderObjectChild(RenderBox child, int oldSlot, int newSlot) {
    renderObject.move(child, after: _before(newSlot));
  }

  @override
  void removeRenderObjectChild(RenderBox child, int slot) {
    renderObject.remove(child);
  }

  @override
  void forgetChild(Element child) {
    _children.remove(child.slot);
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _children.values.toList().forEach(visitor);
  }

  @override
  void unmount() {
    renderObject.element = null;
    super.unmount();
  }
}

class _MarqueeParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMarquee extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MarqueeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MarqueeParentData>,
        RenderObjectWithLayoutCallbackMixin {
  _RenderMarquee(this._configuration);

  _MarqueeViewport _configuration;
  _MarqueeElement? element;
  double _cycleExtent = 0;
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  bool get _horizontal =>
      axisDirectionToAxis(_configuration.direction) == Axis.horizontal;
  double _main(Size value) => _horizontal ? value.width : value.height;
  double _cross(Size value) => _horizontal ? value.height : value.width;
  Size _size(double main, double cross) =>
      _horizontal ? Size(main, cross) : Size(cross, main);
  Offset _offset(double main, double cross) =>
      _horizontal ? Offset(main, cross) : Offset(cross, main);

  void update(_MarqueeViewport configuration) {
    final old = _configuration;
    _configuration = configuration;
    if (old.animation != configuration.animation && attached) {
      old.animation.removeListener(markNeedsPaint);
      configuration.animation.addListener(markNeedsPaint);
    }
    if (old.itemCount != configuration.itemCount ||
        old.spacing != configuration.spacing ||
        axisDirectionToAxis(old.direction) !=
            axisDirectionToAxis(configuration.direction)) {
      markNeedsLayout();
    }
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _configuration.animation.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  @override
  void detach() {
    _configuration.animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MarqueeParentData) {
      child.parentData = _MarqueeParentData();
    }
  }

  @override
  void layoutCallback() => element?._buildItems();

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason: "OwlMarquee measures its items during layout.",
      ),
    );
    return constraints.smallest;
  }

  @override
  void performLayout() {
    final viewportExtent = _horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    if (!viewportExtent.isFinite) {
      throw FlutterError(
        "OwlMarquee requires a finite maximum constraint on its movement axis.",
      );
    }
    runLayoutCallback();
    final itemCount = _configuration.itemCount;
    final maxCross = _horizontal ? constraints.maxHeight : constraints.maxWidth;
    final itemConstraints = _horizontal
        ? BoxConstraints(maxHeight: maxCross)
        : BoxConstraints(maxWidth: maxCross);
    final itemSizes = <Size>[];
    var crossExtent = 0.0;
    var cycleExtent = 0.0;
    RenderBox? child = firstChild;
    for (var index = 0; index < itemCount; index++) {
      child!.layout(itemConstraints, parentUsesSize: true);
      if (!child.size.isFinite) {
        throw FlutterError(
          "OwlMarquee item $index must have a finite natural size.",
        );
      }
      itemSizes.add(child.size);
      crossExtent = math.max(crossExtent, _cross(child.size));
      cycleExtent += _main(child.size) + _configuration.spacing;
      child = childAfter(child);
    }
    size = constraints.constrain(_size(viewportExtent, crossExtent));
    if (!cycleExtent.isFinite) {
      throw FlutterError(
        "OwlMarquee cycle extent must be finite (viewport: $viewportExtent).",
      );
    }
    var groupCount = itemCount == 0 ? 0 : 1;
    if (!size.isEmpty && cycleExtent > 0) {
      final ratio = viewportExtent / cycleExtent;
      final allowedGroups = _maxInstanceCount ~/ itemCount;
      if (!ratio.isFinite || ratio > allowedGroups - 2) {
        throw FlutterError(
          "OwlMarquee exceeds $_maxInstanceCount total item instances: "
          "viewport=$viewportExtent, cycle=$cycleExtent, "
          "required groups=ceil($ratio)+2, items per group=$itemCount. "
          "Use larger items or fewer items.",
        );
      }
      groupCount = ratio.ceil() + 2;
    }
    invokeLayoutCallback<BoxConstraints>(
      (_) => element?._setInstanceCount(groupCount * itemCount),
    );
    child = firstChild;
    for (var group = 0; group < groupCount; group++) {
      var position = group * cycleExtent;
      for (var index = 0; index < itemCount; index++) {
        final itemSize = itemSizes[index];
        // Keep constraint-dependent content identical to the original group.
        if (group > 0) child!.layout(itemConstraints, parentUsesSize: true);
        final data = child!.parentData! as _MarqueeParentData;
        data.offset = _offset(position, (_cross(size) - _cross(itemSize)) / 2);
        position += _main(itemSize) + _configuration.spacing;
        child = childAfter(child);
      }
    }
    _cycleExtent = cycleExtent;
    _configuration.onLayout(cycleExtent, !size.isEmpty);
  }

  Offset get _translation => _cycleExtent > 0
      ? _offset(_configuration.animation.value % _cycleExtent - _cycleExtent, 0)
      : Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintItems,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintItems(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    final translation = _translation;
    while (child != null) {
      final data = child.parentData! as _MarqueeParentData;
      final position = data.offset + translation;
      // Shadows and other artwork can extend beyond the child's layout size.
      // Let the viewport clip the paint instead of discarding whole items.
      context.paintChild(child, offset + position);
      child = childAfter(child);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as _MarqueeParentData;
    final position = data.offset + _translation;
    transform.translateByDouble(position.dx, position.dy, 0, 1);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;
}
