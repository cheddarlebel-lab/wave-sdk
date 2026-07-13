import Foundation

#if canImport(CoreBluetooth)
import CoreBluetooth

/// Real BLE transport. Owns the CoreBluetooth central, performs multi-door
/// strongest-RSSI selection over the settle window, writes without response, and
/// surfaces direct-BLE verdicts. Carries forward the hard-won behaviors from the
/// shipping Wave Passport app (WaveBLEManager.swift):
///  - never wait for a notify after the write (deadlocks the SKBluTag)
///  - collect above-threshold candidates for `rssiSettleWindow`, connect to the strongest
///  - disconnect ~1.5s after the write (BLE hygiene, not a failure point)
public final class CoreBluetoothTransport: NSObject, BLETransport, @unchecked Sendable {
    private let threshold: Int
    private var central: CBCentralManager?
    private var continuation: AsyncStream<BLEEvent>.Continuation?

    private let serviceUUID = CBUUID(string: WaveProtocol.serviceUUIDString)
    private let writeUUID = CBUUID(string: WaveProtocol.writeCharacteristicUUIDString)
    private let statusUUID = CBUUID(string: WaveProtocol.notifyStatusUUIDString)
    private let messageUUID = CBUUID(string: WaveProtocol.notifyMessageUUIDString)

    private var candidates: [UUID: (peripheral: CBPeripheral, rssi: Int)] = [:]
    private var settleArmed = false
    private var chosen: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var pendingPayload: Data?
    private var lastMessage: String = ""

    public init(threshold: Int = WaveProtocol.defaultRSSIThreshold) {
        self.threshold = threshold
        super.init()
    }

    public func events() -> AsyncStream<BLEEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    public func write(_ payload: Data) async throws {
        pendingPayload = payload
        flushWriteIfReady()
    }

    public func stop() {
        central?.stopScan()
        if let chosen { central?.cancelPeripheralConnection(chosen) }
        continuation?.finish()
    }

    private func flushWriteIfReady() {
        guard let payload = pendingPayload, let char = writeChar, let peripheral = chosen else { return }
        // write WITHOUT response; do NOT wait for a notify.
        peripheral.writeValue(payload, for: char, type: .withoutResponse)
        pendingPayload = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + WaveProtocol.disconnectDelay) { [weak self] in
            guard let self, let p = self.chosen else { return }
            self.central?.cancelPeripheralConnection(p)
        }
    }

    private func armSettleWindow() {
        guard !settleArmed else { return }
        settleArmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + WaveProtocol.rssiSettleWindow) { [weak self] in
            self?.selectStrongestAndConnect()
        }
    }

    private func selectStrongestAndConnect() {
        guard chosen == nil,
              let best = candidates.values.max(by: { $0.rssi < $1.rssi }) else { return }
        chosen = best.peripheral
        central?.stopScan()
        continuation?.yield(.readerFound(rssi: best.rssi))
        central?.connect(best.peripheral, options: nil)
    }
}

extension CoreBluetoothTransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .poweredOff, .resetting, .unknown, .unsupported:
            continuation?.yield(.unavailable(.bluetoothOff))
        case .unauthorized:
            continuation?.yield(.unavailable(.permissionDenied))
        @unknown default:
            continuation?.yield(.unavailable(.bluetoothOff))
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        guard rssi >= threshold else { return }
        candidates[peripheral.identifier] = (peripheral, rssi)
        armSettleWindow()
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
}

extension CoreBluetoothTransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([writeUUID, statusUUID, messageUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            if char.uuid == writeUUID { writeChar = char }
            if char.uuid == statusUUID || char.uuid == messageUUID { peripheral.setNotifyValue(true, for: char) }
        }
        flushWriteIfReady()
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        if characteristic.uuid == messageUUID {
            lastMessage = String(data: data, encoding: .utf8) ?? ""
            return
        }
        guard characteristic.uuid == statusUUID, let code = data.first else { return }
        switch code {
        case WaveProtocol.statusGranted:
            continuation?.yield(.verdict(granted: true, message: lastMessage.isEmpty ? "Granted" : lastMessage))
        case WaveProtocol.statusDenied:
            continuation?.yield(.verdict(granted: false, message: lastMessage))
        case WaveProtocol.statusDelivered:
            continuation?.yield(.delivered)
        default:
            break
        }
    }
}
#endif
