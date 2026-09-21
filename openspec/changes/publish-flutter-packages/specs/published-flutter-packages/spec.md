## ADDED Requirements

### Requirement: Independent authoritative package source
The plugins repository SHALL contain the complete reviewed source, public entry points, tests, examples, native bindings and release documentation for `ndef_kit`, `owl_ads`, `owl_ads_gromore`, `owl_haptics`, `owl_marquee`, and `spatial_confetti`. A clean checkout of this repository SHALL validate and build each package without accessing the MyCards source tree or ignored machine-local artifacts.

#### Scenario: Clone and validate source
- **WHEN** a maintainer checks out the plugins repository on a supported toolchain and resolves hosted dependencies
- **THEN** all six package source trees and their documented checks are available without a sibling MyCards checkout

### Requirement: Licensed and reviewable public archive
Every released package SHALL include a complete BSD-3-Clause LICENSE with an authorized copyright notice, accurate metadata and release notes. Before upload, the publisher SHALL inspect the dry-run archive and confirm that no secret, signing file, private configuration, unlicensed third-party binary, or unrelated build output is included.

#### Scenario: Package passes publication review
- **WHEN** an authorized uploader reviews a package version for first publication
- **THEN** the license, provenance, dependency metadata, archive file list and real validation record identify exactly what becomes public

#### Scenario: Unreviewed material is present
- **WHEN** any required right, file identity, secret scan, metadata item or archive check remains unresolved
- **THEN** that package version is not uploaded and no consumer is told to use it as published

### Requirement: Hosted dependency chain and resolvable versions
Every published package root SHALL use only pub.dev hosted and SDK dependencies. `owl_ads_gromore` SHALL depend on a released, resolvable `owl_ads` version rather than a local path. Each published version SHALL be verified as retrievable from pub.dev before a consuming App records it in a lockfile.

#### Scenario: Publish advertising provider
- **WHEN** `owl_ads_gromore` is prepared for public upload
- **THEN** its root manifest references a verified hosted `owl_ads` release and the publish dry-run has no local path dependency error

#### Scenario: Hosted version is not yet visible
- **WHEN** a package upload succeeds but the version cannot yet be resolved by a fresh consumer
- **THEN** downstream publication and consumer cutover wait until the exact version resolves

### Requirement: Real release evidence for native plugins
Native plugin releases SHALL retain generated host protocol drift checks, supported Android/iOS compilation and the package's documented physical-device/provider acceptance gates. A check that cannot run SHALL remain recorded as missing evidence and SHALL NOT be replaced by a mock, simulated success, or a claim of production readiness.

#### Scenario: GroMore release still lacks required acceptance
- **WHEN** its existing release checklist has unresolved real-device, native dependency, or authoritative SSV evidence
- **THEN** the `owl_ads_gromore` public upload is withheld and its dependent demo cutover remains pending

### Requirement: Hosted demo integration
After the respective package releases resolve, the plugins demo App SHALL declare `ndef_kit` and `owl_ads_gromore` hosted version dependencies and commit their lockfile resolution. Package examples SHALL remain able to exercise local source before a new release without becoming published root path dependencies.

#### Scenario: Demo installs from a clean checkout
- **WHEN** the demo App runs dependency installation from its committed manifest and lockfile
- **THEN** its two package dependencies resolve to reviewed hosted releases and the real NFC/advertising integration remains buildable
