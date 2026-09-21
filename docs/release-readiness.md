# Public package release readiness

## Confirmed on 2026-09-22

- Canonical source remote supplied by the owner: `https://github.com/Owl-YH/app_plugins`.
- GitHub reports `Owl-YH/app_plugins` as public. The reviewed local source was committed on `main` and pushed to that remote; `main` now tracks `origin/main`.
- Before publication, the pub.dev package API returned HTTP 404 for all six names. It now returns `0.1.0` for five packages; `owl_ads_gromore` remains unpublished.
- The signed-in pub.dev personal account `heng yang` authorized the Dart Pub CLI upload. No verified publisher was available for this first release.
- The owner confirmed `Heng Yang` as copyright holder for all six packages and confirmed that the package graphics, videos, and example icons may be redistributed publicly under BSD-3-Clause.
- The MyCards source import provenance is recorded in [source-import.md](source-import.md).
- The completed redistribution review and the owner's rights confirmation are recorded in [redistribution-review.md](redistribution-review.md).
- Focused check results and the pub.dev endpoint override are recorded in [release-evidence.md](release-evidence.md).

## Release status

- Five `0.1.0` releases were uploaded, independently downloaded from pub.dev, and tagged at source commit `ea20301`. Exact versions and checksums are in [release-evidence.md](release-evidence.md).
- `owl_ads_gromore` now resolves `owl_ads 0.1.0` from pub.dev, but its physical-device and authoritative SSV release gates remain open. The owner chose to publish the other five packages first and defer GroMore while those environments are unavailable.
