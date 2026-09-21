# Acceptance record

Date: 2026-08-15

## Automated and host-build gates

- `owl_ads`: Dart analysis passed; 5 tests passed.
- `owl_ads_gromore`: Flutter analysis passed; 13 tests passed, including
  shared-runtime identity/configuration conflict, independent placements, and
  reward/revenue event deduplication.
- Root Flutter analysis passed and 7 NFC/ads controller/widget tests passed.
- Example: Flutter analysis passed; 1 widget test passed without using fake
  SDK success.
- Pigeon 27.3.0 generated Dart/Kotlin/Swift bindings match the schema.
- The shared-runtime change rebuilt Android Debug and minified Release APKs,
  the iOS Debug Simulator app, and the unsigned iOS Release device app
  successfully against the pinned SDKs.
- Android plugin lint passed; only existing AGP built-in-Kotlin migration
  warnings were reported.
- Android native JVM tests passed 7 coordinator/reply cases covering compatible
  and conflicting waiters, detach, timeout/callback ordering, stalled recovery,
  stale attempt rejection, generation rejection, and once-only completion.
- iOS XCTest passed the same 7 production-state cases on the iPhone 16e iOS
  18.6 simulator. Neither suite constructs an SDK ad or represents a state
  transition as a real SDK success.
- Android debug and minified release builds passed. Plugin/app lint passed;
  the native unit task has no mock-based sources. The release dependency graph
  contains only `com.pangle.cn:mediation-sdk:7.7.1.6` and the required
  `com.squareup.okhttp3:okhttp:3.12.1`, with no optional ADN dependency.
- iOS CocoaPods installation passed with `Ads-CN/BUAdSDK` and
  `Ads-CN/CSJMediation-Only` 7.7.0.6. Debug Simulator and unsigned arm64
  Release device builds passed. The built apps contain the Ads-CN,
  Flutter, and plugin privacy manifests. No optional ADN pod is resolved.
- Flutter supports only Debug mode for Simulator; both Flutter and the Xcode
  backend reject Release/Profile AOT for Simulator. Release was therefore
  compiled without code signing against the generic iOS device target.
- At the time of this 2026-08-15 record, both Dart packages used
  `publish_to: none`. Pub dry-run verified archive contents, but publication
  was blocked by the deliberate local `owl_ads` path dependency and unknown
  canonical repository URL. The current release-readiness record supersedes
  those packaging details; this section preserves the historical result.

Regenerable build outputs may be cleaned after these checks to control local
disk usage. Rebuild them before attaching binaries to a release.

Flutter reports that this CocoaPods-based plugin does not yet expose a Swift
Package Manager manifest and warns that SPM support will become mandatory in a
future Flutter version. CocoaPods remains the verified integration for the
pinned Ads-CN dependency; SPM adoption is tracked as a remaining packaging
risk rather than represented as complete.

### Shared-runtime iOS Simulator acceptance

The migrated real-SDK integration test passed on the connected iPhone 16e iOS
18.6 simulator with ignored local credentials. It verified that two application
repositories obtain the same isolate runtime, concurrent equivalent
initialization completes successfully, a real reward placement loads and is
reported ready, and terminal disposal through one reference causes another
reference to receive normalized `disposed`. No SDK result was mocked. This test
does not display the reward material and therefore does not replace the reward
playback/SSV matrix below.

## Pending physical-device/backend acceptance

### Host Demo iOS physical-device attempt

The shared-runtime integration test was signed, installed, and launched on the
connected physical `iPhone` (`00008140-000644600E79801C`) running iOS 27.0
(`24A5390f`) in Debug mode. The host bundle identifier was
`com.owlllwo.plugins`, and the test used the ignored local GroMore App ID and
placement configuration. No SDK result was mocked.

The Flutter-to-plugin-to-Ads-CN call path reached the real GroMore asynchronous
initialization callback on three consecutive attempts, but initialization failed
before any ad load with native diagnostic code `-10`, domain
`com.bytedance.GroMore`, and message `聚合配置初次加载失败`. The second diagnostic
run verified that code, domain, native message, and scalar `NSError.userInfo`
are preserved through Swift, Pigeon, and `AdsException`.

The local values pass structural validation and were checked read-only against
the signed-in GroMore console. The configured App ID is the cross-platform
`GroMore测试Demo` test application, for which a bundle identifier is not
required. Its configured reward placement is enabled and contains three active
test code positions (Pangle bidding, GM ADX, and Pangle fallback); its insert
placement is enabled as a full-screen insert. The ignored local configuration
matches the console's App ID and both placement IDs exactly; those identifiers
remain omitted from this tracked record.

This rules out the previously suspected bundle-ID/platform-ID mismatch and an
empty or mistyped placement. The remaining failure scope is the physical
device's first online configuration request or SDK/runtime compatibility on
iOS 27.0. A concurrent `flutter logs` session received no Ads-CN debug lines,
even though the pinned SDK's available `debugLog` and `SDKDEBUG` switches were
enabled. Reward load/show, early close, revenue, lifecycle, and terminal
disposal cannot be claimed for this device until initialization succeeds.

A subsequent retry on the same device and configuration passed after the
earlier failures. The real SDK initialized successfully for two concurrent
repositories, loaded the configured reward placement, reported it ready, and
preserved the shared-runtime terminal-disposal contract (`1/1` integration
test passed). This demonstrates that native configuration fetch can recover and
narrows the earlier `-10` result to a transient first-configuration-fetch
failure. This automated run did not present or play the reward material, so the
physical playback/reward callback was then verified separately.

