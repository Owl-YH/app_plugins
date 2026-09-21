package com.owlllwo.owl_haptics

import android.app.Activity
import android.app.Application
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.View
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.util.UUID

/** Android implementation for short, foreground UI haptics. */
class OwlHapticsPlugin :
    FlutterPlugin,
    ActivityAware,
    OwlHapticsHostApi,
    Application.ActivityLifecycleCallbacks {
    private val owner = UUID.randomUUID().toString()
    private var application: Application? = null
    private var activity: Activity? = null
    private var resumed = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val app = binding.applicationContext as Application
        application = app
        app.registerActivityLifecycleCallbacks(this)
        OwlHapticsHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        OwlHapticsHostApi.setUp(binding.binaryMessenger, null)
        OwlHapticCoordinator.stop(owner)
        application?.unregisterActivityLifecycleCallbacks(this)
        application = null
        activity = null
        resumed = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        resumed = false
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    override fun play(request: HapticRequest) {
        validate(request)
        val currentActivity = activity
        val app = application ?: return
        OwlHapticCoordinator.play(
            owner = owner,
            request = request,
            context = app,
            view = currentActivity?.window?.decorView,
            foreground =
                resumed &&
                    currentActivity?.isFinishing == false &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR1 ||
                        !currentActivity.isDestroyed),
        )
    }

    override fun cancel(id: Long) {
        requireId(id)
        OwlHapticCoordinator.cancel(owner, id)
    }

    override fun stop() {
        OwlHapticCoordinator.stop(owner)
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity === this.activity) resumed = true
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity === this.activity) {
            resumed = false
            OwlHapticCoordinator.stop(owner)
        }
    }

    override fun onActivityDestroyed(activity: Activity) {
        if (activity === this.activity) detachActivity()
    }

    override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit

    private fun detachActivity() {
        resumed = false
        OwlHapticCoordinator.stop(owner)
        activity = null
    }

    private fun validate(request: HapticRequest) {
        requireId(request.id)
        val valid =
            when (request.kind) {
                HapticKind.SELECTION ->
                    request.strength == null && request.outcome == null && request.pulses.isEmpty()
                HapticKind.IMPACT ->
                    request.strength != null && request.outcome == null && request.pulses.isEmpty()
                HapticKind.OUTCOME ->
                    request.strength == null && request.outcome != null && request.pulses.isEmpty()
                HapticKind.SEQUENCE ->
                    request.strength == null && request.outcome == null && validPulses(request.pulses)
            }
        if (!valid) {
            throw FlutterError("invalid_request", "Invalid haptic request.", null)
        }
    }

    private fun requireId(id: Long) {
        if (id <= 0) {
            throw FlutterError("invalid_id", "Playback identity must be positive.", null)
        }
    }

    private fun validPulses(pulses: List<HapticPulse>): Boolean {
        if (pulses.isEmpty() || pulses.size > 16) return false
        var previous = -50L
        for (pulse in pulses) {
            if (pulse.atMillis !in 0..2_000 || pulse.atMillis - previous < 50) return false
            previous = pulse.atMillis
        }
        return true
    }
}

private object OwlHapticCoordinator {
    private const val transientMillis = 18L
    private const val api36 = 36
    private val handler = Handler(Looper.getMainLooper())
    private val fence = OwlHapticPlaybackFence()
    private var active: ActivePlayback? = null

    fun play(
        owner: String,
        request: HapticRequest,
        context: Context,
        view: View?,
        foreground: Boolean,
    ) {
        check(Looper.myLooper() == Looper.getMainLooper())
        cancelActive()
        if (!foreground || view == null || !hapticsEnabled(context)) return

        try {
            when (request.kind) {
                HapticKind.SELECTION ->
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                HapticKind.IMPACT ->
                    view.performHapticFeedback(impactConstant(requireNotNull(request.strength)))
                HapticKind.OUTCOME ->
                    view.performHapticFeedback(outcomeConstant(requireNotNull(request.outcome)))
                HapticKind.SEQUENCE -> playSequence(owner, request, context)
            }
        } catch (error: Exception) {
            cancelActive()
            throw FlutterError("haptic_failed", "Unable to start haptic feedback.", null)
        }
    }

    fun cancel(owner: String, id: Long) {
        check(Looper.myLooper() == Looper.getMainLooper())
        val token = fence.matching(owner, id) ?: return
        cancelActive(token)
    }

    fun stop(owner: String) {
        check(Looper.myLooper() == Looper.getMainLooper())
        val token = fence.matching(owner) ?: return
        cancelActive(token)
    }

