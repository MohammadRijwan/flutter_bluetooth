import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'IBleService.dart';
import 'ble_characteristic.dart';
import 'ble_device.dart';
import 'data_convertor.dart';

class FlutterBluetoothService implements IBleService {
  FlutterBluetoothService._privateConstructor();

  static final FlutterBluetoothService instance =
      FlutterBluetoothService._privateConstructor();

  List<Guid> _serviceGuidsList = [];
  Set<String?> _serviceUuidsSet = {};
  Set<String> _readCharacteristicUuidsSet = {};
  Set<String> _writeCharacteristicUuidsSet = {};
  RegExp? _deviceNameRegex;
  int? _scanDuration;

  @override
  setUuidsList(List<BleDeviceUuids> bleDeviceUuidsList) {
    _serviceGuidsList = [];
    _serviceUuidsSet = {};
    _readCharacteristicUuidsSet = {};
    _writeCharacteristicUuidsSet = {};
    bleDeviceUuidsList.forEach((bleDeviceUuids) {
      _serviceGuidsList.add(Guid(bleDeviceUuids.serviceUuid));
      _serviceUuidsSet.add(bleDeviceUuids.serviceUuid);
      _readCharacteristicUuidsSet.add(bleDeviceUuids.readCharacteristicUuid);
      _writeCharacteristicUuidsSet.add(bleDeviceUuids.writeCharacteristicUuid);
    });
  }

  @override
  setScanDuration(int time) {
    _scanDuration = time;
  }

  @override
  setDeviceNameRegex(RegExp deviceNameRegex) {
    _deviceNameRegex = deviceNameRegex;
  }

  FlutterBlue _flutterBlue = FlutterBlue.instance;
  //..setLogLevel(LogLevel.debug);
  StreamSubscription<ScanResult>? scanSubscription;
  StreamSubscription<List<int>>? characteristicValueSub;
  BluetoothCharacteristic? selectedReadCharacteristic;
  BluetoothCharacteristic? selectedWriteCharacteristic;
  StreamSubscription<BluetoothDeviceState>? _bluetoothDeviceStateSub;

  @override
  StreamController<BleDevice>? scanResultsStream =
      StreamController<BleDevice>.broadcast();

  @override
  Stream<bool>? isScanningStream;

  StreamController<String> errorStream = StreamController<String>.broadcast();

  @override
  StreamController<List<int>>? dataStream =
      StreamController<List<int>>.broadcast();

  @override
  StreamController<BleDeviceState>? bleDeviceStateStream =
      StreamController<BleDeviceState>.broadcast()
        ..add(BleDeviceState.disconnected);

  Future<bool> get isBluetoothAvailable => _flutterBlue.isAvailable;
  Future<bool> get isBluetoothOn => _flutterBlue.isOn;

  late Map<String, ScanResult> scanResults;
  Map<String, BluetoothCharacteristic>? _flutterBlueCharacteristicsMap;
  Map<String, BleCharacteristic> _bleCharacteristicsMap =
      Map<String, BleCharacteristic>();
  Map<String, BleCharacteristic> get bleCharacterics => _bleCharacteristicsMap;
  bool isScanning = false;
  ScanResult? scan;

  Future<bool> isBluetoothOk() async {
    return await isBluetoothAvailable && await isBluetoothOn;
  }

