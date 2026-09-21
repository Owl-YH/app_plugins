## ADDED Requirements

### Requirement: One GroMore runtime per Dart isolate
The system SHALL expose one shared `GroMoreAds` runtime per Dart isolate and SHALL NOT expose a public constructor that creates independently owned GroMore providers on the same Pigeon channels.

#### Scenario: Equivalent configuration is requested twice
- **WHEN** the composition root requests GroMore with an immutable configuration equivalent to the first configuration
- **THEN** both requests return the identical shared runtime and only one Flutter callback handler is registered

#### Scenario: Conflicting configuration is requested
- **WHEN** the shared runtime already exists and a caller supplies a different App ID, unit map, access configuration, debug setting, or other initialization-only setting
- **THEN** the request fails with `configurationConflict` without replacing callbacks or changing native state

#### Scenario: Shared runtime was disposed
- **WHEN** configuration is requested again after terminal runtime disposal in the same isolate
- **THEN** the system rejects recreation and performs no new native work

### Requirement: Placement sessions remain independent
The shared runtime SHALL maintain reward and insert state per ad type, placement, and request generation rather than limiting the process to one loaded ad.

#### Scenario: Different placements load concurrently
- **WHEN** two valid placements are loaded concurrently through the shared runtime
- **THEN** each owns an independent native session, completion, state, and request generation

#### Scenario: Same placement is loaded concurrently
- **WHEN** the same ad type and placement is already loading and another load is requested
- **THEN** no second native object is created and the existing single-flight rule is applied

### Requirement: Shared and idempotent initialization
The runtime SHALL retain one in-flight initialization operation, coalesce equivalent concurrent initialization calls, and prevent a late completion from changing state after disposal.

#### Scenario: Equivalent initialization overlaps
- **WHEN** two callers initialize the same runtime concurrently with equivalent accepted consent and immutable configuration
- **THEN** they await the same underlying native initialization and receive the same terminal outcome

#### Scenario: Incompatible initialization overlaps
- **WHEN** an initialization is in flight and another call supplies incompatible initial privacy or immutable configuration
- **THEN** the second call fails deterministically without changing the in-flight request

#### Scenario: Disposal races initialization success
- **WHEN** the runtime is disposed before native initialization reports success
- **THEN** it remains disposed, emits no post-disposal event, and the late completion cannot mark it initialized

### Requirement: Process-wide native initialization coordination
Android and iOS SHALL coordinate GroMore startup once per compatible process configuration while preserving engine-scoped channels, presenters, sessions, and ad objects.

#### Scenario: Two engines initialize the same configuration
- **WHEN** two Flutter engines request the same GroMore process configuration while startup is pending
- **THEN** one native SDK start operation runs and both live engine waiters receive its result

#### Scenario: Two engines request different App IDs
- **WHEN** a process startup is pending or complete for one App ID and another engine requests a different App ID
- **THEN** the conflicting request fails with `configurationConflict` without restarting or mutating the SDK

#### Scenario: Waiting engine detaches
- **WHEN** an engine detaches while waiting for a shared SDK startup result
- **THEN** its waiter is removed or completed as disposed and no callback is sent through its detached messenger

### Requirement: Terminal disposal has one owner boundary
Runtime disposal SHALL be idempotent and terminal, invalidate all placement generations owned by that engine, release plugin-owned resources, and SHALL NOT claim to deinitialize the process-wide GroMore SDK.

#### Scenario: Feature references share disposal state
- **WHEN** the composition root disposes the shared runtime through any reference
- **THEN** all references observe disposed state and later advertising operations fail with `disposed`

#### Scenario: A widget page is destroyed
- **WHEN** a page or feature controller using injected `Ads` is disposed
- **THEN** it does not dispose the shared provider or invalidate another feature's ad session

#### Scenario: Flutter engine detaches without Dart disposal
- **WHEN** the native plugin detaches from its Flutter engine
- **THEN** that engine's channels, pending completions, ads, delegates, and presenter references are released while process initialization identity remains truthful

### Requirement: Every asynchronous command completes exactly once
Initialization, load, and show operations SHALL have bounded completion behavior, and every native pending reply SHALL complete at most once across SDK callbacks, timeouts, withdrawal, disposal, and engine detach.

