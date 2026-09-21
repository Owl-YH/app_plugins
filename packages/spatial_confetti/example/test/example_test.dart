import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'package:spatial_confetti_example/main.dart';

void main() {
  testWidgets('streak mode emits short-lived independent velocity bands', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ConfettiExample());
    await tester.tap(find.text('光迹'));
    await tester.pump();
    await tester.tap(find.text('发射一批'));
    await tester.pump();
    final controller = tester
        .widget<ConfettiView>(find.byType(ConfettiView))
        .controller;
    expect(controller.stats.streakParticles, 64);
    expect(
      controller.simulation.snapshot.every((p) => p.particle is StreakParticle),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    // Host deliberately bounds catch-up time; advance the remaining fixed-step duration explicitly.
    controller.simulation.advance(const Duration(milliseconds: 300));
    expect(controller.stats.streakParticles, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'single paper starts at rest and turns through actual air interaction',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const ConfettiExample());
      await tester.tap(find.text('静止释放单张纸片'));
      await tester.pump();
      final controller = tester
          .widget<ConfettiView>(find.byType(ConfettiView))
          .controller;
      controller.pause();
      final initial = controller.simulation.snapshot.single;
      expect(initial.particle, isA<PaperParticle>());
      expect(initial.velocity, Vec3.zero);
      expect(initial.angularVelocity, Vec3.zero);
      controller.simulation.advance(const Duration(seconds: 1));
      final current = controller.simulation.snapshot.single;
      expect(current.angularVelocity!.length, greaterThan(.1));
      expect((current.position - initial.position).length, greaterThan(.1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('example emits real particles and controls their playback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ConfettiExample());
    await tester.tap(find.text('观察单条彩带'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final controller = tester
        .widget<ConfettiView>(find.byType(ConfettiView))
        .controller;
    expect(
      controller.simulation.snapshot.single.particle,
      isA<RibbonParticle>(),
    );
    expect(controller.simulation.snapshot.single.nodes.length, 21);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    final time = controller.simulation.time;
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.simulation.time, time);
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(controller.isIdle, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('single ribbon obeys speed and replay restores the wind clock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ConfettiExample());
    await tester.scrollUntilVisible(
      find.text('发射速度'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    final speed = tester
        .widgetList<Slider>(find.byType(Slider))
        .firstWhere((slider) => slider.min == 2 && slider.max == 16);
    speed.onChanged!(12);
    await tester.pump();
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.tap(find.text('观察单条彩带'));
    await tester.pump();
    ConfettiController controller() =>
        tester.widget<ConfettiView>(find.byType(ConfettiView)).controller;
    expect(
      controller().simulation.snapshot.single.velocity.length,
      closeTo(12, 1e-8),
    );
    await tester.tap(find.text('重播同一种子'));
    await tester.pump();
    final first = controller();
    expect(first.simulation.time, Duration.zero);
    first.pause();
    first.simulation.advance(const Duration(milliseconds: 500));
    final positions = first.simulation.snapshot.map((p) => p.position).toList();
    await tester.tap(find.text('重播同一种子'));
    await tester.pump();
    final second = controller();
    expect(identical(first, second), isFalse);
    expect(second.simulation.time, Duration.zero);
    second.pause();
    second.simulation.advance(const Duration(milliseconds: 500));
    expect(second.simulation.snapshot.map((p) => p.position), positions);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shape selection and independent paper air controls configure real births',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const ConfettiExample());
      await tester.tap(find.text('纸片'));
      await tester.pump();
      await tester.tap(find.text('星形'));
      await tester.pump();
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        if (slider.min == 0 && (slider.max == 1 || slider.max == 4))
          slider.onChanged!(0);
      }
      await tester.pump();
      await tester.tap(find.text('发射一批'));
      await tester.pump();
      final controller = tester
          .widget<ConfettiView>(find.byType(ConfettiView))
          .controller;
      expect(controller.stats.livingParticles, 64);
      for (final p in controller.simulation.snapshot) {
        final recipe = p.particle as PaperParticle;
        expect(recipe.shape, const PaperShape.star());
        expect(recipe.dragCoefficient, 0);
        expect(recipe.surfaceFriction, 0);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
