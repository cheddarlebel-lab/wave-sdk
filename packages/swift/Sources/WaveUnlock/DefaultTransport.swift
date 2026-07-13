import Foundation

extension Wave {
    /// The real transport on Apple platforms; a no-op elsewhere (e.g. Linux CI).
    static func makeDefaultTransport() -> BLETransport {
        #if canImport(CoreBluetooth)
        return CoreBluetoothTransport()
        #else
        return MockTransport(scripted: [.unavailable(.bluetoothOff)])
        #endif
    }
}
