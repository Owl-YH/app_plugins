# Package-owned checks

Run checks from the independent plugins repository. Package examples use their
local package source so a source change can be tested before publication.

| Package | Focused checks |
| --- | --- |
| `ndef_kit` | `cd packages/ndef_kit && flutter pub get && dart format --output=none --set-exit-if-changed lib test && flutter analyze --no-pub && flutter test --no-pub`; use the root demo and physical NFC tag for real read/write acceptance. |
| `owl_ads` | `cd packages/owl_ads && dart pub get && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test`; no native build. |
| `owl_ads_gromore` | `cd packages/owl_ads_gromore && flutter pub get && bash tool/check_pigeon.sh && find lib test pigeons -type f -name '*.dart' ! -name '*.g.dart' -print0 \| xargs -0 dart format --output=none --set-exit-if-changed && flutter analyze --no-pub && flutter test --no-pub`; then follow [`release-checklist.md`](../packages/owl_ads_gromore/docs/release-checklist.md) for native, device, and backend evidence. |
| `owl_haptics` | `cd packages/owl_haptics && bash tool/verify.sh`; native Android/iOS checks and in-hand tactile acceptance are described in its README. |
| `owl_marquee` | `cd packages/owl_marquee && flutter pub get && dart format --output=none --set-exit-if-changed lib test example/lib example/test && flutter analyze --no-pub && flutter test --no-pub`; then `cd example && flutter test --no-pub test/examples_test.dart`. |
| `spatial_confetti` | `cd packages/spatial_confetti && bash tool/verify.sh`; use its README for the additional real-engine and example build checks. |

The haptics and confetti scripts preserve the former MyCards package checks in
this source-owning repository. They check committed Pigeon output and focused
package/example behavior; they do not stand in for device performance or
physical feedback evidence.
