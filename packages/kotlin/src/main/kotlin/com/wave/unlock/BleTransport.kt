package com.wave.unlock

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.delay

/** Events a BLE transport surfaces to the engine. */
sealed class BleEvent {
    data class ReaderFound(val rssi: Int) : BleEvent()
    data class Verdict(val granted: Boolean, val message: String) : BleEvent()
    object Delivered : BleEvent()
    data class Unavailable(val error: WaveError) : BleEvent()
}

/** Abstraction over the BLE stack. AndroidBleTransport is the real one; tests use MockTransport. */
interface BleTransport {
    fun events(): Flow<BleEvent>
    suspend fun write(payload: ByteArray)
    fun stop()
}

/** Scripted transport for tests and mock previews. */
class MockTransport(
    private val scripted: List<BleEvent>,
    private val interEventDelayMs: Long = 10,
) : BleTransport {
    var writtenPayload: ByteArray? = null
        private set
    @Volatile var stopped = false
        private set

    override fun events(): Flow<BleEvent> = flow {
        for (event in scripted) {
            if (stopped) break
            emit(event)
            delay(interEventDelayMs)
        }
    }

    override suspend fun write(payload: ByteArray) { writtenPayload = payload }
    override fun stop() { stopped = true }
}
