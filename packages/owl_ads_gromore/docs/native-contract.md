# Verified GroMore native contract

This contract was verified against the official Android `7.7.1.6` AAR/demo,
the CocoaPods-distributed iOS `7.7.0.6` frameworks, the authenticated iOS
`7.8.0.0` frameworks/demo, and the official GroMore integration pages.

## Android

Initialization uses `TTAdSdk.init(Context, TTAdConfig)` followed by
`TTAdSdk.start(TTAdSdk.Callback)`. `TTAdConfig.Builder.useMediation(true)` is
set once. Ad requests are permitted only after `success()` and
`TTAdSdk.isSdkReady()`.

Privacy is supplied through `TTCustomController` and its
`MediationPrivacyConfig`. Verified controller methods include location, phone
state, Wi-Fi state, external storage, OAID, Android ID, installed-app list,
record audio, and mediation personalization/programmatic controls. The plugin
defaults all optional access to denied and never requests permissions.
`TTAdSdk.updateAdConfig` is the verified runtime update entry point. The plugin
uses it only for consent/personalization changes; changing access capabilities
after initialization is reported as restart-required.

Reward ads use `AdSlot.Builder`, `TTAdNative.loadRewardVideoAd`,
`TTRewardVideoAd`, `RewardVideoAdListener`, and
`RewardAdInteractionListener`. Readiness is
`ad.getMediationManager().isReady()`. Reward data is reported by
`onRewardVerify` and `onRewardArrived`. The pinned `TTRewardVideoAd` interface
defines `REWARD_EXTRA_KEY_REWARD_NAME`, `REWARD_EXTRA_KEY_REWARD_AMOUNT`,
`REWARD_EXTRA_KEY_REWARD_PROPOSE`,
`REWARD_EXTRA_KEY_HAS_VIDEO_COMPLETE_REWARD`,
`REWARD_EXTRA_KEY_IS_SERVER_VERIFY`, `REWARD_EXTRA_KEY_ERROR_CODE`, and
`REWARD_EXTRA_KEY_ERROR_MSG`. The provider reads these Bundle values by type
and does not substitute request defaults. `AdSlot.Builder.setMediaExtra` is the
verified custom-data pass-through field; `setUserID`, `setRewardName`, and
`setRewardAmount` remain request metadata. The mediation constants additionally
expose transaction, ADN, reason, and GroMore-S2S keys for safe diagnostics. The
mediation manager is destroyed after load failure, show failure, close,
withdrawal, or disposal.

Insert ads use `TTAdNative.loadFullScreenVideoAd`, `TTFullScreenVideoAd`,
`FullScreenVideoAdListener`, and `FullScreenVideoAdInteractionListener`.
Readiness and destruction use `MediationFullScreenManager`.

Post-show metadata comes from `MediationBaseManager.getShowEcpm()` and
`MediationAdEcpmInfo`: `sdkName`, `slotId`, `ecpm`, `requestId`, and related
fields. `ecpm` is a nullable string. No currency or precision field is exposed,
so the plugin preserves the raw value and does not invent a numeric unit.
Native failures expose an integer code and message.

## iOS

Initialization configures the singleton returned by
`BUAdSDKConfiguration.configuration()`, sets `appID`, a privacy provider,
`mediation.limitPersonalAds`, and `useMediation = YES`, then calls
`BUAdSDKManager.startWithAsyncCompletionHandler`. Requests wait for a successful
completion and `BUAdSDKManager.state == BUAdSDKStateStart`.

`BUAdSDKPrivacyProvider` verifies location, BSSID, and the typed
`BUMPrivacyConfig` keys. `BUAdSDKConfigurationMediation` verifies
`limitPersonalAds`, `limitProgrammaticAds`, `forbiddenIDFA`, and
`allowUploadDeviceInfo`. Official documentation identifies personalization and
the listed mediation settings as runtime-mutable, but the plugin deliberately
limits runtime mutation to personalization/consent. Other access changes are
restart-required.

Reward ads use `BUAdSlot`, `BURewardedVideoModel`,
`BUNativeExpressRewardedVideoAd`, and
`BUMNativeExpressRewardedVideoAdDelegate`. The ad is strongly retained.
Readiness is `ad.mediation.isReady`; `showAdFromRootViewController` returns a
Boolean; load, show-failure, visible, click, close, playback, and server-reward
callbacks are all verified. `BURewardedVideoModel.extra` is the verified
serialized custom-data field. After fill the same model exposes the SDK reward
name, amount, type, proposed percentage, and reward error dictionary. Its
mediation extension exposes reward/trade identifiers, ADN, eCPM,
`verifyByGroMoreS2S`, and failure reason. Reward success is taken from
`nativeExpressRewardedVideoAdServerRewardDidSucceed:verify:` and failure keeps
the supplied `NSError`; request values are never promoted to proof of reward.

Insert ads use `BUNativeExpressFullscreenVideoAd` and
`BUMNativeExpressFullscreenVideoAdDelegate` with the same retention,
`mediation.isReady`, and Boolean show-result rules.

Post-show metadata comes from `getShowEcpmInfo` as `BUMRitInfo`, including
`adnName`, `slotID`, nullable string `ecpm`, `requestID`, and `creativeID`.
The SDK exposes neither currency nor a precision enum, so the public event keeps
only the raw value. Native failures preserve `NSError.domain`, `code`,
`localizedDescription`, and safe string diagnostics from `userInfo`.

## Cross-platform decisions

- The provider uses GroMore mediation only; callers cannot disable it.
- Full-screen insert maps to `TTFullScreenVideoAd` on Android and
  `BUNativeExpressFullscreenVideoAd` on iOS.
- A load callback plus a successful native mediation `isReady` check is the
  portable definition of ready.
- Ads are one-shot. The plugin never retries, auto-reloads, persists material,
  or maintains a ready queue.
- Revenue is emitted only after display metadata exists. Missing values remain
  absent.
- Client reward callbacks are UI/diagnostic signals. Server-side verification
  remains authoritative for server-owned value.

## Callback completion and plugin watchdog contract

The following callback ownership was verified from the pinned interfaces. The
deadlines below are plugin policy, not an SDK guarantee.

- Android initialization terminates through `TTAdSdk.Callback.success` or
  `fail`; iOS uses `BUAdSDKManager.start`'s async completion handler.
- Android reward/insert loads terminate through the matching load/cached
  callback or `onError`; iOS uses `DidLoad`/`DidDownLoadVideo` or
  `didFailWithError`.
- Confirmed display is Android `onAdShow` and iOS `DidVisible`. iOS also has an
  explicit mediation `DidShowFailed`; Android synchronous show exceptions and
  the presentation watchdog cover the absence of an equivalent callback.
- Normal display termination is `onAdClose`/`DidClose`; a show failure or the
  terminal watchdog is the failure termination path.
- Initialization and load watchdogs are 30 seconds. A short presentation
  acknowledgement watchdog detects calls that never reach show/visible, and a
  conservative long show watchdog prevents a lost close callback from leaving
  a Flutter Future pending. Every completion is guarded exactly once, and late
  callbacks are rejected by engine ownership, placement, and generation.
