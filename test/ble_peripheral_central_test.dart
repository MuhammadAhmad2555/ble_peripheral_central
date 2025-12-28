import 'package:flutter_test/flutter_test.dart';
import 'package:ble_peripheral_central/ble_peripheral_central.dart';
import 'package:ble_peripheral_central/ble_peripheral_central_platform_interface.dart';
import 'package:ble_peripheral_central/ble_peripheral_central_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBlePeripheralCentralPlatform
    with MockPlatformInterfaceMixin
    implements BlePeripheralCentralPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BlePeripheralCentralPlatform initialPlatform = BlePeripheralCentralPlatform.instance;

  test('$MethodChannelBlePeripheralCentral is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBlePeripheralCentral>());
  });

  test('getPlatformVersion', () async {
    BlePeripheralCentral blePeripheralCentralPlugin = BlePeripheralCentral();
    MockBlePeripheralCentralPlatform fakePlatform = MockBlePeripheralCentralPlatform();
    BlePeripheralCentralPlatform.instance = fakePlatform;

    expect(await blePeripheralCentralPlugin.getPlatformVersion(), '42');
  });
}
