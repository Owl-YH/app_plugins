import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_confetti/spatial_confetti.dart';
import 'simulation_test.dart' show effect;

Widget root(OverlayEntry entry, {bool reduced = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Overlay(initialEntries: [entry]),
  ),
);

void main() {
  testWidgets('target disposal before the first host build still completes', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      root(
        OverlayEntry(
          builder: (value) {
            context = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final playback = Confetti.launch(context, effect: effect());
    await tester.pumpWidget(const SizedBox());
    expect(await playback.done, ConfettiOverlayCompletion.hostDisposed);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overlay completion releases its host and lets taps pass through',
    (tester) async {
      late BuildContext context;
      var taps = 0;
      final entry = OverlayEntry(
        builder: (value) {
          context = value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          );
        },
      );
      await tester.pumpWidget(root(entry));
      final playback = Confetti.launch(
        context,
        effect: effect(
          lifetime: const Duration(milliseconds: 100),
          particle: const PaperParticle.noBend(),
        ),
      );
      await tester.pump();
      await tester.tapAt(const Offset(200, 200));
      expect(taps, 1);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(await playback.done, ConfettiOverlayCompletion.completed);
      expect(find.byType(ConfettiView), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('overlay owns pause resume and immediate finish', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      root(
        OverlayEntry(
          builder: (value) {
            context = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final playback = Confetti.launch(context, effect: effect());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final controller = tester
        .widget<ConfettiView>(find.byType(ConfettiView))
        .controller;
    final time = controller.simulation.time;
    playback.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(playback.status, ConfettiOverlayStatus.paused);
    expect(controller.simulation.time, time);
    playback.resume();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.simulation.time, greaterThan(time));
    playback.finish();
    expect(await playback.done, ConfettiOverlayCompletion.completed);
    await tester.pump();
    expect(find.byType(ConfettiView), findsNothing);
    expect(controller.stats.particles, 0);
  });

  testWidgets(
    'replacement and cancellation before mount cannot cancel a later request',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        root(
          OverlayEntry(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final first = Confetti.launch(context, effect: effect());
      final second = Confetti.launch(context, effect: effect());
      expect(await first.done, ConfettiOverlayCompletion.replaced);
      second.cancel();
      final third = Confetti.launch(context, effect: effect());
      first.cancel();
      second.finish();
      await tester.pump();
      expect(find.byType(ConfettiView), findsOneWidget);
      expect(third.isComplete, isFalse);
      third.cancel();
      expect(await third.done, ConfettiOverlayCompletion.cancelled);
      await tester.pump();
      expect(find.byType(ConfettiView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion suppresses launches and retires a live host', (
    tester,
  ) async {
    late BuildContext context;
    final entry = OverlayEntry(
      builder: (value) {
        context = value;
        return const SizedBox.expand();
      },
    );
    await tester.pumpWidget(root(entry, reduced: true));
    final suppressed = Confetti.launch(context, effect: effect());
    expect(await suppressed.done, ConfettiOverlayCompletion.reducedMotion);
    await tester.pump();
    expect(find.byType(ConfettiView), findsNothing);
    await tester.pumpWidget(root(entry));
    final live = Confetti.launch(context, effect: effect());
    await tester.pump();
    await tester.pumpWidget(root(entry, reduced: true));
    expect(await live.done, ConfettiOverlayCompletion.reducedMotion);
    await tester.pump();
    expect(find.byType(ConfettiView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing the target Overlay completes and releases the request',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        root(
          OverlayEntry(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final playback = Confetti.launch(context, effect: effect());
      await tester.pump();
      final controller = tester
          .widget<ConfettiView>(find.byType(ConfettiView))
          .controller;
      await tester.pumpWidget(const SizedBox());
      expect(await playback.done, ConfettiOverlayCompletion.hostDisposed);
      expect(controller.stats.particles, 0);
      playback.cancel();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('different target Overlays retain independent requests', (
    tester,
  ) async {
    final contexts = <BuildContext>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) {
                        contexts.add(context);
                        return const SizedBox.expand();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    final first = Confetti.launch(contexts[0], effect: effect());
    final second = Confetti.launch(contexts[1], effect: effect());
    await tester.pump();
    expect(find.byType(ConfettiView), findsNWidgets(2));
    first.cancel();
    await tester.pump();
    expect(second.isComplete, isFalse);
    expect(find.byType(ConfettiView), findsOneWidget);
    second.cancel();
    await tester.pump();
  });
}
