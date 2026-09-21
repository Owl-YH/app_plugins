import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/ndef_record.dart' as plugin_ndef;
import 'package:nfc_manager/nfc_manager.dart' as plugin;
import 'package:nfc_manager/nfc_manager_ios.dart' as plugin_ios;
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart' as plugin_ndef_tech;

import 'ndef_exception.dart';
import 'ndef_models.dart';

/// App-facing NDEF client with serialized session lifecycle management.
final class NdefClient {
  NdefClient._();

  /// Shared process-wide client. Using one instance prevents overlapping native
  /// NFC sessions across features in the same application.
  static final NdefClient instance = NdefClient._();

  Future<void> Function()? _cancelActiveSession;

  plugin.NfcManager get _manager => plugin.NfcManager.instance;

  /// Whether a read or write session is currently active.
  bool get isSessionActive => _cancelActiveSession != null;

  /// Checks whether NFC is enabled and supported on the current device.
  Future<NdefAvailability> checkAvailability() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return NdefAvailability.unsupported;
    }
    final availability = await _manager.checkAvailability();
    return switch (availability) {
      plugin.NfcAvailability.enabled => NdefAvailability.enabled,
      plugin.NfcAvailability.disabled => NdefAvailability.disabled,
      plugin.NfcAvailability.unsupported => NdefAvailability.unsupported,
    };
  }

  /// Reads the first discovered NDEF tag.
  Future<NdefTagResult> read({
    NdefSessionOptions options = const NdefSessionOptions(),
  }) {
    return _runSession(
      options: options,
      operation: (tag) async {
        final ndef = plugin_ndef_tech.Ndef.from(tag);
        if (ndef == null) {
          throw NdefException(
            NdefErrorCode.notNdef,
            'The discovered tag does not support NDEF.',
          );
        }
        final message = ndef.cachedMessage ?? await ndef.read();
        return _tagResult(
          source: NdefResultSource.read,
          ndef: ndef,
          message: message,
        );
      },
    );
  }

  /// Overwrites the first discovered NDEF tag.
  ///
  /// When [verifyAfterWrite] is true, the message is immediately read back and
  /// compared byte-for-byte before this method succeeds.
  Future<NdefTagResult> write(
    NdefMessageData message, {
    bool verifyAfterWrite = true,
    NdefSessionOptions options = const NdefSessionOptions(),
  }) {
    if (message.records.isEmpty) {
      return Future.error(
        NdefException(
          NdefErrorCode.emptyMessage,
          'An NDEF write requires at least one record.',
        ),
      );
    }
    final pluginMessage = _toPluginMessage(message);
    return _runSession(
      options: options,
      operation: (tag) async {
        final ndef = plugin_ndef_tech.Ndef.from(tag);
        if (ndef == null) {
          throw NdefException(
            NdefErrorCode.notNdef,
            'The discovered tag does not support NDEF.',
          );
        }
        if (!ndef.isWritable) {
          throw NdefException(
            NdefErrorCode.readOnly,
            'The discovered NDEF tag is read-only.',
          );
        }
        if (message.byteLength > ndef.maxSize) {
          throw NdefException(
            NdefErrorCode.capacityExceeded,
            'The NDEF message exceeds the tag capacity.',
            details: {
              'requiredBytes': message.byteLength,
              'availableBytes': ndef.maxSize,
            },
          );
        }

        await ndef.write(message: pluginMessage);
        if (!verifyAfterWrite) {
          return _tagResult(
            source: NdefResultSource.write,
            ndef: ndef,
            message: pluginMessage,
          );
        }

        final readBack = await ndef.read();
        if (readBack != pluginMessage) {
          throw NdefException(
            NdefErrorCode.verificationFailed,
            'The write completed but the immediate read-back did not match.',
          );
        }
        return _tagResult(
          source: NdefResultSource.writeVerified,
          ndef: ndef,
          message: readBack,
        );
      },
    );
  }

  /// Cancels the current session. This is a no-op when no session is active.
  Future<void> cancel() async {
    await _cancelActiveSession?.call();
  }

  Future<T> _runSession<T>({
    required NdefSessionOptions options,
    required Future<T> Function(plugin.NfcTag tag) operation,
  }) async {
    if (_cancelActiveSession != null) {
      throw NdefException(
        NdefErrorCode.sessionAlreadyActive,
        'Another NFC session is already active.',
      );
    }

    final availability = await checkAvailability();
    switch (availability) {
      case NdefAvailability.enabled:
        break;
      case NdefAvailability.disabled:
        throw NdefException(
          NdefErrorCode.nfcDisabled,
          'NFC is disabled on this device.',
        );
      case NdefAvailability.unsupported:
        throw NdefException(
          NdefErrorCode.unsupported,
          'NFC tag scanning is not supported on this device.',
        );
    }

    await _clearStaleIosSession();

    final completer = Completer<T>();
    var isFinishing = false;

    Future<void> finishSuccess(T value) async {
      if (isFinishing || completer.isCompleted) {
        return;
      }
      isFinishing = true;
      try {
        await _manager.stopSession(alertMessageIos: options.successMessageIos);
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(_normalizeError(error), stackTrace);
        }
      }
    }

    Future<void> finishError(Object error, StackTrace stackTrace) async {
      if (isFinishing || completer.isCompleted) {
        return;
      }
      isFinishing = true;
      final normalized = _normalizeError(error);
      try {
        await _manager.stopSession(
          errorMessageIos:
              options.errorMessageIos ?? _shortError(normalized.message),
        );
      } catch (_) {
        // Preserve the primary NFC operation error.
      }
      if (!completer.isCompleted) {
        completer.completeError(normalized, stackTrace);
      }
    }

    _cancelActiveSession = () async {
      if (isFinishing || completer.isCompleted) {
        return;
      }
      isFinishing = true;
      try {
        await _manager.stopSession();
      } finally {
        if (!completer.isCompleted) {
          completer.completeError(NdefCancelledException());
        }
      }
    };

    try {
      await _manager.startSession(
        pollingOptions: const {
          plugin.NfcPollingOption.iso14443,
          plugin.NfcPollingOption.iso15693,
        },
        alertMessageIos: options.alertMessageIos,
        // Keeping this true is required on iOS. With false, nfc_manager 4.2.1
        // restarts polling before an asynchronous callback finishes, which
        // disconnects the current tag.
        invalidateAfterFirstReadIos: true,
        onDiscovered: (tag) async {
          if (isFinishing || completer.isCompleted) {
            return;
          }
          try {
            final result = await operation(tag);
            await finishSuccess(result);
          } catch (error, stackTrace) {
            await finishError(error, stackTrace);
          }
        },
        onSessionErrorIos: (error) async {
          if (isFinishing || completer.isCompleted) {
            return;
          }
          isFinishing = true;
          final normalized = _normalizeIosSessionError(error);
          // Core NFC has invalidated the native session, but nfc_manager 4.2.1
          // retains its tagSession reference. stopSession clears that field.
          try {
            await _manager.stopSession();
          } catch (_) {
            // A later plugin version may already clear the session.
          }
          if (!completer.isCompleted) {
            completer.completeError(normalized, StackTrace.current);
          }
        },
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(_normalizeError(error), stackTrace);
      }
    }

    try {
      return await completer.future;
    } finally {
      _cancelActiveSession = null;
    }
  }

  Future<void> _clearStaleIosSession() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _manager.stopSession();
    } on PlatformException catch (error) {
      if (error.code != 'no_active_sessions') {
        rethrow;
      }
    }
  }
}

