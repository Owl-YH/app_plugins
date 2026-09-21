import CoreHaptics
import Flutter
import UIKit

public final class OwlHapticsPlugin: NSObject, FlutterPlugin, OwlHapticsHostApi {
  private let messenger: FlutterBinaryMessenger
  private let owner = UUID()
  private var lifecycleObserver: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = OwlHapticsPlugin(messenger: registrar.messenger())
    OwlHapticsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.publish(instance)
  }

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
    lifecycleObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      OwlHapticCoordinator.shared.stop(owner: self.owner)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    dispose()
  }

  func play(request: HapticRequest) throws {
    try validate(request)
    do {
      try OwlHapticCoordinator.shared.play(owner: owner, request: request)
    } catch let error as PigeonError {
      throw error
    } catch {
      throw PigeonError(
        code: "haptic_failed",
        message: "Unable to start haptic feedback.",
        details: nil
      )
    }
  }

  func cancel(id: Int64) throws {
    try requireId(id)
    OwlHapticCoordinator.shared.cancel(owner: owner, id: id)
  }

  func stop() throws {
    OwlHapticCoordinator.shared.stop(owner: owner)
  }

  private func dispose() {
    OwlHapticsHostApiSetup.setUp(binaryMessenger: messenger, api: nil)
    if let lifecycleObserver {
      NotificationCenter.default.removeObserver(lifecycleObserver)
      self.lifecycleObserver = nil
    }
    OwlHapticCoordinator.shared.stop(owner: owner)
  }

  private func validate(_ request: HapticRequest) throws {
    try requireId(request.id)
    let valid: Bool
    switch request.kind {
    case .selection:
      valid = request.strength == nil && request.outcome == nil && request.pulses.isEmpty
    case .impact:
      valid = request.strength != nil && request.outcome == nil && request.pulses.isEmpty
    case .outcome:
      valid = request.strength == nil && request.outcome != nil && request.pulses.isEmpty
    case .sequence:
      valid = request.strength == nil && request.outcome == nil && validPulses(request.pulses)
    }
    if !valid {
      throw PigeonError(code: "invalid_request", message: "Invalid haptic request.", details: nil)
    }
  }

  private func requireId(_ id: Int64) throws {
    if id <= 0 {
      throw PigeonError(
        code: "invalid_id",
        message: "Playback identity must be positive.",
        details: nil
      )
    }
  }

  private func validPulses(_ pulses: [HapticPulse]) -> Bool {
    guard !pulses.isEmpty, pulses.count <= 16 else { return false }
    var previous: Int64 = -50
    for pulse in pulses {
      guard pulse.atMillis >= 0, pulse.atMillis <= 2_000,
        pulse.atMillis - previous >= 50
      else { return false }
      previous = pulse.atMillis
    }
    return true
  }
}

private final class OwlHapticCoordinator {
  static let shared = OwlHapticCoordinator()

  private struct ActiveSequence {
    let token: OwlHapticPlaybackToken
    let engine: CHHapticEngine
    let player: CHHapticAdvancedPatternPlayer
  }

  private let fence = OwlHapticPlaybackFence()
  private var active: ActiveSequence?

  private init() {}

  func play(owner: UUID, request: HapticRequest) throws {
    dispatchPrecondition(condition: .onQueue(.main))
    cancelActive()
    guard UIApplication.shared.applicationState == .active else { return }

    switch request.kind {
    case .selection:
      let generator = UISelectionFeedbackGenerator()
      generator.prepare()
      generator.selectionChanged()
    case .impact:
      impact(requireNotNil(request.strength))
    case .outcome:
      outcome(requireNotNil(request.outcome))
    case .sequence:
      try sequence(
        owner: owner,
        id: request.id,
        pulses: request.pulses
      )
    }
  }

