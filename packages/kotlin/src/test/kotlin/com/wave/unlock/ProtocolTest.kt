package com.wave.unlock

import kotlin.test.Test
import kotlin.test.assertEquals

class ProtocolTest {
    @Test fun payloadPrefixAndBody() {
        val p = WaveProtocol.payload("10001")
        assertEquals(0x01.toByte(), p[0])
        assertEquals("10001", String(p.copyOfRange(1, p.size), Charsets.US_ASCII))
    }

    @Test fun defaultThresholdMatchesShippingApp() {
        assertEquals(-65, WaveProtocol.DEFAULT_RSSI_THRESHOLD)
    }

    @Test fun denialTableHas14AndMaps() {
        assertEquals(14, DenialMapping.table.size)
        assertEquals("Member not found", DenialMapping.friendly("Blocked by provider : 604 : Client not found"))
        assertEquals("Membership expired", DenialMapping.friendly("[mock] Membership expired"))
        assertEquals("Access denied", DenialMapping.friendly(null))
    }
}
