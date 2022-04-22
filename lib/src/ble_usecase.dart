import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../flutter_bluetooth.dart';

class BleUseCase implements IBlueTooth {
  static BleUseCase? _bleUseCaseInstance;
  String message = '';

  static BleUseCase? get bleUseCaseInstance {
    _bleUseCaseInstance ??= BleUseCase._privateConstructor();
    return _bleUseCaseInstance;
  }

  static IBlueTooth? instance;

  BleUseCase.test();

  BleUseCase(
      {required RegExp deviceNameRegex,
      required int scanDuration,
      required List<BleDeviceUuids> bleDeviceUuidsList}) {
    listenForBleDeviceState();
    _ble = nameDurationUuid(deviceNameRegex, scanDuration, bleDeviceUuidsList);
  }

  IBlueTooth? _ble;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  StreamSubscription<List<int>>? dataSubscription;
  StreamController<String> dataNotifierStream =
      StreamController<String>.broadcast();

  StreamSubscription<BleDeviceState>? bleDeviceStateSubscription;
  @override
  StreamController<BleDeviceState>? bleDeviceStateStream =
      StreamController<BleDeviceState>.broadcast();
  @override
  StreamController<bool>? isScanningStream = StreamController<bool>.broadcast();
  BleDeviceState bleDeviceState = BleDeviceState.disconnected;

  Timer? heartbeatTimer;
  bool _isStreamingData = false;

  bool get isStreamingData => _isStreamingData;
  int heartbeatTimerInterval = 300;

  Future<bool> getConnectionStatus() async {
    final connectedDevices = await _ble!.getAllConnectedDevices();
    _isConnected = connectedDevices.isNotEmpty;
    if (kDebugMode) {
      print('getConnectionStatus() $isConnected');
    }
    return _isConnected;
  }

  disconnectIPADevices() async {
    if (kDebugMode) {
      print('ble_usecase disconnectIPADevice()');
    }
    _isStreamingData = false;
    dataSubscription?.cancel();
    dataSubscription = null;
    if (kDebugMode) {
      print('ble_usecase disconnectIPADevice() dataSub $dataSubscription');
    }
    heartbeatTimer?.cancel();
    await bleUseCaseInstance!.disconnectIPADevice();
    _isConnected = !_isConnected;
  }

  writeCommandToBleWithDelayedQuery(String message, String command) async {
    await writeCommandToBle(message);
    await Future.delayed(const Duration(milliseconds: 500));
    writeCommandToBle(command);
    // writeCommandToBle('Q 18');
  }

  writeCommandToBle(String message) async {
    await _ble!.writeToIpaCharacteristics(message);
  }

  writeEncodedCommandToBle(List<int> encodedMsg) async {
    await _ble!.writeEncodedMessageToCharacteristics(
        AppConstants.characteristicUuid, encodedMsg);
  }

  startScanning() async {
    await _ble!.startScanAndConnectToIpaDevice();
    listenForScanStatus();
    _isConnected = !_isConnected;
    if (dataSubscription == null) {
      listenToData();
    }
  }

  listenForScanStatus() {
    var scanStatusSubscription;
    scanStatusSubscription = _ble!.isScanningStream!.stream.listen(
      (isScanningNow) {
        isScanningStream!.add(isScanningNow);
      },
      onDone: () {
        if (kDebugMode) {
          print(' bluetooth usecase scanresults on done');
        }
        scanStatusSubscription?.cancel();
      },
    );
  }

  sendRepeatedMsgToBle(String message) async {
    final encodedMsg = DataConvertor.encode(message);
    _isStreamingData = true;
    heartbeatTimer = Timer.periodic(
        Duration(milliseconds: heartbeatTimerInterval), (timer) async {
      if (!_isStreamingData) {
        timer.cancel();
      }
      if (kDebugMode) {
        print(
            '${DataConvertor.getDateTimeMillis()} sending query message $message to ble');
      }
      await writeEncodedCommandToBle(encodedMsg);
    });
  }

  listenForBleDeviceState() async {
    if (kDebugMode) {
      print('ble usecase _listenForBleDeviceState');
    }
    await bleDeviceStateSubscription?.cancel();
    bleDeviceStateSubscription = null;
    final id = Random().nextInt(100);
    if (kDebugMode) {
      print('meow######$_ble');
    }
    bleDeviceStateSubscription =
        _ble!.bleDeviceStateStream!.stream.listen((data) {
      //print('id:$id bluetoothInteractor data:$data');
      bleDeviceState = data;
      bleDeviceStateStream!.add(data);
    });
  }

