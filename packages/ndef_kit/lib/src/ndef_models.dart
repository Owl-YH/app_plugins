import 'dart:convert';
import 'dart:typed_data';

/// NFC availability as exposed to application code.
enum NdefAvailability { enabled, disabled, unsupported }

/// The operation that produced a tag result.
enum NdefResultSource { read, write, writeVerified }

/// NDEF Type Name Format values.
enum NdefTypeNameFormat {
  empty,
  wellKnown,
  media,
  absoluteUri,
  external,
  unknown,
  unchanged,
}

/// High-level record categories understood by this package.
enum NdefRecordKind { text, uri, other }

/// Text encoding declared by an NFC Forum Text record.
enum NdefTextEncoding { utf8, utf16 }

/// Options for the system NFC session UI.
final class NdefSessionOptions {
  /// Creates system-session messages. All fields are optional so the host
  /// application owns localization.
  const NdefSessionOptions({
    this.alertMessageIos,
    this.successMessageIos,
    this.errorMessageIos,
  });

  /// Message displayed while iOS scans for a tag.
  final String? alertMessageIos;

  /// Message displayed when an iOS session succeeds.
  final String? successMessageIos;

  /// Message displayed when an iOS session fails.
  final String? errorMessageIos;
}

/// An immutable, dependency-neutral NDEF record.
final class NdefRecordData {
  NdefRecordData._({
    required this.kind,
    required this.typeNameFormat,
    required List<int> type,
    required List<int> identifier,
    required List<int> payload,
    required this.content,
    required this.languageCode,
    required this.textEncoding,
    required this.uriPrefixCode,
    required this.decodingError,
  }) : type = List.unmodifiable(type),
       identifier = List.unmodifiable(identifier),
       payload = List.unmodifiable(payload);

  /// Creates an NFC Forum Text record.
  factory NdefRecordData.text(String text, {required String languageCode}) {
    if (text.isEmpty) {
      throw const FormatException('Text must not be empty.');
    }
    final languageBytes = utf8.encode(languageCode);
    if (languageBytes.isEmpty || languageBytes.length > 63) {
      throw const FormatException(
        'The language code must be between 1 and 63 UTF-8 bytes.',
      );
    }
    return NdefRecordData.fromRaw(
      typeNameFormat: NdefTypeNameFormat.wellKnown,
      type: const [0x54],
      payload: [languageBytes.length, ...languageBytes, ...utf8.encode(text)],
    );
  }

  /// Creates an NFC Forum URI record.
  factory NdefRecordData.uri(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty || uri == null || uri.scheme.isEmpty) {
      throw const FormatException(
        'The URI must be non-empty and include a scheme.',
      );
    }

    var prefixCode = 0;
    var prefixLength = 0;
    for (var index = 1; index < _uriPrefixes.length; index++) {
      final prefix = _uriPrefixes[index];
      if (normalized.startsWith(prefix) && prefix.length > prefixLength) {
        prefixCode = index;
        prefixLength = prefix.length;
      }
    }

