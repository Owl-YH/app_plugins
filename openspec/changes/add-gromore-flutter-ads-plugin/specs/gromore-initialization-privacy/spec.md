## ADDED Requirements

### Requirement: Validated immutable GroMore configuration
The system SHALL require immutable Android and iOS GroMore app IDs and a placement-to-`GroMoreAdUnit` map before initialization. Every unit SHALL contain an ad type and the platform-specific GroMore placement IDs required by the supported platforms.

#### Scenario: Valid configuration is accepted
- **WHEN** both platform app IDs and all reward or insert unit IDs are non-empty and each unit type matches its configured usage
- **THEN** configuration validation succeeds without contacting the native SDK

#### Scenario: Unit type does not match an operation
- **WHEN** `loadReward` receives a placement configured as an insert unit
- **THEN** the operation fails with `wrongAdType` before a native request is made

#### Scenario: Platform identifier is missing
- **WHEN** the current platform's app ID or placement ID is empty
- **THEN** initialization or load fails with a configuration error identifying the missing field

### Requirement: GroMore mediation is always enabled
The GroMore provider SHALL enable GroMore mediation during native initialization and SHALL NOT expose a runtime or Dart configuration switch that disables mediation.

#### Scenario: Android initializes GroMore
- **WHEN** native Android initialization builds its `TTAdConfig`
- **THEN** it sets `useMediation(true)` exactly once

#### Scenario: iOS initializes GroMore
- **WHEN** native iOS initialization builds its `BUAdSDKConfiguration`
- **THEN** it sets `useMediation = YES` and requires the mediation base library

### Requirement: Consent gate before native startup
The system MUST prevent GroMore startup, ADN initialization, and ad requests until the host application supplies `AdConsent.accepted == true`.

#### Scenario: Initialization is attempted before consent
- **WHEN** `init` receives consent with `accepted == false`
- **THEN** it fails with `consentRequired` and no Pigeon initialization call is sent

#### Scenario: Native receives invalid consent
- **WHEN** a malformed or bypassed native initialization request has `accepted == false`
- **THEN** native code rejects it before invoking the GroMore initialization APIs

#### Scenario: Consent is accepted
- **WHEN** valid configuration and accepted consent are supplied
- **THEN** the provider initializes GroMore and does not permit ad requests until the native success callback completes

### Requirement: Idempotent single initialization
The system SHALL initialize the native GroMore SDK at most once per process configuration.

#### Scenario: Same configuration initializes again
- **WHEN** `init` is called after success with an equivalent immutable configuration and accepted consent
- **THEN** the call completes without repeating native initialization

#### Scenario: Different immutable configuration initializes again
- **WHEN** `init` is called after success with a different app ID, unit map, or initialization-only setting
- **THEN** it fails with `configurationConflict`

#### Scenario: Native initialization fails
- **WHEN** the GroMore start callback reports failure
- **THEN** initialization fails with the native code/message preserved and load/show remain blocked

### Requirement: Deny-by-default GroMore data access
The system SHALL provide a strongly typed `GroMoreAccess` model whose optional data-access capabilities default to denied and whose fields map only to interfaces verified in the pinned Android and iOS SDK versions.

#### Scenario: Access configuration is omitted
- **WHEN** an application constructs `GroMoreConfig` without explicit access grants
- **THEN** every optional GroMore data-access capability is denied

#### Scenario: Verified access is granted
- **WHEN** the host has the required system authorization and explicitly enables a supported access field
- **THEN** the provider maps that field to the documented native privacy controller for the current platform

#### Scenario: Native field has not been verified
- **WHEN** a desired privacy field is absent from the pinned SDK interface or documentation
- **THEN** the provider does not invent or transmit that field

### Requirement: Host owns system permission and ATT prompts
The plugin SHALL NOT request Android runtime permissions, request iOS ATT authorization, or display the host privacy-policy UI.

#### Scenario: GroMore needs optional location access
- **WHEN** the host has not granted location access
- **THEN** the plugin keeps location access disabled and does not open a system prompt

#### Scenario: iOS tracking preference changes
- **WHEN** the host receives an ATT result
- **THEN** the host explicitly updates the provider's consent/access configuration and the plugin itself does not invoke the ATT prompt

### Requirement: Consent withdrawal blocks future advertising work
The system SHALL immediately block new load/show operations, invalidate pending requests, and release ready ads when accepted consent is withdrawn.

#### Scenario: Consent is withdrawn with ready ads
- **WHEN** `updateConsent` changes accepted consent from true to false
- **THEN** all ready native reward and insert objects are destroyed or released and their sessions become blocked

#### Scenario: Load is attempted after withdrawal
- **WHEN** a caller loads an ad while consent is rejected
- **THEN** the operation fails with `consentRequired` without a native ad request

#### Scenario: Late callback follows withdrawal
- **WHEN** an invalidated native request reports success after consent withdrawal
- **THEN** the callback is ignored and its native ad object is destroyed

### Requirement: Runtime privacy updates are truthful
The system SHALL update only privacy settings that the pinned GroMore SDK documents as mutable after initialization and SHALL NOT claim that consent withdrawal deinitializes GroMore.

#### Scenario: Mutable preference changes
- **WHEN** personalized-ad preference changes and the pinned platform SDK supports runtime update
- **THEN** the provider applies it through the verified native update API

#### Scenario: Initialization-only access changes
- **WHEN** an initialization-only privacy field changes after initialization
- **THEN** the provider reports that restart/reinitialization is required instead of reporting a false success

