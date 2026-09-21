package com.owlllwo.plugins.gromore

/** Pure process-initialization state. It never calls or simulates an ad SDK. */
internal class InitializationCoordinatorState<Owner : Any, Fingerprint : Any> {
    internal enum class Phase { IDLE, STARTING, STARTED, STALLED }

    internal sealed interface RequestDecision {
        data class Start(val attemptId: Long) : RequestDecision

        data class Wait(val attemptId: Long) : RequestDecision

        data object Complete : RequestDecision

        data object Conflict : RequestDecision

        data object RestartRequired : RequestDecision
    }

    var phase: Phase = Phase.IDLE
        private set

    private var fingerprint: Fingerprint? = null
    private var attemptId = 0L
    private val owners = linkedSetOf<Owner>()

    fun request(
        owner: Owner,
        requestedFingerprint: Fingerprint,
        sdkReady: Boolean,
    ): RequestDecision = when (phase) {
        Phase.IDLE -> {
            fingerprint = requestedFingerprint
            attemptId += 1
            owners += owner
            phase = Phase.STARTING
            RequestDecision.Start(attemptId)
        }

        Phase.STARTING -> {
            if (fingerprint != requestedFingerprint) {
                RequestDecision.Conflict
            } else {
                owners += owner
                RequestDecision.Wait(attemptId)
            }
        }

        Phase.STARTED -> when {
            fingerprint != requestedFingerprint -> RequestDecision.Conflict
            sdkReady -> RequestDecision.Complete
            else -> RequestDecision.RestartRequired
        }

        Phase.STALLED -> when {
            fingerprint != requestedFingerprint -> RequestDecision.Conflict
            sdkReady -> {
                phase = Phase.STARTED
                RequestDecision.Complete
            }

            else -> RequestDecision.RestartRequired
        }
    }

    /** Removes a detached/disposed owner without changing the SDK attempt. */
    fun remove(owner: Owner): Boolean = owners.remove(owner)

    /** Expires one owner. The process attempt becomes stalled after its last timeout. */
    fun timeout(owner: Owner, expectedAttemptId: Long): Boolean {
        if (phase != Phase.STARTING || attemptId != expectedAttemptId || !owners.remove(owner)) {
            return false
        }
        if (owners.isEmpty()) phase = Phase.STALLED
        return true
    }

    /** Accepts only the current native success and returns the live owners to complete. */
    fun nativeSucceeded(expectedAttemptId: Long): Set<Owner>? {
        if ((phase != Phase.STARTING && phase != Phase.STALLED) || attemptId != expectedAttemptId) {
            return null
        }
        val completedOwners = owners.toSet()
        owners.clear()
        phase = Phase.STARTED
        return completedOwners
    }

    /** Accepts only the current native failure, returning to a retryable idle state. */
    fun nativeFailed(expectedAttemptId: Long): Set<Owner>? {
        if ((phase != Phase.STARTING && phase != Phase.STALLED) || attemptId != expectedAttemptId) {
            return null
        }
        val completedOwners = owners.toSet()
        owners.clear()
        fingerprint = null
        phase = Phase.IDLE
        return completedOwners
    }
}
