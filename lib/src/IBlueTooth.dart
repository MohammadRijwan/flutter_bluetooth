import 'dart:async';

import 'ble_characteristic.dart';
import 'ble_device.dart';

abstract class IBlueTooth {
  StreamController<BleDevice>? scanResultsStream;
  StreamController<bool>? isScanningStream;
  connect(String? deviceId);
  Future<Map<String, String>> initializeConnectedDevices();
  Map<String, BleCharacteristic> getAllBleCharacteristic();
  StreamController<BleDeviceState>? bleDeviceStateStream;
  Future<String> readCharacteristics(String? characteristicUuid);
  setNotificationForCharacteristic(String? characteristicUuid, bool value);
  writeToCharacteristics(String? characteristicUuid, String? message);
  writeToIpaCharacteristics(String message);
  writeEncodedMessageToCharacteristics(
      String characteristicUuid, List<int> encodedMsg);
  Future<Map<String, String>> getAllConnectedDevices();
  disconnect(String? deviceId);
  Future<bool> isDeviceConnected(String deviceId);
  startScan();
  startScanAndConnectToIpaDevice();
  stopScan();
  writeMessageToMldpCharacteristic(String deviceId, String message);
  StreamController<List<int>>? dataStream;
  disconnectIPADevice();
}
