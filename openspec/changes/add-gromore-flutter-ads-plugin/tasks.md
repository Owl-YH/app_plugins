## 1. Verify the official native contract

- [x] 1.1 Obtain the production GroMore Android SDK, iOS SDK, and matching official demos from the authorized ByteDance distribution channel, then record their release dates, exact Maven/CocoaPods coordinates, checksums, and minimum platform requirements.
- [x] 1.2 Inspect the pinned Android artifacts and demo to document the actual initialization, reward-ad, full-screen insert-ad, revenue, privacy-controller, and disposal APIs used by this plugin.
- [x] 1.3 Inspect the pinned iOS headers and demo to document the actual initialization, reward-ad, full-screen insert-ad, revenue, privacy-provider, presentation, and disposal APIs used by this plugin.
- [x] 1.4 Create `docs/versions.md` with the verified GroMore base SDK versions plus every enabled ADN SDK/adapter pair, and add a rule that rejects placeholder, beta-example, dynamic, or mismatched versions.
- [x] 1.5 Resolve the design open questions against the pinned SDKs: supported runtime privacy updates, obtainable paid-value precision/currency fields, full-screen class choice, and native error fields; record unsupported fields explicitly rather than synthesizing values.

## 2. Scaffold the package boundary

- [x] 2.1 Create `packages/owl_ads` as a pure Dart package with no Flutter or native SDK dependency, public library exports, repository metadata, and the workspace-supported Dart constraint.
- [x] 2.2 Create `packages/owl_ads_gromore` as a federated-ready Flutter plugin using Kotlin on Android and Swift on iOS, depending on `owl_ads` and declaring Android API 24 and iOS 13 as its minimums.
- [x] 2.3 Add a dedicated `packages/owl_ads_gromore/example` application without changing the existing root NFC application's runtime behavior or dependencies.
- [x] 2.4 Configure example App IDs, Code IDs, test-device identifiers, and signing values through ignored local configuration or build-time defines; fail clearly when required real credentials are absent and commit no usable credentials.

## 3. Implement and test the provider-neutral Dart API

- [x] 3.1 Implement immutable core types for consent, placement identity, reward options/result, ad readiness, normalized errors, revenue, and domain events.
- [x] 3.2 Implement the `Ads` facade contract for initialization, consent updates, reward load/readiness/show, insert load/readiness/show, event streaming, and disposal.
- [x] 3.3 Define and document normalized error codes including invalid state, consent required, already loading, not ready, presenter unavailable, native load/show failure, and disposed, while retaining provider/native diagnostics separately.
- [x] 3.4 Add pure Dart tests for value equality, validation, lifecycle guards, reward outcomes, event ordering rules, and disposal behavior without mocking or pretending to execute a native SDK.
- [x] 3.5 Add an explicit unsupported-format result for splash, banner, feed, draw, and any provider capability outside the first release.

## 4. Generate the typed Flutter/native boundary

- [x] 4.1 Pin a Pigeon generator version compatible with the repository toolchain and define typed host APIs, Flutter callback APIs, enums, and DTOs for initialization, consent, reward, insert, events, errors, and disposal.
- [x] 4.2 Generate and commit the Dart, Kotlin, and Swift Pigeon bindings, then add a reproducible generation command and a drift check that fails when committed output is stale.
- [x] 4.3 Implement explicit mappers between Pigeon DTOs and public Dart domain types so generated transport types do not leak from the plugin API.
- [x] 4.4 Add boundary tests for enum evolution, nullable native diagnostics, request-generation correlation, and unknown future event/error values.

## 5. Implement the Dart GroMore provider

- [x] 5.1 Implement validated immutable `GroMoreConfig`, `GroMoreAdUnit`, and `GroMoreAccess` types; keep App IDs and Code IDs out of the provider-neutral package and prevent callers from disabling mediation.
- [x] 5.2 Implement `GroMoreAds` as the `Ads` provider with an initialization state machine and a consent hard gate before every initialize, load, and show operation.
- [x] 5.3 Implement per-placement reward and insert sessions with request generations, duplicate-load suppression, ready-state checks, one-shot show semantics, and terminal cleanup.
- [x] 5.4 Implement native callback-to-domain event mapping, normalized errors, reward close outcomes, event stream shutdown, and idempotent disposal without disk caching, automatic retries, or automatic reloads.
- [x] 5.5 Add Dart tests using deterministic state-machine inputs and mapper fixtures captured from the verified native contract; do not create a fake advertising provider or report simulated SDK success.

## 6. Implement Android GroMore integration

