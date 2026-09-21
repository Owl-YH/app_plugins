# ndef_kit

`ndef_kit` is a reusable, UI-independent Flutter package for ordinary NFC
Forum NDEF tags on Android and iOS. It wraps `nfc_manager` with an app-facing
API that does not expose plugin types.

## Capabilities

- NFC availability checks.
- Text, URI, and raw NDEF record models.
- Read, overwrite, optional read-back verification, and cancellation.
- Process-wide single-session coordination.
- Stable error codes and structured diagnostics.
- Cleanup for stale iOS sessions observed with `nfc_manager 4.2.1`.

The package does not format non-NDEF tags, permanently lock tags, read
protected card data, or provide host card emulation.

## Install

After the first `0.1.0` release is available on pub.dev, add:

```yaml
dependencies:
  ndef_kit: ^0.1.0
```

For this repository's demo during development:

```yaml
dependencies:
  ndef_kit:
    path: ../packages/ndef_kit
```

The demo keeps the local source dependency until a published version has been
verified and the demo is updated separately.

## Usage

```dart
import 'package:ndef_kit/ndef_kit.dart';

final ndef = NdefClient.instance;

final availability = await ndef.checkAvailability();

final readResult = await ndef.read(
  options: const NdefSessionOptions(
    alertMessageIos: 'Hold your iPhone near an NDEF tag.',
    successMessageIos: 'Read complete',
  ),
);

final message = NdefMessageData(
  records: [
    NdefRecordData.text('Hello NFC', languageCode: 'en'),
  ],
);

final writeResult = await ndef.write(
  message,
  verifyAfterWrite: true,
  options: const NdefSessionOptions(
    alertMessageIos: 'Hold your iPhone near the tag to write.',
    successMessageIos: 'Write verified',
  ),
);
```

Catch `NdefException` and branch on `error.code`; its technical message is not
localized. Applications own user-facing strings and iOS session messages.

## Host app configuration

Platform security declarations cannot be installed by a Dart package. Every
consumer app must configure them explicitly.

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />
```

Use `android:required="false"` when NFC is optional and the app should remain
installable on devices without NFC hardware.

### iOS

The app must target iOS 13 or later and provide:

- `NFCReaderUsageDescription` in `Info.plist`.
- Near Field Communication Tag Reading in Signing & Capabilities.
- `com.apple.developer.nfc.readersession.formats` containing `TAG` in the app
  entitlements file.

The provisioning profile and signing identifier must include that capability.
NFC end-to-end behavior requires a physical device and physical NDEF tag.

## Verification

```shell
flutter analyze
flutter test
```

Automated tests cover domain models, codecs, validation, error contracts, and
diagnostics without fabricating platform NFC responses. Read/write sessions
must be verified on real Android and iOS devices.
