import "dart:collection";

/// Platform-neutral strength for an impact or sequence pulse.
enum OwlHapticStrength { light, medium, heavy }

/// Platform-neutral result feedback.
enum OwlHapticOutcome { success, warning, error }

/// A short platform-neutral haptic effect.
sealed class OwlHaptic {
  const OwlHaptic();

  /// A subtle selection change.
  const factory OwlHaptic.selection() = OwlHapticSelection;

  /// A discrete impact with semantic [strength].
  const factory OwlHaptic.impact(OwlHapticStrength strength) = OwlHapticImpact;

  /// A semantic result notification.
  const factory OwlHaptic.outcome(OwlHapticOutcome outcome) =
      OwlHapticOutcomeEffect;

  /// A bounded sequence of distinguishable transient [pulses].
  factory OwlHaptic.sequence(Iterable<OwlHapticPulse> pulses) =
      OwlHapticSequence;
}

/// A subtle selection change.
final class OwlHapticSelection extends OwlHaptic {
  /// Creates a selection effect.
  const OwlHapticSelection();

  @override
  bool operator ==(Object other) => other is OwlHapticSelection;

  @override
  int get hashCode => Object.hash(OwlHapticSelection, 0);

  @override
  String toString() => "OwlHaptic.selection()";
}

/// A discrete impact.
final class OwlHapticImpact extends OwlHaptic {
  /// Creates an impact with [strength].
  const OwlHapticImpact(this.strength);

  /// Requested semantic strength.
  final OwlHapticStrength strength;

  @override
  bool operator ==(Object other) =>
      other is OwlHapticImpact && other.strength == strength;

  @override
  int get hashCode => Object.hash(OwlHapticImpact, strength);

  @override
  String toString() => "OwlHaptic.impact(${strength.name})";
}

/// A semantic result notification.
final class OwlHapticOutcomeEffect extends OwlHaptic {
  /// Creates a result effect for [outcome].
  const OwlHapticOutcomeEffect(this.outcome);

  /// Requested semantic result.
  final OwlHapticOutcome outcome;

  @override
  bool operator ==(Object other) =>
      other is OwlHapticOutcomeEffect && other.outcome == outcome;

  @override
  int get hashCode => Object.hash(OwlHapticOutcomeEffect, outcome);

  @override
  String toString() => "OwlHaptic.outcome(${outcome.name})";
}

/// One transient pulse in a sequence.
final class OwlHapticPulse {
  /// Creates a pulse at [at] with [strength].
  OwlHapticPulse({required this.at, required this.strength}) {
    if (at.isNegative || at > OwlHapticSequence.maxStart) {
      throw ArgumentError.value(
        at,
        "at",
        "must be between Duration.zero and ${OwlHapticSequence.maxStart}",
      );
    }
  }

  /// Start offset relative to sequence playback.
  final Duration at;

  /// Requested semantic strength.
  final OwlHapticStrength strength;

  @override
  bool operator ==(Object other) =>
      other is OwlHapticPulse && other.at == at && other.strength == strength;

  @override
  int get hashCode => Object.hash(at, strength);

  @override
  String toString() => "OwlHapticPulse(at: $at, strength: ${strength.name})";
}

/// A bounded immutable sequence of transient pulses.
final class OwlHapticSequence extends OwlHaptic {
  /// Creates and validates a sequence from [pulses].
  factory OwlHapticSequence(Iterable<OwlHapticPulse> pulses) {
    final copy = List<OwlHapticPulse>.of(pulses, growable: false);
    if (copy.isEmpty || copy.length > maxPulses) {
      throw ArgumentError.value(
        copy.length,
        "pulses",
        "must contain 1 to $maxPulses pulses",
      );
    }

    for (var index = 1; index < copy.length; index += 1) {
      final gap = copy[index].at - copy[index - 1].at;
      if (gap < minGap) {
        throw ArgumentError.value(
          copy[index].at,
          "pulses[$index].at",
          "must be at least $minGap after the previous pulse",
        );
      }
    }
    return OwlHapticSequence._(copy);
  }

  OwlHapticSequence._(List<OwlHapticPulse> pulses)
    : pulses = UnmodifiableListView<OwlHapticPulse>(pulses);

  /// Maximum number of pulses in one short UI sequence.
  static const int maxPulses = 16;

  /// Minimum start separation for distinguishable transient pulses.
  static const Duration minGap = Duration(milliseconds: 50);

  /// Latest permitted pulse start for a short UI sequence.
  static const Duration maxStart = Duration(seconds: 2);

  /// Immutable pulse list in ascending start order.
  final List<OwlHapticPulse> pulses;

  @override
  bool operator ==(Object other) {
    if (other is! OwlHapticSequence || other.pulses.length != pulses.length) {
      return false;
    }
    for (var index = 0; index < pulses.length; index += 1) {
      if (other.pulses[index] != pulses[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([OwlHapticSequence, ...pulses]);

  @override
  String toString() => "OwlHaptic.sequence($pulses)";
}
