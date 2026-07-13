import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave_unlock/wave_unlock.dart';

const config = WaveConfig(
  gatewayUrl: 'https://x/functions/v1',
  anonKey: 'anon',
  publishableKey: 'wave_pub_x',
  userNumber: '10001',
);

/// Fake gateway returning a scripted outcome.
class FakeGateway implements Gateway {
  final Outcome outcome;
  FakeGateway(this.outcome);
  @override
  Future<String> fetchToken() async => 'tok';
  @override
  Future<Outcome> readOutcome(String token) async => outcome;
  @override
  Future<Outcome> awaitOutcome(String token, Duration timeout, {Duration poll = const Duration(milliseconds: 500)}) async => outcome;
}

Future<List<String>> labels(Stream<UnlockState> s) async =>
    [await for (final st in s) st].map((e) => e.label).toList();

void main() {
  final fast = {
    'scanTimeout': const Duration(seconds: 1),
    'cloudTimeout': const Duration(milliseconds: 300),
  };

  test('granted via direct-BLE verdict', () async {
    final t = MockTransport([const EvtReaderFound(-50), const EvtVerdict(true, 'Granted')]);
    final seq = await labels(runUnlock(t, null, config, scanTimeout: fast['scanTimeout']!, cloudTimeout: fast['cloudTimeout']!));
    expect(seq, ['scanning', 'readerFound', 'writing', 'awaitingConfirmation', 'granted']);
    expect(t.writtenPayload, Uint8List.fromList([0x01, ...'10001'.codeUnits]));
  });

  test('denied maps a friendly reason', () async {
    final t = MockTransport([const EvtReaderFound(-40), const EvtVerdict(false, 'Client not found')]);
    final states = [await for (final s in runUnlock(t, null, config, scanTimeout: fast['scanTimeout']!, cloudTimeout: fast['cloudTimeout']!)) s];
    expect(states.map((e) => e.label).toList(), ['scanning', 'readerFound', 'writing', 'awaitingConfirmation', 'denied']);
    expect((states.last as Denied).reason, 'Member not found');
  });

  test('granted via cloud gateway', () async {
    final t = MockTransport([const EvtReaderFound(-50)]);
    final gw = FakeGateway(const Outcome(OutcomeStatus.granted, '[mock] Access Granted'));
    final seq = await labels(runUnlock(t, gw, config, scanTimeout: fast['scanTimeout']!, cloudTimeout: fast['cloudTimeout']!));
    expect(seq, ['scanning', 'readerFound', 'writing', 'awaitingConfirmation', 'granted']);
  });

  test('times out with no verdict and no gateway', () async {
    final t = MockTransport([const EvtReaderFound(-50)]);
    final seq = await labels(runUnlock(t, null, config, scanTimeout: fast['scanTimeout']!, cloudTimeout: const Duration(milliseconds: 80)));
    expect(seq.last, 'timedOut');
  });

  test('too far does not write', () async {
    final t = MockTransport([const EvtReaderFound(-90)]);
    final seq = await labels(runUnlock(t, null, config, scanTimeout: const Duration(milliseconds: 200), cloudTimeout: fast['cloudTimeout']!));
    expect(seq.take(2).toList(), ['scanning', 'tooFar']);
    expect(t.writtenPayload, isNull);
  });

  test('bluetooth off fails', () async {
    final t = MockTransport([const EvtUnavailable(WaveError.bluetoothOff)]);
    final seq = await labels(runUnlock(t, null, config, scanTimeout: fast['scanTimeout']!, cloudTimeout: fast['cloudTimeout']!));
    expect(seq, ['scanning', 'failed']);
  });

  test('friendly strips mock tag + matches substrings', () {
    expect(friendly('[mock] Membership expired'), 'Membership expired');
    expect(friendly('Blocked by provider : 604 : Client not found'), 'Member not found');
    expect(friendly(null), 'Access denied');
    expect(denialTableLength, 14);
  });
}
