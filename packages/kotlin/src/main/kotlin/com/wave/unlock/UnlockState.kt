package com.wave.unlock

/** States an unlock streams through. Labels match contract/conformance/state-sequences.json. */
sealed class UnlockState(val label: String) {
    object Idle : UnlockState("idle")
    object Scanning : UnlockState("scanning")
    data class ReaderFound(val rssi: Int) : UnlockState("readerFound")
    data class TooFar(val rssi: Int) : UnlockState("tooFar")
    object Writing : UnlockState("writing")
    object AwaitingConfirmation : UnlockState("awaitingConfirmation")
    data class Granted(val reason: String?) : UnlockState("granted")
    data class Denied(val reason: String) : UnlockState("denied")
    object TimedOut : UnlockState("timedOut")
    data class Failed(val error: WaveError) : UnlockState("failed")

    val isTerminal: Boolean
        get() = this is Granted || this is Denied || this is TimedOut || this is Failed
}

enum class WaveError { BLUETOOTH_OFF, PERMISSION_DENIED, WRITE_FAILED, NETWORK, AUTH }
