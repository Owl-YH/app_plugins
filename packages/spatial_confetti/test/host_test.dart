import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

Widget host(
  ConfettiController controller, {
  bool reduced = false,
  bool enabled = true,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: TickerMode(
      enabled: enabled,
      child: SizedBox(
        width: 400,
        height: 400,
        child: ConfettiView(controller: controller),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'pause and resume preserve simulation time without wall-clock catch-up',
    (tester) async {
      final controller = ConfettiController();
      await tester.pumpWidget(host(controller));
      controller.emit(effect());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final time = controller.simulation.time;
      expect(time, const Duration(milliseconds: 100));
      controller.pause();
      await tester.pump(const Duration(seconds: 5));
      expect(controller.simulation.time, time);
      controller.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        controller.simulation.time,
        time + const Duration(milliseconds: 50),
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('TickerMode suspends and idle playback stops scheduling ticks', (
    tester,
  ) async {
    final controller = ConfettiController();
    await tester.pumpWidget(host(controller));
    final playback = controller.emit(
      effect(
        lifetime: const Duration(milliseconds: 50),
        particle: const PaperParticle.noBend(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(host(controller, enabled: false));
    final frozen = controller.simulation.time;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.simulation.time, frozen);
    await tester.pumpWidget(host(controller));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await playback.done, ConfettiCompletion.completed);
    expect(controller.isIdle, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'reduced motion clears active effects and suppresses new effects',
    (tester) async {
      final controller = ConfettiController();
      await tester.pumpWidget(host(controller));
      final first = controller.emit(effect());
      await tester.pump();
      await tester.pumpWidget(host(controller, reduced: true));
      expect(await first.done, ConfettiCompletion.cancelled);
      final next = controller.emit(effect());
      expect(await next.done, ConfettiCompletion.cancelled);
      expect(controller.isIdle, isTrue);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('host disposal cancels its playback and releases all particles', (
    tester,
  ) async {
    final controller = ConfettiController();
    await tester.pumpWidget(host(controller));
    final playback = controller.emit(effect());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    expect(await playback.done, ConfettiCompletion.cancelled);
    expect(controller.stats.particles, 0);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