#### Scenario: Initialization callback never arrives
- **WHEN** GroMore does not complete initialization before its deadline
- **THEN** initialization fails with a normalized timeout diagnostic and the Dart Future does not remain pending

#### Scenario: Load callback never arrives
- **WHEN** a current reward or insert load receives no terminal SDK callback before its deadline
- **THEN** the request fails, its native object is released, its generation returns to idle, and its Future completes once

#### Scenario: SDK callback follows timeout
- **WHEN** a native callback arrives after its operation already timed out
- **THEN** the callback is discarded, any returned stale ad is released, and no second reply or domain event is produced

#### Scenario: Terminal show callback is lost
- **WHEN** an ad was presented but no close or show-failure callback arrives before the conservative terminal deadline
- **THEN** show fails with native diagnostics, the session is invalidated, and no reward is inferred

### Requirement: Reward outcomes use actual SDK callbacks
The system SHALL derive reward grant, verification, name, amount, and failure diagnostics from the current native SDK callbacks and SHALL treat request reward fields only as request metadata.

#### Scenario: SDK reports a verified reward
- **WHEN** the current session receives an SDK reward result with actual name, amount, and successful verification
- **THEN** the final `RewardResult` and the single rewarded event contain that SDK-reported outcome

#### Scenario: Request defaults differ from SDK result
- **WHEN** requested reward metadata differs from the SDK callback or the SDK omits a value
- **THEN** the provider preserves the SDK result or absence and does not substitute the request default as proof of reward

#### Scenario: Legacy and current callbacks both arrive
- **WHEN** the SDK invokes more than one reward callback for the same generation
- **THEN** the provider aggregates at most one effective outcome and emits no duplicate reward grant event

#### Scenario: Reward verification fails
- **WHEN** the SDK reports that the reward was not verified or reports a reward error
- **THEN** the provider does not represent it as a verified grant and preserves available native diagnostics

### Requirement: Reward custom data supports server correlation
The provider SHALL accept optional reward custom data, forward it only through fields verified in the pinned SDKs, and document backend verification as authoritative for server-owned value.

#### Scenario: Verified custom-data field exists
- **WHEN** a reward request includes custom data and the current platform's pinned SDK exposes the verified field
- **THEN** the provider forwards the value without changing it

#### Scenario: Platform field is not verified
- **WHEN** the pinned SDK has no verified custom-data mapping
- **THEN** the provider reports the limitation and does not invent a native key or claim forwarding success

#### Scenario: Client reports a reward
- **WHEN** the reward controls server-owned currency or entitlement
- **THEN** documentation requires backend settlement from the advertising platform's server callback rather than trusting the client result alone

### Requirement: Revenue is emitted once at confirmed display
The provider SHALL query available GroMore revenue metadata at the first confirmed show or visible callback for the current generation and SHALL emit at most one revenue event for that impression.

#### Scenario: Impression metadata is available
- **WHEN** the native SDK confirms display and exposes serving network, placement, raw eCPM, or request identity
- **THEN** the provider emits one revenue event immediately with only the available verified fields

#### Scenario: Visibility callback repeats
- **WHEN** the native SDK invokes its confirmed-display callback more than once for the same generation
- **THEN** no duplicate revenue event is emitted

#### Scenario: Metadata omits currency or precision
- **WHEN** GroMore exposes only its nullable raw eCPM string
- **THEN** the provider does not fabricate a currency, precision, zero value, or converted amount

### Requirement: Provider-neutral future extension boundary
The system SHALL keep shared runtime ownership inside provider packages and SHALL keep feature code dependent on the provider-neutral `Ads` contract.

#### Scenario: A direct Google provider is added later
- **WHEN** a future `owl_ads_google` implementation supplies `Ads`
- **THEN** feature load/show code and application-owned placement names require no provider-specific source changes

#### Scenario: Application selects a provider
- **WHEN** an application chooses GroMore or a future Google implementation at its composition root
- **THEN** exactly that provider is injected into features without requiring a global provider registry in `owl_ads`

#### Scenario: Both monetization networks are desired
- **WHEN** multiple demand sources are required for one inventory flow
- **THEN** the selected mediation platform owns arbitration and the Flutter layer does not issue competing first-response-wins requests automatically
