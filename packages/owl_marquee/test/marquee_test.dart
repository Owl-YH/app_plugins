import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:owl_marquee/owl_marquee.dart";

Widget _host(
  Widget child, {
  double width = 300,
  double? height = 80,
  bool reducedMotion = false,
  bool ticking = true,
  TextDirection textDirection = TextDirection.ltr,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: textDirection,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: TickerMode(enabled: ticking, child: child),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

List<Rect> _rects(WidgetTester tester, String key) => [
  for (final element in find.byKey(ValueKey(key)).evaluate())
    tester.getRect(
      find.byElementPredicate((candidate) => candidate == element),
    ),
];

void _expectCoverage(WidgetTester tester, Axis axis) {
  final bounds = tester.getRect(find.byType(OwlMarquee));
  final rects = [
    ..._rects(tester, "first"),
    ..._rects(tester, "second"),
  ].where((rect) => rect.overlaps(bounds)).toList();
  double start(Rect rect) => axis == Axis.horizontal ? rect.left : rect.top;
  double end(Rect rect) => axis == Axis.horizontal ? rect.right : rect.bottom;
  rects.sort((a, b) => start(a).compareTo(start(b)));
  expect(rects, isNotEmpty);
  expect(start(rects.first), lessThanOrEqualTo(start(bounds) + 0.001));
  expect(end(rects.last), greaterThanOrEqualTo(end(bounds) - 0.001));
  for (var index = 1; index < rects.length; index++) {
    expect(start(rects[index]), closeTo(end(rects[index - 1]), 0.001));
  }
}

void main() {
  test("invalid inputs fail before building items", () {
    Widget builder(BuildContext context, int index) => const SizedBox();
    for (final count in [-1, 65]) {
      expect(
        () => OwlMarquee(itemCount: count, itemBuilder: builder),
        throwsArgumentError,
      );
    }
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(
        () => OwlMarquee(itemCount: 1, itemBuilder: builder, speed: value),
        throwsArgumentError,
      );
      expect(
        () => OwlMarquee(itemCount: 1, itemBuilder: builder, spacing: value),
        throwsArgumentError,
      );
    }
    expect(
      () => OwlMarquee(
        itemCount: 1,
        itemBuilder: builder,
        semanticsLabel: "Complete text",
      ),
      throwsArgumentError,
    );
    expect(
      () => OwlMarquee(
        itemCount: 1,
        itemBuilder: builder,
        semanticsLabel: " ",
        reducedMotionChild: const Text("Complete text"),
      ),
      throwsArgumentError,
    );
  });

  for (final direction in AxisDirection.values) {
    testWidgets(
      "$direction keeps a nonuniform cycle seamless at the configured speed",
      (tester) async {
        final axis = axisDirectionToAxis(direction);
        final horizontal = axis == Axis.horizontal;
        await tester.pumpWidget(
          _host(
            OwlMarquee(
              itemCount: 2,
              direction: direction,
              speed: 20,
              itemBuilder: (context, index) => SizedBox(
                key: ValueKey(index == 0 ? "first" : "second"),
                width: horizontal ? (index == 0 ? 160 : 240) : 80,
                height: horizontal ? 80 : (index == 0 ? 160 : 240),
              ),
            ),
            width: horizontal ? 300 : 80,
            height: horizontal ? 80 : 300,
            textDirection: TextDirection.rtl,
          ),
        );
        _expectCoverage(tester, axis);
        await tester.pump();
        final before = _rects(tester, "first")[1];
        final beforePosition = horizontal ? before.left : before.top;
        await tester.pump(const Duration(seconds: 1));
        final sign =
            direction == AxisDirection.left || direction == AxisDirection.up
            ? -1
            : 1;
        final positions = _rects(
          tester,
          "first",
        ).map((rect) => horizontal ? rect.left : rect.top);
        expect(
          positions.any(
            (position) => (position - beforePosition - sign * 20).abs() < 0.001,
          ),
          isTrue,
        );
        _expectCoverage(tester, axis);
        final count = find.byKey(const ValueKey("first")).evaluate().length;
        await tester.pump(const Duration(seconds: 20));
        _expectCoverage(tester, axis);
        expect(find.byKey(const ValueKey("first")).evaluate().length, count);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets("spacing is retained at the last-to-first seam", (tester) async {
    await tester.pumpWidget(
      _host(
        OwlMarquee(
          itemCount: 1,
          spacing: 12,
          itemBuilder: (context, index) =>
              const SizedBox(key: ValueKey("first"), width: 100, height: 40),
        ),
      ),
    );
    final rects = _rects(tester, "first");
    for (var index = 1; index < rects.length; index++) {
      expect(rects[index].left - rects[index - 1].right, closeTo(12, 0.001));
    }
  });

  testWidgets(
    "natural sizes follow cross-axis constraints and later child changes",
    (tester) async {
      final size = ValueNotifier(const Size(140, 30));
      addTearDown(size.dispose);
      final marquee = OwlMarquee(
        itemCount: 1,
        paused: true,
        itemBuilder: (context, index) => ValueListenableBuilder<Size>(
          valueListenable: size,
          builder: (context, value, child) => SizedBox(
            key: const ValueKey("first"),
            width: value.width,
            height: value.height,
          ),
        ),
      );
      await tester.pumpWidget(_host(marquee, height: null));
      expect(tester.getSize(find.byType(OwlMarquee)), const Size(300, 30));
      size.value = const Size(90, 45);
      await tester.pump();
      expect(tester.getSize(find.byType(OwlMarquee)), const Size(300, 45));
      final rects = _rects(tester, "first");
      expect(rects.every((rect) => rect.size == const Size(90, 45)), isTrue);
      expect(rects[1].left - rects[0].left, 90);
      await tester.pumpWidget(_host(marquee, width: 360, height: 80));
      expect(tester.getSize(find.byType(OwlMarquee)), const Size(360, 80));
      expect(_rects(tester, "first").first.height, 45);
      expect(
        _rects(tester, "first").first.center.dy,
        tester.getCenter(find.byType(OwlMarquee)).dy,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("translation does not rebuild or lay out stable items", (
    tester,
  ) async {
    var builds = 0;
    var layouts = 0;
    await tester.pumpWidget(
      _host(
        OwlMarquee(
          itemCount: 1,
          itemBuilder: (context, index) {
            builds++;
            return _LayoutCounter(
              onLayout: () => layouts++,
              child: const SizedBox(width: 120, height: 40),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final initialBuilds = builds;
    final initialLayouts = layouts;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(builds, initialBuilds);
    expect(layouts, initialLayouts);
  });

  testWidgets("original and repeated items use the same natural constraints", (
    tester,
  ) async {
    final itemConstraints = <BoxConstraints>[];
    await tester.pumpWidget(
      _host(
        OwlMarquee(
          itemCount: 1,
          itemBuilder: (context, index) => LayoutBuilder(
            builder: (context, constraints) {
              itemConstraints.add(constraints);
              return SizedBox(
                width: 120,
                height: 40,
                child: ColoredBox(
                  color: constraints.hasBoundedWidth ? Colors.blue : Colors.red,
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(itemConstraints.length, greaterThan(1));
    expect(itemConstraints.toSet(), {const BoxConstraints(maxHeight: 80)});
    final artwork = find.descendant(
      of: find.byType(OwlMarquee),
      matching: find.byType(ColoredBox),
    );
    expect(
      tester
          .widgetList<ColoredBox>(artwork)
          .every((box) => box.color == Colors.red),
      isTrue,
    );
    final layouts = itemConstraints.length;
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(itemConstraints.length, layouts);
    expect(tester.takeException(), isNull);
  });

  testWidgets("shadows remain visible after item bounds leave the viewport", (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: OwlMarquee(
              itemCount: 1,
              direction: AxisDirection.left,
              speed: 110,
              spacing: 100,
              itemBuilder: (context, index) => const SizedBox(
                width: 100,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [BoxShadow(color: Colors.red, spreadRadius: 20)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixel = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List((40 * image.width + 5) * 4, 4).toList();
      } finally {
        image.dispose();
      }
    });
    // The item ends at x=-10; its 20-pixel shadow still reaches x=10.
    expect(pixel, [244, 67, 54, 255]);
  });

  testWidgets(
    "pause, speed, reverse, host and app suspension retain position",
    (tester) async {
      Widget builder(BuildContext context, int index) =>
          const SizedBox(key: ValueKey("first"), width: 200, height: 40);
      Widget subject({
        double speed = 20,
        bool paused = false,
        bool ticking = true,
        AxisDirection direction = AxisDirection.right,
      }) => _host(
        OwlMarquee(
          itemCount: 1,
          itemBuilder: builder,
          direction: direction,
          speed: speed,
          paused: paused,
        ),
        ticking: ticking,
      );
      double position() => _rects(tester, "first")[1].left;
      await tester.pumpWidget(subject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final moved = position();
      await tester.pumpWidget(subject(paused: true));
      await tester.pump(const Duration(seconds: 10));
      expect(position(), moved);
      await tester.pumpWidget(subject(speed: 0));
      await tester.pump(const Duration(seconds: 10));
      expect(position(), moved);
      await tester.pumpWidget(subject(speed: 40));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(position(), closeTo(moved + 40, 0.001));
      await tester.pumpWidget(
        subject(speed: 40, direction: AxisDirection.left),
      );
      expect(position(), closeTo(moved + 40, 0.001));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(position(), closeTo(moved + 20, 0.001));
      await tester.pumpWidget(subject(ticking: false));
      final suspended = position();
      await tester.pump(const Duration(seconds: 10));
      expect(position(), suspended);
      await tester.pumpWidget(subject());
      await tester.pump();
      expect(position(), suspended);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(position(), suspended);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(position(), closeTo(suspended + 20, 0.001));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets("empty, zero-area and zero-cycle layouts remain static", (
    tester,
  ) async {
    for (final count in [0, 1]) {
      await tester.pumpWidget(
        _host(
          OwlMarquee(
            itemCount: count,
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      _host(
        OwlMarquee(
          itemCount: 1,
          itemBuilder: (context, index) =>
              const SizedBox(width: 100, height: 40),
        ),
        width: 0,
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("tiny cycles fail before allocating repeated instances", (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      _host(
        OwlMarquee(
          itemCount: 1,
          itemBuilder: (context, index) {
            builds++;
            return const SizedBox(width: 0.1, height: 40);
          },
        ),
      ),
    );
    expect(
      tester.takeException().toString(),
      contains("512 total item instances"),
    );
    expect(builds, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    "semantics stay stable and reduced motion replaces only the track",
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      final marquee = OwlMarquee(
        itemCount: 1,
        semanticsLabel: "Full announcement",
        reducedMotionChild: TextButton(
          onPressed: () => taps++,
          child: const Text("Read full announcement"),
        ),
        itemBuilder: (context, index) => SizedBox(
          width: 180,
          height: 40,
          child: TextButton(
            onPressed: () => taps++,
            child: const Text("Track control"),
          ),
        ),
      );
      await tester.pumpWidget(_host(marquee));
      expect(find.bySemanticsLabel("Full announcement"), findsOneWidget);
      expect(find.bySemanticsLabel("Track control"), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(OwlMarquee)));
      expect(taps, 0);
      final trackButtons = find.widgetWithText(TextButton, "Track control");
      for (final element in trackButtons.evaluate()) {
        final focus = Focus.of(element);
        expect(focus.canRequestFocus, isFalse);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(find.bySemanticsLabel("Full announcement"), findsOneWidget);
      await tester.pumpWidget(_host(marquee, reducedMotion: true));
      expect(trackButtons, findsNothing);
      expect(find.bySemanticsLabel("Full announcement"), findsNothing);
      expect(find.bySemanticsLabel("Read full announcement"), findsOneWidget);
      await tester.tap(find.text("Read full announcement"));
      expect(taps, 1);
      await tester.pumpWidget(_host(marquee));
      expect(find.bySemanticsLabel("Full announcement"), findsOneWidget);
      expect(find.text("Read full announcement"), findsNothing);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );
}

/// Counts real layout passes without substituting the child's layout behavior.
class _LayoutCounter extends SingleChildRenderObjectWidget {
  const _LayoutCounter({required this.onLayout, required super.child});
  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutCounter(onLayout);
}

class _RenderLayoutCounter extends RenderProxyBox {
  _RenderLayoutCounter(this.onLayout);
  final VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
