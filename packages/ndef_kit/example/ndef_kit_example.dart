import 'package:ndef_kit/ndef_kit.dart';

Future<NdefTagResult> readTag() {
  return NdefClient.instance.read(
    options: const NdefSessionOptions(
      alertMessageIos: 'Hold your iPhone near an NDEF tag.',
      successMessageIos: 'Read complete',
    ),
  );
}

Future<NdefTagResult> writeText(String text) {
  final message = NdefMessageData(
    records: [NdefRecordData.text(text, languageCode: 'en')],
  );
  return NdefClient.instance.write(
    message,
    verifyAfterWrite: true,
    options: const NdefSessionOptions(
      alertMessageIos: 'Hold your iPhone near the tag to write.',
      successMessageIos: 'Write verified',
    ),
  );
}