The root Demo was launched on the same physical device and the configured
reward material was played to completion. The retained on-screen event log was
read through Flutter's debug service after close and recorded one generation in
this order: `loaded`, ready `true`, `shown`, Pangle `revenue`, user click events,
one `rewarded`, then `closed`. The reward event arrived before close with
`rewarded=true`, `verified=true`, reward name `测试奖励`, and amount `100`.
The awaited `showReward()` result returned the same values immediately after
close. No duplicate reward event or failed event was present. This confirms the
physical-device client reward-eligible path; it does not represent
authoritative SSV backend settlement.

On 2026-08-15 the remaining controllable iOS physical-device matrix was run on
the same connected iPhone and configuration through iPhone Mirroring. The
installed Debug app continued to use the real Ads-CN 7.7.0.6 SDK and live test
placements; no platform result was mocked:

- an early-closed reward generation emitted `loaded`, `shown`, Pangle
  `revenue`, then `closed`; it emitted no `rewarded` event and `showReward()`
  returned `rewarded=false`, `verified=false`;
- a separate reward generation completed its interactive requirement and
  emitted `rewarded=true`, `verified=true`, name `测试奖励`, amount `100` before
  `closed`; the awaited result matched the event;
- the full-screen insert emitted `loaded`, `shown`, Pangle `revenue`, then
  `closed`, and the awaited show call completed after close;
- native presentations and an explicit three-second host background interval
  produced the expected `inactive`, `hidden`, `paused`, and `resumed`
  lifecycle sequence without losing the cached ready state;
- withdrawing consent invalidated a ready reward generation with normalized
  `consentRequired`, cleared readiness, and disabled requests; re-applying
  consent allowed a new generation to load and become ready;
- application-level Runtime disposal cleared readiness and was terminal for
  the isolate; a later initialization attempt returned normalized `disposed`.

After either native full-screen format closed, iPhone Mirroring stopped
forwarding pointer clicks to the Flutter surface even though the app returned
visibly, Dart remained responsive, callbacks completed, and a Debug window
inspection showed the Flutter `UIWindow` was key with no Ads-CN window left in
the scene. System Home/App Switcher controls still worked. The attempted host
window restoration made no difference and was removed from the production
source. This is recorded as a mirroring-input limitation until a direct
on-device post-close tap confirms or disproves it; it is not represented as a
plugin window-management fix.

### Host Demo iOS Simulator regression

The root host Demo was run in Debug mode on an iPhone 16e simulator with iOS
18.6, using ignored local App ID and reward/insert Code ID configuration. This
simulator run produced real GroMore/Pangle responses; no platform result was
mocked:

- consent gating and SDK initialization succeeded;
- reward generation 1 loaded, became ready, showed, emitted revenue, and
  closed; it was intentionally closed before earning, so the returned result
  was `rewarded=false` and `verified=false`;
- insert generation 1 loaded, became ready, showed, emitted revenue, closed,
  and returned to not-ready;
- foreground/background lifecycle transitions were observed around both
  native presentations;
- a direct show without a ready object returned the normalized `notReady`
  error;
- consent withdrawal invalidated the ready reward and blocked requests;
  re-acceptance remained blocked until the updated consent was applied to the
  SDK;
- the historical V1 simulator run exercised provider disposal and recreation.
  That behavior is superseded by the shared-runtime contract: disposal is now
  terminal for the Dart isolate, while SDK initialization remains truthfully
  process-wide. The physical run above now validates terminal disposal rather
  than recreation.
- a subsequent reward generation was allowed to finish its real interactive
  material instead of being closed early. The native rewarded callback arrived
  before close with `rewarded=true`, `verified=true`, reward name
  `测试奖励`, and amount `100`. The awaited `showReward()` result returned the
  same values after close, so the host client-side reward-eligible state was
  confirmed end to end.

### Host Demo Android Emulator regression

The same real-SDK integration test was run on a Pixel 3a API 34 arm64 emulator.
The first cold SDK dynamic-component attempt logged provider code `4205`
(`Get ClassLoader failed`) without invoking its documented load callback. A
30-second native watchdog was added so this condition now returns
`nativeLoadFailed` and destroys the session instead of hanging indefinitely.
After the SDK component cache was available, the original V1 success test
passed. The current shared-runtime Android Debug APK compiles, but its updated
terminal-disposal and multi-engine paths still require a new device run.

Android native presentation/close was not controlled in this run, so those
callbacks are not claimed here.

### Still pending

Physical iOS initialization, load/readiness, reward early-close, complete reward,
insert presentation/close, background/resume, consent withdrawal/re-application,
and terminal Runtime disposal are complete. Direct physical-screen touch after
full-screen close, device rotation during presentation, and engine detach while
an ad is presented remain pending. Detaching `flutter run` is not equivalent to
detaching the Flutter engine and is not claimed.

No reward callback endpoint is available, so authoritative SSV backend
settlement remains unverified even though iOS physical device and simulator both
confirm the client-side `rewarded=true` and `verified=true` path. Android native
presentation/close, a new physical Android shared-runtime run, and every optional
ADN SDK/adapter pair remain untested.

Before release, complete the physical-device/backend matrix in task 7.4 of the
`optimize-ads-provider-runtime` OpenSpec change and record, for every run:

- device model, OS version, build mode, App ID environment, and Code ID names;
- consent/init, reward, insert, click, close, revenue, lifecycle, withdrawal,
  disposal, and presenter/activity results;
- SSV request identifier and authoritative backend settlement result;
- every enabled ADN SDK/adapter pair and its exact tested version.

Task 7.2 is complete through the Android JVM and iOS XCTest state suites above.
They verify plugin-owned coordination and reply invariants only; physical SDK
playback and authoritative backend settlement remain task 7.4.
