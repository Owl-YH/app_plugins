## Context

The current package separation is sound: `owl_ads` owns a provider-neutral contract and `owl_ads_gromore` owns GroMore configuration, Pigeon, and native SDK integration. Placement sessions are already keyed by placement and generation on Dart, Android, and iOS.

The ownership boundary above those sessions is inconsistent. Every public `GroMoreAds(config)` construction registers the same unsuffixed Pigeon Flutter callback handler, while the native Host API and GroMore SDK are shared within an engine/process. A second object can therefore replace the first event recipient, and either object's `dispose` can invalidate sessions that the other object believes it owns. Android and iOS also keep initialization state per host even though the underlying GroMore SDK is process-wide, so simultaneous Flutter engines can independently attempt startup.

The root application already uses Riverpod and a repository composition boundary. The package must remain usable without Riverpod and must not put an application DI framework into the plugin. GroMore exposes no verified deinitialize operation, so disposal can release plugin-owned sessions/channels but cannot reset the process SDK. The current pinned native contract provides actual reward callbacks and post-impression eCPM metadata but does not provide a verified currency/precision contract.

## Goals / Non-Goals

**Goals:**

- Make one `GroMoreAds` runtime per Dart isolate an enforced API invariant.
- Preserve concurrent, isolated sessions for different placements and generations.
- Coordinate one compatible native SDK startup across Flutter engines in a process.
- Make equivalent initialization idempotent and concurrent initialization deterministic.
- Prevent init/dispose and late-callback races from changing terminal Dart state.
- Bound asynchronous commands and complete every Pigeon reply exactly once.
- Derive reward outcomes from SDK callbacks, deduplicate callbacks, and carry custom data needed for server verification.
- Emit revenue once at confirmed display rather than delaying it until close.
- Preserve a clean path for a separate future Google provider.

**Non-Goals:**

- Adding `google_mobile_ads`, AdMob mediation, or a Google provider in this change.
- Creating a global `Ads.instance`, provider registry, runtime provider switching, or automatic GroMore/Google fallback.
- Supporting more than one GroMore configuration in the same isolate or process.
- Deinitializing GroMore, resetting its process singleton, or recreating a disposed Dart runtime in the same isolate.
- Adding splash, banner, feed, draw, native, or app-open formats.
- Adding automatic load retries, automatic reload, or a ready-ad queue.

## Decisions

### 1. Use a provider-specific shared runtime, not a global Ads singleton

`GroMoreAds` gets a private constructor and an explicit entry point equivalent to:

```dart
final ads = GroMoreAds.configure(config);
```

The first call creates the isolate-scoped runtime. A later call with an equivalent `GroMoreConfig` returns the identical object. A different configuration throws `configurationConflict` before changing a channel or invoking native code. Equality covers App IDs, placement/unit mapping, access controls, debug settings, and any later initialization-only GroMore setting.

The Pigeon Flutter callback handler is registered once when the runtime is created and removed only by terminal runtime disposal. `dispose` is idempotent but terminal: `configure` does not create a replacement in the same isolate. This reflects the native SDK's real process lifetime and prevents an old reference from interfering with a replacement.

Alternative considered: use a factory constructor named `GroMoreAds(config)`. Rejected because it visually suggests independent object construction and hides shared ownership.

Alternative considered: use `messageChannelSuffix` and support many Dart providers. Rejected because it adds native instance registries and disposal ownership while the underlying SDK and privacy configuration remain process-global. It provides no product benefit over multiple placement sessions.

Alternative considered: add `Ads.instance`. Rejected because it would bind the provider-neutral package to one implementation and complicate a future Google provider.

### 2. Keep placement concurrency below the shared runtime

The existing `AdSessionRegistry` and native reward/insert maps remain keyed by ad type plus placement, and every request retains its generation. Different placements can load concurrently. The same placement remains one loading/ready/showing session, and every displayed native object remains one-shot.

The singleton change does not introduce a global "one ad loaded" restriction. It removes duplicate runtimes while keeping independent placement ownership.

