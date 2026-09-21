import Foundation

/// Pure process-initialization state. It never calls or simulates an ad SDK.
final class InitializationCoordinatorState<Owner: Hashable, Fingerprint: Equatable> {
  enum Phase: Equatable {
    case idle
    case starting
    case started
    case stalled
  }

  enum RequestDecision: Equatable {
    case start(attemptID: UInt64)
    case wait(attemptID: UInt64)
    case complete
    case conflict
    case restartRequired
  }

  private(set) var phase = Phase.idle
  private var fingerprint: Fingerprint?
  private var attemptID: UInt64 = 0
  private var owners: Set<Owner> = []

  func request(
    owner: Owner,
    fingerprint requestedFingerprint: Fingerprint,
    sdkReady: Bool
  ) -> RequestDecision {
    switch phase {
    case .idle:
      fingerprint = requestedFingerprint
      attemptID += 1
      owners.insert(owner)
      phase = .starting
      return .start(attemptID: attemptID)
    case .starting:
      guard fingerprint == requestedFingerprint else { return .conflict }
      owners.insert(owner)
      return .wait(attemptID: attemptID)
    case .started:
      guard fingerprint == requestedFingerprint else { return .conflict }
      return sdkReady ? .complete : .restartRequired
    case .stalled:
      guard fingerprint == requestedFingerprint else { return .conflict }
      guard sdkReady else { return .restartRequired }
      phase = .started
      return .complete
    }
  }

  /// Removes a detached/disposed owner without changing the SDK attempt.
  @discardableResult
  func remove(owner: Owner) -> Bool {
    owners.remove(owner) != nil
  }

  /// Expires one owner. The process attempt becomes stalled after its last timeout.
  @discardableResult
  func timeout(owner: Owner, attemptID expectedAttemptID: UInt64) -> Bool {
    guard phase == .starting, attemptID == expectedAttemptID,
      owners.remove(owner) != nil
    else { return false }
    if owners.isEmpty { phase = .stalled }
    return true
  }

  /// Accepts only the current native success and returns the live owners to complete.
  func nativeSucceeded(attemptID expectedAttemptID: UInt64) -> Set<Owner>? {
    guard (phase == .starting || phase == .stalled), attemptID == expectedAttemptID else {
      return nil
    }
    let completedOwners = owners
    owners.removeAll()
    phase = .started
    return completedOwners
  }

  /// Accepts only the current native failure, returning to a retryable idle state.
  func nativeFailed(attemptID expectedAttemptID: UInt64) -> Set<Owner>? {
    guard (phase == .starting || phase == .stalled), attemptID == expectedAttemptID else {
      return nil
    }
    let completedOwners = owners
    owners.removeAll()
    fingerprint = nil
    phase = .idle
    return completedOwners
  }
}
