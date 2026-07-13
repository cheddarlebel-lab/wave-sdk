import Foundation
import WaveUnlock  // the Swift core (SPM / CocoaPods dependency)

// RN native module: runs the Swift UnlockEngine and emits each state as a
// "WaveUnlockState" event. The JS side (stream.ts) turns those into an async iterator.
@objc(WaveUnlock)
class WaveUnlockModule: RCTEventEmitter {
    private var task: Task<Void, Never>?
    private var hasListeners = false

    override static func requiresMainQueueSetup() -> Bool { false }
    override func supportedEvents() -> [String]! { ["WaveUnlockState"] }
    override func startObserving() { hasListeners = true }
    override func stopObserving() { hasListeners = false }

    private func emit(_ payload: [String: Any]) {
        if hasListeners { sendEvent(withName: "WaveUnlockState", body: payload) }
    }

    @objc(startUnlock:)
    func startUnlock(_ config: NSDictionary) {
        guard
            let pub = config["publishableKey"] as? String,
            let user = config["userNumber"] as? String
        else {
            emit(["kind": "failed", "error": "invalid config"])
            return
        }
        let url = (config["gatewayUrl"] as? String).flatMap(URL.init) ?? WaveConfig.defaultGatewayURL
        Wave.configure(WaveConfig(publishableKey: pub, userNumber: user, gatewayURL: url))
        task?.cancel()
        task = Task { [weak self] in
            for await state in Wave.unlock() {
                self?.emit(Self.encode(state))
            }
        }
    }

    @objc func cancel() { task?.cancel() }

    private static func encode(_ s: UnlockState) -> [String: Any] {
        switch s {
        case .idle: return ["kind": "idle"]
        case .scanning: return ["kind": "scanning"]
        case .readerFound(let r): return ["kind": "readerFound", "rssi": r]
        case .tooFar(let r): return ["kind": "tooFar", "rssi": r]
        case .writing: return ["kind": "writing"]
        case .awaitingConfirmation: return ["kind": "awaitingConfirmation"]
        case .granted(let reason): return ["kind": "granted", "reason": reason as Any]
        case .denied(let reason): return ["kind": "denied", "reason": reason]
        case .timedOut: return ["kind": "timedOut"]
        case .failed(let e): return ["kind": "failed", "error": "\(e)"]
        }
    }
}