  Future<void> listenToData() async {
    if (kDebugMode) {
      print('bleusecase _listenForBleData');
    }
    await dataSubscription?.cancel();
    dataSubscription = null;
    final id = Random().nextInt(100);
    StringBuffer concatenatedMsg = StringBuffer();
    dataSubscription = _ble!.dataStream!.stream.listen((data) {
      if (kDebugMode) {
        print('id:$id bleusecase bledata:$data');
      }
      if (data.isNotEmpty) {
        final utfDecodedData = DataConvertor.decodeUtf8(data)!;
        concatenatedMsg.write(utfDecodedData);
        if (utfDecodedData.contains("\n")) {
          final responseData = concatenatedMsg.toString();
          if (kDebugMode) {
            print('id:$id bleusecase utfdata:$responseData');
          }
          handleBleData(responseData);
          concatenatedMsg.clear();
        } else {
          if (kDebugMode) {
            print('id:$id bleusecase utfdata:${concatenatedMsg.toString()}');
          }
        }
      }
    });
  }

  cancelListener() async {
    await dataSubscription?.cancel();
    dataSubscription = null;
  }

  stopDataStream() {
    _isStreamingData = false;
  }

  dispose() {
    dataSubscription?.cancel();
    dataSubscription = null;
    _ble = null;
  }

  void handleBleData(String responseData) {
    if (kDebugMode) {
      print('ble_usecase  handleBleData');
    }
  }

  sendPostConnectionMessages() async {}

  ///Ble Interact class data

  late IBleService bleService;

  BleUseCase._privateConstructor() {
    bleService = FlutterBluetoothService.instance..setScanDuration(4);
    _initializeListeners();
  }

  BleUseCase._nameDurationUuid(RegExp deviceNameRegex, int scanDuration,
      List<BleDeviceUuids> bleDeviceUuidsList) {
    bleService = FlutterBluetoothService.instance
      ..setUuidsList(bleDeviceUuidsList)
      ..setDeviceNameRegex(deviceNameRegex)
      ..setScanDuration(scanDuration);
    _initializeListeners();
  }

  nameDurationUuid(RegExp deviceNameRegex, int scanDuration,
      List<BleDeviceUuids> bleDeviceUuidsList) {
    instance ??= BleUseCase._nameDurationUuid(
        deviceNameRegex, scanDuration, bleDeviceUuidsList);
    return instance;
  }

  Map<String, BleDevice> scanItems = <String, BleDevice>{};
  Map<String?, String?> connectedDevices = <String?, String?>{};
  bool isScanning = false;
  bool isError = false;
  StreamSubscription<Map<String, BleCharacteristic>>?
      characteristicsSubscription;
  StreamSubscription<BleDeviceState>? bleDeviceStateSubscriptions;

  @override
  StreamController<BleDevice>? scanResultsStream =
      StreamController<BleDevice>.broadcast();

  @override
  StreamController<List<int>>? dataStream =
      StreamController<List<int>>.broadcast();

  /* @override
  StreamController<BleDeviceState> bleDeviceStateStreams =
  StreamController<BleDeviceState>.broadcast();*/

  StreamController<bool> isScanningStreams = StreamController<bool>.broadcast();

  @override
  connect(String? deviceId) async {
    await bleService.connect(deviceId);
    _addToConnectedDevices(deviceId);
    _listenForBleData();
  }

  _addToConnectedDevices(deviceId) async {
    if (kDebugMode) {
      print('adding deviceId $deviceId to connected list');
    }
    connectedDevices[deviceId] = deviceId;
  }

  _initializeListeners() async {
    await _listenForBleDeviceState();
  }

  @override
  Future<Map<String, String>> initializeConnectedDevices() async {
    return await bleService.getConnectedDevicesMap();
  }

  @override
  Future<Map<String, String>> getAllConnectedDevices() async {
    return await bleService.getConnectedDevicesMap();
  }

  @override
  disconnectIPADevice() async {
    if (kDebugMode) {
      print('disconnectIPADevice()');
    }
    final connectedDevices = await getAllConnectedDevices();
    for (String id in connectedDevices.keys) {
      if (kDebugMode) {
        print('Disconnecting device $id');
      }
      await disconnect(id);
    }
  }

