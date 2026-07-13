import XCTest
@testable import WaveUnlock

/// Validates the Swift engine against the SHARED conformance vectors copied from
/// contract/conformance/. Keeps this implementation honest with every other platform.
final class ConformanceTests: XCTestCase {

    private func vector(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Vectors")!
        return try! Data(contentsOf: url)
    }

    func testStateSequencesMatch() async throws {
        struct Vec: Decodable { let event: Event?; let states: [String]
            struct Event: Decodable { let result: String; let reason: String? }
        }
        let vectors = try JSONDecoder().decode([Vec].self, from: vector("state-sequences"))
        XCTAssertEqual(vectors.count, 3)

        for vec in vectors {
            let scripted: [BLEEvent]
            switch vec.event?.result {
            case "granted": scripted = [.readerFound(rssi: -50), .verdict(granted: true, message: "Granted")]
            case "denied": scripted = [.readerFound(rssi: -50), .verdict(granted: false, message: vec.event?.reason ?? "denied")]
            default: scripted = [.readerFound(rssi: -50)] // no verdict -> timedOut
            }
            let engine = UnlockEngine(transport: MockTransport(scripted: scripted), gateway: nil, threshold: -65, scanTimeout: 1.0, cloudTimeout: 0.3)
            var labels: [String] = []
            for await s in engine.unlock(payload: WaveProtocol.payload(for: "10001")) { labels.append(s.label) }
            XCTAssertEqual(labels, vec.states, "sequence mismatch for event \(String(describing: vec.event?.result))")
        }
    }

    func testDenialTableMatchesContract() throws {
        struct Row: Decodable { let sicm: String; let friendly: String }
        let rows = try JSONDecoder().decode([Row].self, from: vector("denial-mapping"))
        XCTAssertEqual(rows.count, 14)
        for row in rows {
            XCTAssertEqual(DenialMapping.friendly(row.sicm), row.friendly, "denial mismatch for \(row.sicm)")
        }
    }
}
