import 'package:ndef_kit/ndef_kit.dart';

enum NfcOperation { idle, checking, reading, writing }

enum NfcNoticeTone { info, success, error }

enum NfcPayloadKind { text, uri }

final class NfcDemoState {
  const NfcDemoState({
    this.availability,
    this.operation = NfcOperation.idle,
    this.noticeTone = NfcNoticeTone.info,
    this.notice = '尚未检测 NFC 状态。',
    this.lastSnapshot,
    this.lastError,
    this.lastErrorStackTrace,
    this.lastErrorAt,
  });

  static const _unset = Object();

  final NdefAvailability? availability;
  final NfcOperation operation;
  final NfcNoticeTone noticeTone;
  final String notice;
  final NdefTagResult? lastSnapshot;
  final Object? lastError;
  final StackTrace? lastErrorStackTrace;
  final DateTime? lastErrorAt;

  bool get isBusy => operation != NfcOperation.idle;

  bool get canScan => !isBusy && availability == NdefAvailability.enabled;

  NfcDemoState copyWith({
    Object? availability = _unset,
    NfcOperation? operation,
    NfcNoticeTone? noticeTone,
    String? notice,
    Object? lastSnapshot = _unset,
    Object? lastError = _unset,
    Object? lastErrorStackTrace = _unset,
    Object? lastErrorAt = _unset,
  }) {
    return NfcDemoState(
      availability: identical(availability, _unset)
          ? this.availability
          : availability as NdefAvailability?,
      operation: operation ?? this.operation,
      noticeTone: noticeTone ?? this.noticeTone,
      notice: notice ?? this.notice,
      lastSnapshot: identical(lastSnapshot, _unset)
          ? this.lastSnapshot
          : lastSnapshot as NdefTagResult?,
      lastError: identical(lastError, _unset) ? this.lastError : lastError,
      lastErrorStackTrace: identical(lastErrorStackTrace, _unset)
          ? this.lastErrorStackTrace
          : lastErrorStackTrace as StackTrace?,
      lastErrorAt: identical(lastErrorAt, _unset)
          ? this.lastErrorAt
          : lastErrorAt as DateTime?,
    );
  }
}
