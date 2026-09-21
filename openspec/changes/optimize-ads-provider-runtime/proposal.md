## Why

`GroMoreAds` currently permits multiple Dart instances even though its Pigeon callback channel and native SDK runtime are shared, so a later instance can replace an earlier callback handler and disposal can invalidate another caller's sessions. The provider should make its real ownership model explicit now, while preserving independent placement sessions and the provider-neutral boundary needed for a future direct Google Mobile Ads implementation.

## What Changes

- **BREAKING** Replace the public `GroMoreAds(GroMoreConfig)` constructor with one isolate-scoped shared-runtime entry point; equivalent configuration returns the same runtime and conflicting configuration fails deterministically.
- Keep concurrent advertising scoped below the runtime: reward and insert sessions remain independently keyed by placement and request generation, while the same placement remains single-flight and one-shot.
- Coalesce equivalent concurrent initialization calls, add an initialization epoch and terminal disposal guards, and guarantee that late initialization or ad callbacks cannot resurrect a disposed runtime.
- Coordinate GroMore initialization at process scope on Android and iOS so multiple Flutter engines share one compatible SDK start operation; reject conflicting App IDs and incompatible immutable settings.
- Define bounded initialization, load, and show completion behavior, with normalized timeout failures and exactly-once completion of every Dart/native call.
- Complete the reward contract using SDK-reported reward metadata, custom data/server-verification correlation, and an exactly-once final reward outcome rather than request defaults or duplicate legacy callbacks.
- Emit revenue metadata at the first confirmed impression/show callback, with per-generation exactly-once deduplication and no fabricated currency or precision.
- Keep `owl_ads` provider-neutral and keep singleton ownership provider-specific: a future `owl_ads_google` may expose its own shared runtime implementing `Ads` without changing feature code or turning `Ads` into a global provider registry.
- Document composition-root/Riverpod ownership so pages and feature controllers never construct or dispose the shared provider.

## Capabilities

### New Capabilities

- `ads-provider-runtime`: Shared provider ownership, process-wide initialization coordination, asynchronous completion guarantees, reward/revenue correctness, and the extension boundary for future provider implementations.

### Modified Capabilities

None. This change adds stricter runtime guarantees on top of the active GroMore V1 capabilities without widening the V1 ad-format surface.

## Impact

- Affects `packages/owl_ads_gromore` public construction, Dart lifecycle state, Pigeon DTOs, Android and iOS host implementations, tests, examples, and integration documentation.
- Keeps the `packages/owl_ads` `Ads` interface and feature-facing load/show calls provider-neutral; reward models gain only fields that have verified cross-provider meaning or preserved provider diagnostics.
- Requires migration of the root Riverpod composition and plugin example from direct construction to the shared GroMore runtime.
- Does not add Google SDK dependencies, a provider registry, runtime provider switching, automatic cross-provider fallback, or additional ad formats.
