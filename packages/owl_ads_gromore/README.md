# owl_ads_gromore

Typed Android/iOS GroMore mediation provider for the provider-neutral
`owl_ads` API. Version `0.1.0` supports reward and full-screen insert ads only.

After its `0.1.0` release is available on pub.dev, add:

```yaml
dependencies:
  owl_ads_gromore: ^0.1.0
```

This provider depends on the separately published `owl_ads` package. The
package example keeps a local path dependency while developing this source.

The plugin uses real native SDKs and contains no demo App ID, fallback Code ID,
simulated provider, automatic retry, automatic reload, persistent ad cache, or
permission/ATT prompt.

## Minimums and pinned base SDKs

- Flutter 3.44.6 / Dart 3.12.2
- Android API 24, `com.pangle.cn:mediation-sdk:7.7.1.6`
- iOS 13, `Ads-CN/BUAdSDK` and `Ads-CN/CSJMediation-Only` `7.7.0.6`
- Pigeon `27.3.0`

See [the audited version matrix](docs/versions.md) before adding any optional
ADN. The plugin intentionally bundles no Baidu, GDT, Kuaishou, Sigmob, or other
third-party adapter.

## Usage

App IDs and Code IDs belong at the application composition root, not inside
feature code or `owl_ads`:

```dart
final reward = AdPlacement('reward_after_level');
final insert = AdPlacement('insert_between_rounds');

final ads = GroMoreAds.configure(
  GroMoreConfig(
    androidAppId: const String.fromEnvironment('GROMORE_ANDROID_APP_ID'),
    iosAppId: const String.fromEnvironment('GROMORE_IOS_APP_ID'),
    units: <AdPlacement, GroMoreAdUnit>{
      reward: GroMoreAdUnit(
        type: AdType.reward,
        androidCodeId: const String.fromEnvironment('GROMORE_REWARD_ANDROID_CODE_ID'),
        iosCodeId: const String.fromEnvironment('GROMORE_REWARD_IOS_CODE_ID'),
      ),
      insert: GroMoreAdUnit(
        type: AdType.insert,
        androidCodeId: const String.fromEnvironment('GROMORE_INSERT_ANDROID_CODE_ID'),
        iosCodeId: const String.fromEnvironment('GROMORE_INSERT_IOS_CODE_ID'),
      ),
    },
  ),
);

await ads.init(const AdConsent(accepted: true, personalizedAds: false));
await ads.loadReward(
  reward,
  options: const RewardOptions(
    userId: 'host-user-id',
    customData: 'backend-correlation-id',
  ),
);
if (await ads.isRewardReady(reward)) {
  final result = await ads.showReward(reward);
  // UI feedback only. Use your real server-side callback for settlement.
  print('rewarded=${result.rewarded}, verified=${result.verified}');
}
```

Configuration rejects blank IDs, unknown placements, type mismatches, and V1
unsupported formats before invoking native code. `init`, every load, and every
show are independently consent-gated in Dart, Android, and iOS.

`GroMoreAds.configure` returns one runtime per Dart isolate. Equivalent
configuration returns the identical object; conflicting configuration fails
with `configurationConflict`. Different placements still load independently.
Only the application composition root owns terminal `dispose`; pages and
feature controllers cancel their subscriptions but never dispose this runtime.

Android and iOS coordinate the process-wide GroMore startup across Flutter
engines. Compatible engines join one initialization operation; a different App
ID or immutable privacy configuration fails instead of racing SDK startup.

`customData` maps only to the verified Android `setMediaExtra` and iOS reward
model `extra` fields. It is opaque correlation data. For currency,
entitlements, or other server-owned value, settle only after the authoritative
advertising-platform server callback.

## Host setup

- [Android integration](docs/android-setup.md)
- [iOS integration](docs/ios-setup.md)
- [Consent, access, events, and lifecycle](docs/privacy-lifecycle.md)
- [Release checklist](docs/release-checklist.md)
- [Acceptance record](docs/acceptance-record.md)
- [Verified native contract](docs/native-contract.md)
- [Shared-runtime migration](docs/migration-shared-runtime.md)

The executable [example](example) accepts only ignored
`--dart-define-from-file` credentials and displays readiness, domain events,
consent withdrawal, and reward close/verification outcomes.

The provider-neutral `owl_ads` package intentionally has no singleton or
provider registry. A future direct Google implementation belongs in a separate
`owl_ads_google` package and can be selected at the application composition
root without changing feature calls or placement names.