  @override
  startScan() async {
    isScanningStream = _flutterBlue.isScanning.asBroadcastStream();
    if (!await isBluetoothOk()) {
      if (kDebugMode) {
        print('please switch on bluetooth');
      }
      errorStream.add('please switch on bluetooth');
      return;
    }
    if (kDebugMode) {
      print('flutter_blue_service inside startScan');
    }
    if (isScanningStream == true) {
      if (kDebugMode) {
        print('Previous scan is already in progress');
      }
      errorStream.add('Previous scan is already in progress');
      return;
    }
    scanResults = Map<String, ScanResult>();
    if (!isScanning) {
      if (kDebugMode) {
        print('flutter_blue_service not scanning, will start scan');
      }
      try {
        scanSubscription = _flutterBlue.scan(
            scanMode: ScanMode.lowLatency,
            timeout: Duration(seconds: _scanDuration ?? 4),
            withServices: []).listen((scanResult) {
          isScanning = true;
          if (kDebugMode) {
            print('flutter_blue service inside scan result');
          }

          if (scanResult.device.id != null) {
            final scannedDevice = scanResult.device;
            print(
                '${scannedDevice.id} ${scannedDevice.name} found! rssi: ${scanResult.rssi}');
            var bleDevice = BleDevice(
                id: scanResult.device.id.id,
                name: scanResult.device.name,
                rssi: scanResult.rssi);

            if (_deviceNameRegex != null) {
              if (_deviceNameRegex!.firstMatch(scannedDevice.name) != null) {
                if (kDebugMode) {
                  print(
                      'Connecting to IPA Device ${scannedDevice.id} ${scannedDevice.name} found! rssi: ${scanResult.rssi}');
                }
                scanResults[scanResult.device.id.toString()] = scanResult;
                scanResultsStream!.sink.add(bleDevice);
                stopScan();
                connect(scannedDevice.id.id);
              }
            } else {
              scanResults[scanResult.device.id.toString()] = scanResult;
              scanResultsStream!.sink.add(bleDevice);
            }
          }
        }, onDone: () {
          if (kDebugMode) {
            print('Scan done');
          }
          stopScan();
        });
      } catch (e) {
        if (kDebugMode) {
          print('${e.toString()}');
        }
      }
    }
  }

  @override
  stopScan() {
    if (kDebugMode) {
      print('stop scan');
    }
    _flutterBlue.stopScan();
    scanSubscription?.cancel();
    isScanning = false;
  }

  @override
  connect(String? deviceId) async {
    var device = scanResults[deviceId!]?.device;
    if (device == null) {
      if (kDebugMode) {
        print('Please scan to find device first');
      }
      errorStream.add('Please scan to find device first');
      return;
    }

    if (kDebugMode) {
      print('connecting to ${device.name}');
    }
    try {
      await device.connect(autoConnect: false);
      _bluetoothDeviceStateSub?.cancel();
      _bluetoothDeviceStateSub = device.state.listen(_handleDeviceState);
      if (_serviceGuidsList.isNotEmpty) {
        await _setServicesAndCharacteristicsMap(device);
        await _setNotification(deviceId);
        await _setWriteCharacteristicForDeviceId(deviceId);
      } else {
        await _setServicesAndCharacteristicsMap(device);
      }
    } catch (e) {
      if (kDebugMode) {
        print('error connnecting to bluetooth id $deviceId $e');
      }
    }
  }

  _handleDeviceState(BluetoothDeviceState bluetoothDeviceState) {
    switch (bluetoothDeviceState) {
      case BluetoothDeviceState.disconnected:
        bleDeviceStateStream!.add(BleDeviceState.disconnected);
        break;
      case BluetoothDeviceState.connecting:
        bleDeviceStateStream!.add(BleDeviceState.connecting);
        break;
      case BluetoothDeviceState.connected:
        print('flutter_blue_service _handleDeviceState() state connected');
        bleDeviceStateStream!.add(BleDeviceState.connected);
        break;
      case BluetoothDeviceState.disconnecting:
        bleDeviceStateStream!.add(BleDeviceState.disconnecting);
        break;
    }
  }

  _setServicesAndCharacteristicsMap(BluetoothDevice device) async {
    _flutterBlueCharacteristicsMap = Map<String, BluetoothCharacteristic>();
    _bleCharacteristicsMap = Map<String, BleCharacteristic>();

    final _services = await device.discoverServices();
    _services.forEach((service) {
      service.characteristics.forEach((characteristic) {
        final serviceUuid = service.uuid.toString();
        final characteristicUuid = characteristic.uuid.toString();
        if (kDebugMode) {
          print(
              'service uuid:$serviceUuid,characteristic uuid:$characteristicUuid,$characteristic.lastValue.toString() ');
        }
        BleCharacteristic _bleCharacteristic = BleCharacteristic(
          uuid: characteristicUuid,
          isNotifying: characteristic.isNotifying,
          serviceUuid: serviceUuid,
          isIndicatable: characteristic.properties.indicate,
          isNotifiable: characteristic.properties.notify,
          isReadable: characteristic.properties.read,
          isWriteable: characteristic.properties.write,
        );

        _flutterBlueCharacteristicsMap![characteristicUuid] = characteristic;
        _bleCharacteristicsMap[characteristicUuid] = _bleCharacteristic;
      });
    });
  }

