package com.wave.unlock.android

// NOTE: This file depends on the Android SDK (android.bluetooth.*) and is compiled
// by the consuming Android app / the `com.android.library` module — NOT by the pure
// Kotlin JVM core build. It is the Android counterpart of Swift's CoreBluetoothTransport.
// Carries forward the hard-won behaviors from the shipping Wave Passport Android app:
//   - strongest-RSSI selection over a 400ms settle window (multi-door)
//   - writeType = WRITE_TYPE_NO_RESPONSE; never wait for a notify (deadlocks SKBluTag)
//   - disconnect ~1.5s after the write
//
// Requires manifest permissions BLUETOOTH_SCAN + BLUETOOTH_CONNECT (API 31+).

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import com.wave.unlock.BleEvent
import com.wave.unlock.BleTransport
import com.wave.unlock.WaveError
import com.wave.unlock.WaveProtocol
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import java.util.UUID

@SuppressLint("MissingPermission")
class AndroidBleTransport(
    private val context: Context,
    private val threshold: Int = WaveProtocol.DEFAULT_RSSI_THRESHOLD,
) : BleTransport {

    private val serviceUuid = UUID.fromString(WaveProtocol.SERVICE_UUID)
    private val writeUuid = UUID.fromString(WaveProtocol.WRITE_CHARACTERISTIC_UUID)
    private val statusUuid = UUID.fromString(WaveProtocol.NOTIFY_STATUS_UUID)
    private val messageUuid = UUID.fromString(WaveProtocol.NOTIFY_MESSAGE_UUID)

    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var pending: ByteArray? = null
    private var lastMessage = ""
    private val candidates = mutableMapOf<String, Pair<BluetoothDevice, Int>>()
    private var chosen = false

    override fun events(): Flow<BleEvent> = callbackFlow {
        val scanner = adapter?.bluetoothLeScanner
        if (adapter?.isEnabled != true || scanner == null) {
            trySend(BleEvent.Unavailable(WaveError.BLUETOOTH_OFF)); awaitClose { }; return@callbackFlow
        }

        val gattCallback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothGatt.STATE_CONNECTED) g.discoverServices()
            }
            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val svc = g.getService(serviceUuid) ?: return
                writeChar = svc.getCharacteristic(writeUuid)
                listOf(statusUuid, messageUuid).forEach { uuid ->
                    svc.getCharacteristic(uuid)?.let { g.setCharacteristicNotification(it, true) }
                }
                flushWrite()
            }
            override fun onCharacteristicChanged(g: BluetoothGatt, ch: BluetoothGattCharacteristic, value: ByteArray) {
                when (ch.uuid) {
                    messageUuid -> lastMessage = String(value)
                    statusUuid -> when (value.firstOrNull()) {
                        WaveProtocol.STATUS_GRANTED -> trySend(BleEvent.Verdict(true, lastMessage.ifEmpty { "Granted" }))
                        WaveProtocol.STATUS_DENIED -> trySend(BleEvent.Verdict(false, lastMessage))
                        WaveProtocol.STATUS_DELIVERED -> trySend(BleEvent.Delivered)
                    }
                }
            }
        }

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (result.rssi < threshold) return
                candidates[result.device.address] = result.device to result.rssi
                // settle then connect to strongest
                if (!chosen) {
                    chosen = true
                    android.os.Handler(context.mainLooper).postDelayed({
                        val best = candidates.values.maxByOrNull { it.second } ?: return@postDelayed
                        scanner.stopScan(this)
                        trySend(BleEvent.ReaderFound(best.second))
                        gatt = best.first.connectGatt(context, false, gattCallback)
                    }, WaveProtocol.RSSI_SETTLE_WINDOW_MS)
                }
            }
        }

        scanner.startScan(scanCallback)
        awaitClose { scanner.stopScan(scanCallback); gatt?.disconnect() }
    }

    private fun flushWrite() {
        val payload = pending ?: return
        val ch = writeChar ?: return
        ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        @Suppress("DEPRECATION")
        run { ch.value = payload; gatt?.writeCharacteristic(ch) }
        pending = null
        android.os.Handler(context.mainLooper).postDelayed({ gatt?.disconnect() }, WaveProtocol.DISCONNECT_DELAY_MS)
    }

    override suspend fun write(payload: ByteArray) { pending = payload; flushWrite() }
    override fun stop() { gatt?.disconnect() }
}
