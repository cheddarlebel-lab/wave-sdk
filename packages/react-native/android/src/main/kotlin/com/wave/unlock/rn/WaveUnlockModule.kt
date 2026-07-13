package com.wave.unlock.rn

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.Arguments
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.wave.unlock.*
import com.wave.unlock.android.AndroidBleTransport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

// RN native module: runs the Kotlin UnlockEngine and emits each state as a
// "WaveUnlockState" event. The JS side (stream.ts) turns those into an async iterator.
class WaveUnlockModule(private val ctx: ReactApplicationContext) : ReactContextBaseJavaModule(ctx) {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var job: Job? = null

    override fun getName() = "WaveUnlock"

    private fun emit(payload: WritableMap) {
        ctx.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("WaveUnlockState", payload)
    }

    @ReactMethod
    fun startUnlock(config: ReadableMap) {
        val cfg = WaveConfig(
            publishableKey = config.getString("publishableKey") ?: "",
            userNumber = config.getString("userNumber") ?: "",
            gatewayUrl = config.getString("gatewayUrl") ?: "https://app.wavepassport.com/api",
        )
        val engine = UnlockEngine(AndroidBleTransport(ctx), gateway = HttpGateway(cfg))
        job?.cancel()
        job = scope.launch {
            engine.unlock(WaveProtocol.payload(cfg.userNumber)).collect { emit(encode(it)) }
        }
    }

    @ReactMethod
    fun cancel() { job?.cancel() }

    // RN requires these for the NativeEventEmitter contract.
    @ReactMethod fun addListener(eventName: String) {}
    @ReactMethod fun removeListeners(count: Int) {}

    private fun encode(s: UnlockState): WritableMap {
        val m = Arguments.createMap()
        m.putString("kind", s.label)
        when (s) {
            is UnlockState.ReaderFound -> m.putInt("rssi", s.rssi)
            is UnlockState.TooFar -> m.putInt("rssi", s.rssi)
            is UnlockState.Granted -> s.reason?.let { m.putString("reason", it) }
            is UnlockState.Denied -> m.putString("reason", s.reason)
            is UnlockState.Failed -> m.putString("error", s.error.name)
            else -> {}
        }
        return m
    }
}
