import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:owl_haptics/owl_haptics.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("plays, replaces, cancels, and stops through the real host", (
    tester,
  ) async {
    for (final haptic in const <OwlHaptic>[
      OwlHaptic.selection(),
      OwlHaptic.impact(OwlHapticStrength.light),
      OwlHaptic.impact(OwlHapticStrength.medium),
      OwlHaptic.impact(OwlHapticStrength.heavy),
      OwlHaptic.outcome(OwlHapticOutcome.success),
      OwlHaptic.outcome(OwlHapticOutcome.warning),
      OwlHaptic.outcome(OwlHapticOutcome.error),
    ]) {
      final handle = OwlHaptics.play(haptic);
      await handle.started;
      await handle.cancel();
    }

    final first = OwlHaptics.play(
      OwlHaptic.sequence([
        for (var index = 0; index < 6; index += 1)
          OwlHapticPulse(
            at: Duration(milliseconds: index * 100),
            strength: OwlHapticStrength.medium,
          ),
      ]),
    );
    final second = OwlHaptics.play(
      const OwlHaptic.impact(OwlHapticStrength.light),
    );

    await first.cancel();
    await first.cancel();
    await second.started;
    await second.cancel();
    await OwlHaptics.stop();
  });
}
