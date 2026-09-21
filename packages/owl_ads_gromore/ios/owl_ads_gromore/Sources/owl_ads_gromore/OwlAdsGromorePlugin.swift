import BUAdSDK
import Flutter
import UIKit

public final class OwlAdsGromorePlugin: NSObject, FlutterPlugin {
  private let messenger: FlutterBinaryMessenger
  private let host: IOSGroMoreHost
  private let methodChannel: FlutterMethodChannel

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    host = IOSGroMoreHost(messenger: messenger)
    methodChannel = FlutterMethodChannel(
      name: "com.owlllwo.plugins.gromore/methods",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler { [weak host] call, result in
      guard let host else {
        result(FlutterError(code: "disposed", message: "The native plugin is unavailable.", details: nil))
        return
      }
      host.handleMethodCall(call, result: result)
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = OwlAdsGromorePlugin(messenger: registrar.messenger())
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    methodChannel.setMethodCallHandler(nil)
    host.disposeFromEngineDetach()
  }
}

private enum IOSSessionState {
  case loading
  case ready
  case showing
}

/// Presents fullscreen native ads outside Flutter's UIWindow so UIKit touch
/// state from the ad's dismissal cannot leak into Flutter's gesture pipeline.
private final class IOSAdPresenterViewController: UIViewController {
  private(set) var wasCoveredByPresentation = false
  private(set) var returnedFromPresentation = false
  var onReturnFromPresentation: (() -> Void)?

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    wasCoveredByPresentation = true
    returnedFromPresentation = false
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard wasCoveredByPresentation else { return }
    returnedFromPresentation = true
    onReturnFromPresentation?()
  }
}

private final class IOSAdPresentationWindow {
  let presenter: IOSAdPresenterViewController

  private weak var previousKeyWindow: UIWindow?
  private var window: UIWindow?
  private var finishing = false
  private var finishCompletion: (() -> Void)?

  init(presentingWindow: UIWindow) {
    previousKeyWindow = presentingWindow

    let adWindow: UIWindow
    if let scene = presentingWindow.windowScene {
      adWindow = UIWindow(windowScene: scene)
    } else {
      adWindow = UIWindow(frame: presentingWindow.bounds)
    }
    adWindow.frame = presentingWindow.bounds
    adWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    adWindow.windowLevel = UIWindow.Level(rawValue: presentingWindow.windowLevel.rawValue + 1)

    let presenter = IOSAdPresenterViewController()
    presenter.view.backgroundColor = .clear
    presenter.view.isUserInteractionEnabled = true
    adWindow.rootViewController = presenter

    self.presenter = presenter
    window = adWindow
    adWindow.makeKeyAndVisible()
  }

  /// GroMore does not expose a dismissal completion. Wait until UIKit removes
  /// the presented controller, with a one-second safety bound, before restoring
  /// Flutter's window and allowing the MethodChannel result to re-enter Dart.
  func finish(completion: @escaping () -> Void) {
    guard !finishing else { return }
    finishing = true
    finishCompletion = completion
    presenter.onReturnFromPresentation = { [weak self] in
      self?.completeFinish()
    }
    DispatchQueue.main.async { [weak self] in
      self?.waitForDismissal(remainingChecks: 60)
    }
  }

  /// Used when the engine or provider is disposed and no asynchronous result
  /// should keep the temporary window alive.
  func forceCleanup() {
    finishing = true
    finishCompletion = nil
    presenter.onReturnFromPresentation = nil
    cleanup()
  }

  private func waitForDismissal(remainingChecks: Int) {
    guard window != nil else { return }
    let presentationFinished =
      presenter.returnedFromPresentation
      || (!presenter.wasCoveredByPresentation && presenter.presentedViewController == nil)
    guard !presentationFinished, remainingChecks > 0 else {
      completeFinish()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / 60.0)) { [weak self] in
      guard let self else { return }
      self.waitForDismissal(remainingChecks: remainingChecks - 1)
    }
  }

  private func completeFinish() {
    guard window != nil else { return }
    let completion = finishCompletion
    finishCompletion = nil
    presenter.onReturnFromPresentation = nil
    cleanup()
    completion?()
  }

  private func cleanup() {
    guard let window else { return }
    window.isHidden = true
    previousKeyWindow?.makeKey()
    window.rootViewController = nil
    self.window = nil
    previousKeyWindow = nil
  }
}

private final class IOSRewardSession {
  let request: NativeAdRequest
  let ad: BUNativeExpressRewardedVideoAd
  var state = IOSSessionState.loading
  var loadCompletion: PendingReply<Void>?
  var showCompletion: PendingReply<NativeShowResult>?
  var reward = NativeRewardResult(rewarded: false, verified: false)
  var rewardEmitted = false
  var revenueEmitted = false
  var presented = false
  var finishing = false
  var presentationWindow: IOSAdPresentationWindow?
  var loadTimeout: DispatchWorkItem?
  var presentationTimeout: DispatchWorkItem?
  var terminalTimeout: DispatchWorkItem?

  init(
    request: NativeAdRequest,
    ad: BUNativeExpressRewardedVideoAd,
    loadCompletion: @escaping (Result<Void, Error>) -> Void
  ) {
    self.request = request
    self.ad = ad
    self.loadCompletion = PendingReply(generation: request.generation, completion: loadCompletion)
  }
}

private final class IOSInsertSession {
  let request: NativeAdRequest
  let ad: BUNativeExpressFullscreenVideoAd
  var state = IOSSessionState.loading
  var loadCompletion: PendingReply<Void>?
  var showCompletion: PendingReply<NativeShowResult>?
  var revenueEmitted = false
  var presented = false
  var finishing = false
  var presentationWindow: IOSAdPresentationWindow?
  var loadTimeout: DispatchWorkItem?
  var presentationTimeout: DispatchWorkItem?
  var terminalTimeout: DispatchWorkItem?

  init(
    request: NativeAdRequest,
    ad: BUNativeExpressFullscreenVideoAd,
    loadCompletion: @escaping (Result<Void, Error>) -> Void
  ) {
    self.request = request
    self.ad = ad
    self.loadCompletion = PendingReply(generation: request.generation, completion: loadCompletion)
  }
}

