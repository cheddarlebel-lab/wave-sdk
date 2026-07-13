import 'dart:convert';
import 'dart:typed_data';

/// BLE + protocol constants. Single source of truth: contract/wave-protocol.json.
class WaveProtocol {
  static const serviceUuid = '496B2C43-B05E-4A9A-9592-535173B7AB51';
  static const writeCharacteristicUuid = '995B637F-13F2-4335-96F5-5541ECFCE219';
  static const readerNameFilter = 'SKBluTag';
  static const credentialPrefix = 0x01;

  static const defaultRssiThreshold = -65;
  static const rssiSettleWindowMs = 400;
  static const disconnectDelayMs = 1500;
  static const scanTimeoutMs = 30000;
  static const cloudConfirmationTimeoutMs = 5000;

  // SKBluTag status notify codes.
  static const statusGranted = 0x34; // "4"
  static const statusDenied = 0x35; // "5"
  static const statusDelivered = 0x38; // "8"

  /// Write payload: 0x01 prefix + userNumber ASCII.
  static Uint8List payload(String userNumber) =>
      Uint8List.fromList([credentialPrefix, ...ascii.encode(userNumber)]);
}
