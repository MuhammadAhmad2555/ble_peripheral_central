library ble_peripheral_central;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'ble_peripheral_central_platform_interface.dart';

/// Main API class for BLE Peripheral Central Plugin
///
/// This plugin enables a device to simultaneously act as both a BLE Peripheral
/// (server/advertiser) and a BLE Central (client/scanner).
///
/// Example usage:
/// ```dart
/// final ble = BlePeripheralCentral();
/// await ble.startPeripheral(serviceUuid, txUuid, rxUuid);
/// ble.events.listen((event) {
///   print('BLE Event: ${event['type']}');
/// });
/// ```
class BlePeripheralCentral {
  static const int MAX_MTU = 512;

  // Channels
  static const MethodChannel _methodChannel =
      MethodChannel('ble_peripheral_central/methods');
  static const EventChannel _eventChannel =
      EventChannel('ble_peripheral_central/events');

  // Cached event stream (shared across instances)
  static Stream<Map<String, dynamic>>? _eventStream;

  /// Stream of BLE events
  ///
  /// Events include scan results, connection status, notifications, writes, etc.
  /// This stream is shared across all instances of this class.
  Stream<Map<String, dynamic>> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  // ==================== Peripheral Operations ====================

  /// Validates a UUID string format
  static bool _isValidUuid(String uuid) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(uuid);
  }

  /// Start advertising as a BLE peripheral
  ///
  /// [serviceUuid] - UUID of the service to advertise (format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
  /// [txUuid] - UUID of the TX characteristic for notifications
  /// [rxUuid] - UUID of the RX characteristic for writes
  ///
  /// Throws [ArgumentError] if UUIDs are invalid.
  Future<void> startPeripheral(
    String serviceUuid,
    String txUuid,
    String rxUuid,
  ) async {
    if (!_isValidUuid(serviceUuid)) {
      throw ArgumentError('Invalid service UUID format: $serviceUuid');
    }
    if (!_isValidUuid(txUuid)) {
      throw ArgumentError('Invalid TX UUID format: $txUuid');
    }
    if (!_isValidUuid(rxUuid)) {
      throw ArgumentError('Invalid RX UUID format: $rxUuid');
    }

    try {
      await _methodChannel.invokeMethod('startPeripheral', {
        'serviceUuid': serviceUuid,
        'txUuid': txUuid,
        'rxUuid': rxUuid,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start peripheral: ${e.message}');
    }
  }

  /// Stop advertising as a BLE peripheral
  Future<void> stopPeripheral() async {
    try {
      await _methodChannel.invokeMethod('stopPeripheral');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop peripheral: ${e.message}');
    }
  }

  /// Send a notification to all subscribed central devices
  ///
  /// [charUuid] - UUID of the characteristic (typically the TX UUID)
  /// [value] - Data to send as Uint8List
  ///
  /// Throws [ArgumentError] if charUuid is invalid or value is empty.
  Future<void> sendNotification(String charUuid, Uint8List value) async {
    if (!_isValidUuid(charUuid)) {
      throw ArgumentError('Invalid characteristic UUID format: $charUuid');
    }
    if (value.isEmpty) {
      throw ArgumentError('Value cannot be empty');
    }
    if (value.length > MAX_MTU - 3) {
      throw ArgumentError('Value exceeds maximum MTU size: ${value.length} > ${MAX_MTU - 3}');
    }

    try {
      await _methodChannel.invokeMethod('sendNotification', {
        'charUuid': charUuid,
        'value': value,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to send notification: ${e.message}');
    }
  }

  // ==================== Central Operations ====================

  /// Start scanning for BLE devices
  ///
  /// [serviceUuid] - UUID of the service to filter by (optional, can be empty string for all devices)
  ///
  /// Throws [ArgumentError] if serviceUuid is not empty and has invalid format.
  Future<void> startScan(String serviceUuid) async {
    if (serviceUuid.isNotEmpty && !_isValidUuid(serviceUuid)) {
      throw ArgumentError('Invalid service UUID format: $serviceUuid');
    }

    try {
      await _methodChannel.invokeMethod('startScan', {
        'serviceUuid': serviceUuid,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start scan: ${e.message}');
    }
  }

  /// Stop scanning for BLE devices
  Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop scan: ${e.message}');
    }
  }

  /// Connect to a specific BLE device
  ///
  /// [deviceId] - Device identifier (MAC address on Android, UUID string on iOS)
  ///
  /// Throws [ArgumentError] if deviceId is empty.
  Future<void> connect(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }

    try {
      await _methodChannel.invokeMethod('connect', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to connect: ${e.message}');
    }
  }

  /// Disconnect from a specific BLE device
  ///
  /// [deviceId] - Device identifier to disconnect
  ///
  /// Throws [ArgumentError] if deviceId is empty.
  Future<void> disconnect(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }

    try {
      await _methodChannel.invokeMethod('disconnect', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to disconnect: ${e.message}');
    }
  }

  /// Disconnect from all connected devices
  Future<void> disconnectAll() async {
    try {
      await _methodChannel.invokeMethod('disconnectAll');
    } on PlatformException catch (e) {
      throw Exception('Failed to disconnect all: ${e.message}');
    }
  }

  /// Write to a characteristic on a connected device
  ///
  /// [deviceId] - Device identifier
  /// [charUuid] - UUID of the characteristic to write to
  /// [value] - Data to write as Uint8List
  ///
  /// Throws [ArgumentError] if deviceId is empty, charUuid is invalid, or value is empty.
  Future<void> writeCharacteristic(
    String deviceId,
    String charUuid,
    Uint8List value,
  ) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }
    if (!_isValidUuid(charUuid)) {
      throw ArgumentError('Invalid characteristic UUID format: $charUuid');
    }
    if (value.isEmpty) {
      throw ArgumentError('Value cannot be empty');
    }

    try {
      await _methodChannel.invokeMethod('writeCharacteristic', {
        'deviceId': deviceId,
        'charUuid': charUuid,
        'value': value,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to write characteristic: ${e.message}');
    }
  }

  /// Request MTU change for a connected device
  ///
  /// [deviceId] - Device identifier
  /// [mtu] - Requested MTU size (default: 512, max supported: 512)
  ///
  /// Note: On iOS, this will report the current MTU but cannot request a specific value.
  ///
  /// Throws [ArgumentError] if deviceId is empty or mtu is out of range (23-512).
  Future<void> requestMtu(String deviceId, {int mtu = MAX_MTU}) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }
    if (mtu < 23 || mtu > MAX_MTU) {
      throw ArgumentError('MTU must be between 23 and $MAX_MTU, got: $mtu');
    }

    try {
      await _methodChannel.invokeMethod('requestMtu', {
        'deviceId': deviceId,
        'mtu': mtu,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to request MTU: ${e.message}');
    }
  }

  // ==================== Connection Management ====================

  /// Get list of all connected device IDs
  Future<List<String>> getConnectedDevices() async {
    try {
      final result =
          await _methodChannel.invokeMethod<List<dynamic>>('getConnectedDevices');
      return result?.map((e) => e.toString()).toList() ?? [];
    } on PlatformException catch (e) {
      throw Exception('Failed to get connected devices: ${e.message}');
    }
  }

  /// Check if a specific device is connected
  ///
  /// [deviceId] - Device identifier to check
  ///
  /// Throws [ArgumentError] if deviceId is empty.
  Future<bool> isDeviceConnected(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isDeviceConnected',
        {'deviceId': deviceId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check device connection: ${e.message}');
    }
  }

  // ==================== Utilities ====================

  /// Toggle native logging
  ///
  /// [enable] - Whether to enable logging
  Future<void> enableLogs(bool enable) async {
    try {
      await _methodChannel.invokeMethod('enableLogs', {'enable': enable});
    } on PlatformException catch (e) {
      throw Exception('Failed to enable logs: ${e.message}');
    }
  }

  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothOn() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBluetoothOn');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check Bluetooth state: ${e.message}');
    }
  }

  /// Stop all BLE operations (scanning, connections, advertising)
  Future<void> stopAll() async {
    try {
      await _methodChannel.invokeMethod('stopAll');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop all: ${e.message}');
    }
  }
}