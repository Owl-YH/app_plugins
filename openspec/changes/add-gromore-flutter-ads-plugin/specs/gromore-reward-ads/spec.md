## ADDED Requirements

### Requirement: Reward load lifecycle
The system SHALL manage one reward-ad session per configured placement through idle, loading, ready, showing, and terminal cleanup states.

#### Scenario: Reward load succeeds
- **WHEN** `loadReward` is called for a valid reward placement after initialization and GroMore reports a completed load whose mediation object is ready
- **THEN** the session becomes ready and `AdLoaded` is emitted

#### Scenario: Reward load fails
- **WHEN** GroMore reports a reward load failure
- **THEN** the load future fails with `loadFailed`, `AdFailed` preserves native diagnostics, partial native state is released, and the session returns to idle

#### Scenario: Reward load is duplicated while loading
- **WHEN** `loadReward` is called again for the same placement while its session is loading
- **THEN** the second call fails with `alreadyLoading` and no second native request is created

#### Scenario: Reward load is requested while ready
- **WHEN** `loadReward` is called for a placement that already owns a ready reward ad
- **THEN** the call completes without replacing the ready object or issuing another native request

#### Scenario: Different placements load concurrently
- **WHEN** two configured reward placements are loaded at the same time
- **THEN** each placement maintains an independent session and request generation

### Requirement: Reward readiness is verified natively
The system SHALL report a reward placement as ready only when it owns the current native object and the GroMore mediation readiness API reports that it can display.

#### Scenario: Cached object expires
- **WHEN** the Dart session is ready but native `isReady` returns false
- **THEN** `isRewardReady` returns false, releases the unusable object, and returns the session to idle

#### Scenario: Reward readiness is queried before load
- **WHEN** `isRewardReady` is called for an idle valid placement
- **THEN** it returns false without issuing a load

### Requirement: Reward display is one-shot
The system SHALL display a ready reward ad at most once and SHALL release it after close or show failure.

#### Scenario: Ready reward is displayed
- **WHEN** `showReward` is called with a current presenter and native readiness remains true
- **THEN** the session enters showing, emits the native-equivalent shown/clicked/closed events, and returns to idle after close

#### Scenario: Reward is shown again without a new load
- **WHEN** `showReward` is called after the previously displayed object closed
- **THEN** it fails with `notReady`

#### Scenario: Reward show fails
- **WHEN** native presentation reports failure
- **THEN** the show future fails with `showFailed`, `AdFailed` is emitted, the object is released, and the session returns to idle

#### Scenario: Presenter is unavailable
- **WHEN** Android has no attached Activity or iOS has no safe top ViewController
- **THEN** `showReward` fails with `presenterUnavailable` without consuming a still-valid ready object

### Requirement: Reward options and outcome
The system SHALL support optional user ID, reward name, reward amount, and custom data for reward requests and SHALL return a normalized `RewardResult` when the presentation closes.

#### Scenario: Verified reward arrives before close
- **WHEN** native callbacks report a verified reward and then close
- **THEN** `showReward` completes with rewarded and verified true plus available reward metadata

#### Scenario: Ad closes without a reward callback
- **WHEN** the user closes or skips an ad without a valid reward callback
- **THEN** `showReward` completes with rewarded false

#### Scenario: Verification fails
- **WHEN** native server-reward verification reports failure
- **THEN** the provider emits a failed reward outcome with native diagnostics and does not represent it as a verified reward

### Requirement: Server verification for valuable rewards
The system SHALL preserve the identifiers and verification result required for GroMore server-side reward verification and SHALL document server verification as authoritative for server-owned value.

#### Scenario: Application grants server-owned value
- **WHEN** a reward controls currency, entitlement, or another server-owned asset
- **THEN** the example and documentation require the host backend to validate the GroMore server callback before final settlement

### Requirement: Reward callback generations
The system SHALL associate reward callbacks with the request generation that created the native object and SHALL ignore stale callbacks.

#### Scenario: Old reward load finishes late
- **WHEN** an invalidated older request reports success after a newer generation exists
- **THEN** the old object is released and does not replace or emit loaded for the current session

#### Scenario: Callback arrives after disposal
- **WHEN** a native reward callback arrives after provider disposal
- **THEN** it is ignored and creates no domain event or completed future

### Requirement: No competing plugin reward cache
The plugin SHALL hold at most one ready reward object per placement and SHALL NOT implement material disk caching, a ready queue, automatic reload after close, or automatic retry loops.

#### Scenario: Reward closes
- **WHEN** a reward presentation closes
- **THEN** the plugin returns the placement to idle and does not automatically call load again

