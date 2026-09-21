## ADDED Requirements

### Requirement: Provider-neutral package boundary
The system SHALL provide `owl_ads` as a pure Dart package whose public API contains no GroMore, Pangle, Google Ads, Pigeon, Android, iOS, or permission-library types.

#### Scenario: Feature code uses the common contract
- **WHEN** a feature receives an object typed as `Ads`
- **THEN** it can initialize advertising, observe events, and load or show V1 ads without importing `owl_ads_gromore`

#### Scenario: Provider implementation is replaced
- **WHEN** the application composition root supplies another implementation of `Ads`
- **THEN** feature code using only `owl_ads` requires no source changes

### Requirement: Stable placement identity
The system SHALL represent an application advertising location with an immutable `AdPlacement` value object whose equality and hash code are derived from its non-empty stable name.

#### Scenario: Equivalent placements are map-compatible
- **WHEN** two `AdPlacement` values are constructed with the same valid name
- **THEN** they compare equal and address the same configured unit

#### Scenario: Empty placement is rejected
- **WHEN** an application constructs or validates a placement with an empty or whitespace-only name
- **THEN** the system reports an `invalidPlacement` configuration error before calling a provider

### Requirement: V1 advertising contract
The `Ads` interface SHALL expose initialization, consent update, event streaming, reward load/readiness/show, insert load/readiness/show, and disposal operations.

#### Scenario: Reward workflow is available
- **WHEN** feature code is given an `Ads` implementation
- **THEN** it can call `loadReward`, `isRewardReady`, and `showReward` with an `AdPlacement`

#### Scenario: Insert workflow is available
- **WHEN** feature code is given an `Ads` implementation
- **THEN** it can call `loadInsert`, `isInsertReady`, and `showInsert` with an `AdPlacement`

#### Scenario: Code IDs remain outside feature calls
- **WHEN** feature code loads or shows an ad
- **THEN** no Android app ID, iOS app ID, Android code ID, or iOS code ID is accepted by that operation

### Requirement: Normalized events
The system SHALL expose a broadcast stream of domain events for loaded, shown, clicked, closed, failed, rewarded, and revenue outcomes. Every event SHALL contain the placement and ad type and SHALL NOT expose generated Pigeon DTOs or native callback objects.

#### Scenario: Analytics observes an impression lifecycle
- **WHEN** a provider reports that a configured ad loaded, displayed, was clicked, and closed
- **THEN** the event stream emits the equivalent domain events with the same placement and ad type

#### Scenario: Native failure is normalized
- **WHEN** a provider returns a native load or show failure
- **THEN** the stream emits `AdFailed` with a stable domain error code and preserves optional native code and message for diagnostics

### Requirement: Stable error contract
The system SHALL define stable error codes including at least unsupported platform, not initialized, consent required, configuration conflict, invalid placement, wrong ad type, already loading, not ready, presenter unavailable, load failed, show failed, disposed, and native error.

#### Scenario: Application handles a provider-independent failure
- **WHEN** an operation fails because no ready ad exists
- **THEN** the caller receives `notReady` regardless of the underlying Android or iOS error representation

### Requirement: Unsupported-platform behavior
The system SHALL fail deterministically on platforms other than Android and iOS without invoking a platform channel.

#### Scenario: V1 API is called on an unsupported platform
- **WHEN** an application calls initialization, load, readiness, or show on web, macOS, Windows, or Linux
- **THEN** the operation fails with `unsupportedPlatform`

### Requirement: Disposal semantics
The `Ads` implementation SHALL provide idempotent disposal that closes its event stream, releases provider resources, and rejects later operations.

#### Scenario: Dispose is called twice
- **WHEN** the caller invokes `dispose` more than once
- **THEN** subsequent dispose calls complete without creating new native work

#### Scenario: Operation follows disposal
- **WHEN** the caller invokes an advertising operation after disposal
- **THEN** the operation fails with `disposed`

