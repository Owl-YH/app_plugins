# First release evidence

## Local checks on 2026-09-22

The following checks used Flutter 3.44.6 / Dart 3.12.2. Dependency resolution
completed for all six package roots. No public package was uploaded.

| Package | Focused source checks | Example / archive |
| --- | --- | --- |
| `ndef_kit` | Format and analysis passed; 11 tests passed. | Official pub.dev dry-run passed with 0 warnings; 11 KB compressed archive. |
| `owl_ads` | Format and analysis passed; 5 tests passed. | Official pub.dev dry-run passed with 0 warnings; 4 KB compressed archive. |
| `owl_ads_gromore` | Pigeon drift, non-generated format, analysis, and 13 Dart tests passed with local `owl_ads`. | Hosted `owl_ads`, native/device/SSV gates, and archive pending. |
| `owl_haptics` | Pigeon drift, format, analysis, and 4 Dart tests passed. | Android Debug APK and unsigned iOS simulator Debug app built from the package example. Official pub.dev dry-run passed with 0 warnings; 58 KB compressed archive. Physical feedback remains separate. |
| `owl_marquee` | Format, analysis, and 14 package tests passed. | Independent example's 2 tests passed; official pub.dev dry-run passed with 0 warnings and a 17 KB compressed archive. |
| `spatial_confetti` | Existing source required Dart format; after formatting, analysis and 68 focused package tests passed. | Independent example's 5 tests passed. Initial official dry-run found Pub's `docs/` layout warning; package docs and tool paths now use `doc/`, with a follow-up clean dry-run pending. |

The machine's default `PUB_HOSTED_URL` points at `https://pub.flutter-io.cn`.
The first haptics dry-run reported that mirror and was repeated with
`PUB_HOSTED_URL=https://pub.dev`, producing the same 58 KB archive and zero
warnings. Every release and final dry-run must set that official endpoint
explicitly. A browser session is signed into pub.dev, but CLI upload
authorization has not been checked. The first four clean archives contained
their complete BSD-3-Clause notice, manifests, and expected source/example
files; no local build output or credentials appeared.

The two haptics example builds prove native compilation for those Debug targets,
but do not prove physical device behavior. The GroMore acceptance checklist
still controls its release.
