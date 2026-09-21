# iOS host integration

## CocoaPods

The verified GroMore distribution is CocoaPods. Ensure the application uses
iOS 13 or newer and disables Flutter's project-level Swift Package Manager
integration for this dependency:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

Use the normal Flutter Podfile and static linkage because the official
BUAdSDK/CSJMediation binaries are static XCFrameworks:

```ruby
platform :ios, '13.0'

target 'Runner' do
  use_frameworks! :linkage => :static
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

Then run `flutter pub get` and `pod install`. `Podfile.lock` must resolve both
`Ads-CN/BUAdSDK` and `Ads-CN/CSJMediation-Only` to exactly `7.7.0.6`.

The plugin's generated `Package.swift` is intentionally absent: the official
reproducible distribution is the audited Pod, not an invented SPM binary
target.

## Optional ADNs and disclosure ownership

The host adds only selected third-party ADN SDK/adapter pods. Use the exact
adapter names and versions in `versions.md` plus the exact corresponding SDK
from the same official GroMore compatibility bundle. Do not mix the current
`7.8.0.0` media-platform adapter bundle with this plugin's `7.7.0.6` base until
ByteDance publishes and the project verifies a matching reproducible base.

`Ads-CN` includes `CSJAdSDK.bundle/PrivacyInfo.xcprivacy`; the plugin also ships
a manifest describing only the plugin wrapper's own access. The host remains
responsible for checking the merged archive and declaring its own data use and
every enabled ADN. Update the host `PrivacyInfo.xcprivacy` whenever the SDK or
adapter matrix changes.

Add the current SKAdNetwork identifiers required by GroMore and each enabled
ADN from their official documentation/console export. Do not copy a stale
hard-coded list from this plugin. The host also owns ATT timing and
`NSUserTrackingUsageDescription`; the plugin never displays ATT. Add location
or other Info.plist usage descriptions only when the host enables and lawfully
uses the corresponding access.

## Release verification

Build both simulator and device architectures. For the archive, inspect linked
frameworks, resources, privacy manifests, and `Podfile.lock`; no unselected ADN
may be present. Real-ad acceptance must run on a physical device because the
simulator build verifies linking only.

