import XCTest
@testable import WaveUnlock

final class ProtocolTests: XCTestCase {
    func testPayloadPrefixAndBody() {
        let payload = WaveProtocol.payload(for: "10001")
        XCTAssertEqual(payload.first, 0x01)
        XCTAssertEqual(Array(payload.dropFirst()), Array("10001".utf8))
    }

    func testDefaultThresholdMatchesShippingApp() {
        XCTAssertEqual(WaveProtocol.defaultRSSIThreshold, -65)
    }

    func testFriendlyStripsMockTagAndMatchesSubstring() {
        XCTAssertEqual(DenialMapping.friendly("[mock] Membership expired"), "Membership expired")
        XCTAssertEqual(DenialMapping.friendly("Blocked by provider : 604 : Client not found"), "Member not found")
        XCTAssertEqual(DenialMapping.friendly(nil), "Access denied")
    }
}