NdefTagResult _tagResult({
  required NdefResultSource source,
  required plugin_ndef_tech.Ndef ndef,
  required plugin_ndef.NdefMessage? message,
}) {
  return NdefTagResult(
    source: source,
    isWritable: ndef.isWritable,
    maxSize: ndef.maxSize,
    message: message == null ? null : _fromPluginMessage(message),
    additionalData: Map<String, Object?>.from(ndef.additionalData),
  );
}

NdefMessageData _fromPluginMessage(plugin_ndef.NdefMessage message) {
  return NdefMessageData(
    records: message.records.map((record) {
      return NdefRecordData.fromRaw(
        typeNameFormat: _fromPluginTypeNameFormat(record.typeNameFormat),
        type: record.type,
        identifier: record.identifier,
        payload: record.payload,
      );
    }),
  );
}

plugin_ndef.NdefMessage _toPluginMessage(NdefMessageData message) {
  return plugin_ndef.NdefMessage(
    records: message.records
        .map((record) {
          return plugin_ndef.NdefRecord(
            typeNameFormat: _toPluginTypeNameFormat(record.typeNameFormat),
            type: Uint8List.fromList(record.type),
            identifier: Uint8List.fromList(record.identifier),
            payload: Uint8List.fromList(record.payload),
          );
        })
        .toList(growable: false),
  );
}

