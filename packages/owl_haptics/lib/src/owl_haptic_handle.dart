/// A request-scoped handle returned by `OwlHaptics.play`.
abstract interface class OwlHapticHandle {
  /// Completes when the native start request is accepted.
  ///
  /// This does not represent physical playback completion.
  Future<void> get started;

  /// Cancels remaining playback for this request.
  ///
  /// Repeated calls are safe and cannot cancel a newer request.
  Future<void> cancel();
}