    return NdefRecordData.fromRaw(
      typeNameFormat: NdefTypeNameFormat.wellKnown,
      type: const [0x55],
      payload: [prefixCode, ...utf8.encode(normalized.substring(prefixLength))],
    );
  }

  /// Creates and decodes a record from raw NDEF fields.
  factory NdefRecordData.fromRaw({
    required NdefTypeNameFormat typeNameFormat,
    required Iterable<int> type,
    Iterable<int> identifier = const [],
    required Iterable<int> payload,
  }) {
    final frozenType = _validatedBytes(type, 'type');
    final frozenIdentifier = _validatedBytes(identifier, 'identifier');
    final frozenPayload = _validatedBytes(payload, 'payload');
    _validateRawRecord(
      typeNameFormat,
      frozenType,
      frozenIdentifier,
      frozenPayload,
    );

    if (_isWellKnownType(typeNameFormat, frozenType, 0x54)) {
      return _decodeText(
        typeNameFormat,
        frozenType,
        frozenIdentifier,
        frozenPayload,
      );
    }
    if (_isWellKnownType(typeNameFormat, frozenType, 0x55)) {
      return _decodeUri(
        typeNameFormat,
        frozenType,
        frozenIdentifier,
        frozenPayload,
      );
    }

    return NdefRecordData._(
      kind: NdefRecordKind.other,
      typeNameFormat: typeNameFormat,
      type: frozenType,
      identifier: frozenIdentifier,
      payload: frozenPayload,
      content: _tryDecodePrintableUtf8(frozenPayload),
      languageCode: null,
      textEncoding: null,
      uriPrefixCode: null,
      decodingError: null,
    );
  }

  /// Recognized semantic record category.
  final NdefRecordKind kind;

  /// NDEF Type Name Format.
  final NdefTypeNameFormat typeNameFormat;

  /// Raw NDEF type bytes.
  final List<int> type;

  /// Raw NDEF identifier bytes.
  final List<int> identifier;

  /// Raw NDEF payload bytes.
  final List<int> payload;

  /// Decoded text, URI, or printable UTF-8 payload when available.
  final String? content;

  /// Language code for Text records.
  final String? languageCode;

  /// Encoding for Text records.
  final NdefTextEncoding? textEncoding;

  /// NFC Forum URI prefix code for URI records.
  final int? uriPrefixCode;

  /// Technical decoding failure. Raw fields remain available when set.
  final String? decodingError;

  /// Encoded record size in bytes.
  int get byteLength {
    var length = 3;
    if (typeNameFormat == NdefTypeNameFormat.empty) {
      return length;
    }
    length += type.length + payload.length;
    if (identifier.isNotEmpty) {
      length += 1 + identifier.length;
    }
    if (payload.length > 255) {
      length += 3;
    }
    return length;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    typeNameFormat,
    Object.hashAll(type),
    Object.hashAll(identifier),
    Object.hashAll(payload),
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NdefRecordData &&
            kind == other.kind &&
            typeNameFormat == other.typeNameFormat &&
            _bytesEqual(type, other.type) &&
            _bytesEqual(identifier, other.identifier) &&
            _bytesEqual(payload, other.payload);
  }
}

/// An immutable NDEF message independent from the underlying plugin.
final class NdefMessageData {
  /// Creates a message from records.
  NdefMessageData({required Iterable<NdefRecordData> records})
    : records = List.unmodifiable(records);

  /// Records in message order.
  final List<NdefRecordData> records;

  /// Encoded message size in bytes.
  int get byteLength => records.fold(0, (total, record) {
    return total + record.byteLength;
  });

  @override
  int get hashCode => Object.hashAll(records);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NdefMessageData && _recordsEqual(records, other.records);
  }
}

/// An immutable snapshot of an NDEF tag operation.
final class NdefTagResult {
  /// Creates a tag result.
  NdefTagResult({
    required this.source,
    required this.isWritable,
    required this.maxSize,
    required this.message,
    Map<String, Object?> additionalData = const {},
  }) : additionalData = Map.unmodifiable(additionalData);

  /// Operation that produced this result.
  final NdefResultSource source;

  /// Whether the discovered tag reported itself writable.
  final bool isWritable;

  /// Maximum NDEF message size supported by the tag.
  final int maxSize;

  /// Read or written message. It may be null for an empty tag.
  final NdefMessageData? message;

  /// Platform-specific metadata copied from the underlying plugin.
  final Map<String, Object?> additionalData;
}

const List<String> _uriPrefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

List<int> _validatedBytes(Iterable<int> bytes, String field) {
  final result = bytes.toList(growable: false);
  if (result.any((byte) => byte < 0 || byte > 255)) {
    throw FormatException('$field contains a value outside the byte range.');
  }
  return result;
}

void _validateRawRecord(
  NdefTypeNameFormat format,
  List<int> type,
  List<int> identifier,
  List<int> payload,
) {
  switch (format) {
    case NdefTypeNameFormat.empty:
      if (type.isNotEmpty || identifier.isNotEmpty || payload.isNotEmpty) {
        throw const FormatException('An EMPTY record cannot contain data.');
      }
      break;
    case NdefTypeNameFormat.unknown:
      if (type.isNotEmpty) {
        throw const FormatException('An UNKNOWN record cannot contain a type.');
      }
      break;
    case NdefTypeNameFormat.unchanged:
      throw const FormatException(
        'UNCHANGED is not valid for a complete logical record.',
      );
    default:
      break;
  }
}