  @override
  Future<List<int>?> readCharacteristics(String? characteristicUuid) async {
    if (await isBluetoothOk()) {
      if (_flutterBlueCharacteristicsMap != null) {
        BluetoothCharacteristic? c =
            _flutterBlueCharacteristicsMap![characteristicUuid!];
        if (c != null) {
          return await c.read();
        }
      }
    }
    return null;
  }

  @override
  writeToCharacteristics(String? characteristicUuid, List<int> value) async {
    if (await isBluetoothOk()) {
      if (_flutterBlueCharacteristicsMap != null) {
        BluetoothCharacteristic? c =
            _flutterBlueCharacteristicsMap![characteristicUuid!];
        if (c != null) {
          await writeCharacteristicValue(c, value);
        }
      }
    }
  }

  @override
  disconnect(String? deviceId) async {
    if (await isBluetoothOk()) {
      final connectedDevice = await _findConnectedDeviceForId(deviceId);
      if (connectedDevice != null) {
        if (kDebugMode) {
          print('removing deviceId $deviceId from connected list');
        }
        //_removeCharacteristicNotificationListener();
        _flutterBlueCharacteristicsMap = Map<String, BluetoothCharacteristic>();
        _bleCharacteristicsMap = Map<String, BleCharacteristic>();
        connectedDevice.disconnect();
        await characteristicValueSub?.cancel();
        characteristicValueSub = null;
      }
    }
  }

  @override
  Future<bool> isDeviceConnected(String deviceId) async {
    if (await isBluetoothOk()) {
      return await _findConnectedDeviceForId(deviceId) != null;
    }
    return Future.value(false);
  }

  Future<List<BluetoothDevice>?> _getConnectedDevices() async {
    if (await isBluetoothOk()) {
      return await _flutterBlue.connectedDevices;
    }
    return null;
  }

  @override
  Future<Map<String, String>> getConnectedDevicesMap() async {
    var connectedDevices = Map<String, String>();
    List<BluetoothDevice>? connectedDevicesList = await _getConnectedDevices();
    if (connectedDevicesList != null) {
      for (var device in connectedDevicesList) {
        var deviceId = device.id.id;
        if (kDebugMode) {
          print('adding deviceId $deviceId to connected list');
        }
        connectedDevices[deviceId] = deviceId;
      }
    }
    return connectedDevices;
  }

  Future<BluetoothDevice> _findConnectedDeviceForId(String? deviceId) async {
    final List<BluetoothDevice> connectedDevicesList =
        await (_getConnectedDevices() as FutureOr<List<BluetoothDevice>>);
    return connectedDevicesList.firstWhere((device) => device.id.id == deviceId,
        orElse: null);
  }

  _setNotification(String? deviceId) async {
    BluetoothCharacteristic c =
        await (_findReadCharacteristicForDeviceId(deviceId)
            as FutureOr<BluetoothCharacteristic>);
    _setCharacteristicNotificationListener(c, true);
  }

  Future<BluetoothCharacteristic?> _findReadCharacteristicForDeviceId(
      String? deviceId) async {
    final _device = await _findConnectedDeviceForId(deviceId);
    final _selectedService =
        await (_findUuidMatchingService(_device) as FutureOr<BluetoothService>);
    selectedReadCharacteristic =
        _findMatchingReadCharacteristic(_selectedService);
    if (kDebugMode) {
      print(
          'flutter_blue_service _findCharacteristicForDeviceId ${selectedReadCharacteristic?.uuid.toString()} ');
    }
    return selectedReadCharacteristic;
  }

  Future<BluetoothCharacteristic?> _setWriteCharacteristicForDeviceId(
      String? deviceId) async {
    final _device = await _findConnectedDeviceForId(deviceId);
    final _selectedService =
        await (_findUuidMatchingService(_device) as FutureOr<BluetoothService>);
    selectedWriteCharacteristic =
        _findMatchingWriteCharacteristic(_selectedService);
    if (kDebugMode) {
      print(
          'flutter_blue_service _findCharacteristicForDeviceId ${selectedWriteCharacteristic?.uuid.toString()} ');
    }
    return selectedWriteCharacteristic;
  }

