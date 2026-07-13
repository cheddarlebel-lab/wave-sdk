package com.wave.unlock

import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertContentEquals

class EngineTest {
    private fun engine(t: BleTransport) =
        UnlockEngine(t, gateway = null, threshold = -65, scanTimeoutMs = 1000, cloudTimeoutMs = 300)

    private suspend fun labels(t: BleTransport) =
        engine(t).unlock(WaveProtocol.payload("10001")).toList().map { it.label }

    @Test fun grantedSequence() = runTest {
        val t = MockTransport(listOf(BleEvent.ReaderFound(-50), BleEvent.Verdict(true, "Granted")))
        assertEquals(listOf("scanning", "readerFound", "writing", "awaitingConfirmation", "granted"), labels(t))
        assertContentEquals(WaveProtocol.payload("10001"), t.writtenPayload)
    }

    @Test fun deniedSequenceMapsReason() = runTest {
        val t = MockTransport(listOf(BleEvent.ReaderFound(-40), BleEvent.Verdict(false, "Client not found")))
        val states = engine(t).unlock(WaveProtocol.payload("10001")).toList()
        assertEquals(listOf("scanning", "readerFound", "writing", "awaitingConfirmation", "denied"), states.map { it.label })
        assertEquals("Member not found", (states.last() as UnlockState.Denied).reason)
    }

    @Test fun timedOutWhenNoVerdict() = runTest {
        val t = MockTransport(listOf(BleEvent.ReaderFound(-50)))
        assertEquals(listOf("scanning", "readerFound", "writing", "awaitingConfirmation", "timedOut"), labels(t))
    }

    @Test fun tooFarDoesNotWrite() = runTest {
        val t = MockTransport(listOf(BleEvent.ReaderFound(-90)))
        val labels = labels(t)
        assertEquals(listOf("scanning", "tooFar"), labels.take(2))
        assertNull(t.writtenPayload)
    }

    @Test fun deliveredResolvesGranted() = runTest {
        val t = MockTransport(listOf(BleEvent.ReaderFound(-50), BleEvent.Delivered))
        assertEquals(listOf("scanning", "readerFound", "writing", "awaitingConfirmation", "granted"), labels(t))
    }

    @Test fun bluetoothOffFails() = runTest {
        val t = MockTransport(listOf(BleEvent.Unavailable(WaveError.BLUETOOTH_OFF)))
        assertEquals(listOf("scanning", "failed"), labels(t))
    }
}
