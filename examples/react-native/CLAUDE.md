# Wave Unlock — React Native

```bash
npm install @wave/unlock-react-native
cd ios && pod install   # links the Swift core
```

```tsx
import { WaveUnlock } from "@wave/unlock-react-native";

const wave = new WaveUnlock({
  gatewayUrl: "https://app.wavepassport.com/api",
  anonKey: "<supabase anon key>",
  publishableKey: "wave_pub_…",
  userNumber: "10001",
});

async function unlock() {
  for await (const state of wave.unlock()) {
    if (state.kind === "granted") open();
    if (state.kind === "denied") toast(state.reason);
  }
}
```

- **iOS:** `Info.plist` → `NSBluetoothAlwaysUsageDescription` + `UIBackgroundModes` `bluetooth-central`.
- **Android:** `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` in the manifest, requested at runtime.

The native module runs the Swift/Kotlin `UnlockEngine` and streams each state to JS.
