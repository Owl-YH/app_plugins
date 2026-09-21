## Why

The project needs a reusable Flutter advertising layer that can integrate GroMore once for Android and iOS while keeping application code independent of GroMore, native callbacks, and platform-specific code IDs. A first-party wrapper is needed now to enforce privacy consent, lifecycle safety, exact SDK compatibility, and real-device verification instead of inheriting the static APIs, string protocols, and implicit permission behavior of existing community wrappers.

## What Changes

- Add `packages/owl_ads` as a pure Dart package that defines provider-neutral placements, ad types, consent, events, errors, reward results, and the `Ads` contract.
- Add `packages/owl_ads_gromore` as a standard Android/iOS Flutter plugin implementing `Ads` with GroMore and an internal Pigeon protocol.
- Support V1 reward ads and insert ads, including load, readiness checks, one-shot display, close/failure handling, reward verification data, and post-display revenue metadata.
- Require explicit privacy-policy consent before GroMore initialization or ad requests; keep operating-system permission and ATT prompts in the host application.
- Add strongly typed, deny-by-default GroMore data-access controls and a defined consent-withdrawal behavior.
- Fix GroMore mediation mode internally, integrate only the GroMore base SDK in the provider, and require host applications to add only the ADN SDKs and adapters they actually use.
- Pin and document a verified Android/iOS GroMore SDK and adapter compatibility matrix; do not use dynamic dependency versions.
- Add a dedicated example application and real-device acceptance procedure using real GroMore application and placement IDs supplied outside source control.
- Defer splash, banner, feed, draw, automatic permission requests, automatic plugin-side preloading, and a Google Ads provider from V1.

## Capabilities

### New Capabilities

- `ads-core-api`: Provider-neutral Dart API, configuration models, placements, events, errors, reward results, and unsupported-platform behavior.
- `gromore-initialization-privacy`: GroMore configuration, consent gate, deny-by-default privacy access, initialization lifecycle, and consent withdrawal.
- `gromore-reward-ads`: Cross-platform reward ad loading, readiness, display, reward verification, events, and object lifecycle.
- `gromore-insert-ads`: Cross-platform insert ad loading, readiness, display, events, revenue metadata, and object lifecycle.
- `gromore-host-integration`: Android/iOS SDK integration, exact SDK/adapter version governance, required host configuration, diagnostics, example app, and real-device acceptance.

### Modified Capabilities

None.

## Impact

- Adds two packages under `packages/` and a new Android/iOS example application under `packages/owl_ads_gromore/example`.
- Adds generated Pigeon Dart, Kotlin, and Swift code plus native GroMore lifecycle coordinators.
- Adds Gradle/Maven and CocoaPods dependencies for the verified GroMore base SDK; optional ADN SDKs and adapters remain host-owned.
- Raises no project minimums beyond the current environment: Android API 24 and iOS 13 are already configured.
- Requires host-level privacy disclosures, iOS PrivacyInfo/SKAdNetwork/optional ATT configuration, and ADN-specific manifest, linker, adapter, and obfuscation settings.
- Does not modify the existing `ndef_kit` API or make the root application depend on GroMore.
