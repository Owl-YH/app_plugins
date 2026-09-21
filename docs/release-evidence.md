# First release evidence

## Local checks on 2026-09-22

The following checks used Flutter 3.44.6 / Dart 3.12.2. Dependency resolution
completed for all six package roots. No public package was uploaded.

| Package | Focused source checks | Example / archive |
| --- | --- | --- |
| `ndef_kit` | Format and analysis passed; 11 tests passed. | Archive pending complete license and rights confirmation. |
| `owl_ads` | Format and analysis passed; 5 tests passed. | Archive pending complete license and rights confirmation. |
| `owl_ads_gromore` | Pigeon drift, non-generated format, analysis, and 13 Dart tests passed with local `owl_ads`. | Hosted `owl_ads`, native/device/SSV gates, and archive pending. |
| `owl_haptics` | Pigeon drift, format, analysis, and 4 Dart tests passed. | Android Debug APK and unsigned iOS simulator Debug app built from the package example. Official pub.dev dry-run passed with 0 warnings; 58 KB compressed archive. Physical feedback and final copyright/asset confirmation pending. |
| `owl_marquee` | Format, analysis, and 14 package tests passed. | Independent example's 2 tests passed; archive pending complete license and rights confirmation. |
| `spatial_confetti` | Existing source required Dart format; after formatting, analysis and 68 focused package tests passed. | Independent example's 5 tests passed; archive pending complete license and media rights confirmation. |

The machine's default `PUB_HOSTED_URL` points at `https://pub.flutter-io.cn`.
The first haptics dry-run reported that mirror and was repeated with
`PUB_HOSTED_URL=https://pub.dev`, producing the same 58 KB archive and zero
warnings. Every release and final dry-run must set that official endpoint
explicitly. A browser session is signed into pub.dev, but CLI upload
authorization has not been checked.

The two haptics example builds prove native compilation for those Debug targets,
but do not prove physical device behavior. The GroMore acceptance checklist
still controls its release.
