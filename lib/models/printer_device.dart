// lib/models/printer_device.dart
class PrinterDevice {
  final String name;
  final String address;
  final String? type; // 'bluetooth', 'usb', 'network'
  final dynamic originalDevice; // Store the original device object from the library

  PrinterDevice({
    required this.name,
    required this.address,
    this.type,
    this.originalDevice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PrinterDevice &&
              runtimeType == other.runtimeType &&
              address == other.address;

  @override
  int get hashCode => address.hashCode;
}