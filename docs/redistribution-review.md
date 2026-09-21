# Redistribution review for the first pub.dev release

The owner confirmed public redistribution rights for the package graphics,
videos, and example icons on 2026-09-22. The archive audit below documents
what was inspected and which generated font outlines were removed.

## Source and native dependencies

- `owl_haptics`, `owl_marquee`, and `spatial_confetti` were copied from the
  tracked MyCards commit recorded in [source-import.md](source-import.md).
- `ndef_kit`, `owl_ads`, and `owl_ads_gromore` were already in this workspace.
- No AAR, JAR, XCFramework, framework, static library, dynamic library, APK, or
  IPA appeared in the first candidate Git file list under `packages/`.
  GroMore SDKs are resolved from Maven/CocoaPods coordinates in the native
  build files, not vendored in this repository.
- The Pigeon Dart/Kotlin/Swift bindings are generated from schemas in the
  respective package. `owl_haptics` and `owl_ads_gromore` generation drift
  checks passed on the imported/current source.

## Package assets

- `spatial_confetti/docs/assets` contains about 1.8 MB of screenshots, diagrams,
  simulation plots, and six MP4 recordings. The package's own capture,
  plotting, and guide scripts document how these assets were generated from
  Flutter rendering and simulation, but the repository alone cannot prove
  that every graphic and video is owned or licensed for public redistribution;
  the owner separately confirmed those rights.
- Two imported Matplotlib SVG plots embedded Arial Unicode MS glyph outlines.
  Their scripts now generate PNG only, the docs use existing PNG plots, and
  those two SVG files are removed from this repository's release source.
- Flutter example app launcher and launch images are present in
  `owl_haptics`, `spatial_confetti`, and `owl_ads_gromore`. Their provenance and
  public redistribution rights should be confirmed before including the
  examples in a public archive. The owner confirmed their redistribution.
- Existing Flutter/Dart dependencies and the external GroMore SDK carry their
  own licenses; the package BSD-3-Clause notice does not relicense them.

Review the exact `pub publish --dry-run` archive lists before release. Remove
an asset from the published archive or replace it if its rights cannot be
confirmed. The external GroMore SDK remains outside the archive.