### 3. Make initialization a shared Future with lifecycle epochs

Dart stores the in-flight initialization Future and the consent/configuration fingerprint that created it. Equivalent concurrent calls await the same Future. A concurrent call with incompatible initial privacy input fails deterministically rather than racing with a last-writer-wins policy. Calls after successful initialization update only verified mutable consent fields.

Every asynchronous lifecycle operation captures a runtime epoch. Terminal disposal increments the epoch before native disposal and callback unregistration. A completion whose captured epoch is stale may complete its caller with `disposed`, but it cannot set the runtime to initialized, ready, or showing and cannot emit an event.

Alternative considered: reject every second call while initializing. Rejected because application startup paths can legitimately converge on the same idempotent initialization.

### 4. Coordinate native startup at process scope

Android introduces a process coordinator serialized on the main thread and protected against concurrent access. iOS introduces the equivalent static coordinator serialized on a dedicated queue/main-thread handoff. Its state is conceptually:

```text
notStarted -> starting(fingerprint, waiters) -> started(fingerprint)
                   |                  \-----> failed -> notStarted
                   \-----> stalled(fingerprint) --SDK ready--> started
```

An equivalent request while starting joins the waiter list. A conflicting App ID or immutable initialization fingerprint fails with `configurationConflict`. SDK success completes all live waiters once; detached/disposed engine waiters are removed without trying to stop the SDK. Failure completes all waiters and permits a later equivalent retry when the verified SDK state allows it.

If the last live waiter times out before the SDK reports a terminal callback,
the attempt becomes `stalled`. The plugin does not issue an unsafe overlapping
SDK start. An equivalent later request succeeds if the real SDK is ready and
otherwise fails quickly with `restartRequired`; a late callback for the current
attempt may still move the process to `started`, but cannot complete an expired
waiter. Attempt identifiers reject callbacks from older retries.

Each Flutter engine still owns its BinaryMessenger, Host API, Activity/presenter lifecycle, ad session maps, and native ad objects. The coordinator owns only process SDK startup identity/state; it never stores an Activity, ViewController, ad, or Flutter callback API.

### 5. Separate runtime disposal from SDK deinitialization

Calling Dart `dispose` invalidates that engine host's sessions, destroys/releases retained ads, completes pending operations, closes the event stream, and unregisters the Dart callback handler. It does not clear the process initialization fingerprint or claim to unload GroMore. Engine detach performs the same native resource release even if Dart disposal was not called.

The root Riverpod provider is `keepAlive`; pages and feature controllers receive `Ads` and do not dispose it. Only the application composition root owns terminal disposal. Package users without Riverpod follow the same ownership rule.

### 6. Bound asynchronous phases and complete replies exactly once

Initialization and load operations use a 30-second watchdog on both native platforms. Show uses two phases: a short presentation-acknowledgement guard and a long terminal-callback safety deadline that is longer than a valid reward/full-screen experience. A timeout is a failure, never a reward or close success, and invalidates the current generation.

Every native pending completion is wrapped by a generation-aware, once-only
completion guard. SDK callback, timeout, withdrawal, disposal, and engine
detach all compete through that guard, so exactly one Pigeon reply is sent and
an older generation cannot finish a newer request. Timer callbacks verify
current session identity/generation and are cancelled at terminal completion.

The exact show terminal deadline is an internal documented constant and can be adjusted after real-device evidence without changing the public API. It is not exposed as an application tuning knob in this change.

### 7. Normalize one final reward outcome from actual SDK data

`RewardOptions` adds optional `customData` and transports it through the verified GroMore request model for server-verification correlation. Native reward aggregators consume the current SDK callbacks and actual reward bundle/model fields. Request `rewardName` and `rewardAmount` are request hints only and are not copied into a successful result unless the SDK reports them.

