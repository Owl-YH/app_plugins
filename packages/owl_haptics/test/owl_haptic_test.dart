import "package:flutter_test/flutter_test.dart";
import "package:owl_haptics/owl_haptics.dart";

void main() {
  test("semantic effects use structural equality", () {
    expect(const OwlHaptic.selection(), const OwlHaptic.selection());
    expect(
      const OwlHaptic.impact(OwlHapticStrength.medium),
      const OwlHaptic.impact(OwlHapticStrength.medium),
    );
    expect(
      const OwlHaptic.outcome(OwlHapticOutcome.success),
      const OwlHaptic.outcome(OwlHapticOutcome.success),
    );
    expect(
      const OwlHaptic.impact(OwlHapticStrength.light),
      isNot(const OwlHaptic.impact(OwlHapticStrength.heavy)),
    );
  });

  test("sequence copies values and compares structurally", () {
    final source = [
      OwlHapticPulse(at: Duration.zero, strength: OwlHapticStrength.light),
      OwlHapticPulse(
        at: const Duration(milliseconds: 100),
        strength: OwlHapticStrength.medium,
      ),
    ];
    final sequence = OwlHaptic.sequence(source) as OwlHapticSequence;
    source.add(
      OwlHapticPulse(
        at: const Duration(milliseconds: 200),
        strength: OwlHapticStrength.heavy,
      ),
    );

    expect(sequence.pulses, hasLength(2));
    expect(
      sequence,
      OwlHaptic.sequence([
        OwlHapticPulse(at: Duration.zero, strength: OwlHapticStrength.light),
        OwlHapticPulse(
          at: const Duration(milliseconds: 100),
          strength: OwlHapticStrength.medium,
        ),
      ]),
    );
    expect(() => sequence.pulses.add(source.first), throwsUnsupportedError);
  });

  test("pulse rejects a start outside the short UI window", () {
    expect(
      () => OwlHapticPulse(
        at: const Duration(milliseconds: -1),
        strength: OwlHapticStrength.light,
      ),
      throwsArgumentError,
    );
    expect(
      () => OwlHapticPulse(
        at: const Duration(milliseconds: 2001),
        strength: OwlHapticStrength.light,
      ),
      throwsArgumentError,
    );
  });

  test("sequence rejects empty, dense, and oversized input", () {
    expect(() => OwlHaptic.sequence(const []), throwsArgumentError);
    expect(
      () => OwlHaptic.sequence([
        OwlHapticPulse(at: Duration.zero, strength: OwlHapticStrength.light),
        OwlHapticPulse(
          at: const Duration(milliseconds: 49),
          strength: OwlHapticStrength.light,
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      () => OwlHaptic.sequence([
        for (var index = 0; index < 17; index += 1)
          OwlHapticPulse(
            at: Duration(milliseconds: index * 50),
            strength: OwlHapticStrength.light,
          ),
      ]),
      throwsArgumentError,
    );
  });
}
