package com.muhammadahmad.ble_peripheral_central

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/** BlePeripheralCentralPlugin */
class BlePeripheralCentralPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var loggingEnabled = false
    
    // ==================== Peripheral (Server) State ====================
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var serverServiceUuid: UUID? = null
    private var serverTxUuid: UUID? = null
    private var serverRxUuid: UUID? = null
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null
    private val subscribers = Collections.synchronizedSet(mutableSetOf<BluetoothDevice>())
    
    // ==================== Central (Client) State ====================
    private var scanner: BluetoothLeScanner? = null
    private val gattClients = ConcurrentHashMap<String, BluetoothGatt>()
    private val connectedDevices = ConcurrentHashMap<String, BluetoothDevice>()
    private val deviceCallbacks = ConcurrentHashMap<String, BluetoothGattCallback>()
    private var scanCallback: ScanCallback? = null
    private var isScanning = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "ble_peripheral_central/methods")
        methodChannel.setMethodCallHandler(this)
        
        val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_peripheral_central/events")
        eventChannel.setStreamHandler(this)
        
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventSink = null
        
        // Clean up all resources
        try {
            stopAll()
        } catch (e: Exception) {
            log("Error during cleanup: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Peripheral operations
            "startPeripheral" -> {
                val serviceUuid = call.argument<String>("serviceUuid") ?: ""
                val txUuid = call.argument<String>("txUuid") ?: ""
                val rxUuid = call.argument<String>("rxUuid") ?: ""
                startPeripheral(serviceUuid, txUuid, rxUuid, result)
            }
            "stopPeripheral" -> {
                stopPeripheral(result)
            }
            "sendNotification" -> {
                val charUuid = call.argument<String>("charUuid") ?: ""
                val value = call.argument<ByteArray>("value") ?: byteArrayOf()
                sendNotification(charUuid, value, result)
            }
            // Central operations
            "startScan" -> {
                val serviceUuid = call.argument<String>("serviceUuid") ?: ""
                startScan(serviceUuid, result)
            }
            "stopScan" -> {
                stopScan(result)
            }
            "connect" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                connect(deviceId, result)
            }
            "disconnect" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                disconnect(deviceId, result)
            }
            "disconnectAll" -> {
                disconnectAll(result)
            }
            "writeCharacteristic" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                val charUuid = call.argument<String>("charUuid") ?: ""
                val value = call.argument<ByteArray>("value") ?: byteArrayOf()
                writeCharacteristic(deviceId, charUuid, value, result)
            }
            "requestMtu" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                val mtu = call.argument<Int>("mtu") ?: 512
                requestMtu(deviceId, mtu, result)
            }
            // Connection management
            "getConnectedDevices" -> {
                getConnectedDevices(result)
            }
            "isDeviceConnected" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                isDeviceConnected(deviceId, result)
            }
            // Utilities
            "enableLogs" -> {
                val enable = call.argument<Boolean>("enable") ?: false
                loggingEnabled = enable
                result.success(null)
            }
            "isBluetoothOn" -> {
                isBluetoothOn(result)
            }
            "stopAll" -> {
                stopAll()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        log("Event channel cancelled")
    }

    private fun sendEvent(event: Map<String, Any?>) {
        val sink = eventSink
        if (sink != null) {
            mainHandler.post {
                try {
                    sink.success(event)
                } catch (e: Exception) {
                    log("Error sending event: ${e.message}")
                }
            }
        }
    }

    private fun log(message: String) {
        if (loggingEnabled) {
            Log.d("BlePeripheralCentral", message)
        }
    }

    // ==================== Peripheral Operations ====================

    private fun startPeripheral(serviceUuid: String, txUuid: String, rxUuid: String, result: Result) {
        try {
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                result.error("BLUETOOTH_OFF", "Bluetooth is not enabled", null)
                return
            }

            this.serverServiceUuid = UUID.fromString(serviceUuid)
            this.serverTxUuid = UUID.fromString(txUuid)
            this.serverRxUuid = UUID.fromString(rxUuid)

            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            gattServer = bluetoothManager.openGattServer(context, gattServerCallback)

            // Create service
            val service = BluetoothGattService(serverServiceUuid!!, BluetoothGattService.SERVICE_TYPE_PRIMARY)

            // Create TX characteristic (notify)
            txCharacteristic = BluetoothGattCharacteristic(
                serverTxUuid!!,
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_READ
            )
            val txDescriptor = BluetoothGattDescriptor(
                UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
                BluetoothGattDescriptor.PERMISSION_WRITE
            )
            txCharacteristic!!.addDescriptor(txDescriptor)
            service.addCharacteristic(txCharacteristic)

            // Create RX characteristic (write)
            rxCharacteristic = BluetoothGattCharacteristic(
                serverRxUuid!!,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            service.addCharacteristic(rxCharacteristic)

            gattServer?.addService(service)

            // Start advertising
            advertiser = bluetoothAdapter!!.bluetoothLeAdvertiser
            val advertiseSettings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setConnectable(true)
                .setTimeout(0)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .build()

            val advertiseData = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(serverServiceUuid!!))
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    log("Advertising started successfully")
                    sendEvent(mapOf("type" to "advertising_started"))
                    sendEvent(mapOf("type" to "peripheral_started"))
                }

                override fun onStartFailure(errorCode: Int) {
                    log("Advertising failed with error: $errorCode")
                    sendEvent(mapOf("type" to "advertising_failed", "code" to errorCode))
                    result.error("ADVERTISING_FAILED", "Failed to start advertising: $errorCode", null)
                }
            }

            try {
                advertiser?.startAdvertising(advertiseSettings, advertiseData, advertiseCallback)
                result.success(null)
            } catch (e: Exception) {
                log("Error starting advertising: ${e.message}")
                result.error("ADVERTISING_START_ERROR", e.message, null)
                return
            }
        } catch (e: Exception) {
            log("Error starting peripheral: ${e.message}")
            result.error("START_PERIPHERAL_ERROR", e.message, null)
        }
    }

    private fun stopPeripheral(result: Result) {
        try {
            advertiseCallback?.let {
                advertiser?.stopAdvertising(it)
                advertiseCallback = null
            }
            
            gattServer?.clearServices()
            gattServer?.close()
            gattServer = null
            
            subscribers.clear()
            advertiser = null
            
            sendEvent(mapOf("type" to "peripheral_stopped"))
            result.success(null)
        } catch (e: Exception) {
            log("Error stopping peripheral: ${e.message}")
            result.error("STOP_PERIPHERAL_ERROR", e.message, null)
        }
    }

    private fun sendNotification(charUuid: String, value: ByteArray, result: Result) {
        try {
            val uuid = UUID.fromString(charUuid)
            val characteristic = if (uuid == serverTxUuid) txCharacteristic else null
            
            if (characteristic == null) {
                result.error("CHARACTERISTIC_NOT_FOUND", "Characteristic not found: $charUuid", null)
                return
            }

            characteristic.value = value
            var notified = false
            
            synchronized(subscribers) {
                subscribers.forEach { device ->
                    val notifiedDevice = gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                    if (notifiedDevice == true) {
                        notified = true
                    }
                }
            }

            if (notified) {
                result.success(null)
            } else {
                result.error("NO_SUBSCRIBERS", "No subscribed devices", null)
            }
        } catch (e: Exception) {
            log("Error sending notification: ${e.message}")
            result.error("SEND_NOTIFICATION_ERROR", e.message, null)
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            val deviceId = device.address
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    log("Device connected: $deviceId")
                    sendEvent(mapOf(
                        "type" to "server_connected",
                        "deviceId" to deviceId,
                        "name" to (device.name ?: "Unknown")
                    ))
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    log("Device disconnected: $deviceId")
                    subscribers.remove(device)
                    sendEvent(mapOf(
                        "type" to "server_disconnected",
                        "deviceId" to deviceId
                    ))
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, characteristic.value)
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (characteristic.uuid == serverRxUuid) {
                sendEvent(mapOf(
                    "type" to "rx",
                    "charUuid" to characteristic.uuid.toString(),
                    "value" to value,
                    "deviceId" to device.address
                ))
            }
            
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (descriptor.uuid == UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")) {
                val enabled = value.isNotEmpty() && (value[0].toInt() and 0x01) != 0
                if (enabled) {
                    subscribers.add(device)
                    log("Device subscribed to notifications: ${device.address}")
                } else {
                    subscribers.remove(device)
                    log("Device unsubscribed from notifications: ${device.address}")
                }
            }
            
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            log("MTU changed for ${device.address}: $mtu")
            sendEvent(mapOf(
                "type" to "mtu_changed",
                "deviceId" to device.address,
                "mtu" to mtu
            ))
        }
    }

    // ==================== Central Operations ====================

    @SuppressLint("MissingPermission")
    private fun startScan(serviceUuid: String, result: Result) {
        try {
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                result.error("BLUETOOTH_OFF", "Bluetooth is not enabled", null)
                return
            }

            if (isScanning) {
                result.success(null)
                return
            }

            scanner = bluetoothAdapter!!.bluetoothLeScanner
            val scanFilters = mutableListOf<ScanFilter>()
            
            if (serviceUuid.isNotEmpty()) {
                val uuid = ParcelUuid(UUID.fromString(serviceUuid))
                scanFilters.add(ScanFilter.Builder().setServiceUuid(uuid).build())
            }

            val scanSettings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val device = result.device
                    val deviceId = device.address
                    log("Scan result: $deviceId, RSSI: ${result.rssi}")
                    sendEvent(mapOf(
                        "type" to "scanResult",
                        "deviceId" to deviceId,
                        "name" to (device.name ?: "Unknown"),
                        "rssi" to result.rssi
                    ))
                }

                override fun onBatchScanResults(results: MutableList<ScanResult>) {
                    results.forEach { result ->
                        val device = result.device
                        val deviceId = device.address
                        sendEvent(mapOf(
                            "type" to "scanResult",
                            "deviceId" to deviceId,
                            "name" to (device.name ?: "Unknown"),
                            "rssi" to result.rssi
                        ))
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    log("Scan failed with error: $errorCode")
                    sendEvent(mapOf("type" to "scan_failed", "code" to errorCode))
                }
            }

            scanner?.startScan(scanFilters, scanSettings, scanCallback)
            isScanning = true
            sendEvent(mapOf("type" to "scan_started"))
            result.success(null)
        } catch (e: Exception) {
            log("Error starting scan: ${e.message}")
            result.error("START_SCAN_ERROR", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopScan(result: Result) {
        try {
            scanCallback?.let {
                scanner?.stopScan(it)
                scanCallback = null
            }
            isScanning = false
            sendEvent(mapOf("type" to "scan_stopped"))
            result.success(null)
        } catch (e: Exception) {
            log("Error stopping scan: ${e.message}")
            result.error("STOP_SCAN_ERROR", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(deviceId: String, result: Result) {
        try {
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                result.error("BLUETOOTH_OFF", "Bluetooth is not enabled", null)
                return
            }

            val device = bluetoothAdapter!!.getRemoteDevice(deviceId)
            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found: $deviceId", null)
                return
            }

            if (gattClients.containsKey(deviceId)) {
                result.error("ALREADY_CONNECTED", "Device already connected", null)
                return
            }

            sendEvent(mapOf("type" to "connecting", "deviceId" to deviceId))
            
            val callback = createGattClientCallback(deviceId)
            deviceCallbacks[deviceId] = callback
            
            val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
            } else {
                @Suppress("DEPRECATION")
                device.connectGatt(context, false, callback)
            }
            
            gattClients[deviceId] = gatt
            result.success(null)
        } catch (e: Exception) {
            log("Error connecting: ${e.message}")
            sendEvent(mapOf(
                "type" to "connectionFailed",
                "deviceId" to deviceId,
                "message" to (e.message ?: "Unknown error")
            ))
            result.error("CONNECT_ERROR", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(deviceId: String, result: Result) {
        try {
            val gatt = gattClients.remove(deviceId)
            connectedDevices.remove(deviceId)
            deviceCallbacks.remove(deviceId)
            
            gatt?.disconnect()
            gatt?.close()
            
            sendEvent(mapOf("type" to "disconnected", "deviceId" to deviceId))
            result.success(null)
        } catch (e: Exception) {
            log("Error disconnecting: ${e.message}")
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun disconnectAll(result: Result) {
        try {
            val deviceIds = gattClients.keys.toList()
            deviceIds.forEach { deviceId ->
                val gatt = gattClients.remove(deviceId)
                connectedDevices.remove(deviceId)
                deviceCallbacks.remove(deviceId)
                gatt?.disconnect()
                gatt?.close()
                sendEvent(mapOf("type" to "disconnected", "deviceId" to deviceId))
            }
            result.success(null)
        } catch (e: Exception) {
            log("Error disconnecting all: ${e.message}")
            result.error("DISCONNECT_ALL_ERROR", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeCharacteristic(deviceId: String, charUuid: String, value: ByteArray, result: Result) {
        try {
            val gatt = gattClients[deviceId]
            if (gatt == null) {
                result.error("NOT_CONNECTED", "Device not connected: $deviceId", null)
                return
            }

            val uuid = UUID.fromString(charUuid)
            val characteristic = findCharacteristic(gatt, uuid)
            
            if (characteristic == null) {
                result.error("CHARACTERISTIC_NOT_FOUND", "Characteristic not found: $charUuid", null)
                return
            }

            characteristic.value = value
            val writeType = if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            }
            characteristic.writeType = writeType

            val success = gatt.writeCharacteristic(characteristic)
            if (success) {
                // Result will be sent via callback
                result.success(null)
            } else {
                result.error("WRITE_FAILED", "Failed to write characteristic", null)
                sendEvent(mapOf(
                    "type" to "write_error",
                    "deviceId" to deviceId,
                    "message" to "Write operation failed"
                ))
            }
        } catch (e: Exception) {
            log("Error writing characteristic: ${e.message}")
            result.error("WRITE_ERROR", e.message, null)
            sendEvent(mapOf(
                "type" to "write_error",
                "deviceId" to deviceId,
                "message" to (e.message ?: "Unknown error")
            ))
        }
    }

    @SuppressLint("MissingPermission")
    private fun requestMtu(deviceId: String, mtu: Int, result: Result) {
        try {
            val gatt = gattClients[deviceId]
            if (gatt == null) {
                result.error("NOT_CONNECTED", "Device not connected: $deviceId", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val success = gatt.requestMtu(mtu)
                if (success) {
                    result.success(null)
                } else {
                    result.error("MTU_REQUEST_FAILED", "Failed to request MTU", null)
                    sendEvent(mapOf(
                        "type" to "mtu_change_failed",
                        "deviceId" to deviceId,
                        "status" to -1
                    ))
                }
        } else {
                result.error("NOT_SUPPORTED", "MTU request not supported on this Android version", null)
            }
        } catch (e: Exception) {
            log("Error requesting MTU: ${e.message}")
            result.error("MTU_ERROR", e.message, null)
        }
    }

    private fun getConnectedDevices(result: Result) {
        result.success(connectedDevices.keys.toList())
    }

    private fun isDeviceConnected(deviceId: String, result: Result) {
        result.success(connectedDevices.containsKey(deviceId))
    }

    private fun isBluetoothOn(result: Result) {
        result.success(bluetoothAdapter?.isEnabled == true)
    }

    @SuppressLint("MissingPermission")
    private fun stopAll() {
        try {
            stopPeripheral(Result { })
            stopScan(Result { })
            disconnectAll(Result { })
        } catch (e: Exception) {
            log("Error stopping all: ${e.message}")
        }
    }

    // ==================== Helper Methods ====================

    @SuppressLint("MissingPermission")
    private fun createGattClientCallback(deviceId: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        log("Connected to device: $deviceId")
                        connectedDevices[deviceId] = gatt.device
                        sendEvent(mapOf("type" to "connected", "deviceId" to deviceId))
                        gatt.discoverServices()
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        log("Disconnected from device: $deviceId")
                        connectedDevices.remove(deviceId)
                        gattClients.remove(deviceId)
                        deviceCallbacks.remove(deviceId)
                        sendEvent(mapOf("type" to "disconnected", "deviceId" to deviceId, "status" to status))
                        gatt.close()
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    log("Services discovered for device: $deviceId")
                    // Automatically subscribe to notify characteristics
                    gatt.services?.forEach { service ->
                        service.characteristics?.forEach { characteristic ->
                            if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 ||
                                characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) {
                                val descriptor = characteristic.getDescriptor(
                                    UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                                )
                                if (descriptor != null) {
                                    gatt.setCharacteristicNotification(characteristic, true)
                                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                    gatt.writeDescriptor(descriptor)
                                }
                            }
                        }
                    }
                } else {
                    log("Service discovery failed for device: $deviceId, status: $status")
                    sendEvent(mapOf(
                        "type" to "connectionFailed",
                        "deviceId" to deviceId,
                        "status" to status
                    ))
                }
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                log("Notification received from device: $deviceId, characteristic: ${characteristic.uuid}")
                sendEvent(mapOf(
                    "type" to "notification",
                    "deviceId" to deviceId,
                    "charUuid" to characteristic.uuid.toString(),
                    "value" to (characteristic.value ?: byteArrayOf())
                ))
            }

            override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                log("Write result for device: $deviceId, characteristic: ${characteristic.uuid}, status: $status")
                sendEvent(mapOf(
                    "type" to "write_result",
                    "deviceId" to deviceId,
                    "charUuid" to characteristic.uuid.toString(),
                    "status" to status
                ))
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    log("MTU changed for device: $deviceId, MTU: $mtu")
                    sendEvent(mapOf(
                        "type" to "mtu_changed",
                        "deviceId" to deviceId,
                        "mtu" to mtu
                    ))
                } else {
                    log("MTU change failed for device: $deviceId, status: $status")
                    sendEvent(mapOf(
                        "type" to "mtu_change_failed",
                        "deviceId" to deviceId,
                        "status" to status
                    ))
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun findCharacteristic(gatt: BluetoothGatt, uuid: UUID): BluetoothGattCharacteristic? {
        gatt.services?.forEach { service ->
            service.characteristics?.forEach { characteristic ->
                if (characteristic.uuid == uuid) {
                    return characteristic
                }
            }
        }
        return null
    }
}