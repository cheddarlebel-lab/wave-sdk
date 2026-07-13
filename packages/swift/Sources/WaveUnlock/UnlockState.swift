import Foundation

/// The states an unlock attempt streams through. Names match the shared conformance
/// vectors (contract/conformance/state-sequences.json).
public enum UnlockState: Equatable, Sendable {
    case idle
    case scanning
    case readerFound(rssi: Int)
    case tooFar(rssi: Int)
    case writing
    case awaitingConfirmation
    case granted(reason: String?)
    case denied(reason: String)
    case timedOut
    case failed(WaveError)

    /// The stable string label used by the conformance vectors.
    public var label: String {
        switch self {
        case .idle: return "idle"
        case .scanning: return "scanning"
        case .readerFound: return "readerFound"
        case .tooFar: return "tooFar"
        case .writing: return "writing"
        case .awaitingConfirmation: return "awaitingConfirmation"
        case .granted: return "granted"
        case .denied: return "denied"
        case .timedOut: return "timedOut"
        case .failed: return "failed"
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .granted, .denied, .timedOut, .failed: return true
        default: return false
        }
    }
}

public enum WaveError: Error, Equatable, Sendable {
    case bluetoothOff
    case permissionDenied
    case bluetoothDisabledByConfig
    case writeFailed(String)
    case network(String)
    case auth(String)
}
