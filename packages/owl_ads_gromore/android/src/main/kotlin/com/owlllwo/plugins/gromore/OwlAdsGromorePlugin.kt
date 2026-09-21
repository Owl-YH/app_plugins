@file:Suppress("OVERRIDE_DEPRECATION")

package com.owlllwo.plugins.gromore

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTCustomController
import com.bytedance.sdk.openadsdk.TTFullScreenVideoAd
import com.bytedance.sdk.openadsdk.TTRewardVideoAd
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

/** Flutter V2 entry point. Activity references are retained only while attached. */
class OwlAdsGromorePlugin : FlutterPlugin, ActivityAware {
    private var host: AndroidGroMoreHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val handler = AndroidGroMoreHost(
            applicationContext = binding.applicationContext,
            messenger = binding.binaryMessenger,
        )
        host = handler
        GroMoreHostApi.setUp(binding.binaryMessenger, handler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        GroMoreHostApi.setUp(binding.binaryMessenger, null)
        host?.disposeFromEngineDetach()
        host = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        host?.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        host?.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        host?.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        host?.activity = null
    }
}

private enum class SessionState { LOADING, READY, SHOWING }

private data class RewardSession(
    val request: NativeAdRequest,
    var state: SessionState = SessionState.LOADING,
    var ad: TTRewardVideoAd? = null,
    var loadCallback: PendingReply<Unit>? = null,
    var showCallback: PendingReply<NativeShowResult>? = null,
    var reward: NativeRewardResult = NativeRewardResult(false, false),
    var legacyReward: NativeRewardResult? = null,
    var rewardEmitted: Boolean = false,
    var revenueEmitted: Boolean = false,
    var presented: Boolean = false,
    var loadTimeout: Runnable? = null,
    var presentationTimeout: Runnable? = null,
    var terminalTimeout: Runnable? = null,
)

private data class InsertSession(
    val request: NativeAdRequest,
    var state: SessionState = SessionState.LOADING,
    var ad: TTFullScreenVideoAd? = null,
    var loadCallback: PendingReply<Unit>? = null,
    var showCallback: PendingReply<NativeShowResult>? = null,
    var revenueEmitted: Boolean = false,
    var presented: Boolean = false,
    var loadTimeout: Runnable? = null,
    var presentationTimeout: Runnable? = null,
    var terminalTimeout: Runnable? = null,
)

private class AndroidPrivacyController(
    private val consent: () -> NativeConsent,
    private val access: () -> NativeAccess,
) : TTCustomController() {
    override fun isCanUseLocation(): Boolean = access().canUseLocation

    override fun alist(): Boolean = access().canUseInstalledApps

    override fun isCanUsePhoneState(): Boolean = access().canUsePhoneState

    override fun getDevImei(): String? = if (access().canUsePhoneState) null else ""

    override fun isCanUseWifiState(): Boolean = access().canUseWifiState

    override fun getMacAddress(): String? = if (access().canUseWifiState) null else ""

    override fun isCanUseWriteExternal(): Boolean = access().canUseWriteExternalStorage

    override fun getDevOaid(): String? = if (access().canUseOaid) null else ""

    override fun isCanUseAndroidId(): Boolean = access().canUseAndroidId

    override fun getAndroidId(): String? = if (access().canUseAndroidId) null else ""

    override fun isCanUsePermissionRecordAudio(): Boolean = access().canUseRecordAudio

    override fun isCanUseMessage(): Boolean = false

    override fun getMediationPrivacyConfig(): MediationPrivacyConfig =
        object : MediationPrivacyConfig() {
            override fun isCanUseOaid(): Boolean = access().canUseOaid

            override fun isLimitPersonalAds(): Boolean = !consent().personalizedAds

            override fun isProgrammaticRecommend(): Boolean = consent().personalizedAds
        }
}

private data class AndroidInitializationFingerprint(
    val appId: String,
    val debugLogging: Boolean,
    val access: NativeAccess,
)

/** Owns only process-wide SDK initialization and privacy state. */
private object AndroidGroMoreProcess {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val coordinator =
        InitializationCoordinatorState<Any, AndroidInitializationFingerprint>()
    private val waiters = linkedMapOf<Any, (Result<Unit>) -> Unit>()
    private val ownerAttempts = mutableMapOf<Any, Long>()
    private var consent = NativeConsent(false, false)
    private var access = deniedAccess()

    val privacyController = AndroidPrivacyController({ consent }, { access })

    fun updatePrivacy(newConsent: NativeConsent, newAccess: NativeAccess) {
        consent = newConsent
        access = newAccess
    }

