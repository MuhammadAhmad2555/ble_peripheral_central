# ble_peripheral_central

A production-ready Flutter plugin that enables a mobile device to simultaneously act as both a **Bluetooth Low Energy (BLE) Peripheral** (server/advertiser) and a **BLE Central** (client/scanner). This dual-mode capability enables peer-to-peer mesh networking scenarios.

[![GitHub](https://img.shields.io/github/stars/MuhammadAhmad2555/ble_peripheral_central?style=social)](https://github.com/MuhammadAhmad2555/ble_peripheral_central)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub repository](https://img.shields.io/badge/GitHub-Repository-blue)](https://github.com/MuhammadAhmad2555/ble_peripheral_central)

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

### Option 1: From GitHub (Current)

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ble_peripheral_central:
    git:
      url: https://github.com/MuhammadAhmad2555/ble_peripheral_central.git
      ref: main
```

### Option 2: From pub.dev (When published)

```yaml
dependencies:
  ble_peripheral_central: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Configure Permissions

#### Android

**Note:** The plugin's AndroidManifest.xml automatically declares all required Bluetooth permissions, which should be merged into your app's manifest during build. However, if you encounter permission issues, you can explicitly add them to your app's `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Bluetooth permissions for Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <!-- Legacy Bluetooth permissions for Android 11 and below (API 30 and below) -->
    <uses-permission android:name="android.permission.BLUETOOTH"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
        android:maxSdkVersion="30" />
    
    <!-- Location permission required for BLE scanning on Android 6.0+ to Android 11 -->
    <!-- Note: Not required for Android 12+ when using BLUETOOTH_SCAN with neverForLocation flag -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"
        android:maxSdkVersion="30" />
</manifest>
```

Ensure minimum SDK in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to advertise to nearby devices</string>
```

### 2. Request Runtime Permissions

**⚠️ Important:** On Android 12+ (API 31+), **do NOT request location permissions** - they are not needed when using `BLUETOOTH_SCAN` with the `neverForLocation` flag. Only request location on Android 11 and below.

Install `permission_handler`:

```yaml
dependencies:
  permission_handler: ^11.0.0
```

Request permissions in your code:

```dart
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:io' show Platform;

Future<void> requestBluetoothPermissions() async {
  if (Platform.isAndroid) {
    // Always request Bluetooth permissions (works on all Android versions)
    await Permission.bluetoothScan.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.bluetoothConnect.request();
    
    // Location permission is ONLY needed on Android 11 and below (API 30 and below)
    // On Android 12+, BLUETOOTH_SCAN with neverForLocation flag replaces location permission
    // Check if we're on Android < 12 by checking if location permission is actually needed
    try {
      // Try to check if we're on Android 12+ by checking if BLUETOOTH_SCAN is available
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      
      // If BLUETOOTH_SCAN is available and granted, we're likely on Android 12+
      // Only request location if BLUETOOTH_SCAN is not available or denied
      if (bluetoothScanStatus.isDenied || bluetoothScanStatus.isPermanentlyDenied) {
        // Might be Android < 12, request location permission
        await Permission.location.request();
      }
      // If BLUETOOTH_SCAN is granted, we don't need location (Android 12+)
    } catch (e) {
      // Fallback: request location permission if we can't determine Android version
      // This is safe - on Android 12+ it will be ignored, on Android < 12 it's required
      await Permission.location.request();
    }
  }
  // iOS permissions are requested automatically
}
```

**Simpler alternative** (if you know your minSdkVersion):

```dart
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> requestBluetoothPermissions() async {
  if (Platform.isAndroid) {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    
    // Request Bluetooth permissions
    await Permission.bluetoothScan.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.bluetoothConnect.request();
    
    // Only request location on Android 11 and below
    if (sdkInt < 31) {
      await Permission.location.request();
    }
  }
  // iOS permissions are requested automatically
}
```

**Recommended approach** (using plugin's `checkPermissions()`):

```dart
import 'package:permission_handler/permission_handler.dart';
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'dart:io';

Future<void> requestBluetoothPermissions() async {
  if (Platform.isAndroid) {
    // Check current permission status
    final permissions = await BlePeripheralPlugin.checkPermissions();
    
    // Request Bluetooth permissions if needed
    if (!permissions['bluetoothScan']!) {
      await Permission.bluetoothScan.request();
    }
    if (!permissions['bluetoothAdvertise']!) {
      await Permission.bluetoothAdvertise.request();
    }
    if (!permissions['bluetoothConnect']!) {
      await Permission.bluetoothConnect.request();
    }
    
    // Only request location if it's actually required (Android < 12)
    // On Android 12+, locationRequired will be false
    if (permissions['locationRequired'] == true && !permissions['location']!) {
      await Permission.location.request();
    }
    // Note: On Android 12+, location permission is NOT needed and will show as denied
    // This is expected and OK - you can ignore location permission status on Android 12+
  }
  // iOS permissions are requested automatically
}
```

**Important:** 
- On **Android 12+ (API 31+)**: Location permissions are **NOT required** when using `BLUETOOTH_SCAN` with the `neverForLocation` flag
- On **Android 11 and below (API 30 and below)**: Location permission **IS required** for BLE scanning
- Use `BlePeripheralPlugin.checkPermissions()` to determine which permissions are actually needed on the current device

### 3. Basic Usage

```dart
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'dart:typed_data';

// Create instance
final ble = BlePeripheralCentral();

// Enable logging (optional)
await ble.enableLogs(true);

// Check Bluetooth state
bool isOn = await ble.isBluetoothOn();
if (!isOn) {
  print('Please enable Bluetooth');
  return;
}

// Listen to events
ble.events.listen((event) {
  print('Event: ${event['type']}');
  // Handle different event types...
});
```

## Usage Examples

### Example 1: Act as Peripheral (Server)

```dart
// Define UUIDs
const String serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
const String txUuid = '00002a19-0000-1000-8000-00805f9b34fb'; // For notifications
const String rxUuid = '00002a19-0000-1000-8000-00805f9b34fb'; // For writes

// Start advertising
await ble.startPeripheral(serviceUuid, txUuid, rxUuid);

// Listen for connections and data
ble.events.listen((event) {
  if (event['type'] == 'server_connected') {
    print('Central connected: ${event['deviceId']}');
  }
  
  if (event['type'] == 'rx') {
    final data = event['value'] as Uint8List;
    print('Received: $data');
  }
});

// Send notification to all connected centrals
final data = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
await ble.sendNotification(txUuid, data);

// Stop advertising
await ble.stopPeripheral();
```

### Example 2: Act as Central (Client)

```dart
// Start scanning (empty string = scan all devices)
await ble.startScan(''); // Or filter by serviceUuid

// Listen for scan results
ble.events.listen((event) {
  if (event['type'] == 'scanResult') {
    final deviceId = event['deviceId'] as String;
    final name = event['name'] as String;
    final rssi = event['rssi'] as int;
    print('Found: $name ($deviceId) RSSI: $rssi');
    
    // Connect to device
    ble.connect(deviceId);
  }
  
  if (event['type'] == 'connected') {
    final deviceId = event['deviceId'] as String;
    print('Connected to: $deviceId');
    
    // Write to device
    final data = Uint8List.fromList([72, 101, 108, 108, 111]);
    await ble.writeCharacteristic(deviceId, rxUuid, data);
  }
  
  if (event['type'] == 'notification') {
    final data = event['value'] as Uint8List;
    print('Notification received: $data');
  }
});

// Stop scanning
await ble.stopScan();
```

### Example 3: Dual Mode (Both Simultaneously)

```dart
// Start both peripheral and central modes
await ble.startPeripheral(serviceUuid, txUuid, rxUuid);
await ble.startScan(serviceUuid);

// Handle all events
ble.events.listen((event) {
  switch (event['type']) {
    case 'server_connected':
      // Someone connected to us (peripheral mode)
      print('Central connected: ${event['deviceId']}');
      break;
      
    case 'connected':
      // We connected to someone (central mode)
      print('Connected to peripheral: ${event['deviceId']}');
      break;
      
    case 'rx':
      // Received data as peripheral
      final data = event['value'] as Uint8List;
      print('Received as peripheral: $data');
      break;
      
    case 'notification':
      // Received notification as central
      final data = event['value'] as Uint8List;
      print('Received as central: $data');
      break;
  }
});
```

### Example 4: Complete App with UI

```dart
import 'package:flutter/material.dart';
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'dart:async';
import 'dart:typed_data';

class BleDemoPage extends StatefulWidget {
  const BleDemoPage({super.key});

  @override
  State<BleDemoPage> createState() => _BleDemoPageState();
}

class _BleDemoPageState extends State<BleDemoPage> {
  final BlePeripheralCentral ble = BlePeripheralCentral();
  StreamSubscription? _eventSubscription;
  
  static const String serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String txUuid = '00002a19-0000-1000-8000-00805f9b34fb';
  static const String rxUuid = '00002a19-0000-1000-8000-00805f9b34fb';
  
  bool _isPeripheralActive = false;
  bool _isScanning = false;
  List<String> _discoveredDevices = [];
  List<String> _connectedDevices = [];
  
  @override
  void initState() {
    super.initState();
    _initializeBle();
  }
  
  Future<void> _initializeBle() async {
    // Request permissions first
    // await requestBluetoothPermissions();
    
    await ble.enableLogs(true);
    
    if (!await ble.isBluetoothOn()) {
      print('Bluetooth is not enabled');
      return;
    }
    
    // Listen to events
    _eventSubscription = ble.events.listen((event) {
      setState(() {
        switch (event['type']) {
          case 'peripheral_started':
            _isPeripheralActive = true;
            break;
          case 'peripheral_stopped':
            _isPeripheralActive = false;
            break;
          case 'scan_started':
            _isScanning = true;
            _discoveredDevices.clear();
            break;
          case 'scan_stopped':
            _isScanning = false;
            break;
          case 'scanResult':
            final deviceId = event['deviceId'] as String;
            if (!_discoveredDevices.contains(deviceId)) {
              _discoveredDevices.add(deviceId);
            }
            break;
          case 'connected':
            final deviceId = event['deviceId'] as String;
            if (!_connectedDevices.contains(deviceId)) {
              _connectedDevices.add(deviceId);
            }
            break;
          case 'disconnected':
            final deviceId = event['deviceId'] as String;
            _connectedDevices.remove(deviceId);
            break;
        }
      });
    });
  }
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    ble.stopAll();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Peripheral Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Peripheral Mode', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isPeripheralActive ? null : () async {
                              await ble.startPeripheral(serviceUuid, txUuid, rxUuid);
                            },
                            child: const Text('Start Peripheral'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isPeripheralActive ? () async {
                              await ble.stopPeripheral();
                            } : null,
                            child: const Text('Stop Peripheral'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Central Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Central Mode', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isScanning ? null : () async {
                              await ble.startScan(serviceUuid);
                            },
                            child: const Text('Start Scan'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isScanning ? () async {
                              await ble.stopScan();
                            } : null,
                            child: const Text('Stop Scan'),
                          ),
                        ),
                      ],
                    ),
                    if (_discoveredDevices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Discovered Devices:'),
                      ..._discoveredDevices.map((deviceId) => ListTile(
                        title: Text(deviceId),
                        trailing: ElevatedButton(
                          onPressed: () => ble.connect(deviceId),
                          child: const Text('Connect'),
                        ),
                      )),
                    ],
                    if (_connectedDevices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Connected Devices:'),
                      ..._connectedDevices.map((deviceId) => ListTile(
                        title: Text(deviceId),
                        trailing: ElevatedButton(
                          onPressed: () => ble.disconnect(deviceId),
                          child: const Text('Disconnect'),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## API Reference

### Peripheral Operations

| Method | Description |
|--------|-------------|
| `startPeripheral(serviceUuid, txUuid, rxUuid)` | Start advertising as peripheral |
| `stopPeripheral()` | Stop advertising |
| `sendNotification(charUuid, value)` | Send notification to subscribed centrals |

### Central Operations

| Method | Description |
|--------|-------------|
| `startScan(serviceUuid)` | Start scanning (empty string = scan all) |
| `stopScan()` | Stop scanning |
| `connect(deviceId)` | Connect to a device |
| `disconnect(deviceId)` | Disconnect a device |
| `disconnectAll()` | Disconnect all devices |
| `writeCharacteristic(deviceId, charUuid, value)` | Write to a characteristic |
| `requestMtu(deviceId, {mtu: 512})` | Request MTU change (Android only) |

### Connection Management

| Method | Description |
|--------|-------------|
| `getConnectedDevices()` | Get list of connected device IDs |
| `isDeviceConnected(deviceId)` | Check if device is connected |

### Utilities

| Method | Description |
|--------|-------------|
| `events` | Stream of BLE events |
| `enableLogs(enable)` | Toggle native logging |
| `isBluetoothOn()` | Check Bluetooth state |
| `stopAll()` | Stop all BLE operations |

## Event Types

All events are streamed through `ble.events`. Each event has a `type` field:

| Event Type | Fields | Description |
|------------|--------|-------------|
| `peripheral_started` | - | Peripheral advertising started |
| `peripheral_stopped` | - | Peripheral advertising stopped |
| `server_connected` | `deviceId`, `name` | Central connected to this peripheral |
| `server_disconnected` | `deviceId` | Central disconnected |
| `rx` | `charUuid`, `value` (Uint8List), `deviceId` | Received write on RX characteristic |
| `scan_started` | - | Scanning started |
| `scan_stopped` | - | Scanning stopped |
| `scanResult` | `deviceId`, `name`, `rssi` | Device discovered during scan |
| `connecting` | `deviceId` | Connection attempt started |
| `connected` | `deviceId` | Successfully connected |
| `connectionFailed` | `deviceId`, `message` | Connection failed |
| `disconnected` | `deviceId`, `status` (optional) | Device disconnected |
| `notification` | `deviceId`, `charUuid`, `value` (Uint8List) | Received notification |
| `write_result` | `deviceId`, `charUuid`, `status` | Write completed |
| `write_error` | `deviceId`, `message` | Write failed |
| `mtu_changed` | `deviceId`, `mtu` | MTU changed |
| `bluetooth_state` | `isOn` (bool) | Bluetooth state changed (iOS) |

## Important Notes

### Device IDs

- **Android**: Uses MAC addresses (e.g., `"AA:BB:CC:DD:EE:FF"`)
- **iOS**: Uses UUID strings (e.g., `"12345678-1234-1234-1234-123456789ABC"`)

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

- Wait for Bluetooth state to be determined
- Check that Bluetooth is enabled in Settings

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the **MIT License with Attribution** - see the [LICENSE](LICENSE) file for details.

**Attribution Requirement**: If you use this plugin in your project, you must include attribution with a link to the repository in your project's README, documentation, or About section.

**Example attribution:**
```
This project uses ble_peripheral_central by Muhammad Ahmad
(https://github.com/MuhammadAhmad2555/ble_peripheral_central)
```

## Author

Muhammad Ahmad

## Support

For issues, feature requests, or questions, please open an issue on [GitHub](https://github.com/MuhammadAhmad2555/ble_peripheral_central).

**Repository**: [https://github.com/MuhammadAhmad2555/ble_peripheral_central](https://github.com/MuhammadAhmad2555/ble_peripheral_central)
