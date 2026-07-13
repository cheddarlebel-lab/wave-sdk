import Foundation

/// BLE + protocol constants. Single source of truth: wave-sdk/contract/wave-protocol.json.
/// Values carried forward verbatim from the shipping Wave Passport app (BLEConstants.swift).
public enum WaveProtocol {
    public static let serviceUUIDString = "496B2C43-B05E-4A9A-9592-535173B7AB51"
    public static let writeCharacteristicUUIDString = "995B637F-13F2-4335-96F5-5541ECFCE219"
    public static let notifyStatusUUIDString = "03785C4B-4FBA-4D2F-9276-918EA8F5729F"
    public static let notifyMessageUUIDString = "E08AC766-ABD5-4A2B-8688-273896B3DED1"

    public static let readerNameFilter = "SKBluTag"
    public static let credentialPrefix: UInt8 = 0x01

    /// Default RSSI gate. -65 (~3m, "Medium") matches the WebUI default as of r13.36.
    public static let defaultRSSIThreshold = -65
    /// Multi-door settle window: collect above-threshold readers this long, then
    /// connect to the STRONGEST (RSSI is the only signal that distinguishes two doors).
    public static let rssiSettleWindow: TimeInterval = 0.4
    public static let disconnectDelay: TimeInterval = 1.5
    public static let scanTimeout: TimeInterval = 30.0
    /// How long to wait for a cloud verdict after the BLE write before timing out.
    public static let cloudConfirmationTimeout: TimeInterval = 5.0
    /// Grace after a keyboard-wedge "delivered" (8) for a CBSM verdict to still win.
    public static let deliveredGrace: TimeInterval = 2.0

    // SKBluTag status notify codes.
    public static let statusIdle: UInt8 = 0x31       // "1"
    public static let statusProcessing: UInt8 = 0x33 // "3"
    public static let statusGranted: UInt8 = 0x34    // "4" (direct-BLE verdict, r13.4x+)
    public static let statusDenied: UInt8 = 0x35     // "5"
    public static let statusTimeout: UInt8 = 0x36    // "6"
    public static let statusDelivered: UInt8 = 0x38  // "8" (keyboard-wedge delivery ack)

    /// Build the write payload: 0x01 prefix + userNumber as ASCII.
    public static func payload(for userNumber: String) -> Data {
        var data = Data([credentialPrefix])
        data.append(contentsOf: Array(userNumber.utf8))
        return data
    }
}
