import Foundation

/// Events a BLE transport surfaces to the engine.
public enum BLEEvent: Equatable, Sendable {
    /// A reader was seen at this signal strength (may fire repeatedly).
    case readerFound(rssi: Int)
    /// Direct-BLE verdict pushed by the CBSM (status "4"/"5"), with the human message.
    case verdict(granted: Bool, message: String)
    /// Keyboard-wedge delivery ack (status "8") — credential typed out, no verdict follows.
    case delivered
    /// The transport can't proceed (BLE off, unauthorized, etc.).
    case unavailable(WaveError)
}

/// Abstraction over the BLE stack so the engine can be tested without hardware.
/// The real implementation is `CoreBluetoothTransport`; tests use `MockTransport`.
public protocol BLETransport: AnyObject, Sendable {
    /// Begin scanning; the returned stream emits `readerFound` samples and, after a
    /// successful write, any direct-BLE `verdict`/`delivered`.
    func events() -> AsyncStream<BLEEvent>
    /// Connect to the strongest candidate and write the payload (write-without-response).
    /// Must NOT wait for a notify (that deadlocks the SKBluTag).
    func write(_ payload: Data) async throws
    /// Drop the connection and stop scanning.
    func stop()
}
