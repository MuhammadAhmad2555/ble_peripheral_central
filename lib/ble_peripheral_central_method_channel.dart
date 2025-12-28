import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ble_peripheral_central_platform_interface.dart';

/// An implementation of [BlePeripheralCentralPlatform] that uses method channels.
class MethodChannelBlePeripheralCentral extends BlePeripheralCentralPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  static const methodChannel = MethodChannel('ble_peripheral_central/methods');

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  static const eventChannel = EventChannel('ble_peripheral_central/events');

  Stream<Map<String, dynamic>>? _eventStream;

  @override
  Stream<Map<String, dynamic>> getEvents() {
    _eventStream ??= eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  @override
  Future<void> startPeripheral(
    String serviceUuid,
    String txUuid,
    String rxUuid,
  ) async {
    await methodChannel.invokeMethod('startPeripheral', {
      'serviceUuid': serviceUuid,
      'txUuid': txUuid,
      'rxUuid': rxUuid,
    });
  }

  @override
  Future<void> stopPeripheral() async {
    await methodChannel.invokeMethod('stopPeripheral');
  }

  @override
  Future<void> sendNotification(String charUuid, Uint8List value) async {
    await methodChannel.invokeMethod('sendNotification', {
      'charUuid': charUuid,
      'value': value,
    });
  }

  @override
  Future<void> startScan(String serviceUuid) async {
    await methodChannel.invokeMethod('startScan', {
      'serviceUuid': serviceUuid,
    });
  }

  @override
  Future<void> stopScan() async {
    await methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<void> connect(String deviceId) async {
    await methodChannel.invokeMethod('connect', {
      'deviceId': deviceId,
    });
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await methodChannel.invokeMethod('disconnect', {
      'deviceId': deviceId,
    });
  }

  @override
  Future<void> disconnectAll() async {
    await methodChannel.invokeMethod('disconnectAll');
  }

  @override
  Future<void> writeCharacteristic(
    String deviceId,
    String charUuid,
    Uint8List value,
  ) async {
    await methodChannel.invokeMethod('writeCharacteristic', {
      'deviceId': deviceId,
      'charUuid': charUuid,
      'value': value,
    });
  }

  @override
  Future<void> requestMtu(String deviceId, int mtu) async {
    await methodChannel.invokeMethod('requestMtu', {
      'deviceId': deviceId,
      'mtu': mtu,
    });
  }

  @override
  Future<List<String>> getConnectedDevices() async {
    final result =
        await methodChannel.invokeMethod<List<dynamic>>('getConnectedDevices');
    return result?.map((e) => e.toString()).toList() ?? [];
  }

  @override
  Future<bool> isDeviceConnected(String deviceId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'isDeviceConnected',
      {'deviceId': deviceId},
    );
    return result ?? false;
  }

  @override
  Future<void> enableLogs(bool enable) async {
    await methodChannel.invokeMethod('enableLogs', {'enable': enable});
  }

  @override
  Future<bool> isBluetoothOn() async {
    final result = await methodChannel.invokeMethod<bool>('isBluetoothOn');
    return result ?? false;
  }

  @override
  Future<void> stopAll() async {
    await methodChannel.invokeMethod('stopAll');
  }
}