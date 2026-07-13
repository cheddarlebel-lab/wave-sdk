import 'dart:async';
import 'dart:typed_data';
import 'state.dart';

/// Events a BLE transport surfaces to the engine.
sealed class BleEvent {
  const BleEvent();
}

class EvtReaderFound extends BleEvent {
  final int rssi;
  const EvtReaderFound(this.rssi);
}

class EvtVerdict extends BleEvent {
  final bool granted;
  final String message;
  const EvtVerdict(this.granted, this.message);
}

class EvtDelivered extends BleEvent {
  const EvtDelivered();
}

class EvtUnavailable extends BleEvent {
  final WaveError error;
  const EvtUnavailable(this.error);
}

/// Abstraction over the BLE stack. The real one bridges a platform channel to
/// CoreBluetooth / Android BLE; tests use MockTransport.
abstract class BleTransport {
  Stream<BleEvent> events();
  Future<void> write(Uint8List payload);
  void stop();
}

/// Scripted transport for tests and mock previews.
class MockTransport implements BleTransport {
  final List<BleEvent> scripted;
  final Duration interEventDelay;
  Uint8List? writtenPayload;
  bool stopped = false;

  MockTransport(this.scripted, {this.interEventDelay = const Duration(milliseconds: 10)});

  @override
  Stream<BleEvent> events() async* {
    for (final e in scripted) {
      if (stopped) break;
      yield e;
      await Future.delayed(interEventDelay);
    }
  }

  @override
  Future<void> write(Uint8List payload) async {
    writtenPayload = payload;
  }

  @override
  void stop() {
    stopped = true;
  }
}
