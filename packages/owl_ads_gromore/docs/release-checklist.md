# Release checklist

Record concrete results in [`acceptance-record.md`](acceptance-record.md); do
not convert a pending physical-device or backend item into a simulated pass.

- [ ] Real Android/iOS App IDs and reward/insert Code IDs are supplied only by
      ignored local configuration or CI secrets.
- [ ] `docs/versions.md` records this plugin release, exact GroMore bases, every
      enabled ADN SDK/adapter pair, official timestamps, and checksums.
- [ ] `docs/native-contract.md` still matches the pinned AAR headers/classes and
      Pod headers.
- [ ] `tool/generate_pigeon.sh` has been run and `tool/check_pigeon.sh` passes.
- [ ] Dart formatting, analysis, unit/widget tests, and package metadata checks
      pass for both packages and the example. Before public publication,
      replace the local `owl_ads` path with its verified hosted coordinate,
      remove `publish_to: none`, and require clean pub publish dry-runs.
- [ ] Android debug/release and minified device builds pass; the dependency
      graph, merged manifest, APK/AAB contents, and consumer rules contain no
      unselected ADN.
- [ ] iOS debug/release simulator and signed device/archive builds pass;
      `Podfile.lock`, linked XCFrameworks, resources, SKAdNetwork entries, and
      merged privacy manifests contain only reviewed dependencies.
- [ ] Consent gate, personalization, withdrawal, missing presenter, background,
      rotation/interruption, disposal, stale callbacks, and reload-after-close
      have passed on physical Android and iOS devices.
- [ ] Reward and insert load/show/click/close/revenue/error flows pass for every
      enabled ADN pair and tested device/OS results are attached to the release.
- [ ] The real reward backend has received and verified the server callback;
      client `rewarded` is not used as authoritative settlement.

Any GroMore base or ADN SDK/adapter change invalidates the native acceptance
record. Update `versions.md`, re-inspect the native contract, rebuild both
platforms, and repeat every relevant physical-device/backend check before
release.
