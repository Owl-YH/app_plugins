## 1. Verify the pinned native contract

- [x] 1.1 Inspect the pinned Android 7.7.1.6 AAR/demo and iOS 7.7.0.6 headers for the exact reward custom-data, reward amount/name, verification, error, and server-callback fields; record only verified mappings in `docs/native-contract.md`.
- [x] 1.2 Record the current Android/iOS initialization, load, show-visible, close, and failure callbacks that terminate each pending operation, and document the internal watchdog constants without attributing them to the SDK.

## 2. Enforce the shared Dart runtime

- [x] 2.1 Add complete value equality/fingerprinting to `GroMoreConfig`, `GroMoreAccess`, and unit mappings so equivalent and conflicting runtime requests are deterministic.
- [x] 2.2 Replace the public `GroMoreAds` constructor with a private constructor and `GroMoreAds.configure(config)` isolate singleton that returns the identical runtime for equivalent configuration and rejects conflicts/recreation after disposal.
- [x] 2.3 Register the Pigeon Flutter callback handler once for the shared runtime and make terminal disposal idempotently unregister it, close events, invalidate generations, and reject all later work.
- [x] 2.4 Replace the initialization-in-progress rejection with a retained shared initialization Future for equivalent calls, add lifecycle epochs, and prevent late initialization completions or callbacks from changing disposed state.
- [x] 2.5 Extend provider-neutral reward options/results only with verified cross-provider fields required for custom-data correlation and actual SDK reward outcomes while preserving provider diagnostics separately.

## 3. Update the typed native boundary

- [x] 3.1 Update the Pigeon source with the verified reward/custom-data fields and any normalized timeout diagnostic data needed by the runtime contract.
- [x] 3.2 Regenerate committed Dart, Kotlin, and Swift bindings with the pinned Pigeon version and pass the drift check.
- [x] 3.3 Update Dart/native mappers so SDK absence remains nullable, request defaults are not promoted to reward proof, and unknown future values remain safely normalized.

## 4. Coordinate Android runtime behavior

- [x] 4.1 Add a process-scoped Android initialization coordinator that coalesces compatible waiters, rejects conflicting fingerprints, removes detached waiters, and never stores Activity/ad/Messenger objects.
- [x] 4.2 Route each engine-scoped `AndroidGroMoreHost` through the coordinator while retaining engine-owned `ActivityAware`, callback channel, session maps, and ad objects.
- [x] 4.3 Add once-only pending completion guards and watchdogs for initialization, reward/insert load, presentation acknowledgement, and terminal show completion; cancel guards and release stale ads on every terminal path.
- [x] 4.4 Map Android reward outcomes from the verified SDK Bundle/callback values, forward verified custom data, deduplicate legacy/current callbacks, and keep rewarded and verified semantics distinct.
- [x] 4.5 Move Android revenue extraction to the first current-generation show callback and enforce exactly-once emission before close.

## 5. Coordinate iOS runtime behavior

- [x] 5.1 Add a serialized process-scoped iOS initialization coordinator that coalesces compatible waiters, rejects conflicting fingerprints, removes detached waiters, and never stores presenters/ads/Messengers.
- [x] 5.2 Route each engine-scoped `IOSGroMoreHost` through the coordinator while retaining scene-safe presentation and engine-owned sessions/delegates.
- [x] 5.3 Add once-only completion guards and watchdogs for initialization, reward/insert load, presentation acknowledgement, and terminal show completion; reject stale delegate callbacks after timeout/disposal.
- [x] 5.4 Map iOS reward outcomes and verified custom data from the pinned SDK model/delegate fields, deduplicate callbacks, and keep rewarded and verified semantics distinct.
- [x] 5.5 Emit iOS revenue from the first current-generation visible callback with an exactly-once guard and no close-time duplicate.

## 6. Migrate application ownership and documentation

- [x] 6.1 Update the plugin example and root `GroMorePlatformService`/repository to obtain `GroMoreAds.configure(config)` and remove page/repository recreation semantics.
- [x] 6.2 Make the root Riverpod GroMore provider application-scoped and keep-alive so feature/page disposal never disposes the shared advertising runtime.
- [x] 6.3 Update README, privacy lifecycle, migration, reward SSV, revenue timing, multi-engine, and disposal documentation, including a future `owl_ads_google` composition example without adding Google dependencies.

## 7. Verify lifecycle and compatibility

- [x] 7.1 Add Dart tests for identical singleton identity, configuration conflicts, terminal disposal, shared initialization, init/dispose epochs, independent placements, reward deduplication, and revenue deduplication using deterministic state inputs rather than a fake advertising provider.
- [x] 7.2 Add Android and iOS native state/coordinator tests for compatible/conflicting waiters, detach, timeout-versus-callback races, once-only completion, and stale generation rejection without representing simulated results as SDK success.
- [x] 7.3 Run formatting, `flutter analyze`, package/root tests, Pigeon drift verification, Android debug/release builds, and iOS simulator/device compilation; fix every plugin-owned failure.
- [ ] 7.4 Re-run the physical Android and iOS acceptance matrix for consent initialization, two concurrent placements, reward completion, close-without-reward, revenue-before-close, timeout recovery where reproducible, rotation/backgrounding, and engine detach; record remaining SDK-dependent risks honestly.
