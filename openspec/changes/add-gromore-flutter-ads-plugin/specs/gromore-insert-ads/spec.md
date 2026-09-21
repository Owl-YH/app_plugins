## ADDED Requirements

### Requirement: Insert load lifecycle
The system SHALL manage one insert-ad session per configured placement through idle, loading, ready, showing, and terminal cleanup states.

#### Scenario: Insert load succeeds
- **WHEN** `loadInsert` is called for a valid insert placement after initialization and GroMore reports a completed load whose mediation object is ready
- **THEN** the session becomes ready and `AdLoaded` is emitted

#### Scenario: Insert load fails
- **WHEN** GroMore reports an insert load failure
- **THEN** the load future fails with `loadFailed`, `AdFailed` preserves native diagnostics, partial native state is released, and the session returns to idle

#### Scenario: Insert load is duplicated while loading
- **WHEN** `loadInsert` is called again for the same placement while its session is loading
- **THEN** the second call fails with `alreadyLoading` and no second native request is created

#### Scenario: Insert load is requested while ready
- **WHEN** `loadInsert` is called for a placement that already owns a ready insert ad
- **THEN** the call completes without replacing the ready object or issuing another native request

### Requirement: Insert readiness is verified natively
The system SHALL report an insert placement as ready only when it owns the current native object and the GroMore mediation readiness API reports that it can display.

#### Scenario: Ready insert becomes invalid
- **WHEN** the Dart session is ready but native `isReady` returns false
- **THEN** `isInsertReady` returns false, destroys the unusable object, and returns the session to idle

#### Scenario: Insert readiness is queried before load
- **WHEN** `isInsertReady` is called for an idle valid placement
- **THEN** it returns false without issuing a load

### Requirement: Insert display is one-shot
The system SHALL display a ready insert ad at most once and SHALL destroy or release it after close or show failure.

#### Scenario: Ready insert is displayed
- **WHEN** `showInsert` is called with a current presenter and native readiness remains true
- **THEN** the session enters showing, emits shown/clicked/closed events from native callbacks, and returns to idle after close

#### Scenario: Insert is shown again without a new load
- **WHEN** `showInsert` is called after the previously displayed object closed
- **THEN** it fails with `notReady`

#### Scenario: Insert show fails
- **WHEN** native presentation reports failure
- **THEN** the show future fails with `showFailed`, `AdFailed` is emitted, the object is destroyed or released, and the session returns to idle

#### Scenario: Presenter is unavailable
- **WHEN** Android has no attached Activity or iOS has no safe top ViewController
- **THEN** `showInsert` fails with `presenterUnavailable` without consuming a still-valid ready object

### Requirement: Insert revenue metadata
The system SHALL emit post-display revenue metadata only when GroMore makes it available and SHALL preserve the serving ADN name, ADN placement, and an optional verified eCPM value without guessing missing values or units.

#### Scenario: Post-display metadata is available
- **WHEN** GroMore exposes serving-network and eCPM data after insert display
- **THEN** the provider emits `AdRevenue` for the insert placement with normalized verified fields

#### Scenario: ADN omits eCPM
- **WHEN** the serving ADN supplies network identity but no usable eCPM
- **THEN** `AdRevenue` keeps eCPM absent rather than substituting zero or a fabricated value

### Requirement: Insert callback generations
The system SHALL associate insert callbacks with the request generation that created the native object and SHALL ignore stale callbacks.

#### Scenario: Old insert request finishes late
- **WHEN** an invalidated older insert request reports success after a newer generation exists
- **THEN** the old object is destroyed and does not replace the current session

#### Scenario: Callback arrives after consent withdrawal
- **WHEN** a native insert callback arrives after the request was invalidated by withdrawal
- **THEN** it is ignored and the returned object is destroyed

### Requirement: No automatic insert retry or cache queue
The plugin SHALL hold at most one ready insert object per placement and SHALL NOT automatically retry a failed show, reload after close, maintain a queue, or persist ad material.

#### Scenario: Insert show fails
- **WHEN** an insert presentation fails
- **THEN** the provider performs no automatic second presentation attempt

