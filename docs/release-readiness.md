# Public package release readiness

## Confirmed on 2026-09-22

- Canonical source remote supplied by the owner: `https://github.com/Owl-YH/app_plugins`.
- GitHub reports `Owl-YH/app_plugins` as public with no default branch yet. This local workspace now has that URL configured as `origin`; no push has occurred.
- The pub.dev package API returned HTTP 404 for `owl_haptics`, `owl_marquee`, `spatial_confetti`, `ndef_kit`, `owl_ads`, and `owl_ads_gromore`. This is a point-in-time availability check, not a reservation or proof of upload authorization.
- The signed-in pub.dev profile shows display name `heng yang`, no packages uploaded as an individual account, and no verified-publisher membership. The six packages therefore currently have no verified publisher. The profile page does not prove this shell's `dart pub publish` authentication.
- The owner confirmed `Heng Yang` as copyright holder for all six packages and confirmed that the package graphics, videos, and example icons may be redistributed publicly under BSD-3-Clause.
- The MyCards source import provenance is recorded in [source-import.md](source-import.md).
- Initial redistribution findings and items needing owner confirmation are recorded in [redistribution-review.md](redistribution-review.md).
- Focused check results and the pub.dev endpoint override are recorded in [release-evidence.md](release-evidence.md).

## Still required before public upload

- Verify CLI publishing authorization at release time. Browser login alone does not prove CLI publishing authorization.
- Review each exact dry-run archive, package test/build evidence, native acceptance where applicable, and the final clean Git commit/tag.
- Complete the existing GroMore physical-device and authoritative SSV release gates before publishing `owl_ads_gromore`. The owner chose to publish the other five packages first and defer GroMore while those environments are unavailable.
