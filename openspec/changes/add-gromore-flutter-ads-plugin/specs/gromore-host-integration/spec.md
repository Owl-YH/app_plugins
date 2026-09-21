## ADDED Requirements

### Requirement: Supported native platforms
The GroMore provider SHALL support Android API 24 or newer and iOS 13 or newer using a standard Flutter plugin with Kotlin and Swift implementations.

#### Scenario: Android host meets the minimum
- **WHEN** an Android application with minSdk 24 or newer consumes the provider
- **THEN** its GroMore native dependency can be resolved and compiled with the project's Java/Kotlin toolchain

#### Scenario: iOS host meets the minimum
- **WHEN** an iOS application with deployment target 13 or newer consumes the provider
- **THEN** its GroMore Pod dependencies can be resolved and compiled

### Requirement: Typed generated bridge
The provider SHALL use a pinned Pigeon definition as the only Dart/native command and callback protocol and SHALL commit all generated Dart, Kotlin, and Swift outputs.

#### Scenario: Generated files are stale
- **WHEN** Pigeon generation produces a diff from committed outputs
- **THEN** verification fails before release

#### Scenario: Public API is inspected
- **WHEN** an application imports `owl_ads_gromore`
- **THEN** generated Pigeon DTOs are not exported as public domain types

### Requirement: Exact GroMore dependency versions
The provider SHALL pin exact, currently verified GroMore Android and iOS base dependency versions and SHALL reject dynamic versions such as `latest`, `+`, ranges without a reviewed lock, or placeholder `x.x.x` coordinates.

#### Scenario: Official docs contain placeholders
- **WHEN** the documented dependency example contains beta or placeholder coordinates
- **THEN** implementation uses the exact coordinate verified from the current official SDK download/demo instead of copying the placeholder

#### Scenario: Plugin dependency is upgraded
- **WHEN** the GroMore base SDK version changes
- **THEN** Android and iOS builds, real-device reward/insert flows, and `docs/versions.md` are updated before the plugin version is released

### Requirement: ADN adapters are host-selected and version-matched
The provider SHALL include the GroMore mediation base dependency but SHALL NOT bundle every third-party ADN SDK or adapter. The host SHALL add only the networks it uses with pairs supported by the recorded compatibility matrix.

#### Scenario: Host uses only the base GroMore/Pangle capability
- **WHEN** no additional ADN is selected
- **THEN** the provider compiles without GDT, KS, Baidu, Sigmob, Mintegral, or unrelated adapters

#### Scenario: Host enables an ADN
- **WHEN** the host adds a third-party ADN
- **THEN** it adds both the ADN SDK and the exact matching GroMore adapter plus documented manifest/linker/privacy configuration

#### Scenario: Adapter pair is unsupported
- **WHEN** an ADN SDK/adapter pair is absent from `docs/versions.md`
- **THEN** the integration is not represented as supported until its build and real-device flow are verified

### Requirement: Host and plugin configuration ownership
The provider SHALL own only base-SDK native code, necessary non-sensitive plugin manifest/resources, consumer rules, and SDK initialization. The host SHALL own sensitive/optional permissions, privacy disclosures, ATT, SKAdNetwork entries, PrivacyInfo merging, and ADN-specific configuration.

#### Scenario: Optional Android permission is not needed
- **WHEN** the host does not need an optional sensitive capability
- **THEN** consuming the plugin does not add or request that permission automatically

#### Scenario: iOS app prepares for release
- **WHEN** an iOS host enables GroMore or a third-party ADN
- **THEN** it completes the documented PrivacyInfo, SKAdNetwork, Info.plist, linker, and optional ATT configuration for the actual SDK set

### Requirement: Android Activity lifecycle safety
The Android implementation SHALL implement Flutter V2 plugin attachment and `ActivityAware`, SHALL release Activity references on detach, and SHALL NOT store an Activity in a static field.

#### Scenario: Configuration change occurs before show
- **WHEN** Android detaches and reattaches the Activity for a configuration change
- **THEN** a later show uses the newly attached Activity

#### Scenario: Engine is detached
- **WHEN** the Flutter engine detaches the plugin
- **THEN** channels, callbacks, sessions, ad objects, and Activity references are released

### Requirement: iOS presenter lifecycle safety
The iOS implementation SHALL resolve the active foreground scene and topmost safe ViewController at show time and SHALL retain native ad/delegate objects until terminal callbacks.

#### Scenario: Another controller is already being presented
- **WHEN** no safe presenter is available because presentation is in conflict
- **THEN** show fails with `presenterUnavailable` or a more specific normalized presentation error

#### Scenario: Temporary ad variable would be released
- **WHEN** an iOS ad request starts
- **THEN** the provider stores the ad and delegate strongly until load failure, close, invalidation, or disposal

### Requirement: Version and integration documentation
The provider SHALL include a host integration guide and `docs/versions.md` recording plugin version, GroMore versions, supported adapter pairs, platform minimums, required configuration, and verification date.

#### Scenario: Developer integrates the plugin
- **WHEN** a developer follows the guide for the selected platform and ADN set
- **THEN** every required host-owned configuration step is explicit and no sensitive permission is silently assumed

### Requirement: Real example and acceptance path
The provider SHALL contain an Android/iOS example that uses real GroMore APIs, accepts real IDs outside source control, exposes init/load/readiness/show/withdrawal/diagnostics controls, and does not fabricate successful SDK responses.

#### Scenario: Example has no local IDs
- **WHEN** the example starts without real app or placement IDs
- **THEN** it reports a configuration error and does not substitute demo-shaped fake results

#### Scenario: Real IDs are supplied
- **WHEN** valid IDs and accepted consent are provided on a real device
- **THEN** the example exercises the actual GroMore initialization, reward, and insert flows

### Requirement: Proportionate automated and device verification
The change SHALL run Dart analysis/tests, Pigeon drift verification, Android build/lint, iOS dependency/build checks, release dependency inspection, and a recorded Android/iOS real-device acceptance matrix before release.

#### Scenario: Release contains a test-only GroMore tool
- **WHEN** release dependency inspection finds a mediation test tool or debug-only SDK
- **THEN** verification fails

#### Scenario: Native build passes without device evidence
- **WHEN** Android and iOS compilation succeeds but reward/insert device acceptance is not recorded
- **THEN** the plugin is not marked release-ready
