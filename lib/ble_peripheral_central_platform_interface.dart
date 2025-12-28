import 'dart:async';
import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ble_peripheral_central_method_channel.dart';

/// Platform interface for [BlePeripheralCentralPlatform]
///
/// This interface allows platform-specific implementations to be swapped in for testing.
abstract class BlePeripheralCentralPlatform extends PlatformInterface {
  /// Constructs a BlePeripheralCentralPlatform.
  BlePeripheralCentralPlatform() : super(token: _token);

  static final Object _token = Object();

  static BlePeripheralCentralPlatform _instance =
      MethodChannelBlePeripheralCentral();

  /// The default instance of [BlePeripheralCentralPlatform] to use.
  ///
  /// Defaults to [MethodChannelBlePeripheralCentral].
  static BlePeripheralCentralPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BlePeripheralCentralPlatform] when
  /// they register themselves.
  static set instance(BlePeripheralCentralPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // Peripheral operations
  Future<void> startPeripheral(
    String serviceUuid,
    String txUuid,
    String rxUuid,
  ) {
    throw UnimplementedError('startPeripheral() has not been implemented.');
  }

  Future<void> stopPeripheral() {
    throw UnimplementedError('stopPeripheral() has not been implemented.');
  }

  Future<void> sendNotification(String charUuid, Uint8List value) {
    throw UnimplementedError('sendNotification() has not been implemented.');
  }

  // Central operations
  Future<void> startScan(String serviceUuid) {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  Future<void> connect(String deviceId) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<void> disconnect(String deviceId) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<void> disconnectAll() {
    throw UnimplementedError('disconnectAll() has not been implemented.');
  }

  Future<void> writeCharacteristic(
    String deviceId,
    String charUuid,
    Uint8List value,
  ) {
    throw UnimplementedError('writeCharacteristic() has not been implemented.');
  }

  Future<void> requestMtu(String deviceId, int mtu) {
    throw UnimplementedError('requestMtu() has not been implemented.');
  }

  // Connection management
  Future<List<String>> getConnectedDevices() {
    throw UnimplementedError('getConnectedDevices() has not been implemented.');
  }

  Future<bool> isDeviceConnected(String deviceId) {
    throw UnimplementedError('isDeviceConnected() has not been implemented.');
  }

  // Utilities
  Future<void> enableLogs(bool enable) {
    throw UnimplementedError('enableLogs() has not been implemented.');
  }

  Future<bool> isBluetoothOn() {
    throw UnimplementedError('isBluetoothOn() has not been implemented.');
  }

  Future<void> stopAll() {
    throw UnimplementedError('stopAll() has not been implemented.');
  }

  // Event stream
  Stream<Map<String, dynamic>> getEvents() {
    throw UnimplementedError('getEvents() has not been implemented.');
  }
}