  func cancel(owner: UUID, id: Int64) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let token = fence.matching(owner: owner, id: id) else { return }
    cancelActive(token)
  }

  func stop(owner: UUID) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let token = fence.matching(owner: owner) else { return }
    cancelActive(token)
  }

  private func sequence(owner: UUID, id: Int64, pulses: [HapticPulse]) throws {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
      fallback(pulses)
      return
    }

    let events = pulses.map { pulse in
      let values = shape(pulse.strength)
      return CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: values.intensity),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: values.sharpness),
        ],
        relativeTime: Double(pulse.atMillis) / 1_000
      )
    }
    let pattern = try CHHapticPattern(events: events, parameters: [])
    let engine = try CHHapticEngine()
    engine.playsHapticsOnly = true
    engine.isAutoShutdownEnabled = true
    let token = fence.replace(owner: owner, id: id)
    engine.stoppedHandler = { [weak self, weak engine] _ in
      guard let engine else { return }
      DispatchQueue.main.async {
        self?.invalidate(token, engine: engine, stopEngine: false)
      }
    }
    engine.resetHandler = { [weak self, weak engine] in
      guard let engine else { return }
      DispatchQueue.main.async {
        self?.invalidate(token, engine: engine, stopEngine: true)
      }
    }

    do {
      try engine.start()
      let player = try engine.makeAdvancedPlayer(with: pattern)
      player.completionHandler = { [weak self, weak engine] _ in
        guard let engine else { return }
        DispatchQueue.main.async {
          self?.complete(token, engine: engine)
        }
      }
      active = ActiveSequence(token: token, engine: engine, player: player)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      clearFailedStart(token, engine: engine)
      throw error
    }
  }

  private func complete(_ token: OwlHapticPlaybackToken, engine: CHHapticEngine) {
    guard let sequence = takeActive(token, engine: engine) else { return }
    sequence.engine.stop(completionHandler: nil)
  }

  private func cancelActive() {
    guard let token = fence.current else { return }
    cancelActive(token)
  }

  private func cancelActive(_ token: OwlHapticPlaybackToken) {
    guard let sequence = takeActive(token, engine: nil) else { return }
    try? sequence.player.stop(atTime: CHHapticTimeImmediate)
    sequence.engine.stop(completionHandler: nil)
  }

  private func invalidate(
    _ token: OwlHapticPlaybackToken,
    engine: CHHapticEngine,
    stopEngine: Bool
  ) {
    guard let sequence = takeActive(token, engine: engine) else { return }
    try? sequence.player.stop(atTime: CHHapticTimeImmediate)
    if stopEngine {
      sequence.engine.stop(completionHandler: nil)
    }
  }

  private func clearFailedStart(_ token: OwlHapticPlaybackToken, engine: CHHapticEngine) {
    if let sequence = takeActive(token, engine: engine) {
      try? sequence.player.stop(atTime: CHHapticTimeImmediate)
    } else {
      fence.clear(token)
    }
    engine.stop(completionHandler: nil)
  }

  private func takeActive(
    _ token: OwlHapticPlaybackToken,
    engine expectedEngine: CHHapticEngine?
  ) -> ActiveSequence? {
    guard fence.matches(token), let sequence = active, sequence.token == token else {
      return nil
    }
    if let expectedEngine, sequence.engine !== expectedEngine { return nil }
    active = nil
    fence.clear(token)
    return sequence
  }

  private func impact(_ strength: HapticLevel) {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch strength {
    case .light:
      style = .light
    case .medium:
      style = .medium
    case .heavy:
      style = .heavy
    }
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
  }

  private func outcome(_ result: HapticResult) {
    let type: UINotificationFeedbackGenerator.FeedbackType
    switch result {
    case .success:
      type = .success
    case .warning:
      type = .warning
    case .error:
      type = .error
    }
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(type)
  }

  private func fallback(_ pulses: [HapticPulse]) {
    guard let strongest = pulses.map(\.strength).max(by: { $0.rawValue < $1.rawValue })
    else { return }
    impact(strongest)
  }

  private func shape(_ strength: HapticLevel) -> (intensity: Float, sharpness: Float) {
    switch strength {
    case .light:
      return (0.32, 0.36)
    case .medium:
      return (0.52, 0.50)
    case .heavy:
      return (0.82, 0.64)
    }
  }

  private func requireNotNil<T>(_ value: T?) -> T {
    precondition(value != nil)
    return value!
  }
}
