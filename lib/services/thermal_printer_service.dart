// lib/services/thermal_printer_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:async';

class ThermalPrinterService {
  static final ThermalPrinterService _instance =
  ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  // Bluetooth Thermal Printer
  BluetoothPrintPlus? _bluetoothPrint;
  List<BluetoothDevice> _scanResults = [];
  StreamSubscription<List<BluetoothDevice>>? _scanResultsSubscription;

  // USB Thermal Printer
  UsbPort? _usbPort;
  List<UsbDevice> _usbDevices = [];

  // Initialize Bluetooth Print Plus
  void _initBluetoothPrint() {
    _bluetoothPrint ??= BluetoothPrintPlus();
  }

  // Print via Bluetooth using bluetooth_print_plus
  Future<bool> printReceiptBluetooth({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    try {
      // Request permissions
      await _requestBluetoothPermissions();

      _initBluetoothPrint();

      // Check if Bluetooth is available/on
      if (!BluetoothPrintPlus.isBlueOn) {
        print('Bluetooth is not enabled');
        return false;
      }

      // Start scanning for devices
      await BluetoothPrintPlus.startScan(timeout: Duration(seconds: 10));

      // Listen for scan results
      _scanResultsSubscription = BluetoothPrintPlus.scanResults.listen((
          devices,
          ) {
        _scanResults = devices;
      });

      // Wait for scan to complete
      await Future.delayed(Duration(seconds: 10));

      if (_scanResults.isEmpty) {
        print('No Bluetooth devices found');
        return false;
      }

      // Find a printer device
      BluetoothDevice? printer = _findPrinterDevice(_scanResults);
      if (printer == null) {
        print('No printer device found');
        return false;
      }

      // Connect to printer
      await BluetoothPrintPlus.connect(printer);

      // Wait for connection
      await Future.delayed(Duration(seconds: 2));

      if (!BluetoothPrintPlus.isConnected) {
        print('Failed to connect to Bluetooth printer');
        return false;
      }

      // Generate receipt using ESC/POS commands
      List<int> receiptBytes = await _generateESCPOSReceipt(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      // Print the receipt
      await BluetoothPrintPlus.write(Uint8List.fromList(receiptBytes));

      // Disconnect
      await BluetoothPrintPlus.disconnect();

      print('Receipt printed successfully via Bluetooth');
      return true;
    } catch (e) {
      print('Error printing via Bluetooth: $e');
      return false;
    } finally {
      _scanResultsSubscription?.cancel();
    }
  }

  // Print via Bluetooth using print_bluetooth_thermal
  Future<bool> printReceiptBluetoothThermal({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    try {
      // Request permissions
      await _requestBluetoothPermissions();

      // Check Bluetooth status
      bool connectionStatus = await PrintBluetoothThermal.bluetoothEnabled;
      if (!connectionStatus) {
        print('Bluetooth is not enabled');
        return false;
      }

      // Get paired devices
      List<BluetoothInfo> pairedDevices =
      await PrintBluetoothThermal.pairedBluetooths;

      if (pairedDevices.isEmpty) {
        print('No paired Bluetooth devices found');
        return false;
      }

      // Find a printer device
      BluetoothInfo? printer = _findThermalPrinterDevice(pairedDevices);
      if (printer == null) {
        printer = pairedDevices.first; // Use first device if no specific printer found
      }

      // Connect to printer
      bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );
      if (!connected) {
        print('Failed to connect to thermal printer');
        return false;
      }

      // Generate receipt content
      String receiptContent = _generateReceiptContent(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      // Print the receipt
      List<int> ticket = await _generateThermalTicket(receiptContent);
      await PrintBluetoothThermal.writeBytes(ticket);

      // Disconnect
      await PrintBluetoothThermal.disconnect;

      print('Receipt printed successfully via Bluetooth Thermal');
      return true;
    } catch (e) {
      print('Error printing via Bluetooth Thermal: $e');
      return false;
    }
  }

  // Print receipt with multiple printer options
  Future<bool> printReceipt({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    print('🖨️ Starting print job...');

    // Try USB first
    try {
      bool usbSuccess = await printReceiptUSB(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      if (usbSuccess) {
        return true;
      }
    } catch (e) {
      print('USB print method failed: $e');
    }

    // Try Bluetooth with bluetooth_print_plus
    try {
      bool bluetoothSuccess = await printReceiptBluetooth(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      if (bluetoothSuccess) {
        return true;
      }
    } catch (e) {
      print('Bluetooth print method failed: $e');
    }

    // Try Bluetooth with print_bluetooth_thermal as last option
    try {
      bool thermalSuccess = await printReceiptBluetoothThermal(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      if (thermalSuccess) {
        return true;
      }
    } catch (e) {
      print('Thermal print method failed: $e');
    }

    print('❌ All printer methods failed');
    return false;
  }

  // Generate receipt content
  String _generateReceiptContent({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) {
    StringBuffer receipt = StringBuffer();

    // Header
    receipt.writeln('================================');
    receipt.writeln('         RESTAURANT NAME');
    receipt.writeln('================================');
    receipt.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    receipt.writeln('Transaction ID: $transactionId');
    receipt.writeln('Order Type: ${orderType.toUpperCase()}');
    receipt.writeln('================================');
    receipt.writeln();

    // Items
    receipt.writeln('ITEMS:');
    receipt.writeln('--------------------------------');

    for (CartItem item in cartItems) {
      double itemPricePerUnit = 0.0;
      if (item.foodItem.price.isNotEmpty) {
        var firstKey = item.foodItem.price.keys.first;
        itemPricePerUnit = item.foodItem.price[firstKey] ?? 0.0;
      }
      double itemTotal = itemPricePerUnit * item.quantity;

      receipt.writeln('${item.quantity}x ${item.foodItem.name}');

      // Add options if available
      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          receipt.writeln('  + $option');
        }
      }

      // Add comment if available
      if (item.comment != null && item.comment!.isNotEmpty) {
        receipt.writeln('  Note: ${item.comment}');
      }

      receipt.writeln('  £${itemTotal.toStringAsFixed(2)}');
      receipt.writeln();
    }

    // Totals
    receipt.writeln('--------------------------------');
    receipt.writeln('Subtotal:         £${subtotal.toStringAsFixed(2)}');
    receipt.writeln('VAT (5%):         £${vatAmount.toStringAsFixed(2)}');
    receipt.writeln('================================');
    receipt.writeln('TOTAL:            £${totalCharge.toStringAsFixed(2)}');
    receipt.writeln('================================');

    // Extra notes
    if (extraNotes != null && extraNotes.isNotEmpty) {
      receipt.writeln();
      receipt.writeln('Notes: $extraNotes');
    }

    // Footer
    receipt.writeln();
    receipt.writeln('Thank you for your order!');
    receipt.writeln('================================');

    return receipt.toString();
  }

  // Generate ESC/POS receipt
  Future<List<int>> _generateESCPOSReceipt({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(
      'RESTAURANT NAME',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text('Date: ${DateTime.now().toString().split('.')[0]}');
    bytes += generator.text('Transaction ID: $transactionId');
    bytes += generator.text('Order Type: ${orderType.toUpperCase()}');
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Items
    bytes += generator.text('ITEMS:', styles: const PosStyles(bold: true));
    bytes += generator.text('--------------------------------');

    for (CartItem item in cartItems) {
      double itemPricePerUnit = 0.0;
      if (item.foodItem.price.isNotEmpty) {
        var firstKey = item.foodItem.price.keys.first;
        itemPricePerUnit = item.foodItem.price[firstKey] ?? 0.0;
      }
      double itemTotal = itemPricePerUnit * item.quantity;

      bytes += generator.text('${item.quantity}x ${item.foodItem.name}');

      // Add options if available
      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          bytes += generator.text('  + $option');
        }
      }

      // Add comment if available
      if (item.comment != null && item.comment!.isNotEmpty) {
        bytes += generator.text('  Note: ${item.comment}');
      }

      bytes += generator.text(
        '  £${itemTotal.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.right),
      );
      bytes += generator.emptyLines(1);
    }

    // Totals
    bytes += generator.text('--------------------------------');
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 8),
      PosColumn(
        text: '£${subtotal.toStringAsFixed(2)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'VAT (5%):', width: 8),
      PosColumn(
        text: '£${vatAmount.toStringAsFixed(2)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.row([
      PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '£${totalCharge.toStringAsFixed(2)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Extra notes
    if (extraNotes != null && extraNotes.isNotEmpty) {
      bytes += generator.emptyLines(1);
      bytes += generator.text('Notes: $extraNotes');
    }

    // Footer
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Thank you for your order!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Feed paper
    bytes += generator.emptyLines(3);
    bytes += generator.cut();

    return bytes;
  }

  // Generate thermal ticket for print_bluetooth_thermal
  Future<List<int>> _generateThermalTicket(String content) async {
    List<int> bytes = [];

    // Convert string to bytes
    bytes.addAll(content.codeUnits);

    // Add line feeds
    bytes.addAll([10, 10, 10]); // 3 line feeds

    // Cut paper (if supported)
    bytes.addAll([29, 86, 65, 0]); // Full cut

    return bytes;
  }

  // Find printer device from bluetooth_print_plus devices
  BluetoothDevice? _findPrinterDevice(List<BluetoothDevice> devices) {
    for (BluetoothDevice device in devices) {
      String deviceName = device.name.toLowerCase();
      if (deviceName.contains('printer') ||
          deviceName.contains('thermal') ||
          deviceName.contains('pos') ||
          deviceName.contains('receipt')) {
        return device;
      }
    }
    return devices.isNotEmpty ? devices.first : null;
  }

  // Find printer device from print_bluetooth_thermal devices
  BluetoothInfo? _findThermalPrinterDevice(List<BluetoothInfo> devices) {
    for (BluetoothInfo device in devices) {
      String deviceName = device.name.toLowerCase();
      if (deviceName.contains('printer') ||
          deviceName.contains('thermal') ||
          deviceName.contains('pos') ||
          deviceName.contains('receipt')) {
        return device;
      }
    }
    return null;
  }

  // Find USB thermal printer device
  UsbDevice? _findUSBThermalPrinter(List<UsbDevice> devices) {
    for (UsbDevice device in devices) {
      // Check for common thermal printer vendor IDs
      // These are common vendor IDs for thermal printers
      if (device.vid == 0x0483 || // STMicroelectronics
          device.vid == 0x04b8 || // Epson
          device.vid == 0x04f9 || // Brother
          device.vid == 0x0fe6 || // ICS Advent
          device.vid == 0x154f || // SNBC
          device.vid == 0x0dd4 || // Zijiang
          device.vid == 0x1fc9 || // NXP
          device.vid == 0x2965) {  // Xprinter
        return device;
      }
    }

    // If no specific thermal printer found, return first device
    return devices.isNotEmpty ? devices.first : null;
  }

  // Request Bluetooth permissions
  Future<void> _requestBluetoothPermissions() async {
    try {
      List<Permission> permissions = [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ];

      Map<Permission, PermissionStatus> statuses = await permissions.request();

      for (var entry in statuses.entries) {
        if (entry.value != PermissionStatus.granted) {
          print('Permission ${entry.key} not granted: ${entry.value}');
        }
      }
    } catch (e) {
      print('Error requesting Bluetooth permissions: $e');
    }
  }

  // Get available Bluetooth devices
  Future<List<BluetoothDevice>> getBluetoothDevices() async {
    try {
      await _requestBluetoothPermissions();
      _initBluetoothPrint();

      if (!BluetoothPrintPlus.isBlueOn) {
        return [];
      }

      // Start scanning
      await BluetoothPrintPlus.startScan(timeout: Duration(seconds: 10));

      // Listen for scan results
      Completer<List<BluetoothDevice>> completer = Completer();
      StreamSubscription? subscription;

      subscription = BluetoothPrintPlus.scanResults.listen((devices) {
        if (!completer.isCompleted) {
          completer.complete(devices);
          subscription?.cancel();
        }
      });

      // Wait for scan to complete or timeout
      return await completer.future.timeout(
        Duration(seconds: 15),
        onTimeout: () {
          subscription?.cancel();
          return [];
        },
      );
    } catch (e) {
      print('Error getting Bluetooth devices: $e');
      return [];
    }
  }

  // Get available thermal Bluetooth devices
  Future<List<BluetoothInfo>> getThermalBluetoothDevices() async {
    try {
      await _requestBluetoothPermissions();

      bool connectionStatus = await PrintBluetoothThermal.bluetoothEnabled;
      if (!connectionStatus) {
        return [];
      }

      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      print('Error getting thermal Bluetooth devices: $e');
      return [];
    }
  }

  Future<bool> printReceiptUSB({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    try {
      // Check if USB serial plugin is available
      if (!await _isUSBSerialAvailable()) {
        print('USB serial plugin not available on this platform');
        return false;
      }

      // Get available USB devices
      List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        print('No USB devices found');
        return false;
      }

      // Find thermal printer device
      UsbDevice? printer = _findUSBThermalPrinter(devices);
      if (printer == null) {
        print('No USB thermal printer found');
        return false;
      }

      // Connect to USB device
      _usbPort = await printer.create();
      if (_usbPort == null) {
        print('Failed to create USB port');
        return false;
      }

      bool opened = await _usbPort!.open();
      if (!opened) {
        print('Failed to open USB port');
        return false;
      }

      // Set port parameters for thermal printer
      await _usbPort!.setPortParameters(9600, 8, 1, 0);

      // Generate ESC/POS receipt
      List<int> receiptBytes = await _generateESCPOSReceipt(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      // Send data to USB printer
      await _usbPort!.write(Uint8List.fromList(receiptBytes));

      // Wait for printing to complete
      await Future.delayed(Duration(seconds: 2));

      // Close USB connection
      await _usbPort!.close();

      print('Receipt printed successfully via USB');
      return true;
    } on MissingPluginException catch (e) {
      print('USB serial plugin not implemented on this platform: $e');
      return false;
    } catch (e) {
      print('Error printing via USB: $e');
      if (_usbPort != null) {
        try {
          await _usbPort!.close();
        } catch (closeError) {
          print('Error closing USB port: $closeError');
        }
      }
      return false;
    }
  }

// Check if USB serial plugin is available
  Future<bool> _isUSBSerialAvailable() async {
    try {
      await UsbSerial.listDevices();
      return true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      return false;
    }
  }

// Get available USB printers
  Future<List<UsbDevice>> getUSBPrinters() async {
    try {
      if (!await _isUSBSerialAvailable()) {
        print('USB serial plugin not available on this platform');
        return [];
      }

      List<UsbDevice> devices = await UsbSerial.listDevices();
      return devices.where((device) => _findUSBThermalPrinter([device]) != null).toList();
    } on MissingPluginException catch (e) {
      print('USB serial plugin not implemented on this platform: $e');
      return [];
    } catch (e) {
      print('Error getting USB printers: $e');
      return [];
    }
  }

// Test connection methods
  Future<bool> testUSBConnection() async {
    try {
      if (!await _isUSBSerialAvailable()) {
        print('USB serial plugin not available on this platform');
        return false;
      }

      List<UsbDevice> printers = await getUSBPrinters();
      return printers.isNotEmpty;
    } on MissingPluginException catch (e) {
      print('USB serial plugin not implemented on this platform: $e');
      return false;
    } catch (e) {
      print('Error testing USB connection: $e');
      return false;
    }
  }

  Future<bool> testBluetoothConnection() async {
    try {
      List<BluetoothDevice> devices = await getBluetoothDevices();
      return devices.isNotEmpty;
    } catch (e) {
      print('Error testing Bluetooth connection: $e');
      return false;
    }
  }

  Future<bool> testThermalBluetoothConnection() async {
    try {
      List<BluetoothInfo> devices = await getThermalBluetoothDevices();
      return devices.isNotEmpty;
    } catch (e) {
      print('Error testing thermal Bluetooth connection: $e');
      return false;
    }
  }

  // Run connection tests
  Future<Map<String, bool>> testAllConnections() async {
    print('🧪 Testing all printer connections...');

    Map<String, bool> results = {
      'usb': await testUSBConnection(),
      'bluetooth': await testBluetoothConnection(),
      'thermal': await testThermalBluetoothConnection(),
    };

    print('📊 Connection Test Results:');
    print('   USB: ${results['usb'] == true ? "✅ Available" : "❌ Not Available"}');
    print('   Bluetooth: ${results['bluetooth'] == true ? "✅ Available" : "❌ Not Available"}');
    print('   Thermal: ${results['thermal'] == true ? "✅ Available" : "❌ Not Available"}');

    return results;
  }
}