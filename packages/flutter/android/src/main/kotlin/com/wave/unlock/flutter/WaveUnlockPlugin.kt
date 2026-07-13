package com.wave.unlock.flutter

import android.content.Context
import com.wave.unlock.HttpGateway
import com.wave.unlock.UnlockEngine
import com.wave.unlock.UnlockState
import com.wave.unlock.WaveConfig
import com.wave.unlock.WaveProtocol
import com.wave.unlock.android.AndroidBleTransport
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

// Flutter plugin: runs the Kotlin UnlockEngine and streams each state over an
// EventChannel; startUnlock arrives on a MethodChannel.
class WaveUnlockPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var job: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "wave_unlock/control").apply { setMethodCallHandler(this@WaveUnlockPlugin) }
        events = EventChannel(binding.binaryMessenger, "wave_unlock/states").apply { setStreamHandler(this@WaveUnlockPlugin) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null); events?.setStreamHandler(null); job?.cancel()
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { this.sink = sink }
    override fun onCancel(arguments: Any?) { job?.cancel(); sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "startUnlock") { result.notImplemented(); return }
        val cfg = WaveConfig(
            publishableKey = call.argument("publishableKey") ?: "",
            userNumber = call.argument("userNumber") ?: "",
            gatewayUrl = call.argument("gatewayUrl") ?: "https://app.wavepassport.com/api",
        )
        val engine = UnlockEngine(AndroidBleTransport(context), gateway = HttpGateway(cfg))
        job?.cancel()
        job = scope.launch {
            engine.unlock(WaveProtocol.payload(cfg.userNumber)).collect { sink?.success(encode(it)) }
        }
        result.success(null)
    }

    private fun encode(s: UnlockState): Map<String, Any?> {
        val m = mutableMapOf<String, Any?>("kind" to s.label)
        when (s) {
            is UnlockState.ReaderFound -> m["rssi"] = s.rssi
            is UnlockState.TooFar -> m["rssi"] = s.rssi
            is UnlockState.Granted -> m["reason"] = s.reason
            is UnlockState.Denied -> m["reason"] = s.reason
            is UnlockState.Failed -> m["error"] = s.error.name
            else -> {}
        }
        return m
    }
}
