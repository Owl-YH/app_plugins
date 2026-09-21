import Foundation

/// One-shot Pigeon reply guarded by the native request generation.
final class PendingReply<Value> {
  private let generation: Int64
  private var completion: ((Result<Value, Error>) -> Void)?

  init(generation: Int64, completion: @escaping (Result<Value, Error>) -> Void) {
    self.generation = generation
    self.completion = completion
  }

  @discardableResult
  func complete(generation callbackGeneration: Int64, result: Result<Value, Error>) -> Bool {
    guard callbackGeneration == generation, let completion else { return false }
    self.completion = nil
    completion(result)
    return true
  }
}
