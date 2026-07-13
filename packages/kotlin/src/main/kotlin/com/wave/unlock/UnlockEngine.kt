package com.wave.unlock

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.launch

/** Drives scan -> proximity gate -> write -> await verdict (direct-BLE or cloud) -> terminal.
 *  Transport-agnostic; hardware-free when driven by MockTransport. */
class UnlockEngine(
    private val transport: BleTransport,
    private val gateway: Gateway? = null,
    private val threshold: Int = WaveProtocol.DEFAULT_RSSI_THRESHOLD,
    private val scanTimeoutMs: Long = WaveProtocol.SCAN_TIMEOUT_MS,
    private val cloudTimeoutMs: Long = WaveProtocol.CLOUD_CONFIRMATION_TIMEOUT_MS,
) {
    fun unlock(payload: ByteArray): Flow<UnlockState> = channelFlow {
        trySend(UnlockState.Scanning)
        val done = CompletableDeferred<UnlockState>()
        var wrote = false

        val scanTimeout = launch {
            delay(scanTimeoutMs)
            if (!wrote && !done.isCompleted) done.complete(UnlockState.TimedOut)
        }

        val collector = launch {
            transport.events().collect { event ->
                when (event) {
                    is BleEvent.Unavailable ->
                        if (!done.isCompleted) done.complete(UnlockState.Failed(event.error))

                    is BleEvent.ReaderFound -> if (!wrote) {
                        if (event.rssi >= threshold) {
                            wrote = true
                            trySend(UnlockState.ReaderFound(event.rssi))
                            trySend(UnlockState.Writing)
                            try {
                                transport.write(payload)
                            } catch (e: Exception) {
                                if (!done.isCompleted) done.complete(UnlockState.Failed(WaveError.WRITE_FAILED))
                                return@collect
                            }
                            trySend(UnlockState.AwaitingConfirmation)
                            launch {
                                delay(cloudTimeoutMs)
                                if (!done.isCompleted) done.complete(UnlockState.TimedOut)
                            }
                            gateway?.let { gw ->
                                launch {
                                    val token = runCatching { gw.fetchToken() }.getOrNull() ?: return@launch
                                    val outcome = gw.awaitOutcome(token, cloudTimeoutMs)
                                    val state = when (outcome.status) {
                                        Outcome.Status.GRANTED -> UnlockState.Granted(DenialMapping.friendly(outcome.reason))
                                        Outcome.Status.DENIED -> UnlockState.Denied(DenialMapping.friendly(outcome.reason))
                                        Outcome.Status.PENDING -> null
                                    }
                                    if (state != null && !done.isCompleted) done.complete(state)
                                }
                            }
                        } else {
                            trySend(UnlockState.TooFar(event.rssi))
                        }
                    }

                    is BleEvent.Verdict -> if (wrote && !done.isCompleted) {
                        done.complete(
                            if (event.granted) UnlockState.Granted(DenialMapping.friendly(event.message))
                            else UnlockState.Denied(DenialMapping.friendly(event.message))
                        )
                    }

                    is BleEvent.Delivered -> if (wrote && !done.isCompleted)
                        done.complete(UnlockState.Granted("Key sent"))
                }
            }
        }

        val terminal = done.await()
        scanTimeout.cancel()
        collector.cancel()
        transport.stop()
        trySend(terminal)
        close()
        awaitClose { }
    }
}
