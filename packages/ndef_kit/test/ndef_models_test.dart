import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_kit/ndef_kit.dart';

void main() {
  group('Text records', () {
    test('encode and decode UTF-8 Chinese text', () {
      final record = NdefRecordData.text('真实 NFC 内容', languageCode: 'zh');

      expect(record.typeNameFormat, NdefTypeNameFormat.wellKnown);
      expect(record.type, orderedEquals(const [0x54]));
      expect(record.kind, NdefRecordKind.text);
      expect(record.content, '真实 NFC 内容');
      expect(record.languageCode, 'zh');
      expect(record.textEncoding, NdefTextEncoding.utf8);
      expect(record.decodingError, isNull);
    });

    test('reject an empty value or language code', () {
      expect(
        () => NdefRecordData.text('', languageCode: 'zh'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => NdefRecordData.text('value', languageCode: ''),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode UTF-16 with a byte-order mark', () {
      final record = NdefRecordData.fromRaw(
        typeNameFormat: NdefTypeNameFormat.wellKnown,
        type: const [0x54],
        payload: const [0x82, 0x7A, 0x68, 0xFE, 0xFF, 0x4F, 0x60, 0x59, 0x7D],
      );

      expect(record.content, '你好');
      expect(record.textEncoding, NdefTextEncoding.utf16);
    });

    test('preserve raw fields after a decoding failure', () {
      final record = NdefRecordData.fromRaw(
        typeNameFormat: NdefTypeNameFormat.wellKnown,
        type: const [0x54],
        payload: const [0x05, 0x7A],
      );

      expect(record.kind, NdefRecordKind.text);
      expect(record.content, isNull);
      expect(record.decodingError, isNotNull);
      expect(record.payload, orderedEquals(const [0x05, 0x7A]));
    });
  });

  group('URI records', () {
    test('compress and restore a well-known HTTPS prefix', () {
      final record = NdefRecordData.uri('https://www.example.com/nfc');

      expect(record.type, orderedEquals(const [0x55]));
      expect(record.payload.first, 0x02);
      expect(record.kind, NdefRecordKind.uri);
      expect(record.content, 'https://www.example.com/nfc');
      expect(record.uriPrefixCode, 0x02);
    });

    test('require a URI scheme', () {
      expect(
        () => NdefRecordData.uri('example.com/nfc'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Raw records and messages', () {
    test('keep printable content and raw fields for another record', () {
      final record = NdefRecordData.fromRaw(
        typeNameFormat: NdefTypeNameFormat.media,
        type: 'text/plain'.codeUnits,
        identifier: const [0x01],
        payload: 'payload'.codeUnits,
      );

      expect(record.kind, NdefRecordKind.other);
      expect(record.content, 'payload');
      expect(record.identifier, orderedEquals(const [0x01]));
      expect(
        NdefDiagnostics.bytesToHex(record.payload),
        '70 61 79 6C 6F 61 64',
      );
    });

    test('validate raw NDEF invariants and byte ranges', () {
      expect(
        () => NdefRecordData.fromRaw(
          typeNameFormat: NdefTypeNameFormat.empty,
          type: const [0x54],
          payload: const [],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => NdefRecordData.fromRaw(
          typeNameFormat: NdefTypeNameFormat.media,
          type: const [256],
          payload: const [],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('expose immutable collections and value equality', () {
      final record = NdefRecordData.text('value', languageCode: 'en');
      final same = NdefRecordData.text('value', languageCode: 'en');
      final message = NdefMessageData(records: [record]);

      expect(record, same);
      expect(message, NdefMessageData(records: [same]));
      expect(() => record.payload.add(0), throwsUnsupportedError);
      expect(() => message.records.clear(), throwsUnsupportedError);
      expect(message.byteLength, record.byteLength);
    });
  });

  test('diagnostics include stable record fields', () {
    final result = NdefTagResult(
      source: NdefResultSource.read,
      isWritable: true,
      maxSize: 144,
      message: NdefMessageData(
        records: [NdefRecordData.text('debug', languageCode: 'en')],
      ),
    );

    final diagnostics = NdefDiagnostics.formatTagResult(result);
    expect(diagnostics, contains('result.source: read'));
    expect(diagnostics, contains('record[0].kind: text'));
    expect(diagnostics, contains('record[0].payload:'));
  });

  test('empty write fails before opening a platform session', () async {
    await expectLater(
      NdefClient.instance.write(NdefMessageData(records: const [])),
      throwsA(
        isA<NdefException>().having(
          (error) => error.code,
          'code',
          NdefErrorCode.emptyMessage,
        ),
      ),
    );
  });
}
