# owl_haptics

`owl_haptics` provides short, semantic, cancelable foreground UI haptics for Android and iOS. It favors platform selection, impact, and outcome feedback, while supporting bounded transient sequences without exposing device-specific waveform arrays.

After the first `0.1.0` release is available on pub.dev, add:

```yaml
dependencies:
  owl_haptics: ^0.1.0
```

## Use

```dart
final handle = OwlHaptics.play(
  const OwlHaptic.impact(OwlHapticStrength.medium),
);

await handle.started; // Native start accepted, not physical completion.
await handle.cancel();
```

A six-pulse rising sequence:

```dart
final handle = OwlHaptics.play(
  OwlHaptic.sequence([
    for (var index = 0; index < 6; index += 1)
      OwlHapticPulse(
        at: Duration(milliseconds: index * 100),
        strength: index < 2
            ? OwlHapticStrength.light
            : index < 4
            ? OwlHapticStrength.medium
            : OwlHapticStrength.heavy,
      ),
  ]),
);
```

`play` returns immediately. Store the handle privately with the UI owner and cancel it when that owner is replaced or disposed. `cancel` is idempotent and cannot stop a newer request. `OwlHaptics.stop()` is available for Engine-owner cleanup.

## Behavior

- The newest request replaces remaining playback from the previous request.
- Selection, impact, and outcome effects use native semantic APIs.
- Android preserves distinct Flutter-baseline heavy, warning, and error semantics rather than treating warnings as rejection.
- Sequences contain 1–16 pulses, use increasing starts separated by at least 50 ms, and end within a 2-second start window.
- Every iOS sequence owns a generation-fenced Core Haptics session that is stopped and released on completion, cancellation, failure, reset, or lifecycle exit.
- Unsupported hardware, disabled haptics, or background state degrades to no output.
- The package does not own business mapping, preferences, confetti, sound, notifications, looping, pause/resume, or background vibration.
- A semantic impact that has already fired cannot be undone; cancellation stops only remaining scheduled output.

Android includes the normal `VIBRATE` manifest permission and requests no runtime permission. iOS uses UIKit feedback generators and Core Haptics where supported. Device hardware and operating-system policy determine the final physical feel, so production effects require in-hand review on every supported platform baseline.

## Development

Pigeon 28.0.0 generates the single ordered host contract:

```bash
dart run pigeon \
  --input pigeons/messages.dart \
  --package_name owl_haptics \
  --dart_out lib/src/messages.g.dart \
  --kotlin_out android/src/main/kotlin/com/owlllwo/owl_haptics/Messages.g.kt \
  --kotlin_package com.owlllwo.owl_haptics \
  --swift_out ios/owl_haptics/Sources/owl_haptics/Messages.g.swift
dart format lib/src/messages.g.dart
```

Run `flutter analyze`, `flutter test`, Android native unit tests, iOS `build-for-testing`, and both example platform builds after protocol or native changes. The native tests exercise production fencing logic without a simulated platform. The example exposes manual controls for tactile acceptance; its integration test calls the real native host.

The package-owned Dart and Pigeon check is `bash tool/verify.sh` from this
directory. Native builds and physical feedback checks remain separate evidence.
