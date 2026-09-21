import XCTest

@testable import owl_ads_gromore

final class InitializationCoordinatorStateTests: XCTestCase {
  func testPendingReplyRejectsStaleGenerationAndCompletesOnce() {
    var values: [String] = []
    let reply = PendingReply<String>(generation: 2) { result in
      if case .success(let value) = result { values.append(value) }
    }

    XCTAssertFalse(reply.complete(generation: 1, result: .success("stale")))
    XCTAssertTrue(reply.complete(generation: 2, result: .success("current")))
    XCTAssertFalse(reply.complete(generation: 2, result: .success("duplicate")))
    XCTAssertEqual(values, ["current"])
  }

  func testEquivalentOwnersShareOneAttemptAndCompleteOnce() {
    let state = InitializationCoordinatorState<String, String>()

    guard case .start(let firstAttempt) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }
    guard case .wait(let secondAttempt) =
      state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The compatible owner must join the SDK attempt.") }

    XCTAssertEqual(firstAttempt, secondAttempt)
    XCTAssertEqual(state.nativeSucceeded(attemptID: firstAttempt), ["engine-a", "engine-b"])
    XCTAssertNil(state.nativeSucceeded(attemptID: firstAttempt))
    XCTAssertEqual(state.phase, .started)
  }

  func testConflictingFingerprintDoesNotJoinCurrentAttempt() {
    let state = InitializationCoordinatorState<String, String>()
    guard case .start(let attemptID) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }

    XCTAssertEqual(
      state.request(owner: "engine-b", fingerprint: "app-b", sdkReady: false),
      .conflict
    )
    XCTAssertEqual(state.nativeSucceeded(attemptID: attemptID), ["engine-a"])
  }

  func testDetachedOwnerIsRemovedWithoutCancellingOtherWaiters() {
    let state = InitializationCoordinatorState<String, String>()
    guard case .start(let attemptID) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }
    _ = state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: false)

    XCTAssertTrue(state.remove(owner: "engine-a"))
    XCTAssertEqual(state.nativeSucceeded(attemptID: attemptID), ["engine-b"])
  }

  func testTimeoutAndNativeCallbackRaceCompletesOnlyLiveOwners() {
    let state = InitializationCoordinatorState<String, String>()
    guard case .start(let attemptID) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }
    _ = state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: false)

    XCTAssertTrue(state.timeout(owner: "engine-a", attemptID: attemptID))
    XCTAssertEqual(state.nativeSucceeded(attemptID: attemptID), ["engine-b"])
    XCTAssertNil(state.nativeFailed(attemptID: attemptID))
  }

  func testLastTimeoutStallsUntilTheRealSDKReportsReady() {
    let state = InitializationCoordinatorState<String, String>()
    guard case .start(let attemptID) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }

    XCTAssertTrue(state.timeout(owner: "engine-a", attemptID: attemptID))
    XCTAssertEqual(state.phase, .stalled)
    XCTAssertEqual(
      state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: false),
      .restartRequired
    )
    XCTAssertEqual(
      state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: true),
      .complete
    )
    XCTAssertEqual(state.phase, .started)
  }

  func testFailureAllowsRetryAndRejectsTheStaleAttempt() {
    let state = InitializationCoordinatorState<String, String>()
    guard case .start(let firstAttempt) =
      state.request(owner: "engine-a", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("The first owner must start the SDK attempt.") }
    XCTAssertEqual(state.nativeFailed(attemptID: firstAttempt), ["engine-a"])

    guard case .start(let retryAttempt) =
      state.request(owner: "engine-b", fingerprint: "app-a", sdkReady: false)
    else { return XCTFail("A native failure must allow a later retry.") }
    XCTAssertGreaterThan(retryAttempt, firstAttempt)
    XCTAssertNil(state.nativeSucceeded(attemptID: firstAttempt))
    XCTAssertEqual(state.nativeSucceeded(attemptID: retryAttempt), ["engine-b"])
  }
}
