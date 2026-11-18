package com.csdcorp.speech_to_text

/** Main-thread state for a single Android recognition session. */
class RecognitionSessionGate {
    private var active = false
    private var generation = 0L
    private var stopRequested = false
    private var suppressWords = false
    private val waiters = mutableListOf<(Boolean) -> Unit>()

    fun start(): Long? {
        if (active) return null
        active = true
        suppressWords = false
        return ++generation
    }

    fun isCurrent(value: Long): Boolean = active && value == generation

    fun currentGeneration(): Long? = if (active) generation else null

    fun suppressResults(value: Long) {
        if (isCurrent(value)) suppressWords = true
    }

    fun resultsSuppressed(value: Long): Boolean = isCurrent(value) && suppressWords

    // True means the caller must issue the native stop command. A successful
    // acknowledgement is delivered only when finish observes a terminal event.
    fun requestStop(callback: (Boolean) -> Unit): Boolean {
        if (!active) {
            callback(true)
            return false
        }
        waiters.add(callback)
        if (stopRequested) return false
        stopRequested = true
        return true
    }

    // Forward the terminal event before completing waiters. If forwarding
    // throws, keep the gate closed because delivery is unconfirmed.
    fun finishAfterForward(value: Long, forward: () -> Unit) {
        if (!isCurrent(value)) return
        forward()
        finish(value)
    }

    fun finish(value: Long) {
        if (!isCurrent(value)) return
        active = false
        stopRequested = false
        val callbacks = waiters.toList()
        waiters.clear()
        callbacks.forEach { it(true) }
    }

    fun failStop() {
        stopRequested = false
        val callbacks = waiters.toList()
        waiters.clear()
        callbacks.forEach { it(false) }
    }
}
