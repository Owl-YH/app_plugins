package com.owlllwo.owl_haptics

internal data class OwlHapticPlaybackToken(
    val owner: String,
    val id: Long,
    val generation: Long,
)

internal class OwlHapticPlaybackFence {
    var current: OwlHapticPlaybackToken? = null
        private set

    private var generation = 0L

    fun replace(owner: String, id: Long): OwlHapticPlaybackToken {
        generation = if (generation == Long.MAX_VALUE) 1 else generation + 1
        return OwlHapticPlaybackToken(owner, id, generation).also { current = it }
    }

    fun matches(token: OwlHapticPlaybackToken): Boolean = current == token

    fun matching(owner: String, id: Long): OwlHapticPlaybackToken? =
        current?.takeIf { it.owner == owner && it.id == id }

    fun matching(owner: String): OwlHapticPlaybackToken? =
        current?.takeIf { it.owner == owner }

    fun clear(token: OwlHapticPlaybackToken): Boolean {
        if (current != token) return false
        current = null
        return true
    }
}