    fun initialize(
        owner: Any,
        requestedFingerprint: AndroidInitializationFingerprint,
        requestedConsent: NativeConsent,
        requestedAccess: NativeAccess,
        context: Context,
        config: TTAdConfig,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post {
                initialize(
                    owner,
                    requestedFingerprint,
                    requestedConsent,
                    requestedAccess,
                    context,
                    config,
                    callback,
                )
            }
            return
        }
        when (
            val decision = coordinator.request(
                owner = owner,
                requestedFingerprint = requestedFingerprint,
                sdkReady = TTAdSdk.isSdkReady(),
            )
        ) {
            InitializationCoordinatorState.RequestDecision.Complete -> {
                updatePrivacy(requestedConsent, requestedAccess)
                callback(Result.success(Unit))
                return
            }

            InitializationCoordinatorState.RequestDecision.Conflict -> {
                callback(
                    Result.failure(
                        FlutterError(
                            "configurationConflict",
                            "GroMore is starting or initialized with another process configuration.",
                        ),
                    ),
                )
                return
            }

            InitializationCoordinatorState.RequestDecision.RestartRequired -> {
                callback(
                    Result.failure(
                        FlutterError(
                            "restartRequired",
                            "GroMore initialization previously timed out and the SDK is still not ready.",
                        ),
                    ),
                )
                return
            }

            is InitializationCoordinatorState.RequestDecision.Wait -> {
                updatePrivacy(requestedConsent, requestedAccess)
                waiters[owner] = callback
                ownerAttempts[owner] = decision.attemptId
                return
            }

            is InitializationCoordinatorState.RequestDecision.Start -> {
                updatePrivacy(requestedConsent, requestedAccess)
                waiters[owner] = callback
                ownerAttempts[owner] = decision.attemptId
                startSdk(
                    attemptId = decision.attemptId,
                    context = context,
                    config = config,
                )
            }
        }
    }

    private fun startSdk(attemptId: Long, context: Context, config: TTAdConfig) {
        try {
            TTAdSdk.init(context.applicationContext, config)
            TTAdSdk.start(
                object : TTAdSdk.Callback {
                    override fun success() {
                        mainHandler.post {
                            val ready = TTAdSdk.isSdkReady()
                            val owners = if (ready) {
                                coordinator.nativeSucceeded(attemptId)
                            } else {
                                coordinator.nativeFailed(attemptId)
                            }
                            if (owners == null) return@post
                            val result = if (ready) {
                                Result.success(Unit)
                            } else {
                                Result.failure(
                                    FlutterError(
                                        "initializationFailed",
                                        "GroMore start callback succeeded but the SDK is not ready.",
                                    ),
                                )
                            }
                            completeWaiters(owners, result)
                        }
                    }

                    override fun fail(code: Int, message: String?) {
                        mainHandler.post {
                            val owners = coordinator.nativeFailed(attemptId) ?: return@post
                            completeWaiters(
                                owners,
                                Result.failure(
                                    diagnostic(
                                        "initializationFailed",
                                        message ?: "GroMore initialization failed.",
                                        code,
                                    ).asFlutterError(),
                                ),
                            )
                        }
                    }
                },
            )
        } catch (error: Throwable) {
            val owners = coordinator.nativeFailed(attemptId) ?: return
            completeWaiters(
                owners,
                Result.failure(
                    diagnostic(
                        "initializationFailed",
                        error.message ?: "GroMore initialization threw an exception.",
                        throwable = error,
                    ).asFlutterError(),
                ),
            )
        }
    }

    fun removeWaiter(owner: Any, result: Result<Unit>? = null) {
        val remove = {
            coordinator.remove(owner)
            ownerAttempts.remove(owner)
            val callback = waiters.remove(owner)
            if (result != null) callback?.invoke(result)
        }
        if (Looper.myLooper() == Looper.getMainLooper()) remove() else mainHandler.post(remove)
    }

    fun timeoutWaiter(owner: Any, result: Result<Unit>) {
        val timeout: () -> Unit = {
            val attemptId = ownerAttempts.remove(owner)
            if (attemptId != null) coordinator.timeout(owner, attemptId)
            val callback = waiters.remove(owner)
            callback?.invoke(result)
            Unit
        }
        if (Looper.myLooper() == Looper.getMainLooper()) timeout() else mainHandler.post(timeout)
    }

    private fun completeWaiters(owners: Set<Any>, result: Result<Unit>) {
        val callbacks = owners.mapNotNull { owner ->
            ownerAttempts.remove(owner)
            waiters.remove(owner)
        }
        callbacks.forEach { it(result) }
    }
}

