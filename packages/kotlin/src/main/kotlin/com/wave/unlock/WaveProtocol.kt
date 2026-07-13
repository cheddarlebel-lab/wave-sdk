package com.wave.unlock

/** BLE + protocol constants. Single source of truth: contract/wave-protocol.json.
 *  Carried forward verbatim from the shipping Wave Passport app. */
object WaveProtocol {
    const val SERVICE_UUID = "496B2C43-B05E-4A9A-9592-535173B7AB51"
    const val WRITE_CHARACTERISTIC_UUID = "995B637F-13F2-4335-96F5-5541ECFCE219"
    const val NOTIFY_STATUS_UUID = "03785C4B-4FBA-4D2F-9276-918EA8F5729F"
    const val NOTIFY_MESSAGE_UUID = "E08AC766-ABD5-4A2B-8688-273896B3DED1"

    const val READER_NAME_FILTER = "SKBluTag"
    const val CREDENTIAL_PREFIX: Byte = 0x01

    const val DEFAULT_RSSI_THRESHOLD = -65
    const val RSSI_SETTLE_WINDOW_MS = 400L
    const val DISCONNECT_DELAY_MS = 1500L
    const val SCAN_TIMEOUT_MS = 30_000L
    const val CLOUD_CONFIRMATION_TIMEOUT_MS = 5_000L

    // SKBluTag status notify codes.
    const val STATUS_IDLE: Byte = 0x31       // "1"
    const val STATUS_PROCESSING: Byte = 0x33 // "3"
    const val STATUS_GRANTED: Byte = 0x34    // "4"
    const val STATUS_DENIED: Byte = 0x35     // "5"
    const val STATUS_TIMEOUT: Byte = 0x36    // "6"
    const val STATUS_DELIVERED: Byte = 0x38  // "8"

    /** Write payload: 0x01 prefix + userNumber ASCII. */
    fun payload(userNumber: String): ByteArray =
        byteArrayOf(CREDENTIAL_PREFIX) + userNumber.toByteArray(Charsets.US_ASCII)
}
