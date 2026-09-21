## Why

This Flutter plugin workspace contains three reusable packages, while three more live inside MyCards solely to satisfy local path dependencies. The agreed goal is one independent, versioned source for all six packages and public pub.dev releases under BSD-3-Clause, so consumers can use reviewed versions without copying plugin source.

## What Changes

- Establish this workspace as an independent Git repository and make `packages/` the source owner for `ndef_kit`, `owl_ads`, `owl_ads_gromore`, `owl_haptics`, `owl_marquee`, and `spatial_confetti`.
- Migrate the three MyCards package sources, examples, tests, generated host bindings, documentation, and validation commands without changing their public API or runtime behavior as part of the move.
- Provide complete BSD-3-Clause license texts and correct package metadata; audit the rights and archive contents of every package, including examples, media and native artifacts.
- Release each package to pub.dev only after real verification and `dart pub publish --dry-run`. Publish `owl_ads` before `owl_ads_gromore` and replace the latter's root path dependency with a hosted version. Retain package-local example path dependencies for testing source prior to release.
- **BREAKING (workspace ownership):** this repository becomes the release authority; the MyCards package trees and package-level scripts are removed by the companion MyCards change only after hosted versions resolve.
- Update this workspace's real demo App to consume hosted `ndef_kit` and `owl_ads_gromore` versions after publication, with a committed lockfile.

## Capabilities

### New Capabilities

- `published-flutter-packages`: Each of six packages has a reviewable, attributable, reproducible hosted release and consumers can resolve approved versions.

### Modified Capabilities

None in this repository's current OpenSpec baseline; package APIs and native runtime contracts are preserved.

## Impact

- Package manifests, LICENSE/README/CHANGELOG files, examples, the root demo manifest/lockfile, package check scripts, and this workspace's release documentation change. MyCards source and docs change only in its companion `openspec/changes/publish-flutter-packages` change.
- No intentional Dart API, native protocol, ad/NFC/haptic behavior, database, Server OpenAPI, generated API client, or deployment change. Material behavior changes found during validation require separate review and versioning.
- Public publication is effectively irreversible. An unresolved name, missing pub.dev uploader, absent canonical remote, unreviewed third-party content, unresolved native dependency, or failed real release gate blocks only that package's upload and every consumer cutover depending on it.
- GroMore SDK remains an external native dependency with separate terms. The existing `owl_ads_gromore` physical-device/backend acceptance gaps must be resolved or explicitly excluded from the release claim according to its release checklist; no mock evidence substitutes for them.
