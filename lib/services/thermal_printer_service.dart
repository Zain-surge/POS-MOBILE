// lib/services/thermal_printer_service.dart
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();
  static const bool ENABLE_MOCK_MODE = false; // Set to false in production
  static const bool SIMULATE_PRINTER_SUCCESS = false; // Simulate successful connections
  // Connection pools for persistent connections
  UsbPort? _persistentUsbPort;
  String? _connectedBluetoothDevice;
  bool _isBluetoothConnected = false;

  // Cached devices for speed
  List<BluetoothInfo> _cachedThermalDevices = [];
  List<UsbDevice> _cachedUsbDevices = [];
  DateTime? _lastCacheUpdate;

  // Connection timeout settings
  static const Duration QUICK_TIMEOUT = Duration(seconds: 2);
  static const Duration NORMAL_TIMEOUT = Duration(seconds: 5);
  static const Duration CACHE_VALIDITY = Duration(minutes: 5);

  // Connection health monitoring
  Timer? _connectionHealthTimer;
  bool _isMonitoringConnection = false;

  // OPTIMIZED: Pre-generated receipt cache
  Map<String, List<int>> _receiptCache = {};

  Future<Map<String, bool>> testAllConnections() async {
    print('🧪 Testing all printer connections...');

    // Skip web-specific checks
    if (kIsWeb) {
      print('📱 Web platform detected - skipping native printer checks');
      return {
        'usb': false,
        'bluetooth': false,
      };
    }

    List<Future<bool>> futures = [];
    List<String> methods = [];

    // Only test USB on mobile/desktop platforms
    if (Platform.isAndroid || Platform.isWindows || Platform.isLinux) {
      futures.add(_testUSBConnection());
      methods.add('usb');
    }

    // Only test Bluetooth on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      futures.add(_testThermalBluetoothConnection());
      methods.add('bluetooth');
    }

    if (futures.isEmpty) {
      return {
        'usb': false,
        'bluetooth': false,
      };
    }

    List<bool> results = await Future.wait(futures);

    Map<String, bool> testResults = {};
    for (int i = 0; i < methods.length; i++) {
      testResults[methods[i]] = results[i];
    }

    // Fill in missing methods
    if (!testResults.containsKey('usb')) testResults['usb'] = false;
    if (!testResults.containsKey('bluetooth')) testResults['bluetooth'] = false;

    print('📊 Test Results:');
    print('   USB: ${testResults['usb'] == true ? "✅ Available" : "❌ Not Available"}');
    print('   Bluetooth: ${testResults['bluetooth'] == true ? "✅ Available" : "❌ Not Available"}');

    return testResults;
  }

  // OPTIMIZED: Fast USB connection test with improved caching
  Future<bool> _testUSBConnection() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 500)); // Simulate connection time
      print('🧪 MOCK: USB printer simulated - ${SIMULATE_PRINTER_SUCCESS ? "Connected" : "Failed"}');
      return SIMULATE_PRINTER_SUCCESS;
    }

    try {
      if (!await _isUSBSerialAvailable()) return false;

      // Use cached devices if available and recent
      if (_cachedUsbDevices.isEmpty || _isCacheExpired()) {
        _cachedUsbDevices = await UsbSerial.listDevices();
        _lastCacheUpdate = DateTime.now();
      }

      if (_cachedUsbDevices.isEmpty) return false;

      // If we already have a persistent connection, test it quickly
      if (_persistentUsbPort != null) {
        try {
          // Quick health check - send minimal data
          await _persistentUsbPort!.write(Uint8List.fromList([0x1B, 0x40])); // ESC @ (initialize)
          await Future.delayed(Duration(milliseconds: 100));
          return true;
        } catch (e) {
          print('🔧 USB connection health check failed: $e');
          await _closeUsbConnection();
        }
      }

      // Establish new connection with first available device
      UsbDevice device = _cachedUsbDevices.first;
      return await _establishUSBConnection(device);
    } catch (e) {
      print('❌ USB test error: $e');
      return false;
    }
  }

  // OPTIMIZED: Fast Bluetooth connection test with health monitoring
  Future<bool> _testThermalBluetoothConnection() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 800)); // Simulate connection time
      print('🧪 MOCK: Bluetooth thermal printer simulated - ${SIMULATE_PRINTER_SUCCESS ? "Connected" : "Failed"}');
      return SIMULATE_PRINTER_SUCCESS;
    }

    try {
      if (!await _isBluetoothEnabled()) return false;

      // Use cached devices if available and recent
      if (_cachedThermalDevices.isEmpty || _isCacheExpired()) {
        _cachedThermalDevices = await PrintBluetoothThermal.pairedBluetooths;
        _lastCacheUpdate = DateTime.now();
      }

      if (_cachedThermalDevices.isEmpty) return false;

      // If already connected, test connection health
      if (_isBluetoothConnected && _connectedBluetoothDevice != null) {
        try {
          bool isConnected = await PrintBluetoothThermal.connectionStatus;
          if (isConnected) {
            // Send a quick test command
            await PrintBluetoothThermal.writeBytes([0x1B, 0x40]); // ESC @ (initialize)
            await Future.delayed(Duration(milliseconds: 100));
            return true;
          }
        } catch (e) {
          print('🔧 Bluetooth connection health check failed: $e');
          await _closeBluetoothConnection();
        }
      }

      // Establish new connection
      return await _establishBluetoothConnection();
    } catch (e) {
      print('❌ Bluetooth test error: $e');
      return false;
    }
  }

  // SUPER OPTIMIZED: Ultra-fast printing with pre-generated receipts
  Future<bool> printReceiptWithUserInteraction({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
    Function(List<String> availableMethods)? onShowMethodSelection,
  }) async {
    if (kIsWeb) {
      print('🚫 Web platform - printer not supported');
      return false;
    }

    print('🖨️ Starting super-fast print job...');

    // Pre-generate receipt data while testing connections
    String receiptKey = '$transactionId-$orderType-${cartItems.length}';

    // Generate receipt data in parallel with connection testing
    Future<List<int>> receiptDataFuture = _generateESCPOSReceipt(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
    );

    Future<String> receiptContentFuture = Future.value(_generateReceiptContent(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
    ));

    // Test connections in parallel
    Future<Map<String, bool>> connectionTestFuture = testAllConnections();

    // Wait for all preparations to complete
    List<dynamic> results = await Future.wait([
      connectionTestFuture,
      receiptDataFuture,
      receiptContentFuture,
    ]);

    Map<String, bool> connectionStatus = results[0];
    List<int> receiptData = results[1];
    String receiptContent = results[2];

    // Cache the generated receipt data
    _receiptCache[receiptKey] = receiptData;

    List<String> availableMethods = [];
    if (connectionStatus['usb'] == true) availableMethods.add('USB');
    if (connectionStatus['bluetooth'] == true) availableMethods.add('Thermal Bluetooth');

    if (availableMethods.isEmpty) {
      print('❌ No printer connections available');
      if (onShowMethodSelection != null) {
        onShowMethodSelection(['USB', 'Thermal Bluetooth']);
      }
      return false;
    }

    // Start connection health monitoring
    _startConnectionHealthMonitoring();

    // Try available methods with pre-generated data
    for (String method in availableMethods) {
      print('🚀 Attempting super-fast $method printing...');

      bool success = await _printWithPreGeneratedData(
        method: method,
        receiptData: receiptData,
        receiptContent: receiptContent,
      );

      if (success) {
        print('✅ $method printing successful');
        return true;
      }
    }

    print('❌ All available methods failed');
    if (onShowMethodSelection != null) {
      onShowMethodSelection(availableMethods);
    }
    return false;
  }

  // SUPER OPTIMIZED: Direct printing with pre-generated data
  Future<bool> _printWithPreGeneratedData({
    required String method,
    required List<int> receiptData,
    required String receiptContent,
  }) async {
    switch (method) {
      case 'USB':
        return await _printUSBSuperFast(receiptData);
      case 'Thermal Bluetooth':
        return await _printBluetoothSuperFast(receiptContent);
      default:
        return false;
    }
  }

  // SUPER OPTIMIZED: Ultra-fast USB printing
  Future<bool> _printUSBSuperFast(List<int> receiptData) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1000)); // Simulate print time
      print('🧪 MOCK: USB printing simulated');
      print('📄 Receipt data length: ${receiptData.length} bytes');
      print('📄 Receipt preview: ${String.fromCharCodes(receiptData.take(100))}...');
      return SIMULATE_PRINTER_SUCCESS;
    }


    try {
      // Ensure we have a persistent connection
      if (_persistentUsbPort == null) {
        if (_cachedUsbDevices.isEmpty) {
          _cachedUsbDevices = await UsbSerial.listDevices();
        }
        if (_cachedUsbDevices.isEmpty) return false;

        if (!await _establishUSBConnection(_cachedUsbDevices.first)) {
          return false;
        }
      }

      // Ultra-fast printing with minimal delays
      await _persistentUsbPort!.write(Uint8List.fromList(receiptData));
      await Future.delayed(Duration(milliseconds: 50)); // Minimal delay

      print('✅ USB super-fast print successful');
      return true;

    } catch (e) {
      print('❌ USB super-fast print error: $e');
      await _closeUsbConnection();
      return false;
    }
  }

  // SUPER OPTIMIZED: Ultra-fast Bluetooth printing
  Future<bool> _printBluetoothSuperFast(String receiptContent) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1200)); // Simulate print time
      print('🧪 MOCK: Bluetooth printing simulated');
      print('📄 Receipt content preview:');
      print(receiptContent.substring(0, math.min(200, receiptContent.length)) + '...');
      return SIMULATE_PRINTER_SUCCESS;
    }

    try {
      // Ensure we have a persistent connection
      if (!_isBluetoothConnected) {
        if (!await _establishBluetoothConnection()) {
          return false;
        }
      }

      // Generate thermal ticket and print immediately
      List<int> ticket = await _generateThermalTicket(receiptContent);
      await PrintBluetoothThermal.writeBytes(ticket);

      print('✅ Bluetooth super-fast print successful');
      return true;

    } catch (e) {
      print('❌ Bluetooth super-fast print error: $e');
      await _closeBluetoothConnection();
      return false;
    }
  }

  // Add this method to your class
  Future<bool> validateReceiptGeneration({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    try {
      // Test receipt content generation
      String receiptContent = _generateReceiptContent(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      // Test ESC/POS receipt generation
      List<int> receiptData = await _generateESCPOSReceipt(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        vatAmount: vatAmount,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
      );

      print('✅ Receipt generation validation successful');
      print('📄 Content length: ${receiptContent.length} characters');
      print('📄 ESC/POS data length: ${receiptData.length} bytes');

      return true;
    } catch (e) {
      print('❌ Receipt generation validation failed: $e');
      return false;
    }
  }

  // IMPROVED: Robust USB connection establishment
  Future<bool> _establishUSBConnection(UsbDevice device) async {
    try {
      _persistentUsbPort = await device.create();
      if (_persistentUsbPort == null) return false;

      bool opened = await _persistentUsbPort!.open();
      if (!opened) {
        _persistentUsbPort = null;
        return false;
      }

      // Optimal settings for thermal printers
      await _persistentUsbPort!.setPortParameters(
        115200, // Higher baud rate for faster printing
        8,
        1,
        0,
      );

      // Send initialization command
      await _persistentUsbPort!.write(Uint8List.fromList([0x1B, 0x40])); // ESC @
      await Future.delayed(Duration(milliseconds: 100));

      print('✅ USB persistent connection established with optimal settings');
      return true;

    } catch (e) {
      print('❌ Failed to establish USB connection: $e');
      _persistentUsbPort = null;
      return false;
    }
  }

  // IMPROVED: Robust Bluetooth connection establishment
  Future<bool> _establishBluetoothConnection() async {
    try {
      if (_cachedThermalDevices.isEmpty) return false;

      BluetoothInfo? printer = _findThermalPrinterDevice(_cachedThermalDevices);
      printer ??= _cachedThermalDevices.first;

      // Disconnect any existing connection first
      if (_isBluetoothConnected) {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(Duration(milliseconds: 200));
      }

      bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );

      if (connected) {
        _isBluetoothConnected = true;
        _connectedBluetoothDevice = printer.macAdress;

        // Send initialization command
        await PrintBluetoothThermal.writeBytes([0x1B, 0x40]); // ESC @
        await Future.delayed(Duration(milliseconds: 100));

        print('✅ Bluetooth persistent connection established');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Failed to establish Bluetooth connection: $e');
      _isBluetoothConnected = false;
      _connectedBluetoothDevice = null;
      return false;
    }
  }

  // NEW: Connection health monitoring
  void _startConnectionHealthMonitoring() {
    if (_isMonitoringConnection) return;

    _isMonitoringConnection = true;
    _connectionHealthTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!_isMonitoringConnection) {
        timer.cancel();
        return;
      }

      // Check USB connection health
      if (_persistentUsbPort != null) {
        try {
          await _persistentUsbPort!.write(Uint8List.fromList([0x1B, 0x40]));
        } catch (e) {
          print('🔧 USB connection lost, attempting reconnection...');
          await _closeUsbConnection();
        }
      }

      // Check Bluetooth connection health
      if (_isBluetoothConnected) {
        try {
          bool isConnected = await PrintBluetoothThermal.connectionStatus;
          if (!isConnected) {
            print('🔧 Bluetooth connection lost, attempting reconnection...');
            await _closeBluetoothConnection();
          }
        } catch (e) {
          print('🔧 Bluetooth health check failed: $e');
          await _closeBluetoothConnection();
        }
      }
    });
  }

  void _stopConnectionHealthMonitoring() {
    _isMonitoringConnection = false;
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  // OPTIMIZED: Retry with connection reset
  Future<bool> retryPrintingMethod({
    required String method,
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double vatAmount,
    required double totalCharge,
    String? extraNotes,
  }) async {
    if (kIsWeb) return false;

    print('🔄 Retrying $method printing with connection reset...');

    // Clean up existing connections
    await _closeAllConnections();
    _clearCache();

    // Generate receipt data
    List<int> receiptData = await _generateESCPOSReceipt(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
    );

    String receiptContent = _generateReceiptContent(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
    );

    return await _printWithPreGeneratedData(
      method: method,
      receiptData: receiptData,
      receiptContent: receiptContent,
    );
  }

  // Helper methods
  bool _isCacheExpired() {
    if (_lastCacheUpdate == null) return true;
    return DateTime.now().difference(_lastCacheUpdate!) > CACHE_VALIDITY;
  }

  Future<void> _closeUsbConnection() async {
    try {
      await _persistentUsbPort?.close();
    } catch (e) {
      print('Error closing USB connection: $e');
    } finally {
      _persistentUsbPort = null;
    }
  }

  Future<void> _closeBluetoothConnection() async {
    try {
      if (_isBluetoothConnected) {
        await PrintBluetoothThermal.disconnect;
      }
    } catch (e) {
      print('Error closing Bluetooth connection: $e');
    } finally {
      _isBluetoothConnected = false;
      _connectedBluetoothDevice = null;
    }
  }

  Future<void> _closeAllConnections() async {
    await _closeUsbConnection();
    await _closeBluetoothConnection();
  }

  void _clearCache() {
    _cachedThermalDevices.clear();
    _cachedUsbDevices.clear();
    _receiptCache.clear();
    _lastCacheUpdate = null;
  }

  // Cleanup method
  Future<void> dispose() async {
    _stopConnectionHealthMonitoring();
    await _closeAllConnections();
    _clearCache();
  }

  // Platform-specific helper methods
  Future<bool> _isUSBSerialAvailable() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      return false;
    }

    try {
      await UsbSerial.listDevices();
      return true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isBluetoothEnabled() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }

    try {
      await _requestBluetoothPermissions();
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestBluetoothPermissions() async {
    if (kIsWeb) return; // Skip permissions on web

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

  BluetoothInfo? _findThermalPrinterDevice(List<BluetoothInfo> devices) {
    for (BluetoothInfo device in devices) {
      String deviceName = device.name.toLowerCase();
      if (deviceName.contains('printer') ||
          deviceName.contains('thermal') ||
          deviceName.contains('pos') ||
          deviceName.contains('receipt') ||
          deviceName.contains('rp')) {
        return device;
      }
    }
    return null;
  }

  // Receipt generation methods (optimized)
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

    receipt.writeln('================================');
    receipt.writeln('         RESTAURANT NAME');
    receipt.writeln('================================');
    receipt.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    receipt.writeln('Transaction ID: $transactionId');
    receipt.writeln('Order Type: ${orderType.toUpperCase()}');
    receipt.writeln('================================');
    receipt.writeln();

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

      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          receipt.writeln('  + $option');
        }
      }

      if (item.comment != null && item.comment!.isNotEmpty) {
        receipt.writeln('  Note: ${item.comment}');
      }

      receipt.writeln('  £${itemTotal.toStringAsFixed(2)}');
      receipt.writeln();
    }

    receipt.writeln('--------------------------------');
    receipt.writeln('Subtotal:         £${subtotal.toStringAsFixed(2)}');
    receipt.writeln('VAT (5%):         £${vatAmount.toStringAsFixed(2)}');
    receipt.writeln('================================');
    receipt.writeln('TOTAL:            £${totalCharge.toStringAsFixed(2)}');
    receipt.writeln('================================');

    if (extraNotes != null && extraNotes.isNotEmpty) {
      receipt.writeln();
      receipt.writeln('Notes: $extraNotes');
    }

    receipt.writeln();
    receipt.writeln('Thank you for your order!');
    receipt.writeln('================================');

    return receipt.toString();
  }

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

      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          bytes += generator.text('  + $option');
        }
      }

      if (item.comment != null && item.comment!.isNotEmpty) {
        bytes += generator.text('  Note: ${item.comment}');
      }

      bytes += generator.text(
        '  £${itemTotal.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.right),
      );
      bytes += generator.emptyLines(1);
    }

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

    if (extraNotes != null && extraNotes.isNotEmpty) {
      bytes += generator.emptyLines(1);
      bytes += generator.text('Notes: $extraNotes');
    }

    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Thank you for your order!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _generateThermalTicket(String content) async {
    List<int> bytes = [];
    bytes.addAll(content.codeUnits);
    bytes.addAll([10, 10, 10]); // 3 line feeds
    bytes.addAll([29, 86, 65, 0]); // Full cut
    return bytes;
  }
}