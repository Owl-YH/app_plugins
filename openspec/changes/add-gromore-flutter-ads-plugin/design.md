## Context

The repository is currently a Flutter application with one reusable pure-Dart-facing package, `packages/ndef_kit`. It does not yet contain an advertising abstraction or a native Flutter plugin. The current toolchain uses Flutter 3.44.6, Android API 24 or newer, Java/Kotlin 17, and iOS 13 or newer.

GroMore is the selected provider, not the standalone Pangle integration. The official GroMore documentation states that the fusion SDK contains Pangle and mediation functionality, requires the mediation base library, and requires mediation to be enabled exactly once during initialization. Third-party ADN SDKs and matching adapters remain separate, version-coupled dependencies. The relevant source documents are:

- [GroMore Android SDK integration](https://www.csjplatform.com/supportcenter/28659)
- [GroMore Android reward ads](https://www.csjplatform.com/supportcenter/28661)
- [GroMore Android insert/full-screen ads](https://www.csjplatform.com/supportcenter/28663)
- [GroMore iOS SDK integration](https://www.csjplatform.com/supportcenter/28696)
- [GroMore iOS initialization and privacy](https://www.csjplatform.com/supportcenter/28697)
- [GroMore iOS reward ads](https://www.csjplatform.com/supportcenter/28699)
- [GroMore iOS insert/full-screen ads](https://www.csjplatform.com/supportcenter/28700)

The public documentation contains placeholder or beta dependency coordinates in some examples. Exact dependencies therefore cannot be inferred from snippets; implementation must inspect the currently downloaded official SDK, demo, headers, Pod specifications, and adapter compatibility table before pinning versions.

GroMore is privacy-sensitive and owns native objects whose callbacks outlive the initiating method. The design must prevent initialization before consent, avoid static Activity/ViewController references, preserve ad objects until callbacks complete, reject stale callbacks, and destroy one-shot native ads after use.

## Goals / Non-Goals

**Goals:**

- Expose a small provider-neutral API that application features can use without importing GroMore types or passing platform code IDs.
- Implement GroMore on Android and iOS with one versioned Flutter provider package.
- Support reward and insert ads with equivalent cross-platform semantics.
- Enforce consent and data-access policy in Dart and native code.
- Make native communication typed and reproducible through Pigeon.
- Keep native ad ownership, readiness, callback ordering, and disposal deterministic.
- Keep SDK and adapter versions exact, reviewable, and testable.
- Provide real build and real-device verification without mocked SDK behavior.
- Preserve a clean extension point for a future Google Ads provider without implementing it now.

**Non-Goals:**

- Splash, banner, feed, draw, native-template views, or PlatformView support in V1.
- A provider registry, dependency injection framework, factory framework, or runtime provider switching.
- Automatic Android runtime-permission requests or iOS ATT prompts.
- Persisting privacy-policy versions, consent timestamps, or host privacy documents.
- Bundling every supported ADN SDK and adapter.
- Plugin-managed material disk caching, queues of ready ads, or automatic reload after close.
- Multi-process advertising support in V1; GroMore is configured for a single process.
- A GroMore deinitialization guarantee that the native SDK does not provide.
- A Google/AdMob implementation in this change.

## Decisions

### 1. Two logical packages, one GroMore integration

Create:

```text
packages/
├── owl_ads/           # pure Dart domain contract
└── owl_ads_gromore/   # Flutter plugin with Android and iOS implementations
```

`owl_ads` owns `Ads`, `AdPlacement`, `AdType`, `AdConsent`, domain events, domain errors, `RewardOptions`, and `RewardResult`. It has no dependency on Flutter, Pigeon, GroMore, or a permissions library.

`owl_ads_gromore` owns `GroMoreAds`, `GroMoreConfig`, `GroMoreAdUnit`, `GroMoreAccess`, Pigeon DTO mapping, and both native implementations. The provider implements `Ads` and depends on `owl_ads`.

The application composition root imports the provider to construct `GroMoreAds`; feature code receives only `Ads`.

Alternative considered: one `owl_ads` plugin containing GroMore directly. Rejected because it would make the public package provider-specific and make a future provider replacement a breaking change.

Alternative considered: federating Android and iOS into separate packages immediately. Rejected because the same team owns both implementations, their releases must be version-locked, and the `Ads` package already provides the platform-independent contract. Separate platform packages can be introduced later if ownership or release cadence diverges.

### 2. V1 public API is explicit and provider-neutral

The `Ads` contract exposes initialization, consent update, an event stream, reward operations, insert operations, and disposal. The intended surface is equivalent to:

```dart
abstract interface class Ads {
  bool get initialized;
  Stream<AdEvent> get events;

  Future<void> init(AdConsent consent);
  Future<void> updateConsent(AdConsent consent);

  Future<void> loadReward(
    AdPlacement placement, {
    RewardOptions? options,
  });
  Future<bool> isRewardReady(AdPlacement placement);
  Future<RewardResult> showReward(AdPlacement placement);

  Future<void> loadInsert(AdPlacement placement);
  Future<bool> isInsertReady(AdPlacement placement);
  Future<void> showInsert(AdPlacement placement);

  Future<void> dispose();
}
```

`insert` is retained as the provider-neutral name already selected for this project. In the GroMore native layer it maps to the official insert/full-screen APIs (`TTFullScreenVideoAd` on Android and `BUNativeExpressFullscreenVideoAd` on iOS).

`AdPlacement` is a value object containing a stable application-defined name. Business features never pass Android/iOS code IDs. `GroMoreConfig` maps each placement to one `GroMoreAdUnit` containing the ad type and platform-specific GroMore placement IDs.

Alternative considered: passing code IDs to every load call. Rejected because it leaks provider and platform configuration into feature code and makes validation inconsistent.

### 3. GroMore configuration is immutable and mediation is fixed

`GroMoreConfig` contains Android and iOS app IDs, the placement-to-unit mapping, `GroMoreAccess`, debug logging, and only verified optional GroMore settings. It does not expose `useMediation`.

Native initialization always sets:

- Android `TTAdConfig.Builder().useMediation(true)`.
- iOS `BUAdSDKConfiguration.useMediation = YES` and links `CSJMediation`.

This is fixed because the provider is specifically a GroMore provider and the official API permits this flag to be set only once. Trying to turn the package into both a standalone Pangle and GroMore provider would create ambiguous dependency and runtime behavior.

Initialization is idempotent for the same immutable configuration. Reinitialization with a different app ID, unit map, or immutable native setting fails with `configurationConflict` rather than silently keeping the native SDK's first configuration.

### 4. Pigeon is the only Dart/native protocol

Use a pinned Pigeon generator to define an asynchronous host API and a Flutter callback API. Generated Dart, Kotlin, and Swift files are committed and verified in CI.

The protocol carries only DTOs:

- initialization and privacy DTOs;
- placement, unit, request, and reward-option DTOs;
- readiness and show-result DTOs;
- event, reward, revenue, and native-error DTOs.

All calls and callbacks include a placement name, ad type, and request generation where relevant. Public domain objects are mapped to/from Pigeon DTOs in `owl_ads_gromore`; generated DTOs are never exported.

Native-to-Dart callbacks use the generated Flutter API rather than a handwritten EventChannel with string maps.

Alternative considered: handwritten `MethodChannel`/`EventChannel` calls. Rejected because string keys and untyped maps make Android/iOS drift and privacy-field mapping errors difficult to detect.

### 5. Consent is a hard, duplicated gate

`AdConsent` separates acceptance of the host privacy policy from personalized-ad preference. `init` with `accepted == false` fails with `consentRequired` without calling the native SDK. Native initialization validates the consent DTO again before invoking GroMore.

The host application owns the privacy dialog, accepted policy version, acceptance timestamp, Android runtime permissions, and iOS ATT request. Neither package exposes a permission-request helper.

`GroMoreAccess` is provider-specific and deny-by-default. Its fields are finalized only after checking the selected SDK interfaces, including Android `TTCustomController`/`MediationPrivacyConfig` and iOS `BUAdSDKPrivacyProvider` plus supported mediation privacy settings. Every field has documented platform mapping and unsupported fields are not guessed.

When consent changes from accepted to rejected:

- Dart immediately blocks new load and show calls.
- Ready native sessions are destroyed and pending requests are invalidated.
- Supported runtime privacy settings are updated through the verified native APIs.
- The plugin states only that it stops initiating new advertising work; it does not claim to unload or deinitialize GroMore.

When personalized preference or data access changes while consent remains accepted, the plugin applies only fields the pinned SDK documents as mutable. Changes to initialization-only fields return a restart-required/configuration error instead of pretending they took effect.

### 6. Native ownership follows engine and foreground UI lifecycles

Android uses a standard V2 Flutter plugin with a public constructor and implements `ActivityAware`. It stores the application context for initialization and the current Activity only while attached. It handles configuration-change detach/reattach and rejects show calls with the normalized `presenterUnavailable` error when no Activity is attached, preserving the native cause in diagnostic details. No singleton or ad manager stores a static Activity.

iOS resolves the active foreground `UIWindowScene` and topmost presentable `UIViewController` at show time. A missing presenter or presentation conflict maps to the normalized `presenterUnavailable` error while preserving platform-specific diagnostic details. The provider does not cache a ViewController between calls.

Both native implementations release channels, callback handlers, pending completions, delegates, and ad objects when detached from the Flutter engine.

### 7. Each placement has a one-shot state machine

Reward and insert coordinators each maintain a map keyed by `AdPlacement`. A session contains the placement, native ad object, state, request generation, and pending show outcome.

```text
idle -> loading -> ready -> showing -> idle
             \-> failed -> idle
```

Rules:

- A placement holds at most one ready native object per ad type.
- A second load while loading fails with `alreadyLoading`.
- A load while ready succeeds without issuing another native request.
- Native load failure emits `AdFailed`, destroys partial state, and returns to idle.
- `ready` is exposed only when the GroMore load callback has completed and the native mediation `isReady` check succeeds.
- `show` performs another native `isReady` check immediately before presentation.
- A show without a ready object fails with `notReady`.
- On close or show failure, the object is destroyed/released and the session returns to idle.
- A shown object is never reused.
- Each load increments a generation. Callbacks from an older generation are ignored and recorded in diagnostics.
- The plugin performs no automatic retry and no automatic reload after close.

The official Android docs recommend cached callbacks plus `isReady`; the GroMore iOS docs state that mediation users can treat the load callback as the display opportunity but must still test mediation `isReady`. The common contract therefore uses completed load plus `isReady`, not provider-specific cached callback names.

### 8. Show futures and events have different responsibilities

`events` exposes normalized domain events for analytics and diagnostics:

- loaded;
- shown;
- clicked;
- closed;
- failed;
- rewarded;
- revenue.

Every event carries placement and ad type. Failure preserves the normalized `AdErrorCode` plus optional native code/message. Revenue is emitted only after the native SDK makes post-display metadata available; network, network placement, and eCPM are nullable when an ADN does not report them. Numeric revenue units are normalized only after the pinned Android and iOS APIs are verified; the implementation must omit an unverified value rather than guess units.

`showReward` completes after the ad closes or fails to show. It returns the reward state accumulated from native callbacks, including whether a reward was granted, whether verification succeeded, and optional reward name/amount. Server-side verification is the required authority for server-owned value; a client callback alone is not treated as a secure transaction proof.

`showInsert` completes on close and throws on show failure. Click, impression, and revenue details remain events rather than changing method signatures.

### 9. Dependency ownership is split between provider and host

`owl_ads_gromore` pins the verified GroMore base dependencies required for mediation:

- Android fusion/mediation base artifact and required consumer rules/resources.
- iOS Ads-CN/BUAdSDK plus `CSJMediation` through an exact Pod dependency or verified local integration.

The host application adds only the third-party ADN SDKs and matching adapters it uses. The provider does not bundle GDT, KS, Baidu, Sigmob, Mintegral, or every supported network by default.

`docs/versions.md` records, per plugin release, the Flutter plugin version, Android/iOS GroMore versions, each supported ADN SDK/adapter pair, minimum platforms, and the official source used to verify them. Wildcards, `latest`, `+`, and unconstrained Pods are prohibited.

Necessary non-sensitive plugin-owned Android manifest components and consumer rules live in the plugin. Sensitive/optional permissions and ADN-specific components remain documented host configuration. On iOS, the host owns Info.plist disclosures, PrivacyInfo merging, SKAdNetwork identifiers, optional ATT wording/request, and ADN-specific linker/configuration requirements.

Alternative considered: bundling AARs/frameworks and every adapter inside the Flutter package. Rejected because it increases package size, licensing and disclosure risk, duplicate symbols, and dependency conflicts while making updates harder to audit.

### 10. Verification uses real dependencies and real ad flows

Automated checks cover pure domain models, configuration validation, the state machine, Pigeon generation drift, Dart analysis/tests, Android compilation/lint, iOS Pod resolution/build, and release dependency inspection. These tests exercise real generated/native integration boundaries and do not return fabricated SDK results.

The example application receives real app IDs and placement IDs through `--dart-define` or an ignored local configuration file. It contains a host-owned privacy/permission flow and explicit controls for init, load, readiness, show, consent withdrawal, diagnostics, and event inspection.

Real Android and iOS devices validate initialization, reward, insert, close/reload, server reward verification, rotation/backgrounding, missing Activity/presenter behavior, consent withdrawal, and release builds. GroMore's official test tools may be used only in debug/test builds and are excluded from release artifacts.

## Risks / Trade-offs

- [Official documentation shows placeholder/beta dependency examples] -> Download the current official SDK/demo and inspect its build files, headers, Podspec, and adapter matrix before editing dependency files; pin only verified coordinates.
- [ADN SDK/adapter incompatibility can initialize successfully but fail at load time] -> Maintain `docs/versions.md`, add build checks for supported combinations, and require device testing for every enabled ADN.
- [A host may omit required privacy or ADN configuration] -> Provide a fail-fast configuration validator, startup diagnostics, a host integration checklist, and a real example; do not silently add sensitive permissions.
- [Consent withdrawal cannot unload an already initialized native SDK] -> Define the guarantee narrowly: invalidate sessions, destroy ready ads, update supported privacy settings, and block new plugin requests.
- [Native callbacks may arrive late or out of order] -> Attach request generations and session states to every callback and ignore stale generations.
- [An Activity or ViewController may disappear during display] -> Resolve the presenter immediately before show, reject unavailable presenters, and release references on detach/close.
- [GroMore and an ADN may report different reward or revenue metadata] -> Normalize only documented fields, preserve native diagnostics, and use server-side verification for valuable rewards.
- [Two packages add setup overhead] -> Keep construction in the application composition root and provide a complete example; the separation prevents provider details from spreading through features.
- [No automatic retry/preload may reduce fill responsiveness] -> Let GroMore manage its supported cache behavior and let applications schedule explicit loads; avoid competing cache policies and retry loops.

## Migration Plan

1. Verify and record exact GroMore Android/iOS base dependencies and current adapter compatibility from the official downloaded artifacts.
2. Add `owl_ads` with its domain contract and tests; no existing application behavior changes.
3. Add `owl_ads_gromore`, pinned Pigeon generation, native SDK integration, and native lifecycle coordinators.
4. Add the dedicated example and host integration documentation without changing the existing root NFC application.
5. Run Dart, Android, and iOS build verification with real dependencies.
6. Configure real GroMore application/placement IDs outside source control and complete the device acceptance matrix.
7. Publish or consume the packages internally only after the version matrix and device results are recorded.

Rollback is additive: remove the consuming application's dependency and composition-root construction. Existing application features and `ndef_kit` remain unchanged because no migration replaces their APIs.

## Open Questions

- Which exact GroMore Android artifact coordinate and iOS Pod/subspec version are present in the current official download? This must be resolved from downloaded artifacts before implementation dependencies are written.
- Which third-party ADN adapters, if any, must be included in the first real-device acceptance matrix? The provider remains adapter-agnostic, but each enabled pair needs real validation.
- What real Android/iOS app IDs, reward placement IDs, insert placement IDs, and server-side verification endpoint will be used for acceptance? They must be supplied outside source control.