private class AndroidGroMoreHost(
    private val applicationContext: Context,
    messenger: BinaryMessenger,
) : GroMoreHostApi {
    companion object {
        private const val INITIALIZATION_TIMEOUT_MILLIS = 30_000L
        private const val LOAD_TIMEOUT_MILLIS = 30_000L
        private const val PRESENTATION_TIMEOUT_MILLIS = 10_000L
        private const val SHOW_TERMINAL_TIMEOUT_MILLIS = 15 * 60_000L
    }

    private val flutterApi = GroMoreFlutterApi(messenger)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val processOwner = Any()
    private val rewards = mutableMapOf<String, RewardSession>()
    private val inserts = mutableMapOf<String, InsertSession>()

    var activity: Activity? = null

    private var initialized = false
    private var initializing = false
    private var disposed = false
    private var appId: String? = null
    private var debugLogging = false
    private var consent = NativeConsent(false, false)
    private var access = deniedAccess()
    private var adNative: TTAdNative? = null

    override fun initialize(
        request: NativeInitializationRequest,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (disposed) return callback.failure("disposed", "The native plugin is disposed.")
        if (!request.consent.accepted) {
            return callback.failure("consentRequired", "Consent is required before GroMore initialization.")
        }
        if (initialized && appId == request.appId && TTAdSdk.isSdkReady()) {
            if (access != request.access || debugLogging != request.debugLogging) {
                return callback.failure(
                    "configurationConflict",
                    "GroMore immutable process configuration cannot change after initialization.",
                )
            }
            consent = request.consent
            AndroidGroMoreProcess.updatePrivacy(consent, access)
            try {
                TTAdSdk.updateAdConfig(buildConfig(request.appId))
                callback(Result.success(Unit))
            } catch (error: Throwable) {
                callback.failure(
                    "restartRequired",
                    error.message ?: "GroMore could not apply the provider configuration at runtime.",
                    throwable = error,
                )
            }
            return
        }
        if (initializing) {
            return callback.failure("invalidState", "GroMore initialization is already in progress.")
        }

        initializing = true
        appId = request.appId
        consent = request.consent
        access = request.access
        debugLogging = request.debugLogging
        val config = buildConfig(request.appId)
        var initializationCompleted = false
        lateinit var initializationTimeout: Runnable
        fun completeInitialization(result: Result<Unit>) {
            if (initializationCompleted) return
            initializationCompleted = true
            mainHandler.removeCallbacks(initializationTimeout)
            callback(result)
        }
        initializationTimeout = Runnable {
            if (initializationCompleted) return@Runnable
            initializing = false
            AndroidGroMoreProcess.timeoutWaiter(
                processOwner,
                Result.failure(
                    diagnostic(
                        "initializationFailed",
                        "GroMore initialization timed out after 30 seconds without an SDK callback.",
                    ).asFlutterError(),
                ),
            )
        }
        mainHandler.postDelayed(initializationTimeout, INITIALIZATION_TIMEOUT_MILLIS)
        AndroidGroMoreProcess.initialize(
            owner = processOwner,
            requestedFingerprint = AndroidInitializationFingerprint(
                appId = request.appId,
                debugLogging = request.debugLogging,
                access = request.access,
            ),
            requestedConsent = request.consent,
            requestedAccess = request.access,
            context = applicationContext,
            config = config,
        ) processResult@{ result ->
            initializing = false
            if (result.isFailure) {
                completeInitialization(result)
                return@processResult
            }
            if (disposed) {
                completeInitialization(
                    Result.failure(FlutterError("disposed", "The native plugin was disposed during initialization.")),
                )
                return@processResult
            }
            initialized = true
            adNative = TTAdSdk.getAdManager().createAdNative(applicationContext)
            completeInitialization(Result.success(Unit))
        }
    }

    override fun updatePrivacy(
        request: NativePrivacyUpdate,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (disposed) return callback.failure("disposed", "The native plugin is disposed.")
        if (initialized && access != request.access) {
            return callback.failure(
                "restartRequired",
                "GroMore data-access settings require a process restart after initialization.",
            )
        }
        consent = request.consent
        access = request.access
        AndroidGroMoreProcess.updatePrivacy(consent, access)
        if (!request.consent.accepted) {
            invalidateAll("Consent was withdrawn.")
        }
        if (!initialized) {
            callback(Result.success(Unit))
            return
        }
        try {
            TTAdSdk.updateAdConfig(buildConfig(requireNotNull(appId)))
            callback(Result.success(Unit))
        } catch (error: Throwable) {
            callback.failure(
                "restartRequired",
                error.message ?: "GroMore could not apply the privacy update at runtime.",
                throwable = error,
            )
        }
    }

    override fun loadAd(request: NativeAdRequest, callback: (Result<Unit>) -> Unit) {
        val gate = requestGate()
        if (gate != null) return callback(Result.failure(gate))
        if (request.codeId.isBlank()) {
            return callback.failure("configurationInvalid", "GroMore Code ID must not be empty.")
        }
        when (request.adType) {
            NativeAdType.REWARD -> loadReward(request, callback)
            NativeAdType.INSERT -> loadInsert(request, callback)
        }
    }

    override fun isReady(identity: NativeAdIdentity, callback: (Result<Boolean>) -> Unit) {
        val gate = requestGate()
        if (gate != null) return callback(Result.failure(gate))
        val ready = when (identity.adType) {
            NativeAdType.REWARD -> rewards[key(identity.placement)]?.let { session ->
                session.request.generation == identity.generation &&
                    session.state == SessionState.READY &&
                    session.ad?.mediationManager?.isReady == true
            } ?: false
            NativeAdType.INSERT -> inserts[key(identity.placement)]?.let { session ->
                session.request.generation == identity.generation &&
                    session.state == SessionState.READY &&
                    session.ad?.mediationManager?.isReady == true
            } ?: false
        }
        callback(Result.success(ready))
    }

    override fun showAd(
        identity: NativeAdIdentity,
        callback: (Result<NativeShowResult>) -> Unit,
    ) {
        val gate = requestGate()
        if (gate != null) return callback(Result.failure(gate))
        val presenter = activity
        if (presenter == null || presenter.isFinishing || presenter.isDestroyed) {
            return callback.failure(
                "presenterUnavailable",
                "No attached, usable Android Activity is available.",
            )
        }
        when (identity.adType) {
            NativeAdType.REWARD -> showReward(identity, presenter, callback)
            NativeAdType.INSERT -> showInsert(identity, presenter, callback)
        }
    }

    override fun dispose(callback: (Result<Unit>) -> Unit) {
        if (disposed) {
            callback(Result.success(Unit))
            return
        }
        AndroidGroMoreProcess.removeWaiter(
            processOwner,
            Result.failure(FlutterError("disposed", "The Dart provider was disposed during initialization.")),
        )
        invalidateAll("The Dart provider was disposed.", "disposed")
        initializing = false
        initialized = false
        adNative = null
        callback(Result.success(Unit))
    }

    fun disposeFromEngineDetach() {
        if (disposed) return
        disposed = true
        AndroidGroMoreProcess.removeWaiter(
            processOwner,
            Result.failure(FlutterError("disposed", "The Flutter engine detached during initialization.")),
        )
        invalidateAll("The Flutter engine detached.", "disposed")
        activity = null
        adNative = null
    }

    private fun loadReward(request: NativeAdRequest, callback: (Result<Unit>) -> Unit) {
        val mapKey = key(request.placement)
        val current = rewards[mapKey]
        if (current != null) {
            when (current.state) {
                SessionState.LOADING -> return callback.failure("alreadyLoading", "Reward ad is already loading.")
                SessionState.READY -> return callback(Result.success(Unit))
                SessionState.SHOWING -> return callback.failure("invalidState", "Reward ad is showing.")
            }
        }
        val session = RewardSession(
            request = request,
            loadCallback = PendingReply(request.generation, callback),
        )
        rewards[mapKey] = session
        val builder = AdSlot.Builder().setCodeId(request.codeId).setAdCount(1)
        request.rewardOptions?.userId?.takeIf { it.isNotBlank() }?.let(builder::setUserID)
        request.rewardOptions?.rewardName?.takeIf { it.isNotBlank() }?.let(builder::setRewardName)
        request.rewardOptions?.rewardAmount?.let { builder.setRewardAmount(it.toInt()) }
        request.rewardOptions?.customData?.takeIf { it.isNotBlank() }?.let(builder::setMediaExtra)
        try {
            requireNotNull(adNative).loadRewardVideoAd(
                builder.build(),
                object : TTAdNative.RewardVideoAdListener {
                    override fun onError(code: Int, message: String?) {
                        if (!isCurrent(session)) return
                        val error = diagnostic(
                            "nativeLoadFailed",
                            message ?: "GroMore reward load failed.",
                            code,
                        )
                        emit(session.request, NativeEventKind.FAILED, error = error)
                        destroyReward(session)
                        session.loadCallback?.complete(
                            session.request.generation,
                            Result.failure(error.asFlutterError()),
                        )
                    }

                    override fun onRewardVideoAdLoad(ad: TTRewardVideoAd) {
                        if (!isCurrent(session)) {
                            ad.mediationManager?.destroy()
                            return
                        }
                        session.ad = ad
                        completeRewardLoadIfReady(session)
                    }

                    override fun onRewardVideoCached() {
                        completeRewardLoadIfReady(session)
                    }

                    override fun onRewardVideoCached(ad: TTRewardVideoAd) {
                        if (!isCurrent(session)) {
                            ad.mediationManager?.destroy()
                            return
                        }
                        session.ad = ad
                        completeRewardLoadIfReady(session)
                    }
                },
            )
            val loadTimeout = Runnable {
                if (!isCurrent(session) || session.state != SessionState.LOADING) {
                    return@Runnable
                }
                session.loadTimeout = null
                val error = diagnostic(
                    "nativeLoadFailed",
                    "GroMore reward load timed out after 30 seconds without an SDK callback.",
                )
                emit(session.request, NativeEventKind.FAILED, error = error)
                destroyReward(session)
                session.loadCallback?.complete(
                    session.request.generation,
                    Result.failure(error.asFlutterError()),
                )
            }
            session.loadTimeout = loadTimeout
            mainHandler.postDelayed(loadTimeout, LOAD_TIMEOUT_MILLIS)
        } catch (error: Throwable) {
            destroyReward(session)
            callback.failure(
                "nativeLoadFailed",
                error.message ?: "GroMore reward load threw an exception.",
                throwable = error,
            )
        }
    }

    private fun completeRewardLoadIfReady(session: RewardSession) {
        if (!isCurrent(session) || session.state != SessionState.LOADING) return
        if (session.ad?.mediationManager?.isReady != true) return
        cancelLoadTimeout(session)
        session.state = SessionState.READY
        emit(session.request, NativeEventKind.LOADED)
        session.loadCallback?.complete(session.request.generation, Result.success(Unit))
    }

    private fun showReward(
        identity: NativeAdIdentity,
        presenter: Activity,
        callback: (Result<NativeShowResult>) -> Unit,
    ) {
        val session = rewards[key(identity.placement)]
        val ad = session?.ad
        if (session == null ||
            session.request.generation != identity.generation ||
            session.state != SessionState.READY ||
            ad == null ||
            ad.mediationManager?.isReady != true
        ) {
            return callback.failure("notReady", "Reward ad is not ready.")
        }
        session.state = SessionState.SHOWING
        session.showCallback = PendingReply(session.request.generation, callback)
        ad.setRewardAdInteractionListener(
            object : TTRewardVideoAd.RewardAdInteractionListener {
                override fun onAdShow() {
                    if (!isCurrent(session)) return
                    cancelPresentationTimeout(session)
                    session.presented = true
                    emit(session.request, NativeEventKind.SHOWN)
                    emitRewardRevenueOnce(session, ad.mediationManager?.showEcpm)
                }

                override fun onAdVideoBarClick() {
                    if (isCurrent(session)) emit(session.request, NativeEventKind.CLICKED)
                }

                override fun onAdClose() {
                    if (!isCurrent(session)) return
                    commitLegacyRewardIfNeeded(session)
                    emit(session.request, NativeEventKind.CLOSED)
                    val result = NativeShowResult(session.reward)
                    destroyReward(session)
                    session.showCallback?.complete(
                        session.request.generation,
                        Result.success(result),
                    )
                }

                override fun onVideoComplete() = Unit

                override fun onVideoError() {
                    if (!isCurrent(session)) return
                    val error = diagnostic(
                        "nativeShowFailed",
                        "GroMore reported a reward video playback error.",
                    )
                    emit(session.request, NativeEventKind.FAILED, error = error)
                    destroyReward(session)
                    session.showCallback?.complete(
                        session.request.generation,
                        Result.failure(error.asFlutterError()),
                    )
                }

                @Suppress("DEPRECATION")
                override fun onRewardVerify(
                    rewardVerify: Boolean,
                    rewardAmount: Int,
                    rewardName: String?,
                    errorCode: Int,
                    errorMessage: String?,
                ) {
                    if (!isCurrent(session)) return
                    session.legacyReward = NativeRewardResult(
                        rewarded = rewardVerify,
                        verified = rewardVerify,
                        rewardName = rewardName,
                        rewardAmount = rewardAmount.toLong(),
                    )
                }

                override fun onRewardArrived(
                    isRewardValid: Boolean,
                    rewardType: Int,
                    extraInfo: Bundle?,
                ) {
                    if (!isCurrent(session)) return
                    val amount = extraInfo.numberAsLong(TTRewardVideoAd.REWARD_EXTRA_KEY_REWARD_AMOUNT)
                    val name = extraInfo?.getString(TTRewardVideoAd.REWARD_EXTRA_KEY_REWARD_NAME)
                    session.reward = NativeRewardResult(
                        rewarded = isRewardValid,
                        verified = isRewardValid,
                        rewardName = name,
                        rewardAmount = amount,
                    )
                    emitRewardOnce(session)
                }

                override fun onSkippedVideo() = Unit
            },
        )
        try {
            ad.showRewardVideoAd(presenter)
            scheduleRewardShowWatchdogs(session)
        } catch (error: Throwable) {
            val failure = diagnostic(
                "nativeShowFailed",
                error.message ?: "GroMore reward presentation threw an exception.",
                throwable = error,
            )
            emit(session.request, NativeEventKind.FAILED, error = failure)
            destroyReward(session)
            session.showCallback?.complete(
                session.request.generation,
                Result.failure(failure.asFlutterError()),
            )
        }
    }

    private fun loadInsert(request: NativeAdRequest, callback: (Result<Unit>) -> Unit) {
        val mapKey = key(request.placement)
        val current = inserts[mapKey]
        if (current != null) {
            when (current.state) {
                SessionState.LOADING -> return callback.failure("alreadyLoading", "Insert ad is already loading.")
                SessionState.READY -> return callback(Result.success(Unit))
                SessionState.SHOWING -> return callback.failure("invalidState", "Insert ad is showing.")
            }
        }
        val session = InsertSession(
            request = request,
            loadCallback = PendingReply(request.generation, callback),
        )
        inserts[mapKey] = session
        val slot = AdSlot.Builder().setCodeId(request.codeId).setAdCount(1).build()
        try {
            requireNotNull(adNative).loadFullScreenVideoAd(
                slot,
                object : TTAdNative.FullScreenVideoAdListener {
                    override fun onError(code: Int, message: String?) {
                        if (!isCurrent(session)) return
                        val error = diagnostic(
                            "nativeLoadFailed",
                            message ?: "GroMore insert load failed.",
                            code,
                        )
                        emit(session.request, NativeEventKind.FAILED, error = error)
                        destroyInsert(session)
                        session.loadCallback?.complete(
                            session.request.generation,
                            Result.failure(error.asFlutterError()),
                        )
                    }

                    override fun onFullScreenVideoAdLoad(ad: TTFullScreenVideoAd) {
                        if (!isCurrent(session)) {
                            ad.mediationManager?.destroy()
                            return
                        }
                        session.ad = ad
                        completeInsertLoadIfReady(session)
                    }

                    override fun onFullScreenVideoCached() {
                        completeInsertLoadIfReady(session)
                    }

                    override fun onFullScreenVideoCached(ad: TTFullScreenVideoAd) {
                        if (!isCurrent(session)) {
                            ad.mediationManager?.destroy()
                            return
                        }
                        session.ad = ad
                        completeInsertLoadIfReady(session)
                    }
                },
            )
            val loadTimeout = Runnable {
                if (!isCurrent(session) || session.state != SessionState.LOADING) {
                    return@Runnable
                }
                session.loadTimeout = null
                val error = diagnostic(
                    "nativeLoadFailed",
                    "GroMore insert load timed out after 30 seconds without an SDK callback.",
                )
                emit(session.request, NativeEventKind.FAILED, error = error)
                destroyInsert(session)
                session.loadCallback?.complete(
                    session.request.generation,
                    Result.failure(error.asFlutterError()),
                )
            }
            session.loadTimeout = loadTimeout
            mainHandler.postDelayed(loadTimeout, LOAD_TIMEOUT_MILLIS)
        } catch (error: Throwable) {
            destroyInsert(session)
            callback.failure(
                "nativeLoadFailed",
                error.message ?: "GroMore insert load threw an exception.",
                throwable = error,
            )
        }
    }

    private fun completeInsertLoadIfReady(session: InsertSession) {
        if (!isCurrent(session) || session.state != SessionState.LOADING) return
        if (session.ad?.mediationManager?.isReady != true) return
        cancelLoadTimeout(session)
        session.state = SessionState.READY
        emit(session.request, NativeEventKind.LOADED)
        session.loadCallback?.complete(session.request.generation, Result.success(Unit))
    }

    private fun showInsert(
        identity: NativeAdIdentity,
        presenter: Activity,
        callback: (Result<NativeShowResult>) -> Unit,
    ) {
        val session = inserts[key(identity.placement)]
        val ad = session?.ad
        if (session == null ||
            session.request.generation != identity.generation ||
            session.state != SessionState.READY ||
            ad == null ||
            ad.mediationManager?.isReady != true
        ) {
            return callback.failure("notReady", "Insert ad is not ready.")
        }
        session.state = SessionState.SHOWING
        session.showCallback = PendingReply(session.request.generation, callback)
        ad.setFullScreenVideoAdInteractionListener(
            object : TTFullScreenVideoAd.FullScreenVideoAdInteractionListener {
                override fun onAdShow() {
                    if (!isCurrent(session)) return
                    cancelPresentationTimeout(session)
                    session.presented = true
                    emit(session.request, NativeEventKind.SHOWN)
                    emitInsertRevenueOnce(session, ad.mediationManager?.showEcpm)
                }

                override fun onAdVideoBarClick() {
                    if (isCurrent(session)) emit(session.request, NativeEventKind.CLICKED)
                }

                override fun onAdClose() {
                    if (!isCurrent(session)) return
                    emit(session.request, NativeEventKind.CLOSED)
                    destroyInsert(session)
                    session.showCallback?.complete(
                        session.request.generation,
                        Result.success(NativeShowResult()),
                    )
                }

                override fun onVideoComplete() = Unit

                override fun onSkippedVideo() = Unit
            },
        )
        try {
            ad.showFullScreenVideoAd(presenter)
            scheduleInsertShowWatchdogs(session)
        } catch (error: Throwable) {
            val failure = diagnostic(
                "nativeShowFailed",
                error.message ?: "GroMore insert presentation threw an exception.",
                throwable = error,
            )
            emit(session.request, NativeEventKind.FAILED, error = failure)
            destroyInsert(session)
            session.showCallback?.complete(
                session.request.generation,
                Result.failure(failure.asFlutterError()),
            )
        }
    }

    private fun requestGate(): FlutterError? {
        if (disposed) return FlutterError("disposed", "The native plugin is disposed.")
        if (!consent.accepted) return FlutterError("consentRequired", "Consent is required.")
        if (!initialized || !TTAdSdk.isSdkReady() || adNative == null) {
            return FlutterError("invalidState", "GroMore is not initialized and ready.")
        }
        return null
    }

    private fun buildConfig(configAppId: String): TTAdConfig =
        TTAdConfig.Builder()
            .appId(configAppId)
            .appName("owl_ads_gromore")
            .debug(debugLogging)
            .supportMultiProcess(false)
            .useMediation(true)
            .customController(AndroidGroMoreProcess.privacyController)
            .build()

    private fun emit(
        request: NativeAdRequest,
        kind: NativeEventKind,
        error: NativeDiagnostic? = null,
        reward: NativeRewardResult? = null,
        revenue: NativeRevenue? = null,
    ) {
        val event = NativeAdEvent(
            kind = kind,
            placement = request.placement,
            adType = request.adType,
            generation = request.generation,
            error = error,
            reward = reward,
            revenue = revenue,
        )
        if (Looper.myLooper() == Looper.getMainLooper()) {
            flutterApi.onEvent(event) { }
        } else {
            mainHandler.post { flutterApi.onEvent(event) { } }
        }
    }

    private fun emitRevenue(request: NativeAdRequest, ecpm: MediationAdEcpmInfo?) {
        if (ecpm == null) return
        emit(
            request,
            NativeEventKind.REVENUE,
            revenue = NativeRevenue(
                networkName = ecpm.sdkName,
                networkPlacementId = ecpm.slotId,
                rawEcpm = ecpm.ecpm,
                requestId = ecpm.requestId,
            ),
        )
    }

    private fun emitRewardRevenueOnce(session: RewardSession, ecpm: MediationAdEcpmInfo?) {
        if (session.revenueEmitted) return
        session.revenueEmitted = true
        emitRevenue(session.request, ecpm)
    }

    private fun emitInsertRevenueOnce(session: InsertSession, ecpm: MediationAdEcpmInfo?) {
        if (session.revenueEmitted) return
        session.revenueEmitted = true
        emitRevenue(session.request, ecpm)
    }

    private fun emitRewardOnce(session: RewardSession) {
        if (session.rewardEmitted) return
        session.rewardEmitted = true
        emit(session.request, NativeEventKind.REWARDED, reward = session.reward)
    }

    private fun commitLegacyRewardIfNeeded(session: RewardSession) {
        if (session.rewardEmitted) return
        val legacy = session.legacyReward ?: return
        session.reward = legacy
        emitRewardOnce(session)
    }

    private fun scheduleRewardShowWatchdogs(session: RewardSession) {
        val presentationTimeout = Runnable {
            if (!isCurrent(session) || session.state != SessionState.SHOWING || session.presented) return@Runnable
            session.presentationTimeout = null
            failRewardShow(session, "GroMore reward presentation did not reach onAdShow within 10 seconds.")
        }
        val terminalTimeout = Runnable {
            if (!isCurrent(session) || session.state != SessionState.SHOWING) return@Runnable
            session.terminalTimeout = null
            failRewardShow(session, "GroMore reward presentation did not reach a terminal callback before the safety deadline.")
        }
        session.presentationTimeout = presentationTimeout
        session.terminalTimeout = terminalTimeout
        mainHandler.postDelayed(presentationTimeout, PRESENTATION_TIMEOUT_MILLIS)
        mainHandler.postDelayed(terminalTimeout, SHOW_TERMINAL_TIMEOUT_MILLIS)
    }

    private fun scheduleInsertShowWatchdogs(session: InsertSession) {
        val presentationTimeout = Runnable {
            if (!isCurrent(session) || session.state != SessionState.SHOWING || session.presented) return@Runnable
            session.presentationTimeout = null
            failInsertShow(session, "GroMore insert presentation did not reach onAdShow within 10 seconds.")
        }
        val terminalTimeout = Runnable {
            if (!isCurrent(session) || session.state != SessionState.SHOWING) return@Runnable
            session.terminalTimeout = null
            failInsertShow(session, "GroMore insert presentation did not reach a terminal callback before the safety deadline.")
        }
        session.presentationTimeout = presentationTimeout
        session.terminalTimeout = terminalTimeout
        mainHandler.postDelayed(presentationTimeout, PRESENTATION_TIMEOUT_MILLIS)
        mainHandler.postDelayed(terminalTimeout, SHOW_TERMINAL_TIMEOUT_MILLIS)
    }

    private fun failRewardShow(session: RewardSession, message: String) {
        val error = diagnostic("nativeShowFailed", message)
        emit(session.request, NativeEventKind.FAILED, error = error)
        val completion = session.showCallback
        destroyReward(session)
        completion?.complete(
            session.request.generation,
            Result.failure(error.asFlutterError()),
        )
    }

    private fun failInsertShow(session: InsertSession, message: String) {
        val error = diagnostic("nativeShowFailed", message)
        emit(session.request, NativeEventKind.FAILED, error = error)
        val completion = session.showCallback
        destroyInsert(session)
        completion?.complete(
            session.request.generation,
            Result.failure(error.asFlutterError()),
        )
    }

    private fun invalidateAll(reason: String, normalizedCode: String = "consentRequired") {
        rewards.values.toList().forEach { session ->
            val error = diagnostic(normalizedCode, reason)
            emit(session.request, NativeEventKind.FAILED, error = error)
            session.loadCallback?.complete(
                session.request.generation,
                Result.failure(error.asFlutterError()),
            )
            session.showCallback?.complete(
                session.request.generation,
                Result.failure(error.asFlutterError()),
            )
            destroyReward(session)
        }
        inserts.values.toList().forEach { session ->
            val error = diagnostic(normalizedCode, reason)
            emit(session.request, NativeEventKind.FAILED, error = error)
            session.loadCallback?.complete(
                session.request.generation,
                Result.failure(error.asFlutterError()),
            )
            session.showCallback?.complete(
                session.request.generation,
                Result.failure(error.asFlutterError()),
            )
            destroyInsert(session)
        }
    }

    private fun destroyReward(session: RewardSession) {
        cancelWatchdogs(session)
        if (rewards[key(session.request.placement)] === session) {
            rewards.remove(key(session.request.placement))
        }
        session.ad?.mediationManager?.destroy()
        session.ad = null
    }

    private fun destroyInsert(session: InsertSession) {
        cancelWatchdogs(session)
        if (inserts[key(session.request.placement)] === session) {
            inserts.remove(key(session.request.placement))
        }
        session.ad?.mediationManager?.destroy()
        session.ad = null
    }

    private fun cancelLoadTimeout(session: RewardSession) {
        session.loadTimeout?.let(mainHandler::removeCallbacks)
        session.loadTimeout = null
    }

    private fun cancelLoadTimeout(session: InsertSession) {
        session.loadTimeout?.let(mainHandler::removeCallbacks)
        session.loadTimeout = null
    }

    private fun cancelPresentationTimeout(session: RewardSession) {
        session.presentationTimeout?.let(mainHandler::removeCallbacks)
        session.presentationTimeout = null
    }

    private fun cancelPresentationTimeout(session: InsertSession) {
        session.presentationTimeout?.let(mainHandler::removeCallbacks)
        session.presentationTimeout = null
    }

    private fun cancelWatchdogs(session: RewardSession) {
        cancelLoadTimeout(session)
        cancelPresentationTimeout(session)
        session.terminalTimeout?.let(mainHandler::removeCallbacks)
        session.terminalTimeout = null
    }

    private fun cancelWatchdogs(session: InsertSession) {
        cancelLoadTimeout(session)
        cancelPresentationTimeout(session)
        session.terminalTimeout?.let(mainHandler::removeCallbacks)
        session.terminalTimeout = null
    }

    private fun isCurrent(session: RewardSession): Boolean =
        !disposed && rewards[key(session.request.placement)] === session

    private fun isCurrent(session: InsertSession): Boolean =
        !disposed && inserts[key(session.request.placement)] === session

    private fun key(placement: String): String = placement
}

