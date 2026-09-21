## Context

This workspace contains `ndef_kit`, `owl_ads`, and `owl_ads_gromore` under `packages/`, plus a real Flutter demo App; it currently has no Git repository. MyCards tracks `owl_haptics`, `owl_marquee`, and `spatial_confetti` under its own `packages/`. All six package pubspecs set `publish_to: none`; three lack LICENSE, `owl_ads` has a TODO license, and `owl_ads_gromore` has only a license title and a root path dependency on `owl_ads`. The GroMore release checklist also retains real device/backend gates. The companion MyCards OpenSpec change owns consumer cutover after releases resolve.

## Goals / Non-Goals

**Goals:** One independent Git source for six reusable packages; full BSD-3-Clause licensing for original code; reviewed package contents and metadata; real package validation; sequential pub.dev releases; hosted dependencies for the root demo App and downstream MyCards.

**Non-Goals:** Change product-facing package APIs or native behavior during relocation, bundle third-party GroMore binaries, claim SSV settlement from client callbacks, automate first-time publication, or turn the demo App into a pub.dev package.

## Decisions

1. **Repository boundary.** Initialize this existing workspace as its own Git repository, retain its demo App and `openspec/` history, and place the imported packages beside its current three under `packages/`. Import tracked source, not ignored `.dart_tool`, build, Gradle, Pods, local configuration, signing, or cache output. Record the MyCards source commit and verify file contents after import. Alternative: six Git repositories; rejected because coordinated examples/native tooling and one release workspace would fragment. Alternative: keep MyCards as source; rejected by the chosen independent ownership boundary.
2. **Git visibility and package metadata.** Recommend a public canonical source repository because public pub.dev archives are already readable and users can inspect issues and release tags. A private Git remote with public pub.dev archives is possible, but it weakens source provenance and may require omitting an inaccessible `repository` URL. The actual remote URL, visibility, and authorized pub.dev uploader/publisher remain a human release decision; do not invent them or publish under an unverified identity. Use the resolved canonical URL in each pubspec/README after confirmation.
3. **License and redistribution.** Put the complete standard BSD-3-Clause text with correct copyright holder in each package root; keep pre-existing authors' notices and check rights for imported files, docs images/videos, example assets, generated native bindings and any copied snippets. Apply the chosen license only to code/assets the publisher can license. The plugin references GroMore artifacts from ByteDance Maven and CocoaPods; it does not relicense or upload those binaries. Do not replace release checks with a bare license-name file.
4. **Version and dependency order.** Use the package's actual reviewed version and changelog, never reuse an already published version. Publish independent `owl_ads` first among the ad pair; only after its exact hosted version is resolvable change `owl_ads_gromore`'s root pubspec dependency to a compatible hosted constraint. The other four packages have no internal path dependency and can pass independently. Keep package-local example `path: ../` for source testing before publication; the root demo App switches its `ndef_kit` and `owl_ads_gromore` dependencies to hosted versions after publication. `pubspec.lock` belongs to Apps/examples, not library release dependencies.
5. **Manual first-release gates.** For each package: verify name ownership, metadata/README/changelog/license, package source tests, `flutter pub publish --dry-run` (or `dart pub publish --dry-run` for pure Dart `owl_ads`), archive file list/size/secret scan, and repository tag/release record. A designated authorized uploader reviews the exact archive and performs the actual upload. Never use `--force` or `--skip-validation` to bypass a failed gate. Check the version is visible and installable before marking it released. For `owl_ads_gromore`, the existing `docs/release-checklist.md` and real device/backend record remain additional gates; a pending SSV/physical acceptance item cannot become a simulated pass.
6. **Validation ownership.** Port `spatial_confetti` and `owl_haptics` package checks from MyCards root `package.json` into this workspace's package-owned commands/docs without changing their coverage. Preserve `owl_marquee` focused analysis/test and real examples. Run native compilation on supported platforms for native plugins; package-specific physical-device checks are required where existing release docs say so. Keep credentials only in ignored local inputs and inspect the archive before each publication.

## Risks / Trade-offs

- [No canonical Git remote or pub.dev ownership] → Stop before publication; record the selected URL, uploader/publisher identity, package-name availability, and release tag in the release record.
- [Published version is immutable and public] → Publish only from a clean, reviewed tag after dry-run; fix a mistake in a new version or retract where pub.dev policy permits. Never plan to unpublish as rollback.
- [Source import loses provenance or copies ignored artifacts] → Record originating MyCards commit, compare imported tracked paths, use strict ignore rules, inspect `git status` and the pub archive independently.
- [One package blocks a dependent release] → Publish in dependency order and stop only the affected chain; do not switch a consumer to a local machine path as a fallback.
- [GroMore third-party terms or real acceptance remain unresolved] → Do not upload `owl_ads_gromore`; retain its checked source locally and complete the existing release checklist with real evidence.
- [SDK/toolchain constraints are too narrow] → Keep the current verified minimums unless a separate compatibility assessment and device/build evidence justify widening them.

## Migration Plan

1. Confirm the canonical remote, repo visibility, BSD-3-Clause copyright holder, pub.dev uploader/publisher, package-name ownership, and third-party redistribution rights. Treat these as approval gates for public upload, not guessed metadata.
2. Create Git tracking for the workspace and import the three MyCards packages with source provenance. Exclude local/ignored artifacts. Align documentation, package checks, and complete license/metadata files.
3. Validate independent packages, review each dry-run archive, and publish them in recorded versions. Publish `owl_ads`, change `owl_ads_gromore` to the hosted `owl_ads` dependency, complete its native/physical/backend release evidence, then dry-run and publish it.
4. Switch the root demo App to hosted `ndef_kit` and `owl_ads_gromore`, resolve and commit its lockfile, and verify actual demo integration. Hand exact `owl_haptics`, `owl_marquee`, and `spatial_confetti` published coordinates to the companion MyCards change.
5. Rollback before upload by reverting the plugin repository change. After upload, keep the immutable published version and issue a corrected release if needed. Roll back a consumer by its prior Git commit or last reviewed hosted version; do not delete/rewrite a pub.dev release.

## Open Questions

- Which canonical Git remote and visibility will own this repository? Public source is recommended; private source with public package archives is the alternative.
- Which account or verified publisher owns each package name, and are all six names available? Browser search did not establish availability.
- Who is the copyright holder for all six packages, and are every included asset/snippet/native redistribution right cleared?
- Can the remaining GroMore device and authoritative SSV release gates be completed before its first public version? Option A (recommended): complete the real backend/device matrix, then publish a stable version. Option B: publish a clearly labeled prerelease with those gaps explicitly disclosed, if the owner changes the existing release policy after reviewing the risks; it remains public and immutable and cannot claim production readiness. Until this decision and the required evidence exist, that package and the demo's hosted cutover remain pending while independent packages proceed.
