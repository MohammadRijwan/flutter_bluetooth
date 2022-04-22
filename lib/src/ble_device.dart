class BleDevice {
  String? id;
  String? name;
  int? rssi;

  BleDevice({this.id, this.name, this.rssi});
}

enum BleDeviceState { disconnected, connecting, connected, disconnecting }

class BleDeviceUuids {
  final String serviceUuid;
  final String readCharacteristicUuid;
  final String writeCharacteristicUuid;

  BleDeviceUuids(
      {required this.readCharacteristicUuid,
      required this.writeCharacteristicUuid,
      required this.serviceUuid});
}
