package com.owlllwo.plugins.gromore

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

class InitializationCoordinatorStateTest {
    @Test
    fun pendingReplyRejectsStaleGenerationAndCompletesOnce() {
        val results = mutableListOf<Result<String>>()
        val reply = PendingReply(generation = 2L, callback = results::add)

        assertEquals(false, reply.complete(1L, Result.success("stale")))
        assertTrue(reply.complete(2L, Result.success("current")))
        assertEquals(false, reply.complete(2L, Result.success("duplicate")))
        assertEquals(listOf("current"), results.map { it.getOrThrow() })
    }

    @Test
    fun equivalentOwnersShareOneAttemptAndCompleteOnce() {
        val state = InitializationCoordinatorState<String, String>()

        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )
        val second = assertIs<InitializationCoordinatorState.RequestDecision.Wait>(
            state.request("engine-b", "app-a", sdkReady = false),
        )

        assertEquals(first.attemptId, second.attemptId)
        assertEquals(setOf("engine-a", "engine-b"), state.nativeSucceeded(first.attemptId))
        assertNull(state.nativeSucceeded(first.attemptId))
        assertEquals(InitializationCoordinatorState.Phase.STARTED, state.phase)
    }

    @Test
    fun conflictingFingerprintDoesNotJoinCurrentAttempt() {
        val state = InitializationCoordinatorState<String, String>()
        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )

        assertEquals(
            InitializationCoordinatorState.RequestDecision.Conflict,
            state.request("engine-b", "app-b", sdkReady = false),
        )
        assertEquals(setOf("engine-a"), state.nativeSucceeded(first.attemptId))
    }

    @Test
    fun detachedOwnerIsRemovedWithoutCancellingOtherWaiters() {
        val state = InitializationCoordinatorState<String, String>()
        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )
        state.request("engine-b", "app-a", sdkReady = false)

        assertTrue(state.remove("engine-a"))
        assertEquals(setOf("engine-b"), state.nativeSucceeded(first.attemptId))
    }

    @Test
    fun timeoutAndNativeCallbackRaceCompletesOnlyLiveOwners() {
        val state = InitializationCoordinatorState<String, String>()
        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )
        state.request("engine-b", "app-a", sdkReady = false)

        assertTrue(state.timeout("engine-a", first.attemptId))
        assertEquals(setOf("engine-b"), state.nativeSucceeded(first.attemptId))
        assertNull(state.nativeFailed(first.attemptId))
    }

    @Test
    fun lastTimeoutStallsUntilTheRealSdkReportsReady() {
        val state = InitializationCoordinatorState<String, String>()
        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )

        assertTrue(state.timeout("engine-a", first.attemptId))
        assertEquals(InitializationCoordinatorState.Phase.STALLED, state.phase)
        assertEquals(
            InitializationCoordinatorState.RequestDecision.RestartRequired,
            state.request("engine-b", "app-a", sdkReady = false),
        )
        assertEquals(
            InitializationCoordinatorState.RequestDecision.Complete,
            state.request("engine-b", "app-a", sdkReady = true),
        )
        assertEquals(InitializationCoordinatorState.Phase.STARTED, state.phase)
    }

    @Test
    fun failureAllowsRetryAndRejectsTheStaleAttempt() {
        val state = InitializationCoordinatorState<String, String>()
        val first = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-a", "app-a", sdkReady = false),
        )
        assertEquals(setOf("engine-a"), state.nativeFailed(first.attemptId))

        val retry = assertIs<InitializationCoordinatorState.RequestDecision.Start>(
            state.request("engine-b", "app-a", sdkReady = false),
        )
        assertTrue(retry.attemptId > first.attemptId)
        assertNull(state.nativeSucceeded(first.attemptId))
        assertEquals(setOf("engine-b"), state.nativeSucceeded(retry.attemptId))
    }
}
