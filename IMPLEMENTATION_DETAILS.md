# BLE Peripheral-Central Plugin - Complete Implementation Documentation

## Table of Contents
1. [Plugin Overview](#plugin-overview)
2. [Architecture & Design](#architecture--design)
3. [Platform Implementations](#platform-implementations)
4. [API Reference](#api-reference)
5. [Data Flow & Communication](#data-flow--communication)
6. [Event System](#event-system)
7. [Key Features & Capabilities](#key-features--capabilities)
8. [Code Structure](#code-structure)
9. [Usage Examples](#usage-examples)
10. [Platform-Specific Details](#platform-specific-details)
11. [Error Handling](#error-handling)
12. [Threading & Concurrency](#threading--concurrency)

---

## Plugin Overview

### Purpose
This Flutter plugin enables a mobile app to function as both a **BLE Peripheral (GATT Server)** and a **BLE Central (GATT Client)** simultaneously. It provides a unified Dart API that abstracts platform-specific BLE implementations on Android (Kotlin) and iOS (Swift).

### Core Capabilities
- **Peripheral Mode**: Advertise services, accept connections from centrals, send notifications, receive writes
- **Central Mode**: Scan for devices, connect to peripherals, read/write characteristics, receive notifications
- **Multi-Connection Support**: Connect to multiple peripherals simultaneously (central mode)
- **MTU Negotiation**: Request and handle MTU changes for larger data transfers
- **Event-Driven Architecture**: Real-time event stream for all BLE state changes

### Technology Stack
- **Dart/Flutter**: Main plugin interface
- **Kotlin**: Android implementation using Android BLE APIs
- **Swift**: iOS implementation using CoreBluetooth framework
- **Method Channels**: Flutter-to-native communication
- **Event Channels**: Native-to-Flutter event streaming

---

## Architecture & Design

### Plugin Structure

```
ble_peripheral_plugin/
├── lib/
│   ├── ble_peripheral_plugin.dart              # Main public API
│   ├── ble_peripheral_plugin_platform_interface.dart  # Platform interface abstraction
│   └── ble_peripheral_plugin_method_channel.dart      # Method channel implementation
├── android/
│   └── src/main/kotlin/.../BlePeripheralPlugin.kt    # Android implementation
├── ios/
│   └── Classes/BlePeripheralPlugin.swift              # iOS implementation
└── example/                                        # Example app
```

### Communication Channels

#### Method Channel: `ble_peripheral_plugin/methods`
- **Direction**: Flutter → Native
- **Purpose**: Invoke native BLE operations
- **Methods**: All public API calls (startPeripheral, connect, writeCharacteristic, etc.)

#### Event Channel: `ble_peripheral_plugin/events`
- **Direction**: Native → Flutter
- **Purpose**: Stream BLE events and state changes
- **Format**: `Map<String, dynamic>` with `type` field indicating event type

### Design Patterns

1. **Platform Interface Pattern**: Uses `plugin_platform_interface` for testability
2. **Singleton Pattern**: Static methods in Dart, single plugin instance per platform
3. **Observer Pattern**: Event stream for reactive programming
4. **State Management**: Platform-specific state tracking (connections, services, characteristics)

---

## Platform Implementations

### Android Implementation (Kotlin)

#### Key Components

**1. Managers & Adapters**
```kotlin
- BluetoothManager: System service for BLE access
- BluetoothAdapter: Local Bluetooth adapter
- BluetoothLeAdvertiser: For peripheral advertising
- BluetoothLeScanner: For central scanning
- BluetoothGattServer: GATT server for peripheral mode
- BluetoothGatt: GATT client connections
```

**2. State Storage**
```kotlin
// Peripheral state
- gattServer: BluetoothGattServer?
- serverServiceUuid, serverTxUuid, serverRxUuid: UUID?
- txCharacteristic, rxCharacteristic: BluetoothGattCharacteristic?
- subscribers: Set<BluetoothDevice>  // Centrals subscribed to notifications

// Central state (Multi-connection support)
- gattClients: ConcurrentHashMap<String, BluetoothGatt>  // deviceId -> GATT client
- connectedDevices: ConcurrentHashMap<String, BluetoothDevice>
- deviceCallbacks: ConcurrentHashMap<String, BluetoothGattCallback>  // Per-device callbacks
- discoveredPeripherals: Managed via scan results
```

**3. Key Methods**

**Peripheral Operations:**
- `startPeripheral()`: Creates GATT server, adds service with TX/RX characteristics, starts advertising
- `stopPeripheral()`: Stops advertising, closes GATT server
- `sendNotification()`: Sends notification to all subscribed centrals via `gattServer.notifyCharacteristicChanged()`

**Central Operations:**
- `startScan()`: Uses `BluetoothLeScanner` with service UUID filter
- `connect()`: Creates `BluetoothGatt` connection, stores in `gattClients` map
- `writeCharacteristic()`: Writes to specific device's characteristic
- `disconnect()`: Closes GATT connection, removes from maps

**4. Callbacks**

**GATT Server Callback (Peripheral):**
- `onConnectionStateChange`: Tracks central connections/disconnections
- `onCharacteristicWriteRequest`: Receives writes from centrals
- `onDescriptorWriteRequest`: Handles notification subscription (CCCD)
- `onMtuChanged`: Reports MTU changes

**GATT Client Callback (Central):**
- `onConnectionStateChange`: Per-device connection state
- `onServicesDiscovered`: Auto-subscribes to notify characteristics
- `onCharacteristicChanged`: Receives notifications
- `onCharacteristicWrite`: Write confirmation
- `onMtuChanged`: MTU change confirmation

**5. Threading**
- Event sending uses `runOnUiThread` or `Handler(Looper.getMainLooper())` to ensure UI thread execution
- BLE callbacks may run on background threads

### iOS Implementation (Swift)

#### Key Components

**1. Managers**
```swift
- CBPeripheralManager: For peripheral (GATT server) operations
- CBCentralManager: For central (GATT client) operations
```

**2. State Storage**
```swift
// Peripheral state
- peripheralManager: CBPeripheralManager?
- peripheralService: CBMutableService?
- txCharacteristic, rxCharacteristic: CBMutableCharacteristic?
- subscribedCentrals: Set<CBCentral>  // Centrals subscribed to notifications

// Central state (Multi-connection support)
- discoveredPeripherals: [String: CBPeripheral]  // deviceId -> Peripheral
- connectedPeripherals: [String: CBPeripheral]   // deviceId -> Peripheral
- peripheralCharacteristics: [String: [CBCharacteristic]]  // deviceId -> Characteristics
```

**3. Key Methods**

**Peripheral Operations:**
- `startPeripheral()`: Creates mutable service/characteristics, adds to peripheral manager, starts advertising
- `stopPeripheral()`: Stops advertising, removes service
- `sendNotification()`: Uses `peripheralManager.updateValue()` to send to subscribed centrals

**Central Operations:**
- `startScan()`: Uses `CBCentralManager.scanForPeripherals()` with service UUIDs
- `connect()`: Calls `centralManager.connect()` for discovered peripheral
- `writeCharacteristic()`: Writes to specific peripheral's characteristic
- `disconnect()`: Calls `centralManager.cancelPeripheralConnection()`

**4. Delegates**

**CBPeripheralManagerDelegate (Peripheral):**
- `peripheralManagerDidUpdateState`: Bluetooth state changes
- `peripheralManagerDidStartAdvertising`: Advertising status
- `peripheralManager(_:central:didSubscribeTo:)`: Central subscribed to notifications
- `peripheralManager(_:didReceiveWrite:)`: Received writes from centrals

**CBCentralManagerDelegate (Central):**
- `centralManagerDidUpdateState`: Bluetooth state changes
- `centralManager(_:didDiscover:)`: Scan results
- `centralManager(_:didConnect:)`: Connection established
- `centralManager(_:didDisconnectPeripheral:)`: Disconnection

**CBPeripheralDelegate (Connected Peripheral):**
- `peripheral(_:didDiscoverServices:)`: Service discovery
- `peripheral(_:didDiscoverCharacteristicsFor:)`: Characteristic discovery
- `peripheral(_:didUpdateValueFor:)`: Notification received
- `peripheral(_:didWriteValueFor:)`: Write confirmation

**5. Threading**
- Event sending uses `DispatchQueue.main.async` for UI thread execution
- CoreBluetooth callbacks may run on background queues

---

## API Reference

### Dart API (`ble_peripheral_plugin.dart`)

#### Peripheral Methods

**`startPeripheral(String serviceUuid, String txUuid, String rxUuid)`**
- Starts peripheral mode with specified service and characteristic UUIDs
- Parameters:
  - `serviceUuid`: Primary service UUID (e.g., "0000180f-0000-1000-8000-00805f9b34fb")
  - `txUuid`: TX characteristic UUID (for notifications to centrals)
  - `rxUuid`: RX characteristic UUID (for writes from centrals)
- Returns: `Future<void>`
- Events: `peripheral_started`, `advertising_started`, `error`

**`stopPeripheral()`**
- Stops advertising and closes GATT server
- Returns: `Future<void>`
- Events: `peripheral_stopped`

**`sendNotification(String charUuid, Uint8List value)`**
- Sends notification to all subscribed centrals
- Parameters:
  - `charUuid`: Characteristic UUID (typically TX UUID)
  - `value`: Data to send (Uint8List)
- Returns: `Future<void>`
- Note: Only sends to centrals that have subscribed to notifications

#### Central Methods

**`startScan(String serviceUuid)`**
- Starts scanning for peripherals advertising the specified service
- Parameters:
  - `serviceUuid`: Service UUID to filter scan results
- Returns: `Future<void>`
- Events: `scan_started`, `scanResult`, `scan_failed`, `scan_stopped`

**`stopScan()`**
- Stops scanning
- Returns: `Future<void>`
- Events: `scan_stopped`

**`connect(String deviceId)`**
- Connects to a discovered peripheral
- Parameters:
  - `deviceId`: Device identifier (Android: MAC address, iOS: UUID string)
- Returns: `Future<void>`
- Events: `connecting`, `connected`, `connectionFailed`

**`disconnect(String deviceId)`**
- Disconnects from a specific peripheral
- Parameters:
  - `deviceId`: Device identifier
- Returns: `Future<void>`
- Events: `disconnected`

**`disconnectAll()`**
- Disconnects from all connected peripherals
- Returns: `Future<void>`
- Events: `disconnected` (for each device)

**`writeCharacteristic(String deviceId, String charUuid, Uint8List value)`**
- Writes data to a characteristic on a connected peripheral
- Parameters:
  - `deviceId`: Target device identifier
  - `charUuid`: Characteristic UUID
  - `value`: Data to write
- Returns: `Future<void>`
- Events: `write_result`, `write_error`

**`requestMtu(String deviceId, [int mtu = 512])`**
- Requests MTU change for a connected peripheral
- Parameters:
  - `deviceId`: Target device identifier
  - `mtu`: Desired MTU size (default: 512, max: 512)
- Returns: `Future<void>`
- Events: `mtu_changed`, `mtu_change_failed`
- Note: iOS reports current MTU but cannot request specific value

#### Connection Management

**`getConnectedDevices()`**
- Returns list of currently connected device IDs
- Returns: `Future<List<String>>`

**`isDeviceConnected(String deviceId)`**
- Checks if a specific device is connected
- Parameters:
  - `deviceId`: Device identifier
- Returns: `Future<bool>`

#### Utility Methods

**`events`** (Stream)
- Event stream for all BLE events
- Returns: `Stream<Map<String, dynamic>>`
- See [Event System](#event-system) for event types

**`enableLogs(bool enable)`**
- Enables/disables platform logging
- Parameters:
  - `enable`: true to enable, false to disable
- Returns: `Future<void>`

**`isBluetoothOn()`**
- Checks if Bluetooth is enabled
- Returns: `Future<bool>`

**`stopAll()`**
- Stops all BLE operations (scanning, connections, peripheral)
- Returns: `Future<void>`

---

## Data Flow & Communication

### Peripheral → Central Communication

1. **Setup**: Peripheral starts advertising with service UUID
2. **Connection**: Central discovers and connects to peripheral
3. **Subscription**: Central enables notifications on TX characteristic (writes CCCD descriptor)
4. **Notification**: Peripheral calls `sendNotification()` → Native sends via `notifyCharacteristicChanged()` (Android) or `updateValue()` (iOS)
5. **Reception**: Central receives notification in callback → Event sent to Flutter

### Central → Peripheral Communication

1. **Setup**: Central connects to peripheral and discovers services
2. **Write**: Central calls `writeCharacteristic()` → Native writes to RX characteristic
3. **Reception**: Peripheral receives write in callback → Event sent to Flutter

### Data Format

- **Dart → Native**: `Uint8List` converted to `ByteArray` (Android) or `Data` (iOS)
- **Native → Dart**: `ByteArray`/`Data` converted to `Uint8List` in event payload
- **Event Payload**: `Map<String, dynamic>` with `value` field containing `Uint8List`

---

## Event System

### Event Structure

All events are `Map<String, dynamic>` with at minimum a `type` field:

```dart
{
  "type": "event_type",
  // ... additional fields based on event type
}
```

### Event Types

#### Peripheral Events

**`peripheral_started`**
- Emitted when peripheral mode starts successfully
- Fields: None

**`peripheral_stopped`**
- Emitted when peripheral mode stops
- Fields: None

**`advertising_started`**
- Emitted when advertising begins (Android)
- Fields: None

**`advertising_failed`**
- Emitted when advertising fails to start
- Fields: `code` (int) - Error code

**`server_connected`**
- Emitted when a central connects to peripheral
- Fields:
  - `deviceId` (String) - Central device identifier
  - `name` (String) - Device name (if available)

**`server_disconnected`**
- Emitted when a central disconnects from peripheral
- Fields:
  - `deviceId` (String) - Central device identifier

**`rx`**
- Emitted when peripheral receives write from central
- Fields:
  - `charUuid` (String) - Characteristic UUID
  - `value` (Uint8List) - Received data
  - `deviceId` (String) - Central device identifier

**`mtu_changed`** (Server)
- Emitted when MTU changes for a central connection
- Fields:
  - `deviceId` (String) - Central device identifier
  - `mtu` (int) - New MTU value

#### Central Events

**`scan_started`**
- Emitted when scanning begins
- Fields: None

**`scan_stopped`**
- Emitted when scanning stops
- Fields: None

**`scanResult`**
- Emitted for each discovered peripheral
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `name` (String) - Peripheral name
  - `rssi` (int) - Signal strength

**`scan_failed`**
- Emitted when scanning fails
- Fields: `code` (int) - Error code

**`connecting`**
- Emitted when connection attempt begins
- Fields:
  - `deviceId` (String) - Peripheral identifier

**`connected`**
- Emitted when connection succeeds
- Fields:
  - `deviceId` (String) - Peripheral identifier

**`connectionFailed`**
- Emitted when connection fails
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `status` (String) or `message` (String) - Error details

**`disconnected`**
- Emitted when connection is lost or closed
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `status` (String) - Optional status code

**`notification`**
- Emitted when notification received from peripheral
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `charUuid` (String) - Characteristic UUID
  - `value` (Uint8List) - Notification data

**`write_result`**
- Emitted when write operation completes
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `charUuid` (String) - Characteristic UUID
  - `status` (int) - GATT status code (0 = success)

**`write_error`**
- Emitted when write operation fails
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `message` (String) - Error message

**`mtu_changed`** (Client)
- Emitted when MTU changes for a peripheral connection
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `mtu` (int) - New MTU value

**`mtu_change_failed`**
- Emitted when MTU change request fails
- Fields:
  - `deviceId` (String) - Peripheral identifier
  - `status` (int) - Error status code

#### System Events

**`bluetooth_state`**
- Emitted when Bluetooth state changes
- Fields:
  - `isOn` (bool) - Whether Bluetooth is powered on

**`error`**
- Emitted for general errors
- Fields:
  - `message` (String) - Error message

---

## Key Features & Capabilities

### 1. Dual Mode Operation
- Can operate as both peripheral and central simultaneously
- Independent state management for each mode
- No conflicts between modes

### 2. Multi-Connection Support
- **Central Mode**: Can connect to multiple peripherals concurrently
- Each connection tracked independently with device-specific callbacks
- Per-device characteristic storage and management

### 3. Automatic Notification Subscription
- When connecting as central, automatically discovers services
- Automatically subscribes to all characteristics with NOTIFY property
- No manual subscription required

### 4. MTU Negotiation
- Supports MTU requests for larger data transfers
- Android: Can request specific MTU (up to 512)
- iOS: Reports current MTU (system-managed)

### 5. Event-Driven Architecture
- All state changes and data transfers via event stream
- Reactive programming support
- No polling required

### 6. Thread Safety
- Android: Uses `ConcurrentHashMap` for multi-connection state
- Event sending ensures UI thread execution
- Proper synchronization for subscriber management

---

## Code Structure

### Dart Layer

**`ble_peripheral_plugin.dart`**
- Main public API
- Static methods for all operations
- Method channel and event channel setup
- Event stream management

**`ble_peripheral_plugin_platform_interface.dart`**
- Abstract platform interface
- Allows for test implementations
- Uses `plugin_platform_interface` package

**`ble_peripheral_plugin_method_channel.dart`**
- Default method channel implementation
- Extends platform interface

### Android Layer

**`BlePeripheralPlugin.kt`**
- Implements `FlutterPlugin`, `MethodChannel.MethodCallHandler`, `EventChannel.StreamHandler`
- Manages BLE managers and adapters
- Handles all method calls
- Manages GATT server and clients
- Implements all callbacks

### iOS Layer

**`BlePeripheralPlugin.swift`**
- Implements `FlutterPlugin`, `FlutterStreamHandler`
- Manages `CBPeripheralManager` and `CBCentralManager`
- Implements all delegate protocols
- Handles method calls and events

---

## Usage Examples

### Basic Peripheral Setup

```dart
import 'package:ble_peripheral_plugin/ble_peripheral_plugin.dart';
import 'dart:typed_data';

// Start peripheral mode
await BlePeripheralPlugin.startPeripheral(
  "0000180f-0000-1000-8000-00805f9b34fb",  // Service UUID
  "00002a19-0000-1000-8000-00805f9b34fb",  // TX UUID (notify)
  "00002a18-0000-1000-8000-00805f9b34fb",  // RX UUID (write)
);

// Listen for events
BlePeripheralPlugin.events.listen((event) {
  if (event['type'] == 'rx') {
    final data = event['value'] as Uint8List;
    print('Received: ${String.fromCharCodes(data)}');
  } else if (event['type'] == 'server_connected') {
    print('Central connected: ${event['deviceId']}');
  }
});

// Send notification
await BlePeripheralPlugin.sendNotification(
  "00002a19-0000-1000-8000-00805f9b34fb",
  Uint8List.fromList('Hello Central'.codeUnits),
);
```

### Basic Central Setup

```dart
// Start scanning
await BlePeripheralPlugin.startScan(
  "0000180f-0000-1000-8000-00805f9b34fb",  // Service UUID to scan for
);

// Listen for scan results and connect
BlePeripheralPlugin.events.listen((event) async {
  if (event['type'] == 'scanResult') {
    final deviceId = event['deviceId'] as String;
    print('Found device: $deviceId');
    
    // Connect to first found device
    await BlePeripheralPlugin.connect(deviceId);
  } else if (event['type'] == 'connected') {
    final deviceId = event['deviceId'] as String;
    print('Connected to: $deviceId');
    
    // Request MTU for larger transfers
    await BlePeripheralPlugin.requestMtu(deviceId, 512);
  } else if (event['type'] == 'notification') {
    final data = event['value'] as Uint8List;
    print('Notification: ${String.fromCharCodes(data)}');
  }
});

// Write to characteristic
await BlePeripheralPlugin.writeCharacteristic(
  deviceId,
  "00002a18-0000-1000-8000-00805f9b34fb",  // RX UUID
  Uint8List.fromList('Hello Peripheral'.codeUnits),
);
```

### Multi-Connection Example

```dart
final connectedDevices = <String>{};

BlePeripheralPlugin.events.listen((event) async {
  switch (event['type']) {
    case 'scanResult':
      final deviceId = event['deviceId'] as String;
      if (!connectedDevices.contains(deviceId)) {
        await BlePeripheralPlugin.connect(deviceId);
      }
      break;
      
    case 'connected':
      final deviceId = event['deviceId'] as String;
      connectedDevices.add(deviceId);
      print('Connected devices: ${connectedDevices.length}');
      break;
      
    case 'disconnected':
      final deviceId = event['deviceId'] as String;
      connectedDevices.remove(deviceId);
      break;
      
    case 'notification':
      final deviceId = event['deviceId'] as String;
      final data = event['value'] as Uint8List;
      print('From $deviceId: ${String.fromCharCodes(data)}');
      break;
  }
});

// Get all connected devices
final devices = await BlePeripheralPlugin.getConnectedDevices();
print('Currently connected: $devices');

// Write to specific device
await BlePeripheralPlugin.writeCharacteristic(
  deviceId,
  charUuid,
  data,
);
```

### Complete Example with Error Handling

```dart
class BleManager {
  StreamSubscription? _eventSubscription;
  String? _connectedDeviceId;
  
  Future<void> initialize() async {
    // Check Bluetooth
    final isOn = await BlePeripheralPlugin.isBluetoothOn();
    if (!isOn) {
      throw Exception('Bluetooth is not enabled');
    }
    
    // Listen to events
    _eventSubscription = BlePeripheralPlugin.events.listen(_handleEvent);
    
    // Start as peripheral
    await BlePeripheralPlugin.startPeripheral(
      serviceUuid,
      txUuid,
      rxUuid,
    );
    
    // Start scanning
    await BlePeripheralPlugin.startScan(serviceUuid);
  }
  
  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'scanResult':
        _handleScanResult(event);
        break;
      case 'connected':
        _connectedDeviceId = event['deviceId'] as String;
        break;
      case 'disconnected':
        if (_connectedDeviceId == event['deviceId']) {
          _connectedDeviceId = null;
        }
        break;
      case 'connectionFailed':
        print('Connection failed: ${event['message']}');
        break;
      case 'error':
        print('Error: ${event['message']}');
        break;
    }
  }
  
  Future<void> _handleScanResult(Map<String, dynamic> event) async {
    if (_connectedDeviceId == null) {
      final deviceId = event['deviceId'] as String;
      await BlePeripheralPlugin.connect(deviceId);
    }
  }
  
  Future<void> sendData(Uint8List data) async {
    if (_connectedDeviceId != null) {
      await BlePeripheralPlugin.writeCharacteristic(
        _connectedDeviceId!,
        rxUuid,
        data,
      );
    }
  }
  
  Future<void> cleanup() async {
    await _eventSubscription?.cancel();
    await BlePeripheralPlugin.stopAll();
  }
}
```

---

## Platform-Specific Details

### Android

#### ⚠️ IMPORTANT: Permissions Are NOT Handled Automatically

**The plugin does NOT request or check runtime permissions.** You must handle permissions in your app before using BLE operations. See [PERMISSIONS_GUIDE.md](./PERMISSIONS_GUIDE.md) for complete instructions.

#### Permissions Required
```xml
<!-- Android 11 and below -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

#### Runtime Permissions (MUST REQUEST IN YOUR APP)
- **Android 6.0+**: Location permission (`ACCESS_FINE_LOCATION`) required for scanning
- **Android 12+**: BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT required at runtime
- **Current Implementation**: Plugin uses `@SuppressLint("MissingPermission")` - it does NOT check or request permissions
- **Required Action**: Use `permission_handler` package or implement manual permission requests

#### Device ID Format
- Uses MAC address as device identifier (e.g., "AA:BB:CC:DD:EE:FF")
- On Android 12+, MAC addresses may be randomized

#### MTU
- Can request specific MTU up to 512 bytes
- Actual MTU depends on device capabilities
- MTU negotiation happens after connection

#### Characteristics
- Uses `BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT` for writes
- Supports both write with response and without response
- Notification subscription via CCCD descriptor (UUID: 00002902-0000-1000-8000-00805f9b34fb)

### iOS

#### Info.plist Requirements
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app advertises services to nearby Bluetooth devices.</string>
```

#### Device ID Format
- Uses UUID string as device identifier (e.g., "12345678-1234-1234-1234-123456789ABC")
- UUID is stable per device but not the MAC address

#### MTU
- iOS manages MTU automatically
- Cannot request specific MTU value
- `requestMtu()` reports current effective MTU
- Typical MTU: 185 bytes (without response), 20 bytes (with response)

#### Background Modes
- Requires background modes in Info.plist for background BLE operations:
  - `bluetooth-central` for central mode
  - `bluetooth-peripheral` for peripheral mode

#### Characteristics
- Uses `.withResponse` for writes (write with response)
- Notification subscription via `setNotifyValue(true, for:)`

### Platform Differences Summary

| Feature | Android | iOS |
|---------|---------|-----|
| Device ID | MAC address | UUID string |
| MTU Request | Can request specific value | Reports current value only |
| Write Type | WRITE_TYPE_DEFAULT | .withResponse |
| Background | Requires foreground service | Requires background modes |
| Permissions | Runtime permissions required | System prompts automatically |
| Scan Filter | Service UUID filter | Service UUID filter |

---

## Error Handling

### Common Error Scenarios

1. **Bluetooth Not Available**
   - Check with `isBluetoothOn()` before operations
   - Listen for `bluetooth_state` events

2. **Connection Failures**
   - Handle `connectionFailed` events
   - Check device is in range and advertising

3. **Write Failures**
   - Handle `write_error` events
   - Ensure device is connected and characteristic exists

4. **Service Discovery Failures**
   - May occur if peripheral doesn't expose expected service
   - Check service UUID matches

5. **Notification Queue Full** (iOS)
   - iOS may report notification queue full
   - Implement retry mechanism using `peripheralManagerIsReady(toUpdateSubscribers:)`

### Error Event Structure

```dart
{
  "type": "error",
  "message": "Error description"
}
```

### Best Practices

1. Always check Bluetooth state before operations
2. Handle all event types, especially error events
3. Implement connection retry logic
4. Validate device IDs before operations
5. Check connection state before writes/reads
6. Handle disconnections gracefully

---

## Threading & Concurrency

### Android Threading

- **BLE Callbacks**: May run on background threads
- **Event Sending**: Uses `runOnUiThread` or `Handler(Looper.getMainLooper())` to ensure UI thread
- **State Management**: Uses `ConcurrentHashMap` for thread-safe multi-connection state
- **Synchronization**: Uses `synchronized` blocks for subscriber management

### iOS Threading

- **BLE Callbacks**: May run on background queues
- **Event Sending**: Uses `DispatchQueue.main.async` for UI thread
- **State Management**: Dictionary access should be thread-safe (typically on main queue)

### Dart Threading

- **Method Calls**: All methods are async and return Futures
- **Event Stream**: Events are received on the main isolate
- **No Blocking**: All operations are non-blocking

### Concurrency Considerations

1. **Multiple Connections**: Plugin supports concurrent connections, each managed independently
2. **Peripheral + Central**: Can run simultaneously without conflicts
3. **Event Ordering**: Events may arrive out of order; use deviceId to correlate
4. **State Consistency**: Platform implementations maintain consistent state

---

## Additional Notes

### UUID Format
- All UUIDs should be in standard format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
- Short UUIDs (e.g., "180F") are expanded to full format by platform

### Data Size Limitations
- Default MTU: 20-23 bytes
- With MTU negotiation: Up to 512 bytes
- For larger data: Implement chunking protocol in application layer

### Battery Considerations
- Continuous scanning/advertising drains battery
- Stop operations when not needed
- Use appropriate scan/advertise intervals

### Testing
- BLE requires real devices (emulators/simulators have limited support)
- Test on multiple devices and OS versions
- Test connection/disconnection scenarios
- Test multi-connection scenarios

---

## Summary

This plugin provides a comprehensive BLE implementation supporting both peripheral and central modes with multi-connection support. The architecture uses method channels for Flutter-to-native communication and event channels for native-to-Flutter events. Platform-specific implementations handle the complexities of Android BLE APIs and iOS CoreBluetooth, providing a unified Dart API.

Key strengths:
- Dual mode operation (peripheral + central)
- Multi-connection support
- Event-driven architecture
- Cross-platform compatibility
- Comprehensive error handling
- Thread-safe implementations

This documentation should provide complete understanding of the plugin's implementation, architecture, and usage patterns.

