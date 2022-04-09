import 'dart:async';

// import 'package:ipa_hub/domain/entities/ble_characteristic.dart';
// import 'package:ipa_hub/domain/entities/ble_device.dart';

import 'ble_characteristic.dart';
import 'ble_device.dart';

abstract class IBleService {
  StreamController<BleDevice>? scanResultsStream;
  Stream<bool>? isScanningStream;
  StreamController<List<int>>? dataStream;
  StreamController<BleDeviceState>? bleDeviceStateStream;
  Map<String, BleCharacteristic> get bleCharacterics;
  Future<List<int>?> readCharacteristics(String? characteristicUuid);
  writeToCharacteristics(String? characteristicUuid, List<int> value);
  writeToIpaCharacteristics(List<int> value);
  setNotificationForCharacteristic(String? characteristicUuid, bool value);
  setUuidsList(List<BleDeviceUuids> bleDeviceUuidsList);
  setScanDuration(int time);
  setNameFilter(String nameFilter);
  startScan();
  stopScan();
  connect(String? deviceId);
  disconnect(String? deviceId);
  Future<bool> isDeviceConnected(String deviceId);
  Future<Map<String, String>> getConnectedDevicesMap();
  writeValue(List<int> value);
}
