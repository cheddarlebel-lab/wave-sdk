# Wave Unlock — Swift (iOS / watchOS)

Add the package (`https://github.com/cheddarlebel-lab/wave-sdk`, `packages/swift`) via SPM,
then:

```swift
import WaveUnlock
import WaveUnlockUI  // optional drop-in button

// 1) Configure once (keys from wave_register_app or the Wave dashboard).
// Gateway URL defaults to the branded production gateway — no backend key needed.
Wave.configure(WaveConfig(publishableKey: "wave_pub_…", userNumber: "10001"))

// 2a) Stream the states yourself:
for await state in Wave.unlock() {
    switch state {
    case .granted(let reason): print("open:", reason ?? "")
    case .denied(let reason):  print("denied:", reason)
    default: break
    }
}

// 2b) …or just drop in the button:
WaveUnlockButton()

// No hardware? Preview the flow:
for await s in Wave.mockGranted() { print(s.label) }
```

**Info.plist:** add `NSBluetoothAlwaysUsageDescription` and `UIBackgroundModes` → `bluetooth-central`.