    private fun playSequence(owner: String, request: HapticRequest, context: Context) {
        val vibrator = vibrator(context)
        if (!vibrator.hasVibrator()) return

        val endMillis =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                vibrator.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_CLICK)
            ) {
                playComposition(vibrator, request.pulses)
            } else {
                playWaveform(vibrator, request.pulses)
            }

        val token = fence.replace(owner, request.id)
        active = ActivePlayback(token, vibrator)
        handler.postAtTime(
            { complete(token) },
            token,
            SystemClock.uptimeMillis() + endMillis.coerceAtLeast(1),
        )
    }

    private fun playComposition(vibrator: Vibrator, pulses: List<HapticPulse>): Long {
        val primitive = VibrationEffect.Composition.PRIMITIVE_CLICK
        val primitiveMillis = vibrator.getPrimitiveDurations(primitive).firstOrNull() ?: 0
        if (primitiveMillis <= 0) return playWaveform(vibrator, pulses)

        val composition = VibrationEffect.startComposition()
        if (Build.VERSION.SDK_INT >= api36) {
            var previousStart = 0L
            for ((index, pulse) in pulses.withIndex()) {
                val offset = if (index == 0) pulse.atMillis else pulse.atMillis - previousStart
                composition.addPrimitive(
                    primitive,
                    scale(pulse.strength),
                    offset.toInt(),
                    VibrationEffect.Composition.DELAY_TYPE_RELATIVE_START_OFFSET,
                )
                previousStart = pulse.atMillis
            }
        } else {
            var previousStart = 0L
            for ((index, pulse) in pulses.withIndex()) {
                val pause =
                    if (index == 0) {
                        pulse.atMillis
                    } else {
                        pulse.atMillis - previousStart - primitiveMillis
                    }
                if (pause < 0) return playWaveform(vibrator, pulses)
                composition.addPrimitive(primitive, scale(pulse.strength), pause.toInt())
                previousStart = pulse.atMillis
            }
        }
        vibrate(vibrator, composition.compose())
        return pulses.last().atMillis + primitiveMillis
    }

    private fun playWaveform(vibrator: Vibrator, pulses: List<HapticPulse>): Long {
        val timings = ArrayList<Long>(pulses.size * 2 + 1)
        val amplitudes = ArrayList<Int>(pulses.size * 2 + 1)
        var cursor = 0L
        for (pulse in pulses) {
            timings += pulse.atMillis - cursor
            amplitudes += 0
            timings += transientMillis
            amplitudes += amplitude(pulse.strength)
            cursor = pulse.atMillis + transientMillis
        }
        timings += 1L
        amplitudes += 0

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect =
                if (vibrator.hasAmplitudeControl()) {
                    VibrationEffect.createWaveform(
                        timings.toLongArray(),
                        amplitudes.toIntArray(),
                        -1,
                    )
                } else {
                    VibrationEffect.createWaveform(timings.toLongArray(), -1)
                }
            vibrate(vibrator, effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings.toLongArray(), -1)
        }
        return pulses.last().atMillis + transientMillis + 1
    }

    private fun vibrate(vibrator: Vibrator, effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(
                effect,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH),
            )
        } else {
            vibrator.vibrate(
                effect,
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .build(),
            )
        }
    }

    private fun complete(token: OwlHapticPlaybackToken) {
        if (!fence.matches(token) || active?.token != token) return
        handler.removeCallbacksAndMessages(token)
        active = null
        fence.clear(token)
    }

    private fun cancelActive() {
        val token = fence.current ?: return
        cancelActive(token)
    }

    private fun cancelActive(token: OwlHapticPlaybackToken) {
        val playback = active?.takeIf { it.token == token } ?: return
        handler.removeCallbacksAndMessages(token)
        active = null
        fence.clear(token)
        playback.vibrator.cancel()
    }

    private fun vibrator(context: Context): Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    private fun hapticsEnabled(context: Context): Boolean =
        Settings.System.getInt(
            context.contentResolver,
            Settings.System.HAPTIC_FEEDBACK_ENABLED,
            1,
        ) != 0

    private fun impactConstant(strength: HapticLevel): Int =
        when (strength) {
            HapticLevel.LIGHT -> HapticFeedbackConstants.VIRTUAL_KEY
            HapticLevel.MEDIUM -> HapticFeedbackConstants.KEYBOARD_TAP
            HapticLevel.HEAVY -> HapticFeedbackConstants.CONTEXT_CLICK
        }

    private fun outcomeConstant(result: HapticResult): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            when (result) {
                HapticResult.SUCCESS -> HapticFeedbackConstants.CONFIRM
                HapticResult.WARNING -> HapticFeedbackConstants.KEYBOARD_TAP
                HapticResult.ERROR -> HapticFeedbackConstants.REJECT
            }
        } else {
            when (result) {
                HapticResult.SUCCESS -> HapticFeedbackConstants.VIRTUAL_KEY
                HapticResult.WARNING -> HapticFeedbackConstants.KEYBOARD_TAP
                HapticResult.ERROR -> HapticFeedbackConstants.LONG_PRESS
            }
        }

    private fun scale(strength: HapticLevel): Float =
        when (strength) {
            HapticLevel.LIGHT -> 0.32f
            HapticLevel.MEDIUM -> 0.52f
            HapticLevel.HEAVY -> 0.82f
        }

    private fun amplitude(strength: HapticLevel): Int =
        when (strength) {
            HapticLevel.LIGHT -> 80
            HapticLevel.MEDIUM -> 128
            HapticLevel.HEAVY -> 204
        }

    private data class ActivePlayback(
        val token: OwlHapticPlaybackToken,
        val vibrator: Vibrator,
    )
}
