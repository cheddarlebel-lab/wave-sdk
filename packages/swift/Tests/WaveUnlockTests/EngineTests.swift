import XCTest
@testable import WaveUnlock

final class EngineTests: XCTestCase {
    /// Fast engine: short timeouts so the timedOut path resolves quickly.
    private func engine(_ transport: BLETransport, threshold: Int = -65) -> UnlockEngine {
        UnlockEngine(transport: transport, gateway: nil, threshold: threshold, scanTimeout: 1.0, cloudTimeout: 0.3)
    }

    private func collect(_ stream: AsyncStream<UnlockState>) async -> [String] {
        var labels: [String] = []
        for await s in stream { labels.append(s.label) }
        return labels
    }

    func testGrantedSequence() async {
        let t = MockTransport(scripted: [.readerFound(rssi: -50), .verdict(granted: true, message: "Granted")])
        let labels = await collect(engine(t).unlock(payload: WaveProtocol.payload(for: "10001")))
        XCTAssertEqual(labels, ["scanning", "readerFound", "writing", "awaitingConfirmation", "granted"])
        XCTAssertEqual(t.writtenPayload, WaveProtocol.payload(for: "10001"))
    }

    func testDeniedSequence() async {
        let t = MockTransport(scripted: [.readerFound(rssi: -40), .verdict(granted: false, message: "Client not found")])
        let stream = engine(t).unlock(payload: WaveProtocol.payload(for: "10001"))
        var labels: [String] = []
        var deniedReason: String?
        for await s in stream {
            labels.append(s.label)
            if case .denied(let r) = s { deniedReason = r }
        }
        XCTAssertEqual(labels, ["scanning", "readerFound", "writing", "awaitingConfirmation", "denied"])
        XCTAssertEqual(deniedReason, "Member not found")
    }

    func testTimedOutSequence() async {
        let t = MockTransport(scripted: [.readerFound(rssi: -50)]) // reader, no verdict
        let labels = await collect(engine(t).unlock(payload: WaveProtocol.payload(for: "10001")))
        XCTAssertEqual(labels, ["scanning", "readerFound", "writing", "awaitingConfirmation", "timedOut"])
    }

    func testTooFarThenNoWrite() async {
        let t = MockTransport(scripted: [.readerFound(rssi: -90)]) // below threshold
        let labels = await collect(engine(t).unlock(payload: WaveProtocol.payload(for: "10001")))
        // scanning -> tooFar -> (scan stream ends, nothing written) -> timedOut
        XCTAssertEqual(labels.prefix(2).map { $0 }, ["scanning", "tooFar"])
        XCTAssertNil(t.writtenPayload)
    }

    func testDeliveredResolvesGranted() async {
        let t = MockTransport(scripted: [.readerFound(rssi: -50), .delivered])
        let labels = await collect(engine(t).unlock(payload: WaveProtocol.payload(for: "10001")))
        XCTAssertEqual(labels, ["scanning", "readerFound", "writing", "awaitingConfirmation", "granted"])
    }

    func testBluetoothOffFails() async {
        let t = MockTransport(scripted: [.unavailable(.bluetoothOff)])
        let labels = await collect(engine(t).unlock(payload: WaveProtocol.payload(for: "10001")))
        XCTAssertEqual(labels, ["scanning", "failed"])
    }
}
