package com.owlllwo.plugins.gromore

/** One-shot Pigeon reply guarded by the native request generation. */
internal class PendingReply<T>(
    private val generation: Long,
    callback: (Result<T>) -> Unit,
) {
    private var callback: ((Result<T>) -> Unit)? = callback

    fun complete(callbackGeneration: Long, result: Result<T>): Boolean {
        if (callbackGeneration != generation) return false
        val pending = callback ?: return false
        callback = null
        pending(result)
        return true
    }
}
