import "package:pigeon/pigeon.dart";

enum HapticKind { selection, impact, outcome, sequence }

enum HapticLevel { light, medium, heavy }

enum HapticResult { success, warning, error }

class HapticPulse {
  HapticPulse({required this.atMillis, required this.strength});

  int atMillis;
  HapticLevel strength;
}

class HapticRequest {
  HapticRequest({
    required this.id,
    required this.kind,
    this.strength,
    this.outcome,
    required this.pulses,
  });

  int id;
  HapticKind kind;
  HapticLevel? strength;
  HapticResult? outcome;
  List<HapticPulse> pulses;
}

@HostApi()
abstract class OwlHapticsHostApi {
  void play(HapticRequest request);

  void cancel(int id);

  void stop();
}
