import Flutter
import WaveUnlock  // the Swift core (pod / SPM dependency)

// Flutter plugin: runs the Swift UnlockEngine and streams each state over an
// EventChannel; startUnlock is triggered from a MethodChannel.
public class WaveUnlockPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var task: Task<Void, Never>?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WaveUnlockPlugin()
        let methods = FlutterMethodChannel(name: "wave_unlock/control", binaryMessenger: registrar.messenger())
        let events = FlutterEventChannel(name: "wave_unlock/states", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        events.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        sink = eventSink; return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        task?.cancel(); sink = nil; return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "startUnlock", let a = call.arguments as? [String: Any],
              let pub = a["publishableKey"] as? String, let user = a["userNumber"] as? String
        else { result(FlutterMethodNotImplemented); return }

        let url = (a["gatewayUrl"] as? String).flatMap(URL.init) ?? WaveConfig.defaultGatewayURL
        Wave.configure(WaveConfig(publishableKey: pub, userNumber: user, gatewayURL: url))
        task?.cancel()
        task = Task { [weak self] in
            for await state in Wave.unlock() { self?.sink?(Self.encode(state)) }
        }
        result(nil)
    }

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
