class BleDevice {
  String? id;
  String? name;
  int? rssi;

  BleDevice({this.id, this.name, this.rssi});
}

enum BleDeviceState { disconnected, connecting, connected, disconnecting }

class BleDeviceUuids {
  final String? serviceUuid;
  final String? characteristicsUuid;
  final String? read;
  final String? write;

  BleDeviceUuids(
      {this.read, this.write, this.serviceUuid, this.characteristicsUuid});
}
