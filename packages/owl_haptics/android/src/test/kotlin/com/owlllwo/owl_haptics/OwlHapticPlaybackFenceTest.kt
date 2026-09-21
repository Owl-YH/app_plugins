package com.owlllwo.owl_haptics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OwlHapticPlaybackFenceTest {
    @Test
    fun staleTokenCannotClearReplacement() {
        val fence = OwlHapticPlaybackFence()
        val first = fence.replace(owner = "engine", id = 1)
        val second = fence.replace(owner = "engine", id = 2)

        assertFalse(fence.clear(first))
        assertTrue(fence.matches(second))
        assertEquals(second, fence.matching(owner = "engine", id = 2))
    }

    @Test
    fun cancellationRequiresMatchingOwnerAndIdentifier() {
        val fence = OwlHapticPlaybackFence()
        val token = fence.replace(owner = "engine", id = 7)

        assertNull(fence.matching(owner = "engine", id = 8))
        assertNull(fence.matching(owner = "other"))
        assertEquals(token, fence.matching(owner = "engine"))
        assertTrue(fence.clear(token))
        assertFalse(fence.clear(token))
        assertNull(fence.current)
    }
}
