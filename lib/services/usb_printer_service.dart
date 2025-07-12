// lib/services/usb_printer_service.dart
import 'dart:async';
import 'dart:typed_data'; // Import for Uint8List
import 'package:epos/models/printer_device.dart';
import 'package:epos/services/i_printer_service.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart'; // The package itself
import 'package:flutter/foundation.dart'; // For debugPrint

class UsbPrinterService implements IPrinterService {
  final FlutterUsbPrinter _usbPrinter = FlutterUsbPrinter();
  final _scanController = StreamController<List<PrinterDevice>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  PrinterDevice? _connectedDevice;

  @override
  Stream<List<PrinterDevice>> get onScanResult => _scanController.stream;

  @override
  Stream<String> get onConnectionStatusChanged => _statusController.stream;

  @override
  PrinterDevice? get connectedDevice => _connectedDevice;

  @override
  Future<void> startScan() async {
    _statusController.add('Scanning USB...');
    _scanController.add([]); // Clear previous scan results
    try {
      // Correct method for getting device list
      List<Map<String, dynamic>> devices = (await _usbPrinter.getDeviceList() as List)
          .cast<Map<String, dynamic>>();


      final printerDevices = devices.map((deviceMap) {
        final deviceName = deviceMap['deviceName'] as String?;
        final vendorId = deviceMap['vendorId'] as int?;
        final productId = deviceMap['productId'] as int?;
        final manufacturer = deviceMap['manufacturer'] as String?;
        final serialNumber = deviceMap['serialNumber'] as String?;

        if (deviceName != null && vendorId != null && productId != null) {
          return PrinterDevice(
            name: deviceName,
            // A unique identifier for USB might be vendorId:productId or serialNumber
            address: '$vendorId:$productId-${serialNumber ?? ''}', // More robust address
            type: 'usb',
            originalDevice: deviceMap, // Store the native device map
          );
        }
        return null; // Filter out invalid entries
      }).whereType<PrinterDevice>().toList(); // Filter out nulls

      _scanController.add(printerDevices);
      _statusController.add('USB Scan Complete: ${printerDevices.length} devices found');
    } catch (e) {
      _statusController.add('USB Scan Error: $e');
      debugPrint('USB Scan Error: $e');
    }
  }

  @override
  Future<void> stopScan() async {
    // USB scan is typically a one-shot query, not a continuous stream
    _statusController.add('USB Scan Stopped');
  }

  @override
  Future<bool> connect(PrinterDevice device) async {
    if (device.type != 'usb' || device.originalDevice == null) {
      _statusController.add('Connection Failed: Invalid USB Device Type');
      return false;
    }

    final usbDeviceMap = device.originalDevice as Map<String, dynamic>;
    final vendorId = usbDeviceMap['vendorId'] as int?;
    final productId = usbDeviceMap['productId'] as int?;

    if (vendorId == null || productId == null) {
      _statusController.add('Connection Failed: Missing USB Vendor/Product ID for ${device.name}');
      return false;
    }

    _statusController.add('Connecting to ${device.name} (USB)...');
    try {
      // Correct method for connecting
      bool isConnected = await _usbPrinter.connect(vendorId, productId);
      if (isConnected) { // connect returns true on success
        _connectedDevice = device;
        _statusController.add('Connected to ${device.name} (USB)');
        return true;
      } else {
        _statusController.add('Connection Failed (USB) for ${device.name}');
        return false;
      }
    } catch (e) {
      _statusController.add('Connection Failed: $e');
      debugPrint('USB Connect Error: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _statusController.add('Disconnecting (USB)...');
      try {
        await _usbPrinter.close(); // Correct method to close port
        _connectedDevice = null;
        _statusController.add('Disconnected (USB)');
      } catch (e) {
        _statusController.add('Disconnection Error: $e');
        debugPrint('USB Disconnect Error: $e');
      }
    }
  }

  @override
  Future<bool> printReceipt(List<int> bytes) async {
    if (_connectedDevice == null) {
      _statusController.add('Printing Failed: No USB printer connected');
      return false;
    }
    _statusController.add('Sending data to ${_connectedDevice!.name} (USB)...');
    try {
      // The `write` method typically expects Uint8List
      // Convert List<int> to Uint8List
      await _usbPrinter.write(Uint8List.fromList(bytes));
      _statusController.add('Print Complete');
      return true;
    } catch (e) {
      _statusController.add('Printing Error: $e');
      debugPrint('USB Print Error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _scanController.close();
    _statusController.close();
    // It's good practice to disconnect on dispose, but ensure it's non-blocking
    disconnect();
  }
}