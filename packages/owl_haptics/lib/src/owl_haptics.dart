import "dart:async";

import "messages.g.dart";
import "owl_haptic.dart";
import "owl_haptic_handle.dart";

/// Plays short foreground UI haptics.
abstract final class OwlHaptics {
  static final OwlHapticsHostApi _api = OwlHapticsHostApi();
  static Future<void> _tail = Future<void>.value();
  static int _nextId = 1;

  /// Starts [haptic] and immediately returns its cancelable handle.
  static OwlHapticHandle play(OwlHaptic haptic) {
    final id = _allocateId();
    final started = _enqueue(() => _api.play(_message(id, haptic)));
    return _OwlHapticHandle(id: id, started: started);
  }

  /// Stops remaining playback owned by this Flutter Engine.
  static Future<void> stop() => _enqueue(_api.stop);

  static Future<void> _cancel(int id) => _enqueue(() => _api.cancel(id));

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await operation();
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  static int _allocateId() {
    const maxInt64 = 0x7fffffffffffffff;
    if (_nextId > maxInt64) {
      throw StateError("OwlHaptics playback identity exhausted.");
    }
    return _nextId++;
  }

  static HapticRequest _message(int id, OwlHaptic haptic) => switch (haptic) {
    OwlHapticSelection() => HapticRequest(
      id: id,
      kind: HapticKind.selection,
      pulses: const [],
    ),
    OwlHapticImpact(:final strength) => HapticRequest(
      id: id,
      kind: HapticKind.impact,
      strength: _strength(strength),
      pulses: const [],
    ),
    OwlHapticOutcomeEffect(:final outcome) => HapticRequest(
      id: id,
      kind: HapticKind.outcome,
      outcome: switch (outcome) {
        OwlHapticOutcome.success => HapticResult.success,
        OwlHapticOutcome.warning => HapticResult.warning,
        OwlHapticOutcome.error => HapticResult.error,
      },
      pulses: const [],
    ),
    OwlHapticSequence(:final pulses) => HapticRequest(
      id: id,
      kind: HapticKind.sequence,
      pulses: [
        for (final pulse in pulses)
          HapticPulse(
            atMillis: pulse.at.inMilliseconds,
            strength: _strength(pulse.strength),
          ),
      ],
    ),
  };

  static HapticLevel _strength(OwlHapticStrength strength) =>
      switch (strength) {
        OwlHapticStrength.light => HapticLevel.light,
        OwlHapticStrength.medium => HapticLevel.medium,
        OwlHapticStrength.heavy => HapticLevel.heavy,
      };
}

final class _OwlHapticHandle implements OwlHapticHandle {
  _OwlHapticHandle({required this.id, required this.started});

  final int id;

  @override
  final Future<void> started;

  Future<void>? _canceled;

  @override
  Future<void> cancel() => _canceled ??= OwlHaptics._cancel(id);
}