private final class IOSPrivacyProvider: NSObject, BUAdSDKPrivacyProvider {
  var consent = NativeConsent(accepted: false, personalizedAds: false)
  var access = deniedAccess()

  func canUseLocation() -> Bool { access.canUseLocation }

  func canUseWiFiBSSID() -> Bool { access.canUseWifiState }

  func privacyConfig() -> [AnyHashable: Any]? {
    [
      kBUMPrivacyAdvertiserTrackingEnabled: access.canUseIdfa ? "1" : "0",
      kBUMPrivacyMotionInfo: "0",
      kBUMPrivacyDisableUsePhoneStatus: access.canUsePhoneState ? "0" : "1",
      kBUMPrivacyCanUseSpaceSize: "0",
      kBUMPrivacyCanUseCarrier: NSNumber(value: false),
    ]
  }
}

private struct IOSInitializationFingerprint: Equatable {
  let appID: String
  let debugLogging: Bool
  let access: NativeAccess
}

/** Owns process-wide SDK initialization and privacy state only. */
private final class IOSGroMoreProcess {
  static let shared = IOSGroMoreProcess()

  let privacyProvider = IOSPrivacyProvider()
  private let coordinator =
    InitializationCoordinatorState<UUID, IOSInitializationFingerprint>()
  private var waiters: [UUID: (Result<Void, Error>) -> Void] = [:]
  private var ownerAttempts: [UUID: UInt64] = [:]

  private init() {}

  func initialize(
    owner: UUID,
    request: NativeInitializationRequest,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.initialize(owner: owner, request: request, completion: completion)
      }
      return
    }

    let requested = IOSInitializationFingerprint(
      appID: request.appId,
      debugLogging: request.debugLogging,
      access: request.access
    )
    switch coordinator.request(
      owner: owner,
      fingerprint: requested,
      sdkReady: BUAdSDKManager.state == .start
    ) {
    case .complete:
      updatePrivacy(consent: request.consent, access: request.access)
      completion(.success(()))
    case .conflict:
      completion(
        .failure(
          pigeonError(
            "configurationConflict",
            "GroMore is starting or initialized with another process configuration."
          )))
    case .restartRequired:
      completion(
        .failure(
          pigeonError(
            "restartRequired",
            "GroMore initialization previously timed out and the SDK is still not ready."
          )))
    case .wait(let attemptID):
      updatePrivacy(consent: request.consent, access: request.access)
      waiters[owner] = completion
      ownerAttempts[owner] = attemptID
    case .start(let attemptID):
      updatePrivacy(consent: request.consent, access: request.access)
      waiters[owner] = completion
      ownerAttempts[owner] = attemptID
      startSDK(attemptID: attemptID, request: request)
    }
  }

  private func startSDK(attemptID: UInt64, request: NativeInitializationRequest) {
    let configuration = BUAdSDKConfiguration.configuration()
    configuration.appID = request.appId
    configuration.debugLog = NSNumber(value: request.debugLogging)
    configuration.sdkdebug = request.debugLogging
    configuration.privacyProvider = privacyProvider
    configuration.useMediation = true
    applyMutablePrivacy(configuration: configuration)

    BUAdSDKManager.start(asyncCompletionHandler: { [weak self] success, error in
      DispatchQueue.main.async {
        guard let self else { return }
        guard success, BUAdSDKManager.state == .start else {
          guard let owners = self.coordinator.nativeFailed(attemptID: attemptID) else { return }
          self.completeWaiters(
            owners: owners,
            .failure(
              pigeonError(
                "initializationFailed",
                error?.localizedDescription ?? "GroMore initialization failed.",
                error: error
              )))
          return
        }
        guard let owners = self.coordinator.nativeSucceeded(attemptID: attemptID) else { return }
        self.completeWaiters(owners: owners, .success(()))
      }
    })
  }

  func removeWaiter(owner: UUID, result: Result<Void, Error>? = nil) {
    let remove = { [weak self] in
      guard let self else { return }
      self.coordinator.remove(owner: owner)
      self.ownerAttempts.removeValue(forKey: owner)
      let completion = self.waiters.removeValue(forKey: owner)
      if let result { completion?(result) }
    }
    if Thread.isMainThread { remove() } else { DispatchQueue.main.async(execute: remove) }
  }

  func timeoutWaiter(owner: UUID, result: Result<Void, Error>) {
    let timeout = { [weak self] in
      guard let self else { return }
      if let attemptID = self.ownerAttempts.removeValue(forKey: owner) {
        self.coordinator.timeout(owner: owner, attemptID: attemptID)
      }
      self.waiters.removeValue(forKey: owner)?(result)
    }
    if Thread.isMainThread { timeout() } else { DispatchQueue.main.async(execute: timeout) }
  }

  func updatePrivacy(consent: NativeConsent, access: NativeAccess) {
    privacyProvider.consent = consent
    privacyProvider.access = access
    applyMutablePrivacy(configuration: BUAdSDKConfiguration.configuration())
  }

  private func applyMutablePrivacy(configuration: BUAdSDKConfiguration) {
    let personalized =
      privacyProvider.consent.accepted
      && privacyProvider.consent.personalizedAds
    configuration.mediation.limitPersonalAds = NSNumber(value: !personalized)
    configuration.mediation.limitProgrammaticAds = NSNumber(value: !personalized)
    configuration.mediation.forbiddenIDFA = NSNumber(value: !privacyProvider.access.canUseIdfa)
    configuration.mediation.allowUploadDeviceInfo = privacyProvider.access.canUploadDeviceInfo
  }

  private func completeWaiters(owners: Set<UUID>, _ result: Result<Void, Error>) {
    let completions = owners.compactMap { owner -> ((Result<Void, Error>) -> Void)? in
      ownerAttempts.removeValue(forKey: owner)
      return waiters.removeValue(forKey: owner)
    }
    completions.forEach { $0(result) }
  }
}

