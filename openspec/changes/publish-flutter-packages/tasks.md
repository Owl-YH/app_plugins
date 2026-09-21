## 1. Release identity and source ownership

- [x] 1.1 Confirm and record the canonical Git remote/visibility, authorized pub.dev uploader or verified publisher, ownership/availability of all six package names, and BSD-3-Clause copyright holder before setting public metadata or uploading.
- [x] 1.2 Establish Git tracking for the existing plugins workspace with ignore rules that exclude local credentials, signing files, `.dart_tool`, Pods, Gradle/build output, and caches; inspect the first tracked-file list before commit.
- [x] 1.3 Record the MyCards source commit and import its tracked `packages/owl_haptics`, `packages/owl_marquee`, and `packages/spatial_confetti` trees into this repository's `packages/`, preserving public entry points, examples, tests, and generated native bindings while excluding ignored output.
- [x] 1.4 Compare imported tracked source to the recorded MyCards commit and resolve any path-dependent docs or tooling without changing public API or native behavior.

## 2. Package publication preparation

- [x] 2.1 Replace missing/placeholder/incomplete LICENSE files in all six package roots with complete BSD-3-Clause text and verified holder notices; retain any valid third-party notices.
- [x] 2.2 Review source, example assets, media, generated bindings, native dependencies, and copied snippets for redistribution rights; remove or replace unlicensed material before release and keep the external GroMore SDK out of archives.
- [x] 2.3 Add accurate canonical repository metadata, package descriptions, README installation instructions, and version-matched changelog entries to the six package manifests/docs; leave demo Apps `publish_to: none`.
- [x] 2.4 Move existing `spatial_confetti` and `owl_haptics` package check commands from MyCards root into this workspace's package-owned validation docs/scripts, preserving Pigeon drift, focused package tests, examples, and native checks; document `owl_marquee`, `ndef_kit`, and `owl_ads` checks at their package owners.
- [ ] 2.5 Run focused format/analyze/tests and `flutter pub publish --dry-run` for `ndef_kit`; record archive contents, size, dependencies, and warnings.
- [x] 2.6 Run focused format/analyze/tests and `flutter pub publish --dry-run` for `owl_haptics`; record Pigeon/native evidence and archive review.
- [ ] 2.7 Run focused format/analyze/tests and `flutter pub publish --dry-run` for `owl_marquee`; record its example and archive review.
- [ ] 2.8 Run focused format/analyze/tests and `flutter pub publish --dry-run` for `spatial_confetti`; inspect its docs/media archive contents, size, dependencies, and warnings.
- [ ] 2.9 Run focused Dart checks and `dart pub publish --dry-run` for `owl_ads`; inspect its archive contents, size, dependencies, and warnings.

## 3. Publish independent releases

- [ ] 3.1 From reviewed clean Git source, publish `owl_ads` and verify its exact version resolves from pub.dev; record its version/tag/archive result.
- [ ] 3.2 Publish and verify a retrievable `ndef_kit` version from reviewed clean Git source; record its version/tag/archive result.
- [ ] 3.3 Publish and verify a retrievable `owl_haptics` version from reviewed clean Git source; record its version/tag/archive result.
- [ ] 3.4 Publish and verify a retrievable `owl_marquee` version from reviewed clean Git source; record its version/tag/archive result.
- [ ] 3.5 Publish and verify a retrievable `spatial_confetti` version from reviewed clean Git source; record its version/tag/archive result.
- [ ] 3.6 Change `packages/owl_ads_gromore/pubspec.yaml` to a compatible hosted constraint for the verified `owl_ads` release, update its version/changelog if needed, and prove clean dependency resolution.
- [ ] 3.7 Run focused Dart/native/example checks and `flutter pub publish --dry-run` for `owl_ads_gromore`; inspect its archive contents, native metadata, dependencies, and warnings.
- [ ] 3.8 Complete the existing GroMore release checklist with pinned native dependency inspection, Pigeon drift, Android/iOS builds, physical-device flows, and authoritative SSV backend evidence; record unresolved items as blockers without mock results.
- [ ] 3.9 Publish `owl_ads_gromore` only after its specific real release gates pass; verify the exact hosted version resolves in a fresh consumer and record the tag/archive result.

## 4. Consumers and handoff

- [ ] 4.1 Switch the plugins root demo `pubspec.yaml` and lockfile to the verified hosted `ndef_kit` and `owl_ads_gromore` versions; keep package-local examples exercising local source and run focused real demo analysis/build checks.
- [ ] 4.2 Update the plugins root README, AGENTS.md, package READMEs, and release record to document independent source ownership, public version upgrades, manual first-release gates, missing device evidence, and rollback by new version/consumer commit rather than unpublish.
- [ ] 4.3 Hand the exact hosted `spatial_confetti`, `owl_haptics`, and `owl_marquee` versions plus release evidence to the companion MyCards change; do not remove MyCards package trees from this repo-local task.
