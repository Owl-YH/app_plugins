# First release evidence

## Local checks on 2026-09-22

The following checks used Flutter 3.44.6 / Dart 3.12.2. Dependency resolution
completed for all six package roots. The five independent packages were then
uploaded to pub.dev from clean source commit `ea20301`.

| Package | Focused source checks | Example / archive |
| --- | --- | --- |
| `ndef_kit` | Format and analysis passed; 11 tests passed. | Official pub.dev dry-run passed with 0 warnings; 11 KB compressed archive. |
| `owl_ads` | Format and analysis passed; 5 tests passed. | Official pub.dev dry-run passed with 0 warnings; 4 KB compressed archive. |
| `owl_ads_gromore` | Pigeon drift, non-generated format, analysis, and 13 Dart tests passed with local `owl_ads`. | Hosted `owl_ads`, native/device/SSV gates, and archive pending. |
| `owl_haptics` | Pigeon drift, format, analysis, and 4 Dart tests passed. | Android Debug APK and unsigned iOS simulator Debug app built from the package example. Official pub.dev dry-run passed with 0 warnings; 58 KB compressed archive. Physical feedback remains separate. |
| `owl_marquee` | Format, analysis, and 14 package tests passed. | Independent example's 2 tests passed; official pub.dev dry-run passed with 0 warnings and a 17 KB compressed archive. |
| `spatial_confetti` | Existing source required Dart format; after formatting, analysis and 68 focused package tests passed. | Independent example's 5 tests passed. After moving package docs and tool paths to `doc/`, the official pub.dev dry-run passed with 0 warnings and a 1 MB compressed archive. The archive includes the complete license and `doc/`, with no embedded-font SVG or local build output. |

The machine's default `PUB_HOSTED_URL` points at `https://pub.flutter-io.cn`.
The first haptics dry-run reported that mirror and was repeated with
`PUB_HOSTED_URL=https://pub.dev`, producing the same 58 KB archive and zero
warnings. Every release and final dry-run must set that official endpoint
explicitly. A browser session is signed into pub.dev, but CLI upload
authorization succeeded for the signed-in personal account. The terminal needed
the machine's existing HTTP proxy to reach Google's OAuth token endpoint; the
official package host remained `https://pub.dev`. All five clean archives contained
their complete BSD-3-Clause notice, manifests, and expected source/example
files; no local build output or credentials appeared.

The two haptics example builds prove native compilation for those Debug targets,
but do not prove physical device behavior. The GroMore acceptance checklist
still controls its release.

## Published releases

The pub.dev package API returned version `0.1.0` for each package. A fresh
Flutter consumer downloaded all five exact versions from `https://pub.dev` and
recorded hosted lockfile entries with SHA-256 checksums. The annotated tags
below point to `ea20301` and were pushed to
`https://github.com/Owl-YH/app_plugins`.

| Package | Tag | SHA-256 in fresh consumer lockfile |
| --- | --- | --- |
| `owl_ads` | `owl_ads-v0.1.0` | `dcf7ce0fc9cc98a9a974677d71a1aac971e2a1eb4a1331fbab7f11785e0834e5` |
| `ndef_kit` | `ndef_kit-v0.1.0` | `bf5a9308fb5375ddf41a112d500c56e3210155a031fa5222fddf0faa304d07d6` |
| `owl_haptics` | `owl_haptics-v0.1.0` | `992fb623fadf249d3c35296b1d3a137cb8b748c39a5714646149c3a776b155a5` |
| `owl_marquee` | `owl_marquee-v0.1.0` | `3549440f573cd75a10cac863255dfd2720b4a5b0472b3a8e54d4d49e72ed8525` |
| `spatial_confetti` | `spatial_confetti-v0.1.0` | `2330568b6350d84292d26fe118270e44d5ba4c314881d2b19552aa23006073aa` |

The root Demo now locks `ndef_kit` and GroMore's provider-neutral `owl_ads`
to their hosted `0.1.0` releases. GroMore remains a local path dependency and
is not yet published. Its hosted `owl_ads` dependency resolves, `flutter analyze`
passes, and its 13 Dart tests pass. The root Demo analysis also passes.

Future corrections to a published package require a new version and a consumer
update; pub.dev versions cannot be unpublished. GroMore publication remains
blocked on the real device and SSV evidence in its acceptance checklist.