bool _isWellKnownType(NdefTypeNameFormat format, List<int> type, int expected) {
  return format == NdefTypeNameFormat.wellKnown &&
      type.length == 1 &&
      type.single == expected;
}

NdefRecordData _decodeText(
  NdefTypeNameFormat format,
  List<int> type,
  List<int> identifier,
  List<int> payload,
) {
  String? language;
  NdefTextEncoding? encoding;
  try {
    if (payload.isEmpty) {
      throw const FormatException('The Text record has no status byte.');
    }
    final status = payload.first;
    final languageLength = status & 0x3F;
    final contentOffset = 1 + languageLength;
    if (contentOffset > payload.length) {
      throw const FormatException('The Text language-code length is invalid.');
    }
    language = utf8.decode(
      payload.sublist(1, contentOffset),
      allowMalformed: false,
    );
    encoding = status & 0x80 == 0
        ? NdefTextEncoding.utf8
        : NdefTextEncoding.utf16;
    final contentBytes = Uint8List.fromList(payload.sublist(contentOffset));
    final content = encoding == NdefTextEncoding.utf16
        ? _decodeUtf16(contentBytes)
        : utf8.decode(contentBytes, allowMalformed: false);
    return NdefRecordData._(
      kind: NdefRecordKind.text,
      typeNameFormat: format,
      type: type,
      identifier: identifier,
      payload: payload,
      content: content,
      languageCode: language,
      textEncoding: encoding,
      uriPrefixCode: null,
      decodingError: null,
    );
  } on FormatException catch (error) {
    return NdefRecordData._(
      kind: NdefRecordKind.text,
      typeNameFormat: format,
      type: type,
      identifier: identifier,
      payload: payload,
      content: null,
      languageCode: language,
      textEncoding: encoding,
      uriPrefixCode: null,
      decodingError: error.message,
    );
  }
}

NdefRecordData _decodeUri(
  NdefTypeNameFormat format,
  List<int> type,
  List<int> identifier,
  List<int> payload,
) {
  if (payload.isEmpty) {
    return NdefRecordData._(
      kind: NdefRecordKind.uri,
      typeNameFormat: format,
      type: type,
      identifier: identifier,
      payload: payload,
      content: null,
      languageCode: null,
      textEncoding: null,
      uriPrefixCode: null,
      decodingError: 'The URI record has no prefix byte.',
    );
  }

  final prefixCode = payload.first;
  final prefix = prefixCode < _uriPrefixes.length
      ? _uriPrefixes[prefixCode]
      : '';
  try {
    final suffix = utf8.decode(payload.sublist(1), allowMalformed: false);
    return NdefRecordData._(
      kind: NdefRecordKind.uri,
      typeNameFormat: format,
      type: type,
      identifier: identifier,
      payload: payload,
      content: '$prefix$suffix',
      languageCode: null,
      textEncoding: null,
      uriPrefixCode: prefixCode,
      decodingError: null,
    );
  } on FormatException catch (error) {
    return NdefRecordData._(
      kind: NdefRecordKind.uri,
      typeNameFormat: format,
      type: type,
      identifier: identifier,
      payload: payload,
      content: null,
      languageCode: null,
      textEncoding: null,
      uriPrefixCode: prefixCode,
      decodingError: error.message,
    );
  }
}

String? _tryDecodePrintableUtf8(List<int> bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  try {
    final value = utf8.decode(bytes, allowMalformed: false);
    final containsControls = value.runes.any((rune) {
      return rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D;
    });
    return containsControls ? null : value;
  } on FormatException {
    return null;
  }
}

String _decodeUtf16(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  var offset = 0;
  var bigEndian = true;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      offset = 2;
    } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      offset = 2;
      bigEndian = false;
    }
  }
  if ((bytes.length - offset).isOdd) {
    throw const FormatException('The UTF-16 payload has an odd byte count.');
  }
  final codeUnits = <int>[];
  for (var index = offset; index < bytes.length; index += 2) {
    codeUnits.add(
      bigEndian
          ? (bytes[index] << 8) | bytes[index + 1]
          : bytes[index] | (bytes[index + 1] << 8),
    );
  }
  return String.fromCharCodes(codeUnits);
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _recordsEqual(List<NdefRecordData> left, List<NdefRecordData> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
