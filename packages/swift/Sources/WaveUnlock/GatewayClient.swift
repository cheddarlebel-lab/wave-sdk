import Foundation

/// Configuration for talking to the Wave gateway.
///
/// The SDK only ever talks to the branded gateway, which is tenant-scoped and injects
/// its own backend key server-side. There is deliberately NO Supabase key here — a
/// third-party app can only reach the scoped unlock endpoints, never the data plane.
public struct WaveConfig: Sendable {
    /// The production gateway. Override only for a documented staging environment.
    public static let defaultGatewayURL = URL(string: "https://app.wavepassport.com/api")!

    public var gatewayURL: URL
    public var publishableKey: String
    public var userNumber: String
    /// Optional. When set, the SDK reads this site's cloud-tuned RSSI threshold (set by
    /// the operator) instead of the built-in default, so proximity matches the reader's
    /// configured distance. Leave nil to use `WaveProtocol.defaultRSSIThreshold`.
    public var siteNumber: String?

    public init(publishableKey: String, userNumber: String, siteNumber: String? = nil, gatewayURL: URL = defaultGatewayURL) {
        self.siteNumber = siteNumber
        self.gatewayURL = gatewayURL
        self.publishableKey = publishableKey
        self.userNumber = userNumber
    }
}

/// The unlock result read back from the gateway.
public struct UnlockOutcome: Equatable, Sendable {
    public enum Status: String, Sendable { case granted, denied, pending }
    public var status: Status
    public var reason: String?
}

/// Minimal async client for the partner gateway. Injectable via URLProtocol/stub for tests.
public struct GatewayClient: Sendable {
    let config: WaveConfig
    let session: URLSession

    public init(config: WaveConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    private func request(_ path: String, body: [String: Any], bearer: String? = nil) throws -> URLRequest {
        var req = URLRequest(url: config.gatewayURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// Exchange the publishable key for a short-lived session token.
    public func fetchToken() async throws -> String {
        let req = try request("partner-auth/token", body: ["key": config.publishableKey])
        let (data, resp) = try await session.data(for: req)
        try Self.check(resp, data)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["token"] as? String else {
            throw WaveError.auth("token missing in response")
        }
        return token
    }

    /// Read the latest unlock outcome for this member.
    public func readOutcome(token: String) async throws -> UnlockOutcome {
        let req = try request("unlock-stream", body: ["card_id": config.userNumber], bearer: token)
        let (data, resp) = try await session.data(for: req)
        try Self.check(resp, data)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusRaw = obj["status"] as? String,
              let status = UnlockOutcome.Status(rawValue: statusRaw) else {
            throw WaveError.network("malformed unlock-stream response")
        }
        return UnlockOutcome(status: status, reason: obj["reason"] as? String)
    }

    /// The site's cloud-tuned RSSI threshold, or nil if no siteNumber is configured or the
    /// fetch fails (caller falls back to the default). Never throws — proximity tuning is
    /// best-effort and must not block an unlock.
    public func tunedThreshold() async -> Int? {
        guard let site = config.siteNumber, !site.isEmpty else { return nil }
        guard let token = try? await fetchToken() else { return nil }
        guard let req = try? request("site-config", body: ["site_number": site], bearer: token),
              let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? false,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["rssi_threshold"] as? Int
    }

    /// Poll unlock-stream until a non-pending result or the timeout elapses.
    public func awaitOutcome(token: String, timeout: TimeInterval, pollInterval: TimeInterval = 0.5) async -> UnlockOutcome {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let outcome = try? await readOutcome(token: token), outcome.status != .pending {
                return outcome
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return UnlockOutcome(status: .pending, reason: nil)
    }

    static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw WaveError.network("gateway \(http.statusCode): \(msg ?? "error")")
        }
    }
}
