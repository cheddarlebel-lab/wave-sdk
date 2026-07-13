/// States an unlock streams through. Labels match contract/conformance/state-sequences.json.
sealed class UnlockState {
  const UnlockState();
  String get label;
}

class Scanning extends UnlockState {
  const Scanning();
  @override
  String get label => 'scanning';
}

class ReaderFound extends UnlockState {
  final int rssi;
  const ReaderFound(this.rssi);
  @override
  String get label => 'readerFound';
}

class TooFar extends UnlockState {
  final int rssi;
  const TooFar(this.rssi);
  @override
  String get label => 'tooFar';
}

class Writing extends UnlockState {
  const Writing();
  @override
  String get label => 'writing';
}

class AwaitingConfirmation extends UnlockState {
  const AwaitingConfirmation();
  @override
  String get label => 'awaitingConfirmation';
}

class Granted extends UnlockState {
  final String? reason;
  const Granted(this.reason);
  @override
  String get label => 'granted';
}

class Denied extends UnlockState {
  final String reason;
  const Denied(this.reason);
  @override
  String get label => 'denied';
}

class TimedOut extends UnlockState {
  const TimedOut();
  @override
  String get label => 'timedOut';
}

enum WaveError { bluetoothOff, permissionDenied, writeFailed, network, auth }

class Failed extends UnlockState {
  final WaveError error;
  const Failed(this.error);
  @override
  String get label => 'failed';
}
