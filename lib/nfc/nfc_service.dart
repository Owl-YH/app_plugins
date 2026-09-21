import 'package:demo/nfc/nfc_models.dart';
import 'package:ndef_kit/ndef_kit.dart';

/// Stateless boundary around the real NFC platform plugin.
final class NfcPlatformService {
  NfcPlatformService(this._client);

  final NdefClient _client;

  Future<NdefAvailability> checkAvailability() => _client.checkAvailability();

  Future<NdefTagResult> read() => _client.read(
    options: const NdefSessionOptions(
      alertMessageIos: '请将 iPhone 靠近 NDEF 标签以读取内容。',
      successMessageIos: '读取成功',
      errorMessageIos: '读取失败，请重试。',
    ),
  );

  Future<NdefTagResult> write(NdefMessageData message) => _client.write(
    message,
    verifyAfterWrite: true,
    options: const NdefSessionOptions(
      alertMessageIos: '请将 iPhone 靠近要写入的 NDEF 标签。',
      successMessageIos: '写入并验证成功',
      errorMessageIos: '写入失败，请重试。',
    ),
  );

  Future<void> cancel() => _client.cancel();
}

/// Data-layer owner for NFC request construction and platform operations.
final class NfcRepository {
  NfcRepository(this._service);

  final NfcPlatformService _service;

  Future<NdefAvailability> checkAvailability() => _service.checkAvailability();

  Future<NdefTagResult> read() => _service.read();

  Future<NdefTagResult> write(NfcPayloadKind kind, String payload) =>
      _service.write(createMessage(kind, payload));

  Future<void> cancel() => _service.cancel();

  NdefMessageData createMessage(NfcPayloadKind kind, String payload) {
    final record = switch (kind) {
      NfcPayloadKind.text => NdefRecordData.text(payload, languageCode: 'zh'),
      NfcPayloadKind.uri => NdefRecordData.uri(payload.trim()),
    };
    return NdefMessageData(records: <NdefRecordData>[record]);
  }
}
