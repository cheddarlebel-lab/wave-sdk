# Wave Unlock — Kotlin (Android)

Depend on the core (`com.wave:wave-unlock`) and include `AndroidBleTransport` (from
`packages/kotlin/android`). Then:

```kotlin
import com.wave.unlock.*
import com.wave.unlock.android.AndroidBleTransport

val cfg = WaveConfig(
    gatewayUrl = "https://app.wavepassport.com/api",
    anonKey = "<supabase anon key>",
    publishableKey = "wave_pub_…",
    userNumber = "10001",
)

val engine = UnlockEngine(AndroidBleTransport(context), gateway = HttpGateway(cfg))

lifecycleScope.launch {
    engine.unlock(WaveProtocol.payload(cfg.userNumber)).collect { state ->
        when (state) {
            is UnlockState.Granted -> open(state.reason)
            is UnlockState.Denied  -> toast(state.reason)
            else -> {}
        }
    }
}
```

**Manifest:** add `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions (API 31+), request at runtime.

No hardware? Drive the engine with `MockTransport(listOf(BleEvent.ReaderFound(-50), BleEvent.Verdict(true, "Granted")))`.
