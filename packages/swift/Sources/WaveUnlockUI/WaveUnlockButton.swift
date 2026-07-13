#if canImport(SwiftUI)
import SwiftUI
import WaveUnlock

/// Drop-in unlock button. Tap to run the flow; the label reflects live state.
///
/// ```swift
/// WaveUnlockButton()   // uses Wave.configure(_:)
/// ```
@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
public struct WaveUnlockButton: View {
    @State private var state: UnlockState = .idle
    @State private var running = false
    private let streamProvider: () -> AsyncStream<UnlockState>

    /// Default: drives the configured real unlock. Inject a provider for previews/tests.
    public init(streamProvider: @escaping () -> AsyncStream<UnlockState> = { Wave.unlock() }) {
        self.streamProvider = streamProvider
    }

    public var body: some View {
        Button(action: run) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.4)))
        }
        .disabled(running)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: title)
    }

    private func run() {
        guard !running else { return }
        running = true
        state = .scanning
        Task {
            for await s in streamProvider() { state = s }
            running = false
        }
    }

    private var title: String {
        switch state {
        case .idle: return "Unlock door"
        case .scanning: return "Looking for the door…"
        case .readerFound: return "Door found"
        case .tooFar: return "Move closer"
        case .writing: return "Unlocking…"
        case .awaitingConfirmation: return "Confirming…"
        case .granted(let r): return r ?? "Access granted"
        case .denied(let r): return r
        case .timedOut: return "Sent — couldn't confirm"
        case .failed: return "Can't unlock"
        }
    }

    private var icon: String {
        switch state {
        case .granted: return "lock.open.fill"
        case .denied, .failed: return "lock.trianglebadge.exclamationmark.fill"
        case .timedOut: return "clock.badge.questionmark"
        default: return "lock.fill"
        }
    }

    private var color: Color {
        switch state {
        case .granted: return .green
        case .denied, .failed: return .red
        case .timedOut: return .orange
        default: return .blue
        }
    }
}
#endif
