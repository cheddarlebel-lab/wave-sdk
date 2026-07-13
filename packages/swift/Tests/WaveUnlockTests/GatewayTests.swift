import XCTest
@testable import WaveUnlock

/// Stubs URLSession so we can verify GatewayClient.tunedThreshold end-to-end
/// (fetchToken -> site-config) without a network.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URL) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (code, data) = MockURLProtocol.responder?(request.url!) ?? (404, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GatewayTests: XCTestCase {
    private func stubbedSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    func testTunedThresholdFetchesSiteConfig() async {
        MockURLProtocol.responder = { url in
            if url.path.hasSuffix("partner-auth/token") { return (200, #"{"token":"t","mode":"live","expires_in":300}"#.data(using: .utf8)!) }
            if url.path.hasSuffix("site-config") { return (200, #"{"rssi_threshold":-80,"ble_enabled":true}"#.data(using: .utf8)!) }
            return (404, Data())
        }
        let cfg = WaveConfig(publishableKey: "wave_pub_x", userNumber: "10001", siteNumber: "CBSM-1")
        let gw = GatewayClient(config: cfg, session: stubbedSession())
        let t = await gw.tunedThreshold()
        XCTAssertEqual(t, -80)
    }

    func testTunedThresholdNilWithoutSite() async {
        let cfg = WaveConfig(publishableKey: "wave_pub_x", userNumber: "10001") // no siteNumber
        let gw = GatewayClient(config: cfg, session: stubbedSession())
        let t = await gw.tunedThreshold()
        XCTAssertNil(t) // falls back to the built-in default
    }
}
