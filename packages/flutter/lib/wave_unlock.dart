library wave_unlock;

import 'package:flutter/services.dart';
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

  static const _methods = MethodChannel('wave_unlock/control');
  static const _events = EventChannel('wave_unlock/states');

  /// Streams unlock states. With an injected transport (tests/mocks) the Dart
  /// engine drives it; otherwise the native plugin runs the core engine and
  /// streams states over the platform EventChannel.
  Stream<UnlockState> unlock() {
    final t = _transport;
    if (t != null) return runUnlock(t, _gateway, config);
    _methods.invokeMethod('startUnlock', {
      'gatewayUrl': config.gatewayUrl,
      'publishableKey': config.publishableKey,
      'userNumber': config.userNumber,
    });
    return _events.receiveBroadcastStream().map((e) => _decode(e as Map));
  }

  static UnlockState _decode(Map e) {
    switch (e['kind'] as String) {
      case 'scanning':
        return const Scanning();
      case 'readerFound':
        return ReaderFound((e['rssi'] as num?)?.toInt() ?? 0);
      case 'tooFar':
        return TooFar((e['rssi'] as num?)?.toInt() ?? 0);
      case 'writing':
        return const Writing();
      case 'awaitingConfirmation':
        return const AwaitingConfirmation();
      case 'granted':
        return Granted(e['reason'] as String?);
      case 'denied':
        return Denied(e['reason'] as String? ?? 'Access denied');
      case 'timedOut':
        return const TimedOut();
      default:
        return const Failed(WaveError.network);
    }
  }
}
