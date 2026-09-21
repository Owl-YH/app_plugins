# Verified native dependency matrix

Verification date: 2026-08-14 (Asia/Shanghai)

Plugin release: `owl_ads_gromore 0.1.0`

This file is the dependency source of truth for `owl_ads_gromore`. Dynamic
versions, placeholder versions, beta-example coordinates, and unrecorded ADN
adapter pairs are not supported.

## Plugin base dependencies

| Platform | Selected dependency | Minimum | Official verification |
| --- | --- | --- | --- |
| Android | `com.pangle.cn:mediation-sdk:7.7.1.6` from `https://artifact.bytedance.com/repository/pangle` | Android API 24, Java 8 | The Maven artifact SHA-256 is `c1f148631cd764986a28e3d3cd61ba824dadc81419920faff8b3c4755f6353bf`; it is byte-identical to `open_ad_sdk_7.7.1.6.aar` in the media-platform download. |
| iOS | `Ads-CN`, exact version `7.7.0.6`, subspecs `BUAdSDK` and `CSJMediation-Only` | Pod minimum iOS 11; plugin minimum iOS 13 | CocoaPods Trunk lists `7.7.0.6`; the Podspec source archive SHA-256 is `19125f83c9fe65efa1b1a1526ca139251f7cbc1ef92e1043aa8c92d6f65c254f`. |

The authenticated media platform listed and supplied Android `7.7.1.6`
(updated 2026-07-31 15:36:04). Its complete download SHA-256 is
`dbff12eadff1ff188ee505260f92351a61461d260045cee4d0ce5df19332bbe5`.

The same platform listed and supplied iOS `7.8.0.0`
(updated 2026-08-14 10:31:24). Its complete download SHA-256 is
`9502823069fc9b2853bc6176ffdef765dc12ca81f1289d0cde1e2150bad73a60`.
As of verification time, `7.8.0.0` was not present in CocoaPods Trunk. It is
therefore recorded but not selected: depending on an unpublished Pod would not
be reproducible. The reward, full-screen, mediation-readiness, privacy, and
revenue headers used by this plugin are byte-identical between the selected
`7.7.0.6` Pod archive and the downloaded `7.8.0.0` archive.

Pigeon is pinned to `27.3.0` (Dart SDK requirement `^3.10.0`).

The current official Android integration guide also requires exact
`com.squareup.okhttp3:okhttp:3.12.1`; the GroMore POM itself declares no
transitive dependency, so the plugin pins it explicitly.

## ADN pairs present in the downloaded platform bundles

The plugin bundles none of these optional networks. The rows are recorded for
host configuration review only and are not claimed as release-supported until
the real-device matrix is completed for that exact pair.

### Android bundle 7.7.1.6

| ADN | SDK | Adapter |
| --- | --- | --- |
| Pangle/CSJ | `7.7.1.6` (inside the fusion SDK) | Built in |
| Baidu | `9.4503` | `mediation_baidu_adapter_9.4503.1` |
| GDT/优量汇 | `4.680.1550` | `mediation_gdt_adapter_4.680.1550.1` |
| Kuaishou | `5.3.20.1` | `mediation_ks_adapter_5.3.20.1.1` |
| Sigmob | `windAd 4.25.14`, `windAd-common 2.0.1` | `mediation_sigmob_adapter_4.25.14.1` |

### iOS bundle 7.8.0.0

| ADN | SDK | Adapter |
| --- | --- | --- |
| Pangle/CSJ | `7.8.0.0` (inside the fusion SDK) | Built in |
| Baidu | `10.050` | `CSJMBaiduAdapter 10.050.3` |
| GDT/优量汇 | `4.15.90` | `CSJMGdtAdapter 4.15.90.1` |
| Kuaishou | `5.5.10.1` | `CSJMKsAdapter 5.5.10.1.1` |
| Sigmob | `5.1.2` | `CSJMSigmobAdapter 5.1.2.1` |

## Upgrade rule

Before changing either base dependency or enabling an ADN pair:

1. Download the corresponding official SDK and demo from the authenticated
   media platform.
2. Record the exact coordinate, download timestamp, and SHA-256 here.
3. Inspect the relevant headers/classes and update `native-contract.md`.
4. Regenerate Pigeon output and run Dart, Android, and iOS verification.
5. Complete reward and insert real-device acceptance for every enabled ADN.
