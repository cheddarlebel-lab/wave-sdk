import Foundation

/// The public entry point. Configure once, then stream `unlock()`.
///
/// ```swift
/// Wave.configure(WaveConfig(gatewayURL: url, anonKey: anon, publishableKey: "wave_pub_…", userNumber: "10001"))
/// for await state in Wave.unlock() {
///     // .scanning, .readerFound, .writing, .awaitingConfirmation, .granted, .denied, .timedOut, .failed
/// }
/// ```
public enum Wave {
    nonisolated(unsafe) private static var config: WaveConfig?

    public static func configure(_ config: WaveConfig) {
        self.config = config
    }

    /// Unlock against a real reader using the configured gateway.
    public static func unlock() -> AsyncStream<UnlockState> {
        guard let config else {
            return AsyncStream { $0.yield(.failed(.auth("Wave.configure(_:) not called"))); $0.finish() }
        }
        let transport = makeDefaultTransport()
        let engine = UnlockEngine(transport: transport, gateway: GatewayClient(config: config))
        return engine.unlock(payload: WaveProtocol.payload(for: config.userNumber))
    }

    /// Drive the full flow against a scripted mock — no hardware, no gateway.
    /// Use in previews, tests, and vibe-coder sandboxes.
    public static func mock(_ events: [BLEEvent], userNumber: String = "10001") -> AsyncStream<UnlockState> {
        let engine = UnlockEngine(transport: MockTransport(scripted: events), threshold: WaveProtocol.defaultRSSIThreshold, cloudTimeout: 1.0)
        return engine.unlock(payload: WaveProtocol.payload(for: userNumber))
    }

    /// A convenience "granted" mock: a strong reader then a direct-BLE grant.
    public static func mockGranted() -> AsyncStream<UnlockState> {
        mock([.readerFound(rssi: -50), .verdict(granted: true, message: "Granted")])
    }
}
