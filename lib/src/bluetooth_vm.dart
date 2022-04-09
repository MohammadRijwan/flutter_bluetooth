import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth/src/IBlueTooth.dart';

import 'ble_characteristic.dart';
import 'ble_device.dart';
import 'ble_usecase.dart';
import 'data_convertor.dart';

enum bluetoothState { idle, scanning, error, connected }

class BluetoothVm extends ChangeNotifier {
  IBlueTooth? _ble = BleUseCase.bleUseCaseInstance;
  Map<String?, BleDevice> scanItems = Map<String?, BleDevice>();
  Map<String, String> connectedDevices = Map<String, String>();
  Map<String, BleCharacteristic> allBleCharacteristics =
      Map<String, BleCharacteristic>();
  StreamSubscription<List<int>>? dataSubscription;
  bool isScanning = false;
  bool isBusy = false;
  bool isError = false;
  Map<String?, List<String?>> dataMap = Map<String?, List<String>>();

  BluetoothVm() {
    _initConnectedDevices();
  }

  _initConnectedDevices() async {
    connectedDevices = await _ble!.initializeConnectedDevices();
    allBleCharacteristics = _ble!.getAllBleCharacteristic();
    notifyListeners();
  }

  setIsBusy(bool value) {
    isBusy = value;
    notifyListeners();
  }

  connect(String? deviceId) async {
    setIsBusy(true);
    await _ble!.connect(deviceId);
    connectedDevices = await _ble!.getAllConnectedDevices();
    allBleCharacteristics = _ble!.getAllBleCharacteristic();
    setIsBusy(false);
  }

  disconnect(String? deviceId) async {
    setIsBusy(true);
    await _ble!.disconnect(deviceId);
    scanItems = Map<String?, BleDevice>();
    connectedDevices = await _ble!.getAllConnectedDevices();
    allBleCharacteristics = Map<String, BleCharacteristic>();
    setIsBusy(false);
  }

  bool isDeviceConnected(String? deviceId) {
    return connectedDevices[deviceId!] != null;
  }

  startScan() {
    if (kDebugMode) {
      print('Bluetooth vm startScan()');
    }
    isScanning = true;
    scanItems = Map<String?, BleDevice>();
    notifyListeners();
    _ble!.startScan();
    _listenToScanResult();
    _listenToScanStatus();
  }

  _listenToScanResult() {
    _ble!.scanResultsStream!.stream.listen((scanResult) {
      if (scanResult.id != null) {
        scanItems[scanResult.id] = scanResult;
        notifyListeners();
      }
    }, onDone: () {
      if (kDebugMode) {
        print(' bluetooth VM scanresults on done');
      }
    });
  }

  _listenToScanStatus() {
    _ble!.isScanningStream!.stream.listen((isScanningNow) {
      isScanning = isScanningNow;
      notifyListeners();
    });
  }

  stopScan() {
    if (kDebugMode) {
      print('Bluetooth vm stopScan()');
    }
    _ble!.stopScan();
  }

  sendCommandToBle(String deviceId, String message) async {
    await _ble!.writeMessageToMldpCharacteristic(deviceId, message);
  }

  writeToCharacteristics(String? characteristicUuid, String? message) async {
    await _ble!.writeToCharacteristics(characteristicUuid, message);
  }

  readCharacteristic(String? characteristicUuid) async {
    final data = await _ble!.readCharacteristics(characteristicUuid);
    if (kDebugMode) {
      print('characteristicUuid $characteristicUuid data:$data');
    }
    final characteristicDataList = dataMap[characteristicUuid] ?? <String>[];
    characteristicDataList.add(data);
    dataMap[characteristicUuid] = characteristicDataList;
    notifyListeners();
  }

  setNotificationForCharacteristic(
      String? characteristicUuid, bool value) async {
    await _ble!.setNotificationForCharacteristic(characteristicUuid, value);
    allBleCharacteristics = _ble!.getAllBleCharacteristic();
    notifyListeners();
    if (!value) {
      cancelDataSubscription();
    } else {
      final characteristicDataList = dataMap[characteristicUuid] ?? <String>[];
      dataSubscription = _ble!.dataStream!.stream.listen((data) {
        if (kDebugMode) {
          print('inside bluetooth vm $data');
        }
        final utfData = DataConvertor.decode(data);
        characteristicDataList.add(utfData);
        dataMap[characteristicUuid] = characteristicDataList;
        notifyListeners();
      });
    }
  }

  cancelDataSubscription() {
    dataSubscription?.cancel();
  }

  List<String?> getDataList(String? characteristicUuid) {
    return dataMap[characteristicUuid] ?? <String>[];
  }
}
