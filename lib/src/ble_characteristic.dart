class BleCharacteristic {
  String? uuid;
  bool isNotifying;
  String? serviceUuid;
  bool isReadable;
  bool isWriteable;
  bool isNotifiable;
  bool isIndicatable;

  BleCharacteristic({
    this.uuid,
    this.isNotifying = false,
    this.serviceUuid,
    this.isReadable = false,
    this.isWriteable = false,
    this.isNotifiable = false,
    this.isIndicatable = false,
  });
}
