import 'package:flutter_test/flutter_test.dart';
import 'package:ble_peripheral_central/ble_peripheral_central.dart';

void main() {
  test('BlePeripheralPlugin class exists', () {
    expect(BlePeripheralPlugin, isNotNull);
  });

  test('MAX_MTU constant is 512', () {
    expect(BlePeripheralPlugin.MAX_MTU, 512);
  });

  test('events stream is accessible', () {
    expect(BlePeripheralPlugin.events, isNotNull);
  });
}