private final class IOSGroMoreHost: NSObject, GroMoreHostApi,
  BUMNativeExpressRewardedVideoAdDelegate,
  BUMNativeExpressFullscreenVideoAdDelegate
{
  private static let initializationTimeout: TimeInterval = 30
  private static let loadTimeout: TimeInterval = 30
  private static let presentationTimeout: TimeInterval = 10
  private static let showTerminalTimeout: TimeInterval = 15 * 60

  private let flutterApi: GroMoreFlutterApi
  private let processOwner = UUID()
  private var rewards: [String: IOSRewardSession] = [:]
  private var inserts: [String: IOSInsertSession] = [:]

  private var initialized = false
  private var initializing = false
  private var disposed = false
  private var appID: String?
  private var debugLogging = false
  private var consent = NativeConsent(accepted: false, personalizedAds: false)
  private var access = deniedAccess()

  init(messenger: FlutterBinaryMessenger) {
    flutterApi = GroMoreFlutterApi(binaryMessenger: messenger)
    super.init()
  }

  func initialize(
    request: NativeInitializationRequest,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if disposed {
      completion(.failure(pigeonError("disposed", "The native plugin is disposed.")))
      return
    }
    guard request.consent.accepted else {
      completion(
        .failure(
          pigeonError(
            "consentRequired",
            "Consent is required before GroMore initialization."
          )))
      return
    }
    if initialized, appID == request.appId, BUAdSDKManager.state == .start {
      guard request.access == access, request.debugLogging == debugLogging else {
        completion(
          .failure(
            pigeonError("configurationConflict", "GroMore immutable configuration changed.")))
        return
      }
      consent = request.consent
      IOSGroMoreProcess.shared.updatePrivacy(consent: consent, access: access)
      completion(.success(()))
      return
    }
    guard !initializing else {
      completion(
        .failure(
          pigeonError(
            "invalidState",
            "GroMore initialization is already in progress."
          )))
      return
    }

    initializing = true
    appID = request.appId
    debugLogging = request.debugLogging
    consent = request.consent
    access = request.access

    var completed = false
    var initializationTimeout: DispatchWorkItem?
    let finish: (Result<Void, Error>) -> Void = { result in
      guard !completed else { return }
      completed = true
      initializationTimeout?.cancel()
      initializationTimeout = nil
      completion(result)
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, !completed else { return }
      IOSGroMoreProcess.shared.timeoutWaiter(
        owner: self.processOwner,
        result:
        .failure(
          pigeonError(
            "initializationFailed",
            "GroMore initialization timed out after 30 seconds without an SDK callback."
          ))
      )
    }
    initializationTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.initializationTimeout, execute: timeout)
    IOSGroMoreProcess.shared.initialize(owner: processOwner, request: request) { [weak self] result in
      guard let self else {
        finish(.failure(pigeonError("disposed", "The native plugin was released.")))
        return
      }
      self.initializing = false
      guard !self.disposed else {
        finish(.failure(pigeonError("disposed", "The native plugin was disposed during initialization.")))
        return
      }
      if case .success = result { self.initialized = true }
      finish(result)
    }
  }

  func updatePrivacy(
    request: NativePrivacyUpdate,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if disposed {
      completion(.failure(pigeonError("disposed", "The native plugin is disposed.")))
      return
    }
    if initialized, request.access != access {
      if !request.consent.accepted {
        consent = request.consent
        invalidateAll(reason: "Consent was withdrawn.")
      }
      completion(
        .failure(
          pigeonError(
            "restartRequired",
            "The pinned iOS SDK requires a process restart for data-access changes."
          )))
      return
    }
    consent = request.consent
    access = request.access
    IOSGroMoreProcess.shared.updatePrivacy(consent: consent, access: access)
    if !request.consent.accepted {
      invalidateAll(reason: "Consent was withdrawn.")
    }
    if initialized {
      IOSGroMoreProcess.shared.updatePrivacy(consent: consent, access: access)
    }
    completion(.success(()))
  }

  func loadAd(
    request: NativeAdRequest,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if let gate = requestGate() {
      completion(.failure(gate))
      return
    }
    guard !request.codeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      completion(
        .failure(
          pigeonError(
            "configurationInvalid",
            "GroMore Code ID must not be empty."
          )))
      return
    }
    switch request.adType {
    case .reward:
      loadReward(request: request, completion: completion)
    case .insert:
      loadInsert(request: request, completion: completion)
    }
  }

  func isReady(
    identity: NativeAdIdentity,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    if let gate = requestGate() {
      completion(.failure(gate))
      return
    }
    let ready: Bool
    switch identity.adType {
    case .reward:
      if let session = rewards[identity.placement] {
        ready =
          session.request.generation == identity.generation
          && session.state == .ready
          && session.ad.mediation?.isReady == true
      } else {
        ready = false
      }
    case .insert:
      if let session = inserts[identity.placement] {
        ready =
          session.request.generation == identity.generation
          && session.state == .ready
          && session.ad.mediation?.isReady == true
      } else {
        ready = false
      }
    }
    completion(.success(ready))
  }

  func showAd(
    identity: NativeAdIdentity,
    completion: @escaping (Result<NativeShowResult, Error>) -> Void
  ) {
    if let gate = requestGate() {
      completion(.failure(gate))
      return
    }
    guard let presenter = activePresenter() else {
      completion(
        .failure(
          pigeonError(
            "presenterUnavailable",
            "No active, conflict-free iOS presenter is available."
          )))
      return
    }
    switch identity.adType {
    case .reward:
      showReward(identity: identity, presenter: presenter, completion: completion)
    case .insert:
      showInsert(identity: identity, presenter: presenter, completion: completion)
    }
  }

  func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
    if disposed {
      completion(.success(()))
      return
    }
    IOSGroMoreProcess.shared.removeWaiter(
      owner: processOwner,
      result: .failure(
        pigeonError("disposed", "The Dart provider was disposed during initialization."))
    )
    invalidateAll(reason: "The Dart provider was disposed.", normalizedCode: "disposed")
    initializing = false
    initialized = false
    completion(.success(()))
  }

  func disposeFromEngineDetach() {
    guard !disposed else { return }
    disposed = true
    IOSGroMoreProcess.shared.removeWaiter(
      owner: processOwner,
      result: .failure(
        pigeonError("disposed", "The Flutter engine detached during initialization."))
    )
    invalidateAll(reason: "The Flutter engine detached.", normalizedCode: "disposed")
  }

  private func loadReward(
    request: NativeAdRequest,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if let existing = rewards[request.placement] {
      switch existing.state {
      case .loading:
        completion(.failure(pigeonError("alreadyLoading", "Reward ad is already loading.")))
      case .ready:
        completion(.success(()))
      case .showing:
        completion(.failure(pigeonError("invalidState", "Reward ad is showing.")))
      }
      return
    }

    let model = BURewardedVideoModel()
    model.userId = request.rewardOptions?.userId
    model.extra = request.rewardOptions?.customData
    model.rewardName = request.rewardOptions?.rewardName
    if let amount = request.rewardOptions?.rewardAmount {
      model.rewardAmount = Int(amount)
    }
    let ad = BUNativeExpressRewardedVideoAd(
      slotID: request.codeId,
      rewardedVideoModel: model
    )
    let session = IOSRewardSession(
      request: request,
      ad: ad,
      loadCompletion: completion
    )
    rewards[request.placement] = session
    ad.delegate = self
    ad.loadData()
    let loadTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.rewards[session.request.placement] === session,
        session.state == .loading
      else { return }
      session.loadTimeout = nil
      let failure = diagnostic(
        "nativeLoadFailed",
        "GroMore reward load timed out after 30 seconds without an SDK callback."
      )
      self.emit(request: session.request, kind: .failed, diagnostic: failure)
      let completion = session.loadCompletion
      session.ad.delegate = nil
      self.rewards.removeValue(forKey: session.request.placement)
      completion?.complete(
        generation: session.request.generation,
        result: .failure(failure.asPigeonError())
      )
    }
    session.loadTimeout = loadTimeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadTimeout, execute: loadTimeout)
  }

  private func completeRewardLoadIfReady(_ ad: BUNativeExpressRewardedVideoAd) {
    guard let session = rewardSession(for: ad), session.state == .loading else { return }
    guard ad.mediation?.isReady == true else { return }
    cancelLoadTimeout(session)
    session.state = .ready
    emit(request: session.request, kind: .loaded)
    session.loadCompletion?.complete(
      generation: session.request.generation,
      result: .success(())
    )
  }

  private func showReward(
    identity: NativeAdIdentity,
    presenter: UIViewController,
    completion: @escaping (Result<NativeShowResult, Error>) -> Void
  ) {
    guard let session = rewards[identity.placement],
      session.request.generation == identity.generation,
      session.state == .ready,
      session.ad.mediation?.isReady == true
    else {
      completion(.failure(pigeonError("notReady", "Reward ad is not ready.")))
      return
    }
    guard let presentingWindow = presenter.viewIfLoaded?.window else {
      completion(
        .failure(
          pigeonError(
            "presenterUnavailable",
            "The active iOS presenter is not attached to a window."
          )))
      return
    }
    let presentationWindow = IOSAdPresentationWindow(presentingWindow: presentingWindow)
    session.presentationWindow = presentationWindow
    session.state = .showing
    session.showCompletion = PendingReply(
      generation: session.request.generation,
      completion: completion
    )
    guard session.ad.show(fromRootViewController: presentationWindow.presenter) else {
      finishReward(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore rejected the reward presentation request."
          )),
        emitFailure: true
      )
      return
    }
    scheduleRewardShowWatchdogs(session)
  }

  private func loadInsert(
    request: NativeAdRequest,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    if let existing = inserts[request.placement] {
      switch existing.state {
      case .loading:
        completion(.failure(pigeonError("alreadyLoading", "Insert ad is already loading.")))
      case .ready:
        completion(.success(()))
      case .showing:
        completion(.failure(pigeonError("invalidState", "Insert ad is showing.")))
      }
      return
    }
    let ad = BUNativeExpressFullscreenVideoAd(slotID: request.codeId)
    let session = IOSInsertSession(
      request: request,
      ad: ad,
      loadCompletion: completion
    )
    inserts[request.placement] = session
    ad.delegate = self
    ad.loadData()
    let loadTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.inserts[session.request.placement] === session,
        session.state == .loading
      else { return }
      session.loadTimeout = nil
      let failure = diagnostic(
        "nativeLoadFailed",
        "GroMore insert load timed out after 30 seconds without an SDK callback."
      )
      self.emit(request: session.request, kind: .failed, diagnostic: failure)
      let completion = session.loadCompletion
      session.ad.delegate = nil
      self.inserts.removeValue(forKey: session.request.placement)
      completion?.complete(
        generation: session.request.generation,
        result: .failure(failure.asPigeonError())
      )
    }
    session.loadTimeout = loadTimeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadTimeout, execute: loadTimeout)
  }

  private func completeInsertLoadIfReady(_ ad: BUNativeExpressFullscreenVideoAd) {
    guard let session = insertSession(for: ad), session.state == .loading else { return }
    guard ad.mediation?.isReady == true else { return }
    cancelLoadTimeout(session)
    session.state = .ready
    emit(request: session.request, kind: .loaded)
    session.loadCompletion?.complete(
      generation: session.request.generation,
      result: .success(())
    )
  }

  private func showInsert(
    identity: NativeAdIdentity,
    presenter: UIViewController,
    completion: @escaping (Result<NativeShowResult, Error>) -> Void
  ) {
    guard let session = inserts[identity.placement],
      session.request.generation == identity.generation,
      session.state == .ready,
      session.ad.mediation?.isReady == true
    else {
      completion(.failure(pigeonError("notReady", "Insert ad is not ready.")))
      return
    }
    guard let presentingWindow = presenter.viewIfLoaded?.window else {
      completion(
        .failure(
          pigeonError(
            "presenterUnavailable",
            "The active iOS presenter is not attached to a window."
          )))
      return
    }
    let presentationWindow = IOSAdPresentationWindow(presentingWindow: presentingWindow)
    session.presentationWindow = presentationWindow
    session.state = .showing
    session.showCompletion = PendingReply(
      generation: session.request.generation,
      completion: completion
    )
    guard session.ad.show(fromRootViewController: presentationWindow.presenter) else {
      finishInsert(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore rejected the insert presentation request."
          )),
        emitFailure: true
      )
      return
    }
    scheduleInsertShowWatchdogs(session)
  }

  private func requestGate() -> PigeonError? {
    if disposed { return pigeonError("disposed", "The native plugin is disposed.") }
    if !consent.accepted {
      return pigeonError("consentRequired", "Consent is required.")
    }
    if !initialized || BUAdSDKManager.state != .start {
      return pigeonError("invalidState", "GroMore is not initialized and ready.")
    }
    return nil
  }

  private func rewardSession(for ad: BUNativeExpressRewardedVideoAd) -> IOSRewardSession? {
    rewards.values.first { $0.ad === ad }
  }

  private func insertSession(for ad: BUNativeExpressFullscreenVideoAd) -> IOSInsertSession? {
    inserts.values.first { $0.ad === ad }
  }

  private func finishReward(
    _ session: IOSRewardSession,
    result: Result<NativeShowResult, Error>,
    emitFailure: Bool
  ) {
    guard rewards[session.request.placement] === session, !session.finishing else { return }
    session.finishing = true
    cancelWatchdogs(session)
    let finalize = { [weak self, weak session] in
      guard let self, let session,
        self.rewards[session.request.placement] === session
      else { return }
      session.presentationWindow = nil
      session.ad.delegate = nil
      self.rewards.removeValue(forKey: session.request.placement)
      if emitFailure, case .failure(let error) = result {
        self.emit(
          request: session.request,
          kind: .failed,
          diagnostic: diagnostic("nativeShowFailed", error.localizedDescription, error: error)
        )
      } else if case .success = result {
        self.emit(request: session.request, kind: .closed)
      }
      session.showCompletion?.complete(
        generation: session.request.generation,
        result: result
      )
      session.showCompletion = nil
      session.loadCompletion = nil
    }
    if let presentationWindow = session.presentationWindow {
      presentationWindow.finish(completion: finalize)
    } else {
      DispatchQueue.main.async(execute: finalize)
    }
  }

  private func finishInsert(
    _ session: IOSInsertSession,
    result: Result<NativeShowResult, Error>,
    emitFailure: Bool
  ) {
    guard inserts[session.request.placement] === session, !session.finishing else { return }
    session.finishing = true
    cancelWatchdogs(session)
    let finalize = { [weak self, weak session] in
      guard let self, let session,
        self.inserts[session.request.placement] === session
      else { return }
      session.presentationWindow = nil
      session.ad.delegate = nil
      self.inserts.removeValue(forKey: session.request.placement)
      if emitFailure, case .failure(let error) = result {
        self.emit(
          request: session.request,
          kind: .failed,
          diagnostic: diagnostic("nativeShowFailed", error.localizedDescription, error: error)
        )
      } else if case .success = result {
        self.emit(request: session.request, kind: .closed)
      }
      session.showCompletion?.complete(
        generation: session.request.generation,
        result: result
      )
      session.showCompletion = nil
      session.loadCompletion = nil
    }
    if let presentationWindow = session.presentationWindow {
      presentationWindow.finish(completion: finalize)
    } else {
      DispatchQueue.main.async(execute: finalize)
    }
  }

  private func invalidateAll(reason: String, normalizedCode: String = "consentRequired") {
    for session in Array(rewards.values) {
      cancelWatchdogs(session)
      session.presentationWindow?.forceCleanup()
      session.presentationWindow = nil
      let error = pigeonError(normalizedCode, reason)
      emit(
        request: session.request,
        kind: .failed,
        diagnostic: diagnostic(normalizedCode, reason)
      )
      session.loadCompletion?.complete(
        generation: session.request.generation,
        result: .failure(error)
      )
      session.showCompletion?.complete(
        generation: session.request.generation,
        result: .failure(error)
      )
      session.ad.delegate = nil
    }
    rewards.removeAll()
    for session in Array(inserts.values) {
      cancelWatchdogs(session)
      session.presentationWindow?.forceCleanup()
      session.presentationWindow = nil
      let error = pigeonError(normalizedCode, reason)
      emit(
        request: session.request,
        kind: .failed,
        diagnostic: diagnostic(normalizedCode, reason)
      )
      session.loadCompletion?.complete(
        generation: session.request.generation,
        result: .failure(error)
      )
      session.showCompletion?.complete(
        generation: session.request.generation,
        result: .failure(error)
      )
      session.ad.delegate = nil
    }
    inserts.removeAll()
  }

  private func cancelLoadTimeout(_ session: IOSRewardSession) {
    session.loadTimeout?.cancel()
    session.loadTimeout = nil
  }

  private func cancelLoadTimeout(_ session: IOSInsertSession) {
    session.loadTimeout?.cancel()
    session.loadTimeout = nil
  }

  private func cancelPresentationTimeout(_ session: IOSRewardSession) {
    session.presentationTimeout?.cancel()
    session.presentationTimeout = nil
  }

  private func cancelPresentationTimeout(_ session: IOSInsertSession) {
    session.presentationTimeout?.cancel()
    session.presentationTimeout = nil
  }

  private func cancelWatchdogs(_ session: IOSRewardSession) {
    cancelLoadTimeout(session)
    cancelPresentationTimeout(session)
    session.terminalTimeout?.cancel()
    session.terminalTimeout = nil
  }

  private func cancelWatchdogs(_ session: IOSInsertSession) {
    cancelLoadTimeout(session)
    cancelPresentationTimeout(session)
    session.terminalTimeout?.cancel()
    session.terminalTimeout = nil
  }

  private func emit(
    request: NativeAdRequest,
    kind: NativeEventKind,
    diagnostic: NativeDiagnostic? = nil,
    reward: NativeRewardResult? = nil,
    revenue: NativeRevenue? = nil
  ) {
    let event = NativeAdEvent(
      kind: kind,
      placement: request.placement,
      adType: request.adType,
      generation: request.generation,
      error: diagnostic,
      reward: reward,
      revenue: revenue
    )
    let send = { [flutterApi] in
      flutterApi.onEvent(event: event) { _ in }
    }
    if Thread.isMainThread { send() } else { DispatchQueue.main.async(execute: send) }
  }

  private func emitRevenue(request: NativeAdRequest, info: BUMRitInfo?) {
    guard let info else { return }
    emit(
      request: request,
      kind: .revenue,
      revenue: NativeRevenue(
        networkName: info.adnName,
        networkPlacementId: info.slotID,
        rawEcpm: info.ecpm,
        requestId: info.requestID
      )
    )
  }

  private func emitRewardRevenueOnce(_ session: IOSRewardSession) {
    guard !session.revenueEmitted else { return }
    session.revenueEmitted = true
    emitRevenue(request: session.request, info: session.ad.mediation?.getShowEcpmInfo())
  }

  private func emitInsertRevenueOnce(_ session: IOSInsertSession) {
    guard !session.revenueEmitted else { return }
    session.revenueEmitted = true
    emitRevenue(request: session.request, info: session.ad.mediation?.getShowEcpmInfo())
  }

  private func emitRewardOnce(_ session: IOSRewardSession) {
    guard !session.rewardEmitted else { return }
    session.rewardEmitted = true
    emit(request: session.request, kind: .rewarded, reward: session.reward)
  }

  private func scheduleRewardShowWatchdogs(_ session: IOSRewardSession) {
    let presentationTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.rewards[session.request.placement] === session,
        session.state == .showing,
        !session.presented
      else { return }
      self.finishReward(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore reward presentation did not reach DidVisible within 10 seconds."
          )),
        emitFailure: true
      )
    }
    let terminalTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.rewards[session.request.placement] === session,
        session.state == .showing
      else { return }
      self.finishReward(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore reward presentation did not reach a terminal callback before the safety deadline."
          )),
        emitFailure: true
      )
    }
    session.presentationTimeout = presentationTimeout
    session.terminalTimeout = terminalTimeout
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.presentationTimeout,
      execute: presentationTimeout
    )
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.showTerminalTimeout,
      execute: terminalTimeout
    )
  }

  private func scheduleInsertShowWatchdogs(_ session: IOSInsertSession) {
    let presentationTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.inserts[session.request.placement] === session,
        session.state == .showing,
        !session.presented
      else { return }
      self.finishInsert(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore insert presentation did not reach DidVisible within 10 seconds."
          )),
        emitFailure: true
      )
    }
    let terminalTimeout = DispatchWorkItem { [weak self, weak session] in
      guard let self, let session,
        self.inserts[session.request.placement] === session,
        session.state == .showing
      else { return }
      self.finishInsert(
        session,
        result: .failure(
          pigeonError(
            "nativeShowFailed",
            "GroMore insert presentation did not reach a terminal callback before the safety deadline."
          )),
        emitFailure: true
      )
    }
    session.presentationTimeout = presentationTimeout
    session.terminalTimeout = terminalTimeout
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.presentationTimeout,
      execute: presentationTimeout
    )
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.showTerminalTimeout,
      execute: terminalTimeout
    )
  }

  // MARK: Reward delegate

  func nativeExpressRewardedVideoAdDidLoad(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd
  ) {
    completeRewardLoadIfReady(rewardedVideoAd)
  }

  func nativeExpressRewardedVideoAdDidDownLoadVideo(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd
  ) {
    completeRewardLoadIfReady(rewardedVideoAd)
  }

  func nativeExpressRewardedVideoAd(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd,
    didFailWithError error: Error?
  ) {
    guard let session = rewardSession(for: rewardedVideoAd) else { return }
    let failure = diagnostic(
      "nativeLoadFailed",
      error?.localizedDescription ?? "GroMore reward load failed.",
      error: error
    )
    cancelWatchdogs(session)
    emit(request: session.request, kind: .failed, diagnostic: failure)
    session.loadCompletion?.complete(
      generation: session.request.generation,
      result: .failure(failure.asPigeonError())
    )
    session.loadCompletion = nil
    session.ad.delegate = nil
    rewards.removeValue(forKey: session.request.placement)
  }

  func nativeExpressRewardedVideoAdDidVisible(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd
  ) {
    guard let session = rewardSession(for: rewardedVideoAd) else { return }
    cancelPresentationTimeout(session)
    session.presented = true
    emit(request: session.request, kind: .shown)
    emitRewardRevenueOnce(session)
  }

  func nativeExpressRewardedVideoAdDidClick(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd
  ) {
    guard let session = rewardSession(for: rewardedVideoAd), session.state == .showing else {
      return
    }
    emit(request: session.request, kind: .clicked)
  }

  func nativeExpressRewardedVideoAdServerRewardDidSucceed(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd,
    verify: Bool
  ) {
    guard let session = rewardSession(for: rewardedVideoAd), session.state == .showing else {
      return
    }
    let model = rewardedVideoAd.rewardedVideoModel
    session.reward = NativeRewardResult(
      rewarded: verify,
      verified: verify,
      rewardName: model.rewardName,
      rewardAmount: Int64(model.rewardAmount)
    )
    emitRewardOnce(session)
  }

  func nativeExpressRewardedVideoAdServerRewardDidFail(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd,
    error: Error?
  ) {
    guard let session = rewardSession(for: rewardedVideoAd), session.state == .showing else {
      return
    }
    session.reward = NativeRewardResult(
      rewarded: false,
      verified: false,
      rewardName: rewardedVideoAd.rewardedVideoModel.rewardName,
      rewardAmount: nil
    )
    emitRewardOnce(session)
  }

  func nativeExpressRewardedVideoAdDidShowFailed(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd,
    error: Error
  ) {
    guard let session = rewardSession(for: rewardedVideoAd), session.state == .showing else {
      return
    }
    finishReward(
      session,
      result: .failure(
        pigeonError(
          "nativeShowFailed",
          error.localizedDescription,
          error: error
        )),
      emitFailure: true
    )
  }

  func nativeExpressRewardedVideoAdDidClose(
    _ rewardedVideoAd: BUNativeExpressRewardedVideoAd
  ) {
    guard let session = rewardSession(for: rewardedVideoAd), session.state == .showing else {
      return
    }
    finishReward(
      session, result: .success(NativeShowResult(reward: session.reward)), emitFailure: false)
  }

  // MARK: Insert delegate

  func nativeExpressFullscreenVideoAdDidLoad(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd
  ) {
    completeInsertLoadIfReady(fullscreenVideoAd)
  }

  func nativeExpressFullscreenVideoAdDidDownLoadVideo(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd
  ) {
    completeInsertLoadIfReady(fullscreenVideoAd)
  }

  func nativeExpressFullscreenVideoAd(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd,
    didFailWithError error: Error?
  ) {
    guard let session = insertSession(for: fullscreenVideoAd) else { return }
    let failure = diagnostic(
      "nativeLoadFailed",
      error?.localizedDescription ?? "GroMore insert load failed.",
      error: error
    )
    cancelWatchdogs(session)
    emit(request: session.request, kind: .failed, diagnostic: failure)
    session.loadCompletion?.complete(
      generation: session.request.generation,
      result: .failure(failure.asPigeonError())
    )
    session.loadCompletion = nil
    session.ad.delegate = nil
    inserts.removeValue(forKey: session.request.placement)
  }

  func nativeExpressFullscreenVideoAdDidVisible(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd
  ) {
    guard let session = insertSession(for: fullscreenVideoAd), session.state == .showing else {
      return
    }
    cancelPresentationTimeout(session)
    session.presented = true
    emit(request: session.request, kind: .shown)
    emitInsertRevenueOnce(session)
  }

  func nativeExpressFullscreenVideoAdDidClick(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd
  ) {
    guard let session = insertSession(for: fullscreenVideoAd), session.state == .showing else {
      return
    }
    emit(request: session.request, kind: .clicked)
  }

  func nativeExpressFullscreenVideoAdDidShowFailed(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd,
    error: Error
  ) {
    guard let session = insertSession(for: fullscreenVideoAd) else { return }
    finishInsert(
      session,
      result: .failure(
        pigeonError(
          "nativeShowFailed",
          error.localizedDescription,
          error: error
        )),
      emitFailure: true
    )
  }

  func nativeExpressFullscreenVideoAdDidClose(
    _ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd
  ) {
    guard let session = insertSession(for: fullscreenVideoAd), session.state == .showing else {
      return
    }
    finishInsert(session, result: .success(NativeShowResult()), emitFailure: false)
  }
}

