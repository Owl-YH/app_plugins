/// Stable error categories exposed by `ndef_kit`.
enum NdefErrorCode {
  /// The user or caller cancelled the active NFC session.
  cancelled,

  /// Another NFC operation is already active in this process.
  sessionAlreadyActive,

  /// NFC is supported but disabled on the device.
  nfcDisabled,

  /// The device or platform does not support the requested NFC operation.
  unsupported,

  /// The write request contains no NDEF records.
  emptyMessage,

  /// The discovered tag does not expose NDEF technology.
  notNdef,

  /// The discovered NDEF tag cannot be written.
  readOnly,

  /// The encoded message exceeds the tag capacity.
  capacityExceeded,

  /// A write completed, but the immediate read-back did not match.
  verificationFailed,

  /// Communication with the tag was lost.
  tagLost,

  /// The platform NFC session timed out.
  sessionTimeout,

  /// The platform NFC subsystem is currently busy.
  systemBusy,

  /// The NFC session ended unexpectedly.
  sessionFailure,

  /// An unclassified platform-plugin error occurred.
  platformFailure,
}

/// A normalized NDEF operation failure.
class NdefException implements Exception {
  /// Creates a normalized exception with a stable [code].
  NdefException(
    this.code,
    this.message, {
    this.cause,
    Map<String, Object?> details = const {},
  }) : details = Map.unmodifiable(details);

  /// Stable programmatic error category.
  final NdefErrorCode code;

  /// Technical, non-localized error description.
  final String message;

  /// Original error, when one was provided by the platform plugin.
  final Object? cause;

  /// Structured context such as required and available byte counts.
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

/// An NFC session cancelled by the user or caller.
final class NdefCancelledException extends NdefException {
  /// Creates a cancellation exception.
  NdefCancelledException({Object? cause})
    : super(
        NdefErrorCode.cancelled,
        'The NFC session was cancelled.',
        cause: cause,
      );
}
