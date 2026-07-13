import Foundation

/// First-writer-wins holder for the terminal state, shared across the event loop and
/// the cloud/timeout tasks.
actor StateBox {
    private(set) var value: UnlockState?
    func setOnce(_ s: UnlockState) -> Bool {
        if value == nil { value = s; return true }
        return false
    }
}

/// Drives an unlock attempt: scan -> proximity gate -> write -> await verdict
/// (direct-BLE or cloud) -> terminal state. Transport-agnostic and hardware-free
/// when driven by `MockTransport`.
public final class UnlockEngine: @unchecked Sendable {
    let transport: BLETransport
    let gateway: GatewayClient?
    let threshold: Int
    let scanTimeout: TimeInterval
    let cloudTimeout: TimeInterval

    public init(
        transport: BLETransport,
        gateway: GatewayClient? = nil,
        threshold: Int = WaveProtocol.defaultRSSIThreshold,
        scanTimeout: TimeInterval = WaveProtocol.scanTimeout,
        cloudTimeout: TimeInterval = WaveProtocol.cloudConfirmationTimeout
    ) {
        self.transport = transport
        self.gateway = gateway
        self.threshold = threshold
        self.scanTimeout = scanTimeout
        self.cloudTimeout = cloudTimeout
    }

    /// Stream the unlock through its states. The stream finishes at the terminal state.
    public func unlock(payload: Data) -> AsyncStream<UnlockState> {
        AsyncStream { continuation in
            Task { await self.run(payload: payload, continuation: continuation) }
        }
    }

    private func run(payload: Data, continuation: AsyncStream<UnlockState>.Continuation) async {
        continuation.yield(.scanning)
        let box = StateBox()
        var wrote = false
        var cloudTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?

        let transport = self.transport
        let scanTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(self.scanTimeout * 1_000_000_000))
            if !Task.isCancelled, await box.setOnce(.timedOut) { transport.stop() }
        }

        for await event in transport.events() {
            switch event {
            case .unavailable(let e):
                if await box.setOnce(.failed(e)) { transport.stop() }

            case .readerFound(let rssi):
                guard !wrote else { break }
                if rssi >= threshold {
                    wrote = true
                    scanTimeoutTask.cancel()
                    continuation.yield(.readerFound(rssi: rssi))
                    continuation.yield(.writing)
                    do {
                        try await transport.write(payload)
                    } catch {
                        if await box.setOnce(.failed(.writeFailed("\(error)"))) { transport.stop() }
                        break
                    }
                    continuation.yield(.awaitingConfirmation)
                    timeoutTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(self.cloudTimeout * 1_000_000_000))
                        if await box.setOnce(.timedOut) { transport.stop() }
                    }
                    if let gw = gateway {
                        cloudTask = Task {
                            guard let token = try? await gw.fetchToken() else { return }
                            let outcome = await gw.awaitOutcome(token: token, timeout: self.cloudTimeout)
                            let state: UnlockState?
                            switch outcome.status {
                            case .granted: state = .granted(reason: DenialMapping.friendly(outcome.reason))
                            case .denied: state = .denied(reason: DenialMapping.friendly(outcome.reason))
                            case .pending: state = nil
                            }
                            if let state, await box.setOnce(state) { transport.stop() }
                        }
                    }
                } else {
                    continuation.yield(.tooFar(rssi: rssi))
                }

            case .verdict(let granted, let message):
                guard wrote else { break }
                let state: UnlockState = granted
                    ? .granted(reason: DenialMapping.friendly(message))
                    : .denied(reason: DenialMapping.friendly(message))
                if await box.setOnce(state) { transport.stop() }

            case .delivered:
                guard wrote else { break }
                if await box.setOnce(.granted(reason: "Key sent")) { transport.stop() }
            }
        }

        scanTimeoutTask.cancel()
        timeoutTask?.cancel()
        cloudTask?.cancel()
        let terminal = await box.value ?? .timedOut
        continuation.yield(terminal)
        continuation.finish()
    }
}