extension IOSGroMoreHost {
  fileprivate func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let arguments = methodArguments(call),
        let appID = arguments["appId"] as? String,
        let consent = decodeConsent(arguments["consent"]),
        let access = decodeAccess(arguments["access"]),
        let debugLogging = arguments["debugLogging"] as? Bool
      else {
        result(invalidMethodArguments(call.method))
        return
      }
      initialize(
        request: NativeInitializationRequest(
          appId: appID,
          consent: consent,
          access: access,
          debugLogging: debugLogging
        )
      ) { completeMethodVoid($0, result: result) }
    case "updatePrivacy":
      guard let arguments = methodArguments(call),
        let consent = decodeConsent(arguments["consent"]),
        let access = decodeAccess(arguments["access"])
      else {
        result(invalidMethodArguments(call.method))
        return
      }
      updatePrivacy(request: NativePrivacyUpdate(consent: consent, access: access)) {
        completeMethodVoid($0, result: result)
      }
    case "loadAd":
      guard let arguments = methodArguments(call),
        let request = decodeAdRequest(arguments)
      else {
        result(invalidMethodArguments(call.method))
        return
      }
      loadAd(request: request) { completeMethodVoid($0, result: result) }
    case "isReady":
      guard let arguments = methodArguments(call),
        let identity = decodeAdIdentity(arguments)
      else {
        result(invalidMethodArguments(call.method))
        return
      }
      isReady(identity: identity) { completion in
        completeMethod(completion, result: result) { $0 }
      }
    case "showAd":
      guard let arguments = methodArguments(call),
        let identity = decodeAdIdentity(arguments)
      else {
        result(invalidMethodArguments(call.method))
        return
      }
      showAd(identity: identity) { completion in
        completeMethod(completion, result: result) { showResult in
          var encoded: [String: Any?] = ["reward": nil]
          if let reward = showResult.reward {
            encoded["reward"] = [
              "rewarded": reward.rewarded,
              "verified": reward.verified,
              "rewardName": reward.rewardName,
              "rewardAmount": reward.rewardAmount,
            ]
          }
          return encoded
        }
      }
    case "dispose":
      dispose { completeMethodVoid($0, result: result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private func methodArguments(_ call: FlutterMethodCall) -> [String: Any]? {
  call.arguments as? [String: Any]
}

private func decodeConsent(_ value: Any?) -> NativeConsent? {
  guard let map = value as? [String: Any],
    let accepted = map["accepted"] as? Bool,
    let personalizedAds = map["personalizedAds"] as? Bool
  else { return nil }
  return NativeConsent(accepted: accepted, personalizedAds: personalizedAds)
}

private func decodeAccess(_ value: Any?) -> NativeAccess? {
  guard let map = value as? [String: Any],
    let canUseLocation = map["canUseLocation"] as? Bool,
    let canUsePhoneState = map["canUsePhoneState"] as? Bool,
    let canUseWifiState = map["canUseWifiState"] as? Bool,
    let canUseWriteExternalStorage = map["canUseWriteExternalStorage"] as? Bool,
    let canUseOaid = map["canUseOaid"] as? Bool,
    let canUseAndroidId = map["canUseAndroidId"] as? Bool,
    let canUseInstalledApps = map["canUseInstalledApps"] as? Bool,
    let canUseRecordAudio = map["canUseRecordAudio"] as? Bool,
    let canUseIdfa = map["canUseIdfa"] as? Bool,
    let canUploadDeviceInfo = map["canUploadDeviceInfo"] as? Bool
  else { return nil }
  return NativeAccess(
    canUseLocation: canUseLocation,
    canUsePhoneState: canUsePhoneState,
    canUseWifiState: canUseWifiState,
    canUseWriteExternalStorage: canUseWriteExternalStorage,
    canUseOaid: canUseOaid,
    canUseAndroidId: canUseAndroidId,
    canUseInstalledApps: canUseInstalledApps,
    canUseRecordAudio: canUseRecordAudio,
    canUseIdfa: canUseIdfa,
    canUploadDeviceInfo: canUploadDeviceInfo
  )
}

private func decodeAdType(_ value: Any?) -> NativeAdType? {
  switch value as? String {
  case "reward": return .reward
  case "insert": return .insert
  default: return nil
  }
}

private func decodeAdIdentity(_ map: [String: Any]) -> NativeAdIdentity? {
  guard let placement = map["placement"] as? String,
    let adType = decodeAdType(map["adType"]),
    let generation = (map["generation"] as? NSNumber)?.int64Value
  else { return nil }
  return NativeAdIdentity(placement: placement, adType: adType, generation: generation)
}

private func decodeAdRequest(_ map: [String: Any]) -> NativeAdRequest? {
  guard let identity = decodeAdIdentity(map),
    let codeID = map["codeId"] as? String
  else { return nil }

  var options: NativeRewardOptions?
  if let value = map["rewardOptions"], !(value is NSNull) {
    guard let optionMap = value as? [String: Any] else { return nil }
    options = NativeRewardOptions(
      userId: nullableString(optionMap["userId"]),
      rewardName: nullableString(optionMap["rewardName"]),
      rewardAmount: (optionMap["rewardAmount"] as? NSNumber)?.int64Value,
      customData: nullableString(optionMap["customData"])
    )
  }
  return NativeAdRequest(
    placement: identity.placement,
    adType: identity.adType,
    codeId: codeID,
    generation: identity.generation,
    rewardOptions: options
  )
}

private func nullableString(_ value: Any?) -> String? {
  value is NSNull ? nil : value as? String
}

private func invalidMethodArguments(_ method: String) -> FlutterError {
  FlutterError(
    code: "configurationInvalid",
    message: "Invalid arguments for GroMore method \(method).",
    details: nil
  )
}

private func completeMethodVoid(
  _ completion: Result<Void, Error>,
  result: @escaping FlutterResult
) {
  completeMethod(completion, result: result) { _ in nil }
}

private func completeMethod<T>(
  _ completion: Result<T, Error>,
  result: @escaping FlutterResult,
  encode: (T) -> Any?
) {
  switch completion {
  case .success(let value):
    result(encode(value))
  case .failure(let error):
    if let error = error as? PigeonError {
      result(FlutterError(code: error.code, message: error.message, details: error.details))
    } else {
      let native = error as NSError
      result(
        FlutterError(
          code: "nativeError",
          message: native.localizedDescription,
          details: ["nativeCode": String(native.code), "nativeDomain": native.domain]
        ))
    }
  }
}

private func activePresenter() -> UIViewController? {
  let activeScenes = UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .filter { $0.activationState == .foregroundActive }
  guard activeScenes.count == 1, let scene = activeScenes.first else { return nil }
  let window =
    scene.windows.first(where: \.isKeyWindow)
    ?? scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 })
  guard var presenter = window?.rootViewController else { return nil }
  while true {
    if let presented = presenter.presentedViewController, !presented.isBeingDismissed {
      presenter = presented
    } else if let navigation = presenter as? UINavigationController,
      let visible = navigation.visibleViewController
    {
      presenter = visible
    } else if let tab = presenter as? UITabBarController,
      let selected = tab.selectedViewController
    {
      presenter = selected
    } else {
      break
    }
  }
  guard presenter.viewIfLoaded?.window != nil,
    !presenter.isBeingDismissed,
    !presenter.isBeingPresented
  else { return nil }
  return presenter
}

private func diagnostic(
  _ normalizedCode: String,
  _ message: String,
  error: Error? = nil
) -> NativeDiagnostic {
  let nsError = error as NSError?
  var details: [String: String] = [:]
  if let userInfo = nsError?.userInfo {
    for (key, value) in userInfo {
      if value is NSString || value is NSNumber {
        details[String(describing: key)] = String(describing: value)
      }
    }
  }
  return NativeDiagnostic(
    normalizedCode: normalizedCode,
    message: message,
    nativeCode: nsError.map { String($0.code) },
    nativeDomain: nsError?.domain,
    nativeMessage: nsError?.localizedDescription,
    details: details
  )
}

private func pigeonError(
  _ code: String,
  _ message: String,
  error: Error? = nil
) -> PigeonError {
  let native = diagnostic(code, message, error: error)
  var details = native.details
  if let nativeCode = native.nativeCode { details["nativeCode"] = nativeCode }
  if let nativeDomain = native.nativeDomain { details["nativeDomain"] = nativeDomain }
  if let nativeMessage = native.nativeMessage { details["nativeMessage"] = nativeMessage }
  return PigeonError(code: code, message: message, details: details)
}

extension NativeDiagnostic {
  fileprivate func asPigeonError() -> PigeonError {
    var merged = details
    if let nativeCode { merged["nativeCode"] = nativeCode }
    if let nativeDomain { merged["nativeDomain"] = nativeDomain }
    if let nativeMessage { merged["nativeMessage"] = nativeMessage }
    return PigeonError(code: normalizedCode, message: message, details: merged)
  }
}

private func deniedAccess() -> NativeAccess {
  NativeAccess(
    canUseLocation: false,
    canUsePhoneState: false,
    canUseWifiState: false,
    canUseWriteExternalStorage: false,
    canUseOaid: false,
    canUseAndroidId: false,
    canUseInstalledApps: false,
    canUseRecordAudio: false,
    canUseIdfa: false,
    canUploadDeviceInfo: false
  )
}
