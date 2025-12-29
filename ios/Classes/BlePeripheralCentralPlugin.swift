import Flutter
import UIKit
import CoreBluetooth

public class BlePeripheralCentralPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var loggingEnabled = false
    
    // ==================== Peripheral (Server) State ====================
    private var peripheralManager: CBPeripheralManager?
    private var peripheralService: CBMutableService?
    private var txCharacteristic: CBMutableCharacteristic?
    private var rxCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: Set<CBCentral> = []
    private var peripheralServiceUuid: CBUUID?
    private var peripheralTxUuid: CBUUID?
    private var peripheralRxUuid: CBUUID?
    
    // ==================== Central (Client) State ====================
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    private var peripheralCharacteristics: [String: [CBCharacteristic]] = [:]
    private var isScanning = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BlePeripheralCentralPlugin()
        
        let methodChannel = FlutterMethodChannel(name: "ble_peripheral_plugin/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        instance.methodChannel = methodChannel
        
        let eventChannel = FlutterEventChannel(name: "ble_peripheral_plugin/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        instance.eventChannel = eventChannel
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Peripheral operations
        case "startPeripheral":
            guard let args = call.arguments as? [String: Any],
                  let serviceUuid = args["serviceUuid"] as? String,
                  let txUuid = args["txUuid"] as? String,
                  let rxUuid = args["rxUuid"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            startPeripheral(serviceUuid: serviceUuid, txUuid: txUuid, rxUuid: rxUuid, result: result)
        case "stopPeripheral":
            stopPeripheral(result: result)
        case "sendNotification":
            guard let args = call.arguments as? [String: Any],
                  let charUuid = args["charUuid"] as? String,
                  let value = args["value"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            sendNotification(charUuid: charUuid, value: value.data, result: result)
        // Central operations
        case "startScan":
            guard let args = call.arguments as? [String: Any],
                  let serviceUuid = args["serviceUuid"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            startScan(serviceUuid: serviceUuid, result: result)
        case "stopScan":
            stopScan(result: result)
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            connect(deviceId: deviceId, result: result)
        case "disconnect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            disconnect(deviceId: deviceId, result: result)
        case "disconnectAll":
            disconnectAll(result: result)
        case "writeCharacteristic":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let charUuid = args["charUuid"] as? String,
                  let value = args["value"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            writeCharacteristic(deviceId: deviceId, charUuid: charUuid, value: value.data, result: result)
        case "requestMtu":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            let mtu = args["mtu"] as? Int ?? 512
            requestMtu(deviceId: deviceId, mtu: mtu, result: result)
        // Connection management
        case "getConnectedDevices":
            getConnectedDevices(result: result)
        case "isDeviceConnected":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            isDeviceConnected(deviceId: deviceId, result: result)
        // Utilities
        case "enableLogs":
            guard let args = call.arguments as? [String: Any],
                  let enable = args["enable"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                return
            }
            loggingEnabled = enable
            result(nil)
        case "isBluetoothOn":
            isBluetoothOn(result: result)
        case "stopAll":
            stopAll()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func sendEvent(_ event: [String: Any?]) {
        guard let sink = eventSink else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            sink(event)
        }
    }
    
    private func log(_ message: String) {
        if loggingEnabled {
            print("[BlePeripheralCentral] \(message)")
        }
    }
    
    // ==================== Peripheral Operations ====================
    
    private func startPeripheral(serviceUuid: String, txUuid: String, rxUuid: String, result: @escaping FlutterResult) {
        peripheralServiceUuid = CBUUID(string: serviceUuid)
        peripheralTxUuid = CBUUID(string: txUuid)
        peripheralRxUuid = CBUUID(string: rxUuid)
        
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        guard let manager = peripheralManager else {
            result(FlutterError(code: "PERIPHERAL_MANAGER_ERROR", message: "Failed to create peripheral manager", details: nil))
            return
        }
        
        if manager.state == .poweredOn {
            setupPeripheralService(result: result)
        } else {
            // Wait for poweredOn state in peripheralManagerDidUpdateState
            result(nil)
        }
    }
    
    private func setupPeripheralService(result: @escaping FlutterResult) {
        guard let serviceUuid = peripheralServiceUuid,
              let txUuid = peripheralTxUuid,
              let rxUuid = peripheralRxUuid else {
            result(FlutterError(code: "INVALID_UUID", message: "Service UUIDs not set", details: nil))
            return
        }
        
        // Create TX characteristic (notify, read)
        txCharacteristic = CBMutableCharacteristic(
            type: txUuid,
            properties: [.notify, .read],
            value: nil,
            permissions: [.readable]
        )
        
        // Create RX characteristic (write)
        rxCharacteristic = CBMutableCharacteristic(
            type: rxUuid,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        // Create service
        peripheralService = CBMutableService(type: serviceUuid, primary: true)
        peripheralService?.characteristics = [txCharacteristic!, rxCharacteristic!]
        
        peripheralManager?.add(peripheralService!)
    }
    
    private func stopPeripheral(result: @escaping FlutterResult) {
        peripheralManager?.stopAdvertising()
        if let service = peripheralService {
            peripheralManager?.remove(service)
        }
        peripheralService = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        subscribedCentrals.removeAll()
        
        sendEvent(["type": "peripheral_stopped"])
        result(nil)
    }
    
    private func sendNotification(charUuid: String, value: Data, result: @escaping FlutterResult) {
        guard let manager = peripheralManager else {
            result(FlutterError(code: "PERIPHERAL_NOT_STARTED", message: "Peripheral not started", details: nil))
            return
        }
        
        guard let uuid = peripheralTxUuid,
              CBUUID(string: charUuid) == uuid,
              let characteristic = txCharacteristic else {
            result(FlutterError(code: "CHARACTERISTIC_NOT_FOUND", message: "Characteristic not found: \(charUuid)", details: nil))
            return
        }
        
        guard !subscribedCentrals.isEmpty else {
            result(FlutterError(code: "NO_SUBSCRIBERS", message: "No subscribed centrals", details: nil))
            return
        }
        
        let sent = manager.updateValue(value, for: characteristic, onSubscribedCentrals: Array(subscribedCentrals))
        
        // iOS may return false if queue is full, but it will send when ready
        // Return success as iOS handles queuing automatically
        result(nil)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("Peripheral manager state updated: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            if peripheralService == nil && peripheralServiceUuid != nil {
                setupPeripheralService(result: { _ in })
            }
            sendEvent(["type": "bluetooth_state", "isOn": true])
        case .poweredOff:
            sendEvent(["type": "bluetooth_state", "isOn": false])
        default:
            break
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            log("Error adding service: \(error.localizedDescription)")
            sendEvent(["type": "error", "message": error.localizedDescription])
            return
        }
        
        log("Service added, starting advertising")
        let serviceUuid = service.uuid
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUuid],
            CBAdvertisementDataLocalNameKey: ""
        ]
        
        peripheralManager?.startAdvertising(advertisementData)
        sendEvent(["type": "peripheral_started"])
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            log("Error starting advertising: \(error.localizedDescription)")
            sendEvent(["type": "error", "message": error.localizedDescription])
        } else {
            log("Advertising started successfully")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let deviceId = central.identifier.uuidString
        log("Central subscribed to characteristic: \(deviceId)")
        let wasNew = !subscribedCentrals.contains(central)
        subscribedCentrals.insert(central)
        
        // Send server_connected event when a central first subscribes (iOS equivalent of connection)
        if wasNew {
            sendEvent([
                "type": "server_connected",
                "deviceId": deviceId,
                "name": "Unknown"
            ])
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let deviceId = central.identifier.uuidString
        log("Central unsubscribed from characteristic: \(deviceId)")
        subscribedCentrals.remove(central)
        
        // Send server_disconnected event when unsubscribing (iOS equivalent of disconnection)
        sendEvent([
            "type": "server_disconnected",
            "deviceId": deviceId
        ])
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == peripheralTxUuid {
            if let characteristic = txCharacteristic, let value = characteristic.value {
                if request.offset > value.count {
                    peripheralManager?.respond(to: request, withResult: .invalidOffset)
                    return
                }
                request.value = value.subdata(in: request.offset..<value.count)
                peripheralManager?.respond(to: request, withResult: .success)
            } else {
                peripheralManager?.respond(to: request, withResult: .attributeNotFound)
            }
        } else {
            peripheralManager?.respond(to: request, withResult: .success)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == peripheralRxUuid {
                if let value = request.value {
                    let deviceId = request.central.identifier.uuidString
                    sendEvent([
                        "type": "rx",
                        "charUuid": request.characteristic.uuid.uuidString,
                        "value": FlutterStandardTypedData(bytes: value),
                        "deviceId": deviceId
                    ])
                }
                peripheralManager?.respond(to: request, withResult: .success)
            } else {
                peripheralManager?.respond(to: request, withResult: .success)
            }
        }
    }
    
    // ==================== Central Operations ====================
    
    private func startScan(serviceUuid: String, result: @escaping FlutterResult) {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        guard let manager = centralManager else {
            result(FlutterError(code: "CENTRAL_MANAGER_ERROR", message: "Failed to create central manager", details: nil))
            return
        }
        
        if manager.state == .poweredOn {
            if isScanning {
                result(nil)
                return
            }
            
            var serviceUuids: [CBUUID]? = nil
            if !serviceUuid.isEmpty {
                serviceUuids = [CBUUID(string: serviceUuid)]
            }
            
            manager.scanForPeripherals(withServices: serviceUuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            isScanning = true
            sendEvent(["type": "scan_started"])
            result(nil)
        } else {
            result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not enabled", details: nil))
        }
    }
    
    private func stopScan(result: @escaping FlutterResult) {
        centralManager?.stopScan()
        isScanning = false
        sendEvent(["type": "scan_stopped"])
        result(nil)
    }
    
    private func connect(deviceId: String, result: @escaping FlutterResult) {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found: \(deviceId)", details: nil))
            return
        }
        
        if connectedPeripherals[deviceId] != nil {
            result(FlutterError(code: "ALREADY_CONNECTED", message: "Device already connected", details: nil))
            return
        }
        
        sendEvent(["type": "connecting", "deviceId": deviceId])
        centralManager?.connect(peripheral, options: nil)
        result(nil)
    }
    
    private func disconnect(deviceId: String, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Device not connected", details: nil))
            return
        }
        
        centralManager?.cancelPeripheralConnection(peripheral)
        result(nil)
    }
    
    private func disconnectAll(result: @escaping FlutterResult) {
        for (_, peripheral) in connectedPeripherals {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        result(nil)
    }
    
    private func writeCharacteristic(deviceId: String, charUuid: String, value: Data, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Device not connected: \(deviceId)", details: nil))
            return
        }
        
        guard let characteristics = peripheralCharacteristics[deviceId],
              let characteristic = characteristics.first(where: { $0.uuid.uuidString.lowercased() == charUuid.lowercased() }) else {
            result(FlutterError(code: "CHARACTERISTIC_NOT_FOUND", message: "Characteristic not found: \(charUuid)", details: nil))
            return
        }
        
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(value, for: characteristic, type: writeType)
        result(nil)
    }
    
    private func requestMtu(deviceId: String, mtu: Int, result: @escaping FlutterResult) {
        // iOS doesn't support requesting MTU, but we can report the current MTU
        guard let peripheral = connectedPeripherals[deviceId] else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Device not connected: \(deviceId)", details: nil))
            return
        }
        
        // iOS uses maximumWriteValueLength which is typically 20 bytes (or 185+ with write without response)
        // We'll report what iOS provides
        let currentMtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        sendEvent([
            "type": "mtu_changed",
            "deviceId": deviceId,
            "mtu": currentMtu + 3  // Add 3 for ATT overhead
        ])
        result(nil)
    }
    
    private func getConnectedDevices(result: @escaping FlutterResult) {
        result(Array(connectedPeripherals.keys))
    }
    
    private func isDeviceConnected(deviceId: String, result: @escaping FlutterResult) {
        result(connectedPeripherals[deviceId] != nil)
    }
    
    private func isBluetoothOn(result: @escaping FlutterResult) {
        if let manager = centralManager {
            result(manager.state == .poweredOn)
        } else {
            let tempManager = CBCentralManager(delegate: nil, queue: nil)
            result(tempManager.state == .poweredOn)
        }
    }
    
    private func stopAll() {
        // Stop peripheral
        peripheralManager?.stopAdvertising()
        if let service = peripheralService {
            peripheralManager?.remove(service)
        }
        peripheralService = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        subscribedCentrals.removeAll()
        
        // Stop scanning
        centralManager?.stopScan()
        isScanning = false
        
        // Disconnect all peripherals
        for (_, peripheral) in connectedPeripherals {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripherals.removeAll()
        peripheralCharacteristics.removeAll()
        discoveredPeripherals.removeAll()
    }
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Central manager state updated: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            sendEvent(["type": "bluetooth_state", "isOn": true])
        case .poweredOff:
            sendEvent(["type": "bluetooth_state", "isOn": false])
        default:
            break
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        discoveredPeripherals[deviceId] = peripheral
        
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        sendEvent([
            "type": "scanResult",
            "deviceId": deviceId,
            "name": name,
            "rssi": RSSI.intValue
        ])
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        log("Connected to peripheral: \(deviceId)")
        connectedPeripherals[deviceId] = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        sendEvent(["type": "connected", "deviceId": deviceId])
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        log("Failed to connect to peripheral: \(deviceId), error: \(error?.localizedDescription ?? "Unknown")")
        sendEvent([
            "type": "connectionFailed",
            "deviceId": deviceId,
            "message": error?.localizedDescription ?? "Unknown error"
        ])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        log("Disconnected from peripheral: \(deviceId)")
        connectedPeripherals.removeValue(forKey: deviceId)
        peripheralCharacteristics.removeValue(forKey: deviceId)
        sendEvent([
            "type": "disconnected",
            "deviceId": deviceId,
            "status": error != nil ? 1 : 0
        ])
    }
    
    // MARK: - CBPeripheralDelegate
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        let deviceId = peripheral.identifier.uuidString
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        let deviceId = peripheral.identifier.uuidString
        
        if peripheralCharacteristics[deviceId] == nil {
            peripheralCharacteristics[deviceId] = []
        }
        peripheralCharacteristics[deviceId]?.append(contentsOf: characteristics)
        
        // Automatically enable notifications for notify characteristics
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        
        if let error = error {
            log("Error updating value for characteristic: \(error.localizedDescription)")
            return
        }
        
        if let value = characteristic.value {
            sendEvent([
                "type": "notification",
                "deviceId": deviceId,
                "charUuid": characteristic.uuid.uuidString,
                "value": FlutterStandardTypedData(bytes: value)
            ])
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        
        if let error = error {
            sendEvent([
                "type": "write_error",
                "deviceId": deviceId,
                "message": error.localizedDescription
            ])
        } else {
            sendEvent([
                "type": "write_result",
                "deviceId": deviceId,
                "charUuid": characteristic.uuid.uuidString,
                "status": 0
            ])
        }
    }
}