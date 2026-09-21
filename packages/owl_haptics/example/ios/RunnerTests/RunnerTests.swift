import Foundation
import XCTest

@testable import owl_haptics

final class RunnerTests: XCTestCase {
  func testStaleTokenCannotClearReplacement() {
    let fence = OwlHapticPlaybackFence()
    let owner = UUID()
    let first = fence.replace(owner: owner, id: 1)
    let second = fence.replace(owner: owner, id: 2)

    XCTAssertFalse(fence.clear(first))
    XCTAssertTrue(fence.matches(second))
    XCTAssertEqual(fence.matching(owner: owner, id: 2), second)
  }

  func testOwnerAndIdentifierFenceCancellation() {
    let fence = OwlHapticPlaybackFence()
    let owner = UUID()
    let otherOwner = UUID()
    let token = fence.replace(owner: owner, id: 7)

    XCTAssertNil(fence.matching(owner: owner, id: 8))
    XCTAssertNil(fence.matching(owner: otherOwner))
    XCTAssertEqual(fence.matching(owner: owner), token)
    XCTAssertTrue(fence.clear(token))
    XCTAssertFalse(fence.clear(token))
    XCTAssertNil(fence.current)
  }
}
