# Consent, access, events, and lifecycle

## Required sequence

1. The host presents its own privacy policy and records policy version and
   acceptance outside this plugin.
2. The host requests any Android runtime permissions or iOS ATT it actually
   needs. Consent to the host policy and ATT status are distinct decisions.
3. Obtain `GroMoreAds.configure(config)` once at the application composition
   root with immutable real App IDs, placement mappings, and deny-by-default
   `GroMoreAccess`.
4. Call `init` only with `AdConsent.accepted == true`.
5. Load explicitly, check readiness, and show once. Load again only after the
   prior object reaches close/failure.

No native SDK call is made before accepted consent. This gate is duplicated in
Dart, Android, and iOS so a direct/out-of-order platform invocation is also
rejected.

## `GroMoreAccess` mapping

Every field defaults to denied. A flag grants SDK access only; it does not grant
an operating-system permission or establish a lawful basis.

| Field | Android verified mapping | iOS verified mapping |
| --- | --- | --- |
| `canUseLocation` | `TTCustomController.isCanUseLocation` | `BUAdSDKPrivacyProvider.canUseLocation` |
| `canUsePhoneState` | `isCanUsePhoneState`/empty custom IMEI when denied | `kBUMPrivacyDisableUsePhoneStatus` |
| `canUseWifiState` | `isCanUseWifiState`/empty MAC when denied | `canUseWiFiBSSID` |
| `canUseWriteExternalStorage` | `isCanUseWriteExternal` | No iOS mapping |
| `canUseOaid` | mediation `isCanUseOaid`/empty custom OAID when denied | No iOS mapping |
| `canUseAndroidId` | `isCanUseAndroidId`/empty Android ID when denied | No iOS mapping |
| `canUseInstalledApps` | `TTCustomController.alist` | No iOS mapping |
| `canUseRecordAudio` | `isCanUsePermissionRecordAudio` | No iOS mapping |
| `canUseIdfa` | No Android mapping | `forbiddenIDFA` and advertiser-tracking privacy value |
| `canUploadDeviceInfo` | No Android mapping | mediation `allowUploadDeviceInfo` |

iOS motion, disk-space, and carrier collection are explicitly denied because
V1 exposes no grant for them. Personalized preference maps to the verified
personal/programmatic restriction settings. Android privacy changes use
`TTAdSdk.updateAdConfig`. iOS consent/personalization fields update at runtime;
a direct attempt to change immutable access fields after initialization returns
`restartRequired`.

## Withdrawal

`updateConsent(const AdConsent(accepted: false))` immediately blocks Dart
requests, increments request generations, emits a terminal `failed` event for
active sessions, and asks each native side to destroy/release retained ads.
Late callbacks are discarded. The process-wide GroMore SDK has no verified
deinitialize API, so the plugin never claims it has unloaded the SDK.

## Shared runtime disposal

`GroMoreAds.configure` exposes one shared runtime per Dart isolate. Equivalent
configuration returns the same object; a different immutable configuration is
rejected. Reward and insert sessions remain independent per placement.

`GroMoreAds.dispose()` permanently closes that isolate runtime and invalidates
all active native ad sessions. It does not deinitialize the process-wide
GroMore SDK and does not permit recreation in the same isolate. Page/widget
disposal must only cancel local subscriptions. Terminal runtime disposal belongs
to the application composition root or Flutter engine teardown. Native Host
objects become permanently disposed only on FlutterEngine detach; Dart hot
restart creates a new isolate that may rebind to the still-compatible engine
and process SDK configuration.

## Events and errors

Events are `loaded`, `shown`, `clicked`, `closed`, `failed`, `rewarded`, and
`revenue`. Every event contains application placement, ad type, and request
generation. Terminal failure/close is delivered before its show future settles.

Stable error codes include `invalidState`, `consentRequired`, `alreadyLoading`,
`notReady`, `presenterUnavailable`, `nativeLoadFailed`, `nativeShowFailed`, and
`disposed`. Provider integer/NSError codes, domain, message, and safe details
remain separate diagnostics. Unknown future error values map to `nativeError`;
the Pigeon boundary includes an `unknown` event sentinel.

Initialization and Android/iOS load operations have 30-second native
watchdogs. Some provider
dynamic-component failures do not invoke the documented load callback; the
watchdog destroys that session and returns `nativeLoadFailed` instead of
leaving the Flutter Future pending forever. Show has separate presentation and
long terminal safety deadlines; a timeout never infers a close or reward.
All watchdog work is cancelled when its operation reaches a terminal state, so
completed ads do not retain an engine Host until the original deadline.

If every live initialization waiter times out while the process SDK still has
not reported a terminal callback, the process attempt is marked stalled rather
than started again concurrently. Equivalent requests return `restartRequired`
until the real SDK reports ready or the process restarts. A late success may
restore process readiness, but it cannot complete an already expired request.

Android resolves the current `Activity` through `ActivityAware`. iOS resolves
the active foreground scene and top presenter at show time. Neither platform
stores a static UI controller. Rotation, detach/reattach, engine detach,
backgrounding, and presentation conflicts must still be exercised on devices.

Revenue preserves GroMore's nullable raw eCPM string. The verified APIs provide
no currency or precision enum, so the plugin does not synthesize either.
Revenue is queried once at the first confirmed show/visible callback rather
than being delayed until close.
Client reward callbacks are UI feedback; a real server-side verification
callback is authoritative for server-owned value.

## Future provider composition

Feature code depends on `Ads`, not `GroMoreAds`. A future direct Google package
can implement the same interface with its own provider-specific shared runtime.
The application composition root selects and injects one implementation;
`owl_ads` does not contain a global provider registry or automatically race
GroMore and Google requests.