  @override
  disconnect(String? deviceId) async {
    await dataSubscription?.cancel();
    dataSubscription = null;
    _removeFromConnectedDevices(deviceId);
    await bleService.disconnect(deviceId);
  }

  _removeFromConnectedDevices(deviceId) async {
    if (kDebugMode) {
      print('removing deviceId $deviceId from connected list');
    }
    connectedDevices.remove(deviceId);
  }

  @override
  Future<bool> isDeviceConnected(String deviceId) async {
    return bleService.isDeviceConnected(deviceId);
  }

  @override
  startScan() async {
    scanItems = <String, BleDevice>{};
    await bleService.startScan();
    _listenForScanResults();
    _listenForScanStatus();
  }

  @override
  startScanAndConnectToIpaDevice() async {
    if (kDebugMode) {
      print("startScanAndConnectToIpaDevice");
    }
    await bleService.startScan();
    _listenForBleData();
  }

  _listenForScanResults() {
    var scanSubscription;
    scanSubscription = bleService.scanResultsStream!.stream.listen((bleDevice) {
      scanResultsStream!.add(bleDevice);
    }, onDone: () {
      if (kDebugMode) {
        print(' bluetooth manager scanresults on done');
      }
      scanSubscription?.cancel();
    });
  }

  _listenForScanStatus() {
    var scanStatusSubscription;
    scanStatusSubscription = bleService.isScanningStream!.listen(
      (isScanningNow) {
        isScanningStreams.add(isScanningNow);
      },
      onDone: () {
        if (kDebugMode) {
          print(' bluetooth manager scanresults on done');
        }
        scanStatusSubscription?.cancel();
      },
    );
  }

  @override
  stopScan() {
    bleService.stopScan();
  }

  _listenForBleData() async {
    if (kDebugMode) {
      print('bluetooth interactor _listenForBleData');
    }
    await dataSubscription?.cancel();
    dataSubscription = null;
    final id = Random().nextInt(100);
    dataSubscription = bleService.dataStream!.stream.listen((data) {
      //print('id:$id bluetoothInteractor data:$data');
      dataStream!.add(data);
    });
  }

  _listenForBleDeviceState() async {
    final id = Random().nextInt(100);
    if (kDebugMode) {
      print(' $id bluetooth interactor _listenForBleDeviceState');
    }
    await bleDeviceStateSubscriptions?.cancel();
    bleDeviceStateSubscriptions = null;
    bleDeviceStateSubscriptions =
        bleService.bleDeviceStateStream!.stream.listen((data) {
      //print('id:$id bluetoothInteractor data:$data');
      bleDeviceStateStream!.add(data);
    });
  }

  @override
  Map<String, BleCharacteristic> getAllBleCharacteristic() {
    return bleService.bleCharacterics;
  }

  @override
  writeToCharacteristics(String? characteristicUuid, String? message) async {
    final _encodedMsg = DataConvertor.encode(message!);
    if (kDebugMode) {
      print('bluetooth iteractor writeToCharacteristics() message $message');
    }
    await bleService.writeToCharacteristics(characteristicUuid, _encodedMsg);
  }

  @override
  writeToIpaCharacteristics(String message) async {
    final _encodedMsg = DataConvertor.encode(message);
    if (kDebugMode) {
      print('bluetooth iteractor writeToIpaCharacteristics() message $message');
    }
    await bleService.writeToIpaCharacteristics(_encodedMsg);
  }

  @override
  writeEncodedMessageToCharacteristics(
      String characteristicUuid, List<int> encodedMsg) async {
    if (kDebugMode) {
      print(
          'bluetooth iteractor writeEncodedMessageToCharacteristics() message $encodedMsg');
    }
    await bleService.writeToCharacteristics(characteristicUuid, encodedMsg);
  }

  @override
  Future<String> readCharacteristics(String? characteristicUuid) async {
    final data = await (bleService.readCharacteristics(characteristicUuid)
        as FutureOr<List<int>>);
    return DataConvertor.getUtf8FormattedData(data);
  }

  @override
  writeMessageToMldpCharacteristic(String deviceId, String message) async {
    final _encodedMsg = DataConvertor.encode(message);
    if (kDebugMode) {
      print('send message $message');
    }
    await bleService.writeValue(_encodedMsg);
  }

  @override
  setNotificationForCharacteristic(
      String? characteristicUuid, bool value) async {
    await bleService.setNotificationForCharacteristic(
        characteristicUuid, value);
  }
}
