import 'dart:async';
import 'denials.dart';
import 'gateway.dart';
import 'protocol.dart';
import 'state.dart';
import 'transport.dart';

/// Streams an unlock through its states: scan -> proximity gate -> write ->
/// await verdict (direct-BLE or cloud) -> terminal. Mirrors the native cores.
Stream<UnlockState> runUnlock(
  BleTransport transport,
  Gateway? gateway,
  WaveConfig config, {
  int threshold = WaveProtocol.defaultRssiThreshold,
  Duration scanTimeout = const Duration(milliseconds: WaveProtocol.scanTimeoutMs),
  Duration cloudTimeout = const Duration(milliseconds: WaveProtocol.cloudConfirmationTimeoutMs),
}) {
  final ctrl = StreamController<UnlockState>();

  () async {
    ctrl.add(const Scanning());
    final done = Completer<UnlockState>();
    var wrote = false;

    final scanTimer = Timer(scanTimeout, () {
      if (!wrote && !done.isCompleted) done.complete(const TimedOut());
    });

    late StreamSubscription<BleEvent> sub;
    sub = transport.events().listen((event) async {
      switch (event) {
        case EvtUnavailable(:final error):
          if (!done.isCompleted) done.complete(Failed(error));
        case EvtReaderFound(:final rssi):
          if (wrote) return;
          if (rssi >= threshold) {
            wrote = true;
            ctrl.add(ReaderFound(rssi));
            ctrl.add(const Writing());
            try {
              await transport.write(WaveProtocol.payload(config.userNumber));
            } catch (_) {
              if (!done.isCompleted) done.complete(const Failed(WaveError.writeFailed));
              return;
            }
            ctrl.add(const AwaitingConfirmation());
            Timer(cloudTimeout, () {
              if (!done.isCompleted) done.complete(const TimedOut());
            });
            if (gateway != null) {
              unawaited(() async {
                final token = await gateway.fetchToken().then<String?>((t) => t).catchError((_) => null);
                if (token == null) return;
                final o = await gateway.awaitOutcome(token, cloudTimeout);
                final UnlockState? s = switch (o.status) {
                  OutcomeStatus.granted => Granted(friendly(o.reason)),
                  OutcomeStatus.denied => Denied(friendly(o.reason)),
                  OutcomeStatus.pending => null,
                };
                if (s != null && !done.isCompleted) done.complete(s);
              }());
            }
          } else {
            ctrl.add(TooFar(rssi));
          }
        case EvtVerdict(:final granted, :final message):
          if (wrote && !done.isCompleted) {
            done.complete(granted ? Granted(friendly(message)) : Denied(friendly(message)));
          }
        case EvtDelivered():
          if (wrote && !done.isCompleted) done.complete(const Granted('Key sent'));
      }
    });

    final terminal = await done.future;
    scanTimer.cancel();
    await sub.cancel();
    transport.stop();
    ctrl.add(terminal);
    await ctrl.close();
  }();

  return ctrl.stream;
}
