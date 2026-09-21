import 'ndef_exception.dart';
import 'ndef_models.dart';

/// Helpers for generating copyable, structured NFC diagnostics.
abstract final class NdefDiagnostics {
  /// Converts bytes to uppercase, space-separated hexadecimal text.
  static String bytesToHex(Iterable<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// Formats a normalized exception without discarding the original cause.
  static String formatException(Object error, [StackTrace? stackTrace]) {
    final output = StringBuffer()..writeln('error.type: ${error.runtimeType}');
    if (error is NdefException) {
      output
        ..writeln('error.code: ${error.code.name}')
        ..writeln('error.message: ${error.message}')
        ..writeln('error.details: ${error.details}');
      if (error.cause != null) {
        output.writeln('error.cause: ${error.cause}');
      }
    } else {
      output.writeln('error.message: $error');
    }
    if (stackTrace != null) {
      output
        ..writeln('error.stackTrace:')
        ..writeln(stackTrace);
    }
    return output.toString().trimRight();
  }

  /// Formats a tag result using stable technical field names.
  static String formatTagResult(NdefTagResult? result) {
    if (result == null) {
      return 'result: none';
    }
    final message = result.message;
    final output = StringBuffer()
      ..writeln('result.source: ${result.source.name}')
      ..writeln('tag.isWritable: ${result.isWritable}')
      ..writeln('tag.maxSize: ${result.maxSize}')
      ..writeln('tag.additionalData: ${result.additionalData}')
      ..writeln('message.byteLength: ${message?.byteLength ?? 0}')
      ..writeln('message.recordCount: ${message?.records.length ?? 0}');

    for (final entry
        in (message?.records ?? const <NdefRecordData>[]).indexed) {
      final index = entry.$1;
      final record = entry.$2;
      output
        ..writeln('record[$index].kind: ${record.kind.name}')
        ..writeln('record[$index].tnf: ${record.typeNameFormat.name}')
        ..writeln('record[$index].type: ${bytesToHex(record.type)}')
        ..writeln('record[$index].identifier: ${bytesToHex(record.identifier)}')
        ..writeln('record[$index].payload: ${bytesToHex(record.payload)}');
      if (record.content != null) {
        output.writeln('record[$index].content: ${record.content}');
      }
      if (record.decodingError != null) {
        output.writeln('record[$index].decodingError: ${record.decodingError}');
      }
    }
    return output.toString().trimRight();
  }
}
