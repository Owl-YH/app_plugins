import Foundation

struct OwlHapticPlaybackToken: Equatable {
  let owner: UUID
  let id: Int64
  let generation: UInt64
}

final class OwlHapticPlaybackFence {
  private(set) var current: OwlHapticPlaybackToken?
  private var generation: UInt64 = 0

  @discardableResult
  func replace(owner: UUID, id: Int64) -> OwlHapticPlaybackToken {
    generation = generation == UInt64.max ? 1 : generation + 1
    let token = OwlHapticPlaybackToken(owner: owner, id: id, generation: generation)
    current = token
    return token
  }

  func matches(_ token: OwlHapticPlaybackToken) -> Bool {
    current == token
  }

  func matching(owner: UUID, id: Int64) -> OwlHapticPlaybackToken? {
    guard let current, current.owner == owner, current.id == id else { return nil }
    return current
  }

  func matching(owner: UUID) -> OwlHapticPlaybackToken? {
    guard let current, current.owner == owner else { return nil }
    return current
  }

  @discardableResult
  func clear(_ token: OwlHapticPlaybackToken) -> Bool {
    guard current == token else { return false }
    current = nil
    return true
  }
}
