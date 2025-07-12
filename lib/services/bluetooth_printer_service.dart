// lib/services/bluetooth_printer_service.dart
import 'dart:async';
import 'package:epos/models/printer_device.dart';
import 'package:epos/services/i_printer_service.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class BluetoothPrinterService implements IPrinterService {
  final FlutterBluetoothPrinter _bluetoothPrinter = FlutterBluetoothPrinter();
  final _scanController = StreamController<List<PrinterDevice>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  PrinterDevice? _connectedDevice;
  StreamSubscription? _scanResultsSubscription;

  BluetoothPrinterService() {
    // No _connectionStatusSubscription here. Status updates will be manual based on operation outcomes.
  }

  @override
  Stream<List<PrinterDevice>> get onScanResult => _scanController.stream;

  @override
  Stream<String> get onConnectionStatusChanged => _statusController.stream;

  @override
  PrinterDevice? get connectedDevice => _connectedDevice;

  @override
  Future<void> startScan() async {
    _statusController.add('Scanning Bluetooth...');
    _scanController.add([]); // Clear previous scan results
    await _scanResultsSubscription?.cancel(); // Cancel any ongoing scan

    _scanResultsSubscription = _bluetoothPrinter.devices.listen((List<BluetoothDevice> devices) {
      final uniqueDevices = <String, PrinterDevice>{};
      for (var device in devices) {
        if (device.address != null && device.name != null) {
          uniqueDevices[device.address!] = PrinterDevice(
            name: device.name!,
            address: device.address!,
            type: 'bluetooth',
            originalDevice: device,
          );
        }
      }
      _scanController.add(uniqueDevices.values.toList());
    }, onError: (e) {
      _statusController.add('Bluetooth Scan Error: $e');
      debugPrint('Bluetooth Scan Error: $e');
    }, onDone: () {
      _statusController.add('Bluetooth Scan Complete');
    });

    try {
      await _bluetoothPrinter.startScan();
    } catch (e) {
      debugPrint('Error starting Bluetooth scan: $e');
      _statusController.add('Error starting scan: $e');
    }
  }

  @override
  Future<void> stopScan() async {
    _scanResultsSubscription?.cancel();
    try {
      await _bluetoothPrinter.stopScan();
    } catch (e) {
      debugPrint('Error stopping Bluetooth scan: $e');
    }
    _statusController.add('Bluetooth Scan Stopped');
  }

  @override
  Future<bool> connect(PrinterDevice device) async {
    if (device.type != 'bluetooth' || device.originalDevice == null) {
      _statusController.add('Connection Failed: Invalid Bluetooth Device');
      return false;
    }

    final BluetoothDevice btDevice = device.originalDevice as BluetoothDevice;

    _statusController.add('Connecting to ${device.name}...');
    try {
      await _bluetoothPrinter.connect(address: btDevice.address!, name: btDevice.name!);
      _connectedDevice = device;
      _statusController.add('Connected to ${device.name}');
      return true;
    } catch (e) {
      _statusController.add('Connection Failed: $e');
      debugPrint('Bluetooth Connect Error: $e');
      _connectedDevice = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connectedDevice?.address != null) {
      _statusController.add('Disconnecting from ${_connectedDevice!.name}...');
      try {
        await _bluetoothPrinter.disconnect(address: _connectedDevice!.address);
        _connectedDevice = null;
        _statusController.add('Disconnected');
      } catch (e) {
        _statusController.add('Disconnection Error: $e');
        debugPrint('Bluetooth Disconnect Error: $e');
      }
    }
  }

  @override
  Future<bool> printReceipt(List<int> bytes) async {
    if (_connectedDevice?.address == null) {
      _statusController.add('Printing Failed: No Bluetooth printer connected');
      return false;
    }
    _statusController.add('Sending data to ${_connectedDevice!.name}...');
    try {
      await _bluetoothPrinter.printRawData(bytes);
      _statusController.add('Print Complete');
      return true;
    } catch (e) {
      _statusController.add('Printing Error: $e');
      debugPrint('Bluetooth Print Error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _scanController.close();
    _statusController.close();
  }
}