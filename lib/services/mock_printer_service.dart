// lib/services/mock_printer_service.dart
import 'dart:async';
import 'package:epos/models/printer_device.dart';
import 'package:epos/services/i_printer_service.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class MockPrinterService implements IPrinterService {
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
    _statusController.add('Scanning (Mock)');
    await Future.delayed(const Duration(seconds: 2));
    final mockDevices = [
      PrinterDevice(name: 'Mock Printer 1', address: 'MOCK_BT_001', type: 'bluetooth'),
      PrinterDevice(name: 'Mock Printer 2', address: 'MOCK_USB_001', type: 'usb'),
    ];
    _scanController.add(mockDevices);
    _statusController.add('Scan Complete (Mock)');
  }

  @override
  Future<void> stopScan() async {
    _statusController.add('Scan Stopped (Mock)');
  }

  @override
  Future<bool> connect(PrinterDevice device) async {
    _statusController.add('Connecting to ${device.name} (Mock)...');
    await Future.delayed(const Duration(seconds: 1));
    _connectedDevice = device;
    _statusController.add('Connected to ${device.name} (Mock)');
    return true;
  }

  @override
  Future<void> disconnect() async {
    _statusController.add('Disconnecting (Mock)...');
    await Future.delayed(const Duration(milliseconds: 500));
    _connectedDevice = null;
    _statusController.add('Disconnected (Mock)');
  }

  @override
  Future<bool> printReceipt(List<int> bytes) async {
    if (_connectedDevice == null) {
      _statusController.add('Print Failed: No mock printer connected');
      return false;
    }
    _statusController.add('Printing ${_connectedDevice!.name} (Mock)...');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Mock Print Data (${bytes.length} bytes): ${String.fromCharCodes(bytes)}');
    _statusController.add('Print Complete (${_connectedDevice!.name} Mock)');
    return true;
  }

  @override
  void dispose() {
    _scanController.close();
    _statusController.close();
  }
}