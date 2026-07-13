import Foundation

/// A scripted BLE transport for tests and `Wave.mock()`. Emits a preset sequence of
/// events; records the payload written.
public final class MockTransport: BLETransport, @unchecked Sendable {
    private let scripted: [BLEEvent]
    private let interEventDelay: TimeInterval
    public private(set) var writtenPayload: Data?
    public private(set) var stopped = false

    /// - Parameters:
    ///   - scripted: events emitted in order once scanning starts.
    ///   - interEventDelay: small delay between events so the engine can interleave.
    public init(scripted: [BLEEvent], interEventDelay: TimeInterval = 0.01) {
        self.scripted = scripted
        self.interEventDelay = interEventDelay
    }

    public func events() -> AsyncStream<BLEEvent> {
        AsyncStream { continuation in
            let events = scripted
            let delay = interEventDelay
            Task {
                for event in events {
                    if self.stopped { break }
                    continuation.yield(event)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }

    public func write(_ payload: Data) async throws {
        writtenPayload = payload
    }

    public func stop() { stopped = true }
}