The native session records at most one effective reward outcome. Legacy and current callbacks may enrich the same result but cannot emit two `rewarded` events or cause two grants. `rewarded` represents the SDK grant outcome; `verified` represents the SDK verification signal when supplied. A failure preserves native diagnostics and never turns a request default into a reward. The terminal `showReward` result and event stream agree on the same accumulated outcome.

Backend verification remains authoritative for server-owned currency or entitlement. Client `verified` is not documented as proof that a backend transaction has settled.

### 8. Emit revenue at first confirmed impression exactly once

Android reads `getShowEcpm()` from the first current-session show callback; iOS reads `getShowEcpmInfo` from the first visible callback. Each native session has a revenue-emitted flag, so duplicate visibility/show callbacks cannot duplicate revenue. Revenue remains nullable and preserves raw eCPM plus network/request identifiers without inventing currency or precision.

If metadata is unavailable at impression time, the provider may omit the event; it does not delay a fabricated value until close. Diagnostics may record the absence without failing the ad.

### 9. Preserve provider-neutral future Google composition

`owl_ads` continues to expose `Ads`, placement identities, common events, and common results. `GroMoreAds.configure` remains in `owl_ads_gromore`. A future direct implementation belongs in a separate `owl_ads_google` package and may expose `GoogleAds.configure`/`GoogleAds.instance` according to Google Mobile Ads lifecycle requirements.

The application composition root selects one `Ads` implementation and injects it into features. Provider-specific unit IDs stay in provider configuration. This change does not define provider selection, dual-provider arbitration, or manual first-response-wins requests; mediation/fallback belongs to the selected mediation platform.

## Risks / Trade-offs

- [Existing callers construct `GroMoreAds` directly] -> Mark the constructor removal as breaking, update both examples/root Riverpod composition, and provide a short migration snippet.
- [A page disposes the shared runtime] -> Document composition-root ownership, keep the Riverpod provider alive, and add a test proving every reference observes terminal disposal.
- [Static Dart state makes isolated unit cases harder] -> Test singleton sequences in one case or separate Dart isolates; do not expose a production reset API that violates runtime semantics.
- [Two Flutter engines initialize simultaneously] -> Use one process coordinator with joined waiters and test the coordinator logic independently of fabricated SDK success, then verify the real path on devices.
- [The SDK succeeds after an engine detaches] -> Keep process SDK success but remove the detached waiter; never address the detached Messenger or restore its host state.
- [A show watchdog expires during a legitimate long ad] -> Use a conservative terminal deadline, separate it from presentation acknowledgement, and adjust only from recorded device evidence.
- [Legacy and modern reward callbacks disagree] -> Prefer the pinned SDK's current callback semantics, retain diagnostics, emit no duplicate grant, and require backend verification for valuable rewards.
- [Future Google semantics differ] -> Keep provider diagnostics and provider packages separate; extend common models only for verified cross-provider concepts.

## Migration Plan

1. Add equality/fingerprint support to immutable GroMore configuration and extend verified reward transport fields.
2. Introduce the private shared Dart runtime, shared initialization Future, epoch guards, and terminal disposal behavior while keeping existing placement APIs unchanged.
3. Regenerate Pigeon bindings and implement native once-only completion/watchdog helpers.
4. Add Android and iOS process initialization coordinators, then route engine hosts through them.
5. Correct reward aggregation and move revenue extraction to confirmed impression callbacks.
6. Migrate the plugin example and root Riverpod repository to `GroMoreAds.configure(config)` with composition-root-only disposal.
7. Update lifecycle/privacy/migration documentation and run Dart analysis/tests, Pigeon drift, native builds, and the existing real-device acceptance matrix.

Rollback before release is source-compatible only by reverting the change as a unit. After release, callers migrate by replacing direct construction; feature code typed as `Ads` requires no changes.

## Open Questions

- Confirm the conservative terminal show watchdog value with recorded Android/iOS device durations before release; the public contract requires a bound but does not require a particular duration.
- Confirm the exact pinned Android/iOS field used for reward `customData` and document unsupported platform differences before generating transport code; no unverified field will be synthesized.