  Future<BluetoothService?> _findUuidMatchingService(
      BluetoothDevice device) async {
    final List<BluetoothService> _services = await device.discoverServices();
    return _services.firstWhereOrNull(
        (service) => _serviceUuidsSet.contains(service.uuid.toString()));
  }

  BluetoothCharacteristic? _findMatchingReadCharacteristic(
      BluetoothService service) {
    return service.characteristics.firstWhereOrNull((characteristic) =>
        _readCharacteristicUuidsSet.contains(characteristic.uuid.toString()));
  }

  BluetoothCharacteristic? _findMatchingWriteCharacteristic(
      BluetoothService service) {
    return service.characteristics.firstWhereOrNull((characteristic) =>
        _writeCharacteristicUuidsSet.contains(characteristic.uuid.toString()));
  }

  writeCharacteristicValue(BluetoothCharacteristic c, List<int> value) async {
    String timestamp = DataConvertor.getDateTime();
    if (kDebugMode) {
      print(
          'flutter_blue_service $timestamp writeCharacteristicValue() characteristic ${c.uuid.toString()} notification is set to ${c.isNotifying} :writing message $value');
    }
    await c.write(value, withoutResponse: true);
  }

  @override
  writeValue(List<int> value) async {
    if (await isBluetoothOk()) {
      var c = selectedWriteCharacteristic!;
      if (kDebugMode) {
        print(
            'flutter_blue_service  writeValue() characteristic ${c.uuid.toString()} notification has value ${c.isNotifying} :writing message $value');
      }
      await c.write(value, withoutResponse: true);
    }
  }

  @override
  setNotificationForCharacteristic(
      String? characteristicUuid, bool value) async {
    if (await isBluetoothOk()) {
      BluetoothCharacteristic? c =
          _flutterBlueCharacteristicsMap![characteristicUuid!];
      if (c != null) {
        await _setCharacteristicNotificationListener(c, value);
      }
    }
  }

//  _removeCharacteristicNotificationListener(BluetoothCharacteristic c) async {
//    print('characteristics uuid ${c.uuid.toString()}');
//    await c.setNotifyValue(false);
//  }

  _setCharacteristicNotificationListener(
      BluetoothCharacteristic c, bool valuetoSet) async {
    if (kDebugMode) {
      print(
          'characteristic:${c.uuid.toString()} current notification: ${c.isNotifying}, valuetoset:${valuetoSet}');
    }
    if (valuetoSet == false && c.isNotifying) {
      final newNotify = await c.setNotifyValue(valuetoSet);
      _updateBleMap(c.uuid.toString(), valuetoSet);
      if (kDebugMode) {
        print(
            'characteristic ${c.uuid.toString()} new notification value:${newNotify}');
      }
      characteristicValueSub?.cancel();
      characteristicValueSub = null;
    } else if (valuetoSet == true && !c.isNotifying) {
      final newNotify = await c.setNotifyValue(valuetoSet);
      _updateBleMap(c.uuid.toString(), valuetoSet);
      if (kDebugMode) {
        print(
            'characteristic ${c.uuid.toString()} new notification value:${newNotify}');
      }
      characteristicValueSub?.cancel();
      characteristicValueSub = null;
      characteristicValueSub = c.value.listen((data) {
        dataStream!.add(data);
        if (kDebugMode) {
          print('bluetooth service raw data received from ble $data');
        }
      }, onDone: () {
        if (kDebugMode) {
          print(
              'onDone method before cancel subs characteristic ${c.uuid.toString()} notification is set to ${c.isNotifying}');
        }
        characteristicValueSub?.cancel();
        if (kDebugMode) {
          print(
              'onDone method after cancel subs characteristic ${c.uuid.toString()} notification is set to ${c.isNotifying}');
        }
      });
    }
  }

  _updateBleMap(String characteristicUuid, bool notificationValue) {
    final bleCharacteristic = _bleCharacteristicsMap[characteristicUuid]!;
    bleCharacteristic.isNotifying = notificationValue;
    _bleCharacteristicsMap[characteristicUuid] = bleCharacteristic;
  }

  dispose() {
    scanSubscription?.cancel();
    scanResultsStream?.close();
    _bluetoothDeviceStateSub?.cancel();
  }

  initState() {
    return null;
  }

  @override
  writeToIpaCharacteristics(List<int> value) async {
    await writeToCharacteristics(
        selectedWriteCharacteristic!.uuid.toString(), value);
  }
}
