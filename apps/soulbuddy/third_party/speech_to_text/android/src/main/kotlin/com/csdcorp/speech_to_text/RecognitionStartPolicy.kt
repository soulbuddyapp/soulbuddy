package com.csdcorp.speech_to_text

/** Pure policy for recognizer selection and safe start-failure classification. */
object RecognitionStartPolicy {
    fun select(onDevice: Boolean, sdk: Int, onDeviceAvailable: Boolean): String =
        if (!onDevice) "default"
        else if (sdk >= 31 && onDeviceAvailable) "onDevice"
        else "unavailable"

    fun run(prepare: () -> Unit, begin: () -> Unit): String {
        try { prepare() } catch (_: Exception) { return "beforeStart" }
        try { begin() } catch (_: Exception) { return "afterStart" }
        return "started"
    }
}
