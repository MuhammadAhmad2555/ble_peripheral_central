# ble_peripheral_central

A production-ready Flutter plugin that enables a mobile device to simultaneously act as both a **Bluetooth Low Energy (BLE) Peripheral** (server/advertiser) and a **BLE Central** (client/scanner). This dual-mode capability enables peer-to-peer mesh networking scenarios.

[![pub package](https://img.shields.io/pub/v/ble_peripheral_central.svg)](https://pub.dev/packages/ble_peripheral_central)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **Dual-Mode Operation**: Act as both BLE Peripheral and Central simultaneously
- ✅ **Multi-Connection Support**: Connect to and manage multiple BLE devices concurrently
- ✅ **Cross-Platform**: Native implementations for Android (Kotlin) and iOS (Swift)
- ✅ **Event-Driven**: Real-time event streaming for all BLE operations
- ✅ **Production-Ready**: Thread-safe, memory-efficient, with comprehensive error handling
- ✅ **MTU Support**: Request and negotiate MTU sizes up to 512 bytes (Android)

## Platform Requirements

- **Android**: Minimum SDK 24 (Android 7.0)
- **iOS**: Minimum iOS 12.0
- **Flutter**: >=3.3.0

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ble_peripheral_central: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Setup

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Bluetooth permissions for Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"
        android:maxSdkVersion="32" />
    
    <!-- Legacy Bluetooth permissions for older Android versions -->
    <uses-permission android:name="android.permission.BLUETOOTH"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
        android:maxSdkVersion="30" />
    
    <!-- Location permission required for BLE scanning -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
</manifest>
```

**Important**: You must request runtime permissions before using BLE features. Use a package like `permission_handler` to request permissions at runtime.

### iOS

Add the following keys to your `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to advertise to nearby devices</string>
```

**Note**: On iOS, you must request Bluetooth permissions at runtime before using BLE features.

## Usage

### Basic Setup

```dart
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'dart:typed_data';

final ble = BlePeripheralCentral();

// Enable logging (optional, for debugging)
await ble.enableLogs(true);

// Check if Bluetooth is enabled
bool isOn = await ble.isBluetoothOn();
if (!isOn) {
  print('Please enable Bluetooth');
  return;
}

// Listen to BLE events
ble.events.listen((event) {
  switch (event['type']) {
    case 'scanResult':
      print('Device found: ${event['deviceId']}, RSSI: ${event['rssi']}');
      break;
    case 'connected':
      print('Connected to: ${event['deviceId']}');
      break;
    case 'notification':
      final data = event['value'] as Uint8List;
      print('Received notification: $data');
      break;
    case 'rx':
      final data = event['value'] as Uint8List;
      print('Received write: $data');
      break;
  }
});
```

### Peripheral Mode (Server/Advertiser)

```dart
// Define your service and characteristic UUIDs
const String serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
const String txUuid = '00002a19-0000-1000-8000-00805f9b34fb'; // For notifications
const String rxUuid = '00002a19-0000-1000-8000-00805f9b34fb'; // For writes

// Start advertising as a peripheral
await ble.startPeripheral(serviceUuid, txUuid, rxUuid);

// Send notification to all connected centrals
final data = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
await ble.sendNotification(txUuid, data);

// Stop advertising
await ble.stopPeripheral();
```

### Central Mode (Client/Scanner)

```dart
// Start scanning for devices (empty string scans for all devices)
await ble.startScan(serviceUuid); // Or use '' for all devices

// When a device is found, connect to it
final deviceId = 'AA:BB:CC:DD:EE:FF'; // Android MAC address
// or
final deviceId = '12345678-1234-1234-1234-123456789ABC'; // iOS UUID

await ble.connect(deviceId);

// Write to a characteristic on the connected device
final data = Uint8List.fromList([72, 101, 108, 108, 111]);
await ble.writeCharacteristic(deviceId, rxUuid, data);

// Request MTU change (Android only, iOS reports current MTU)
await ble.requestMtu(deviceId, mtu: 512);

// Check connection status
bool connected = await ble.isDeviceConnected(deviceId);
List<String> connectedDevices = await ble.getConnectedDevices();

// Disconnect
await ble.disconnect(deviceId);

// Or disconnect all
await ble.disconnectAll();

// Stop scanning
await ble.stopScan();
```

### Complete Example: Two-Way Communication

```dart
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'dart:async';
import 'dart:typed_data';

class BleManager {
  final BlePeripheralCentral ble = BlePeripheralCentral();
  StreamSubscription? eventSubscription;
  
  Future<void> initialize() async {
    // Enable logging
    await ble.enableLogs(true);
    
    // Listen to events
    eventSubscription = ble.events.listen(_handleEvent);
    
    // Check Bluetooth
    if (!await ble.isBluetoothOn()) {
      throw Exception('Bluetooth is not enabled');
    }
  }
  
  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'server_connected':
        print('Central connected: ${event['deviceId']}');
        break;
        
      case 'rx':
        final data = event['value'] as Uint8List;
        final deviceId = event['deviceId'] as String;
        print('Received from $deviceId: $data');
        // Echo back
        _sendResponse(deviceId, data);
        break;
        
      case 'connected':
        print('Connected to peripheral: ${event['deviceId']}');
        break;
        
      case 'notification':
        final data = event['value'] as Uint8List;
        print('Received notification: $data');
        break;
        
      case 'scanResult':
        final deviceId = event['deviceId'] as String;
        print('Found device: $deviceId');
        // Auto-connect (optional)
        // ble.connect(deviceId);
        break;
    }
  }
  
  Future<void> startAsPeripheral() async {
    const serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
    const txUuid = '00002a19-0000-1000-8000-00805f9b34fb';
    const rxUuid = '00002a19-0000-1000-8000-00805f9b34fb';
    
    await ble.startPeripheral(serviceUuid, txUuid, rxUuid);
  }
  
  Future<void> startScanning() async {
    const serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
    await ble.startScan(serviceUuid);
  }
  
  Future<void> _sendResponse(String deviceId, Uint8List data) async {
    // This would be used in peripheral mode
    const txUuid = '00002a19-0000-1000-8000-00805f9b34fb';
    await ble.sendNotification(txUuid, data);
  }
  
  Future<void> cleanup() async {
    await eventSubscription?.cancel();
    await ble.stopAll();
  }
}
```

## Event Types

The plugin emits events through the `events` stream. All events have a `type` field:

| Event Type | Fields | Description |
|------------|--------|-------------|
| `peripheral_started` | - | Peripheral advertising started |
| `peripheral_stopped` | - | Peripheral advertising stopped |
| `advertising_started` | - | Advertising successfully started (Android) |
| `advertising_failed` | `code` (int) | Advertising failed (Android) |
| `server_connected` | `deviceId`, `name` | Central connected to this peripheral |
| `server_disconnected` | `deviceId` | Central disconnected from this peripheral |
| `rx` | `charUuid`, `value` (Uint8List), `deviceId` | Received write on RX characteristic |
| `scan_started` | - | Scanning started |
| `scan_stopped` | - | Scanning stopped |
| `scanResult` | `deviceId`, `name`, `rssi` | Device discovered during scan |
| `scan_failed` | `code` (int) | Scan failed (Android) |
| `connecting` | `deviceId` | Connection attempt started |
| `connected` | `deviceId` | Successfully connected to device |
| `connectionFailed` | `deviceId`, `status`/`message` | Connection failed |
| `disconnected` | `deviceId`, `status` (optional) | Device disconnected |
| `notification` | `deviceId`, `charUuid`, `value` (Uint8List) | Received notification from peripheral |
| `write_result` | `deviceId`, `charUuid`, `status` | Write operation completed |
| `write_error` | `deviceId`, `message` | Write operation failed |
| `mtu_changed` | `deviceId`, `mtu` | MTU successfully changed |
| `mtu_change_failed` | `deviceId`, `status` | MTU change failed |
| `bluetooth_state` | `isOn` (bool) | Bluetooth state changed (iOS) |
| `error` | `message` | General error occurred |

## API Reference

### Peripheral Operations

- `startPeripheral(serviceUuid, txUuid, rxUuid)` - Start advertising as peripheral
- `stopPeripheral()` - Stop advertising
- `sendNotification(charUuid, value)` - Send notification to subscribed centrals

### Central Operations

- `startScan(serviceUuid)` - Start scanning (empty string = scan all)
- `stopScan()` - Stop scanning
- `connect(deviceId)` - Connect to a device
- `disconnect(deviceId)` - Disconnect a device
- `disconnectAll()` - Disconnect all devices
- `writeCharacteristic(deviceId, charUuid, value)` - Write to a characteristic
- `requestMtu(deviceId, {mtu: 512})` - Request MTU change (Android only)

### Connection Management

- `getConnectedDevices()` - Get list of connected device IDs
- `isDeviceConnected(deviceId)` - Check if device is connected

### Utilities

- `events` - Stream of BLE events
- `enableLogs(enable)` - Toggle native logging
- `isBluetoothOn()` - Check Bluetooth state
- `stopAll()` - Stop all BLE operations

## Important Notes

### Device IDs

- **Android**: Uses MAC addresses (e.g., "AA:BB:CC:DD:EE:FF")
- **iOS**: Uses UUID strings (e.g., "12345678-1234-1234-1234-123456789ABC")

### UUID Format

All UUIDs must be in standard format: `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`

### MTU Limitations

- Default BLE MTU is 23 bytes
- Plugin supports up to 512 bytes (after negotiation on Android)
- iOS MTU negotiation is automatic (cannot request specific value)
- Large messages should be chunked in application layer

### Permissions

**This plugin does not handle permissions automatically.** You must:

1. Declare permissions in manifest/Info.plist
2. Request runtime permissions before using BLE features
3. Handle permission denials gracefully

Use packages like `permission_handler` for runtime permission handling.

### Testing

- **Real devices required**: BLE does not work reliably in emulators/simulators
- Test with at least 2 physical devices
- Android manufacturer customizations may affect behavior
- iOS has strict background operation limits

## Platform-Specific Considerations

### Android

- Thread-safe implementation using `ConcurrentHashMap`
- Supports MTU negotiation up to 512 bytes
- Requires location permission for scanning on Android 6.0+

### iOS

- All operations run on main queue
- MTU negotiation is automatic (cannot request specific value)
- Background operations have restrictions
- Uses UUID strings for device identification

## Troubleshooting

### "Failed to start peripheral"

- Ensure Bluetooth is enabled
- Check that permissions are granted
- Verify UUID format is correct

### "Device not found" during connect

- Make sure you've scanned and received a `scanResult` event first
- Verify the device is still advertising
- Check that you're using the correct device ID format

### Not receiving notifications

- Ensure the peripheral has started advertising
- Verify the central has connected and subscribed
- Check that you're listening to the `events` stream

### Android: "Bluetooth adapter is null"

- Ensure device supports BLE
- Check that Bluetooth is enabled
- Verify permissions are granted

### iOS: "Bluetooth state unknown"

- Wait for `peripheralManagerDidUpdateState` or `centralManagerDidUpdateState` to be called
- Check that Bluetooth is enabled in Settings

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Muhammad Ahmad

## Support

For issues, feature requests, or questions, please open an issue on [GitHub](https://github.com/muhammadahmad/ble_peripheral_central).
