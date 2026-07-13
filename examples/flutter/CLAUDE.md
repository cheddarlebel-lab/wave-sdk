# Wave Unlock — Flutter

Add `wave_unlock` to `pubspec.yaml` (from `packages/flutter`), then:

```dart
import 'package:wave_unlock/wave_unlock.dart';

// Gateway URL defaults to the branded production gateway — no backend key needed.
final wave = WaveUnlock(const WaveConfig(publishableKey: 'wave_pub_…', userNumber: '10001'));

await for (final state in wave.unlock()) {
  switch (state) {
    case Granted(:final reason): open(reason); break;
    case Denied(:final reason):  toast(reason); break;
    default: break;
  }
}
```

- **iOS:** `Info.plist` → `NSBluetoothAlwaysUsageDescription` + `UIBackgroundModes` `bluetooth-central`.
- **Android:** `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT`, requested at runtime.

No hardware? Inject a mock: `WaveUnlock(config, transport: MockTransport([EvtReaderFound(-50), EvtVerdict(true, 'Granted')]))`.
The native plugin runs the Swift/Kotlin `UnlockEngine` and streams states over an EventChannel.