- [x] 6.1 Add only the verified GroMore mediation base dependency to the plugin Android build, with required repositories, manifest entries, consumer ProGuard/R8 rules, and no bundled optional ADN dependencies.
- [x] 6.2 Implement the Flutter V2 plugin lifecycle and `ActivityAware` handling, rejecting show operations with `presenterUnavailable` when no valid activity is attached.
- [x] 6.3 Implement one-time GroMore initialization with mediation forced on, verified `TTCustomController` and mediation privacy mappings, and native request blocking until successful initialization.
- [x] 6.4 Implement the reward coordinator with verified Code ID use, load callbacks, cache/readiness checks, strong object retention, one-shot show, reward verification data, terminal event ordering, and destruction.
- [x] 6.5 Implement the full-screen insert coordinator with verified Code ID use, load callbacks, cache/readiness checks, one-shot show, terminal event ordering, post-show revenue extraction when supported, and destruction.
- [x] 6.6 Correlate every Android callback with placement and request generation, discard stale callbacks after replacement/withdrawal/disposal, and map native failures to normalized errors with diagnostic details.

## 7. Implement iOS GroMore integration

- [x] 7.1 Add only the verified GroMore mediation base pod and required privacy resources/framework settings to the plugin podspec, with no bundled optional ADN dependencies.
- [x] 7.2 Implement plugin registration and current-presenter resolution at show time, returning `presenterUnavailable` for missing presenters or presentation conflicts while retaining native diagnostics.
- [x] 7.3 Implement one-time GroMore initialization with mediation forced on, the verified `BUAdSDKPrivacyProvider` mappings, and native request blocking until successful initialization.
- [x] 7.4 Implement the reward coordinator with a new verified ad object per load, strong ad/delegate retention, readiness checks, one-shot presentation, reward verification data, terminal event ordering, and reference release.
- [x] 7.5 Implement the full-screen insert coordinator with a new verified ad object per load, strong ad/delegate retention, readiness checks, one-shot presentation, terminal event ordering, supported post-show revenue extraction, and reference release.
- [x] 7.6 Correlate every iOS callback with placement and request generation, discard stale callbacks after replacement/withdrawal/disposal, and map native failures to normalized errors with diagnostic details.

## 8. Enforce consent, access, and withdrawal behavior

- [x] 8.1 Apply the consent hard gate independently in Dart, Android, and iOS so a direct or out-of-order platform invocation cannot initialize, load, or show before consent.
- [x] 8.2 Map only verified `GroMoreAccess` privacy fields, default each optional data access to denied, and document which operating-system permissions remain owned by the host app.
- [x] 8.3 Implement verified runtime privacy updates; when a pinned SDK cannot update a field safely, return a documented restart-required or unsupported result instead of claiming success.
- [x] 8.4 On consent withdrawal, reject future requests, invalidate pending generations, destroy/release ready ad objects, emit the required terminal failures, and avoid claiming that the process-wide SDK has been deinitialized.

## 9. Document and demonstrate real host integration

- [x] 9.1 Build an example screen that initializes with explicit consent, loads/shows reward and insert ads, displays readiness and domain events, and clearly separates user-close from verified reward outcomes using real configured placements only.
- [x] 9.2 Document Android host setup for repositories, App ID/Code IDs, manifest and network/security requirements, optional ADN dependencies, version matching, privacy declarations, shrinker rules, and release-build verification.
- [x] 9.3 Document iOS host setup for App ID/Code IDs, CocoaPods, optional ADN dependencies, version matching, `PrivacyInfo.xcprivacy`, SKAdNetwork entries, ATT/permission ownership, and release-build verification.
- [x] 9.4 Document consent sequencing, `GroMoreAccess` defaults, withdrawal limits, reward server-side verification, event/error contracts, lifecycle constraints, and the intentional absence of retries, preload queues, and fake deinitialization.
- [x] 9.5 Add a release checklist that requires updating `docs/versions.md` and re-running native acceptance checks whenever GroMore or any ADN SDK/adapter changes.

## 10. Run automated verification

- [x] 10.1 Run Dart formatting, static analysis, and package tests for `owl_ads`, `owl_ads_gromore`, and the example; fix every plugin-owned failure.
- [x] 10.2 Run the Pigeon drift check and verify package publication metadata with `dart pub publish --dry-run` or the workspace-equivalent command.
- [x] 10.3 Build Android debug and release variants, run Android unit/lint checks, inspect the resolved dependency graph, and verify that no unselected ADN is packaged.
- [x] 10.4 Install iOS pods and build debug and release variants for simulator plus a signing-capable device target, inspect linked frameworks/privacy manifests, and verify that no unselected ADN is packaged.

## 11. Complete real-device acceptance

- [ ] 11.1 On a physical Android device, verify consent-gated initialization, reward load/show/close/reward, insert load/show/close, click/revenue events, rotation, background/foreground, activity detach/reattach, withdrawal, disposal, and a minified release build.
- [ ] 11.2 On a physical iOS device, verify the same flows plus presenter resolution, interruption/presentation conflicts, background/foreground, withdrawal, disposal, ATT host ownership, and a release build.
- [ ] 11.3 Verify reward server-side callbacks with the real backend and confirm that client `rewarded` events are treated as UI feedback rather than authoritative settlement.
- [ ] 11.4 Repeat load/show/click/revenue/error acceptance for every enabled ADN SDK/adapter pair in `docs/versions.md` and attach the tested version matrix and device/OS results to the release record.
