library wave_unlock;

import 'src/engine.dart';
import 'src/gateway.dart';
import 'src/http_gateway.dart';
import 'src/state.dart';
import 'src/transport.dart';

export 'src/protocol.dart';
export 'src/state.dart';
export 'src/gateway.dart';
export 'src/transport.dart';
export 'src/denials.dart' show friendly, denialTableLength;
export 'src/engine.dart' show runUnlock;
export 'src/http_gateway.dart';

/// Public facade. `unlock()` returns a Stream of states.
///
/// ```dart
/// final wave = WaveUnlock(config);
/// await for (final state in wave.unlock()) { render(state); }
/// ```
class WaveUnlock {
  final WaveConfig config;
  final BleTransport? _transport;
  final Gateway _gateway;

  WaveUnlock(this.config, {BleTransport? transport, Gateway? gateway})
      : _transport = transport,
        _gateway = gateway ?? HttpGateway(config);

  Stream<UnlockState> unlock() {
    final t = _transport;
    if (t == null) {
      throw StateError('A BleTransport must be provided until the platform channel ships.');
    }
    return runUnlock(t, _gateway, config);
  }
}