NdefTypeNameFormat _fromPluginTypeNameFormat(
  plugin_ndef.TypeNameFormat format,
) {
  return switch (format) {
    plugin_ndef.TypeNameFormat.empty => NdefTypeNameFormat.empty,
    plugin_ndef.TypeNameFormat.wellKnown => NdefTypeNameFormat.wellKnown,
    plugin_ndef.TypeNameFormat.media => NdefTypeNameFormat.media,
    plugin_ndef.TypeNameFormat.absoluteUri => NdefTypeNameFormat.absoluteUri,
    plugin_ndef.TypeNameFormat.external => NdefTypeNameFormat.external,
    plugin_ndef.TypeNameFormat.unknown => NdefTypeNameFormat.unknown,
    plugin_ndef.TypeNameFormat.unchanged => NdefTypeNameFormat.unchanged,
  };
}

plugin_ndef.TypeNameFormat _toPluginTypeNameFormat(NdefTypeNameFormat format) {
  return switch (format) {
    NdefTypeNameFormat.empty => plugin_ndef.TypeNameFormat.empty,
    NdefTypeNameFormat.wellKnown => plugin_ndef.TypeNameFormat.wellKnown,
    NdefTypeNameFormat.media => plugin_ndef.TypeNameFormat.media,
    NdefTypeNameFormat.absoluteUri => plugin_ndef.TypeNameFormat.absoluteUri,
    NdefTypeNameFormat.external => plugin_ndef.TypeNameFormat.external,
    NdefTypeNameFormat.unknown => plugin_ndef.TypeNameFormat.unknown,
    NdefTypeNameFormat.unchanged => plugin_ndef.TypeNameFormat.unchanged,
  };
}

NdefException _normalizeIosSessionError(
  plugin_ios.NfcReaderSessionErrorIos error,
) {
  final details = <String, Object?>{
    'platform': 'ios',
    'platformCode': error.code.name,
  };
  return switch (error.code) {
    plugin_ios
        .NfcReaderErrorCodeIos
        .readerSessionInvalidationErrorUserCanceled =>
      NdefCancelledException(cause: error.message),
    plugin_ios
        .NfcReaderErrorCodeIos
        .readerSessionInvalidationErrorSessionTimeout =>
      NdefException(
        NdefErrorCode.sessionTimeout,
        error.message,
        cause: error.message,
        details: details,
      ),
    plugin_ios
        .NfcReaderErrorCodeIos
        .readerSessionInvalidationErrorSystemIsBusy =>
      NdefException(
        NdefErrorCode.systemBusy,
        error.message,
        cause: error.message,
        details: details,
      ),
    plugin_ios.NfcReaderErrorCodeIos.readerTransceiveErrorTagConnectionLost ||
    plugin_ios.NfcReaderErrorCodeIos.readerTransceiveErrorTagNotConnected =>
      NdefException(
        NdefErrorCode.tagLost,
        error.message,
        cause: error.message,
        details: details,
      ),
    plugin_ios.NfcReaderErrorCodeIos.ndefReaderSessionErrorTagNotWritable =>
      NdefException(
        NdefErrorCode.readOnly,
        error.message,
        cause: error.message,
        details: details,
      ),
    plugin_ios.NfcReaderErrorCodeIos.ndefReaderSessionErrorTagSizeTooSmall =>
      NdefException(
        NdefErrorCode.capacityExceeded,
        error.message,
        cause: error.message,
        details: details,
      ),
    plugin_ios.NfcReaderErrorCodeIos.readerErrorUnsupportedFeature =>
      NdefException(
        NdefErrorCode.unsupported,
        error.message,
        cause: error.message,
        details: details,
      ),
    _ => NdefException(
      NdefErrorCode.sessionFailure,
      error.message,
      cause: error.message,
      details: details,
    ),
  };
}

NdefException _normalizeError(Object error) {
  if (error is NdefException) {
    return error;
  }
  if (error is PlatformException) {
    final searchable = '${error.code} ${error.message ?? ''}'.toLowerCase();
    final code = switch (error.code) {
      'session_already_exists' => NdefErrorCode.sessionAlreadyActive,
      'tag_not_found' => NdefErrorCode.tagLost,
      _
          when searchable.contains('connection lost') ||
              searchable.contains('not connected') =>
        NdefErrorCode.tagLost,
      _
          when searchable.contains('system resource unavailable') ||
              searchable.contains('system is busy') =>
        NdefErrorCode.systemBusy,
      _ => NdefErrorCode.platformFailure,
    };
    return NdefException(
      code,
      error.message ?? error.toString(),
      cause: error,
      details: {
        'platformCode': error.code,
        if (error.details != null) 'platformDetails': error.details,
      },
    );
  }
  return NdefException(
    NdefErrorCode.platformFailure,
    error.toString(),
    cause: error,
  );
}

String _shortError(String message) {
  return message.length <= 80 ? message : '${message.substring(0, 77)}...';
}