private fun diagnostic(
    normalizedCode: String,
    message: String,
    nativeCode: Int? = null,
    throwable: Throwable? = null,
): NativeDiagnostic =
    NativeDiagnostic(
        normalizedCode = normalizedCode,
        message = message,
        nativeCode = nativeCode?.toString(),
        nativeDomain = "android",
        nativeMessage = throwable?.message ?: message,
        details = buildMap {
            throwable?.javaClass?.name?.let { put("exceptionClass", it) }
        },
    )

private fun NativeDiagnostic.asFlutterError(): FlutterError {
    val merged = details.toMutableMap()
    nativeCode?.let { merged["nativeCode"] = it }
    nativeDomain?.let { merged["nativeDomain"] = it }
    nativeMessage?.let { merged["nativeMessage"] = it }
    return FlutterError(normalizedCode, message, merged)
}

private fun <T> ((Result<T>) -> Unit).failure(
    code: String,
    message: String,
    nativeCode: Int? = null,
    throwable: Throwable? = null,
) {
    val error = diagnostic(code, message, nativeCode, throwable)
    this(Result.failure(error.asFlutterError()))
}

private fun deniedAccess(): NativeAccess =
    NativeAccess(
        canUseLocation = false,
        canUsePhoneState = false,
        canUseWifiState = false,
        canUseWriteExternalStorage = false,
        canUseOaid = false,
        canUseAndroidId = false,
        canUseInstalledApps = false,
        canUseRecordAudio = false,
        canUseIdfa = false,
        canUploadDeviceInfo = false,
    )

private fun Bundle?.numberAsLong(key: String): Long? =
    (this?.get(key) as? Number)?.toLong()
