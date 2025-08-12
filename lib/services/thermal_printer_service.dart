// lib/services/thermal_printer_service.dart
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService
      ._internal();

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
    print('   USB: ${testResults['usb'] == true
        ? "✅ Available"
        : "❌ Not Available"}');
    print('   Bluetooth: ${testResults['bluetooth'] == true
        ? "✅ Available"
        : "❌ Not Available"}');

    return testResults;
  }

  // Add this method for lightweight status checking without sending printer commands
  Future<Map<String, bool>> checkConnectionStatusOnly() async {
    print('🔍 Checking printer connection status (lightweight)...');

    if (kIsWeb) {
      print('📱 Web platform detected - skipping native printer checks');
      return {
        'usb': false,
        'bluetooth': false,
      };
    }

    Map<String, bool> testResults = {
      'usb': false,
      'bluetooth': false,
    };

    // Check USB without sending commands
    if (Platform.isAndroid || Platform.isWindows || Platform.isLinux) {
      try {
        if (_persistentUsbPort != null) {
          testResults['usb'] = true;
        } else {
          List<UsbDevice> devices = await UsbSerial.listDevices();
          testResults['usb'] = devices.isNotEmpty;
        }
      } catch (e) {
        testResults['usb'] = false;
      }
    }

    // Check Bluetooth without sending commands
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (_isBluetoothConnected) {
          bool isConnected = await PrintBluetoothThermal.connectionStatus;
          testResults['bluetooth'] = isConnected;
        } else {
          List<BluetoothInfo> devices = await PrintBluetoothThermal
              .pairedBluetooths;
          testResults['bluetooth'] = devices.isNotEmpty;
        }
      } catch (e) {
        testResults['bluetooth'] = false;
      }
    }

    return testResults;
  }

  // OPTIMIZED: Fast USB connection test with improved caching
  Future<bool> _testUSBConnection() async {
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(
          Duration(milliseconds: 500)); // Simulate connection time
      print('🧪 MOCK: USB printer simulated - ${SIMULATE_PRINTER_SUCCESS
          ? "Connected"
          : "Failed"}');
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
          await _persistentUsbPort!.write(
              Uint8List.fromList([0x1B, 0x40])); // ESC @ (initialize)
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
      await Future.delayed(
          Duration(milliseconds: 800)); // Simulate connection time
      print(
          '🧪 MOCK: Bluetooth thermal printer simulated - ${SIMULATE_PRINTER_SUCCESS
              ? "Connected"
              : "Failed"}');
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
            await PrintBluetoothThermal.writeBytes(
                [0x1B, 0x40]); // ESC @ (initialize)
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
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
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
      totalCharge: totalCharge,
      extraNotes: extraNotes,
      changeDue: changeDue,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      paymentType: paymentType,
    );

    Future<String> receiptContentFuture = Future.value(_generateReceiptContent(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
      changeDue: changeDue,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      paymentType: paymentType,
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
    if (connectionStatus['bluetooth'] == true) availableMethods.add(
        'Thermal Bluetooth');

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
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1000)); // Simulate print time
      print('🧪 MOCK: USB printing simulated');
      print('📄 Receipt data length: ${receiptData.length} bytes');
      print('📄 Receipt preview: ${String.fromCharCodes(
          receiptData.take(100))}...');
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
      print(receiptContent.substring(0, math.min(200, receiptContent.length)) +
          '...');
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

  Future<bool> validateReceiptGeneration({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
  }) async {
    try {
      // Test receipt content generation
      String receiptContent = _generateReceiptContent(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
        changeDue: changeDue,
        customerName: customerName,
        customerEmail: customerEmail,
        phoneNumber: phoneNumber,
        streetAddress: streetAddress,
        city: city,
        postalCode: postalCode,
        paymentType: paymentType,
      );

      // Test ESC/POS receipt generation
      List<int> receiptData = await _generateESCPOSReceipt(
        transactionId: transactionId,
        orderType: orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
        changeDue: changeDue,
        customerName: customerName,
        customerEmail: customerEmail,
        phoneNumber: phoneNumber,
        streetAddress: streetAddress,
        city: city,
        postalCode: postalCode,
        paymentType: paymentType,
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
      await _persistentUsbPort!.write(
          Uint8List.fromList([0x1B, 0x40])); // ESC @
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
    _connectionHealthTimer =
        Timer.periodic(Duration(seconds: 30), (timer) async {
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
                print(
                    '🔧 Bluetooth connection lost, attempting reconnection...');
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
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
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
      totalCharge: totalCharge,
      extraNotes: extraNotes,
      changeDue: changeDue,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      paymentType: paymentType,
    );

    String receiptContent = _generateReceiptContent(
      transactionId: transactionId,
      orderType: orderType,
      cartItems: cartItems,
      subtotal: subtotal,
      totalCharge: totalCharge,
      extraNotes: extraNotes,
      changeDue: changeDue,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      paymentType: paymentType,
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
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
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

  String _generateReceiptContent({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
  }) {
    StringBuffer receipt = StringBuffer();

    receipt.writeln('================================');
    receipt.writeln('         RESTAURANT NAME');
    receipt.writeln('================================');
    receipt.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    receipt.writeln('Order Type: ${orderType.toUpperCase()}');
    receipt.writeln('================================');
    receipt.writeln();

    // Customer Details Section
    if (customerName != null && customerName.isNotEmpty) {
      receipt.writeln('CUSTOMER DETAILS:');
      receipt.writeln('--------------------------------');
      receipt.writeln('Name: $customerName');

      if (customerEmail != null && customerEmail.isNotEmpty) {
        receipt.writeln('Email: $customerEmail');
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        receipt.writeln('Phone: $phoneNumber');
      }

      // Address details for delivery orders
      if (orderType.toLowerCase() == 'delivery') {
        if (streetAddress != null && streetAddress.isNotEmpty) {
          receipt.writeln('Address: $streetAddress');
        }
        if (city != null && city.isNotEmpty) {
          receipt.writeln('City: $city');
        }
        if (postalCode != null && postalCode.isNotEmpty) {
          receipt.writeln('Postcode: $postalCode');
        }
      }

      receipt.writeln('================================');
      receipt.writeln();
    }

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
    receipt.writeln('================================');
    receipt.writeln('TOTAL:            £${totalCharge.toStringAsFixed(2)}');
    receipt.writeln('================================');

    // Payment Status Section
    receipt.writeln();
    receipt.writeln('PAYMENT STATUS:');
    receipt.writeln('--------------------------------');
    if (paymentType != null && paymentType.isNotEmpty) {
      receipt.writeln('Payment Method: $paymentType');
    }

    // Determine if order is paid or unpaid based on payment type and change due
    String paymentStatus = 'UNPAID';
    if (paymentType != null && paymentType.toLowerCase() == 'cash') {
      if (changeDue > 0) {
        paymentStatus = 'PAID';
        receipt.writeln(
            'Amount Received:  £${(totalCharge + changeDue).toStringAsFixed(
                2)}');
        receipt.writeln('Change Due:       £${changeDue.toStringAsFixed(2)}');
      } else {
        paymentStatus = 'PAID';
      }
    } else
    if (paymentType != null && (paymentType.toLowerCase().contains('card') ||
        paymentType.toLowerCase().contains('online') ||
        paymentType.toLowerCase().contains('paypal'))) {
      paymentStatus = 'PAID';
    }

    receipt.writeln('Status: $paymentStatus');
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

// Replace the existing _generateESCPOSReceipt method
  Future<List<int>> _generateESCPOSReceipt({
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
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
    bytes += generator.text('Order Type: ${orderType.toUpperCase()}');
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Customer Details Section
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text(
          'CUSTOMER DETAILS:', styles: const PosStyles(bold: true));
      bytes += generator.text('--------------------------------');
      bytes += generator.text('Name: $customerName');

      if (customerEmail != null && customerEmail.isNotEmpty) {
        bytes += generator.text('Email: $customerEmail');
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        bytes += generator.text('Phone: $phoneNumber');
      }

      // Address details for delivery orders
      if (orderType.toLowerCase() == 'delivery') {
        if (streetAddress != null && streetAddress.isNotEmpty) {
          bytes += generator.text('Address: $streetAddress');
        }
        if (city != null && city.isNotEmpty) {
          bytes += generator.text('City: $city');
        }
        if (postalCode != null && postalCode.isNotEmpty) {
          bytes += generator.text('Postcode: $postalCode');
        }
      }

      bytes += generator.text(
        '================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

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

    // Payment Status Section
    bytes += generator.emptyLines(1);
    bytes +=
        generator.text('PAYMENT STATUS:', styles: const PosStyles(bold: true));
    bytes += generator.text('--------------------------------');

    if (paymentType != null && paymentType.isNotEmpty) {
      bytes += generator.text('Payment Method: $paymentType');
    }

    // Determine if order is paid or unpaid based on payment type and change due
    String paymentStatus = 'UNPAID';
    if (paymentType != null && paymentType.toLowerCase() == 'cash') {
      if (changeDue > 0) {
        paymentStatus = 'PAID';
        bytes += generator.row([
          PosColumn(text: 'Amount Received:', width: 8),
          PosColumn(
            text: '£${(totalCharge + changeDue).toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.row([
          PosColumn(text: 'Change Due:', width: 8),
          PosColumn(
            text: '£${changeDue.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      } else {
        paymentStatus = 'PAID';
      }
    } else
    if (paymentType != null && (paymentType.toLowerCase().contains('card') ||
        paymentType.toLowerCase().contains('online') ||
        paymentType.toLowerCase().contains('paypal'))) {
      paymentStatus = 'PAID';
    }

    bytes += generator.text(
        'Status: $paymentStatus', styles: const PosStyles(bold: true));
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

  Future<bool> printSalesReportWithUserInteraction({
    required String reportType,
    required Map<String, dynamic> reportData,
    required Map<String, String> filters,
    String? selectedDate,
    int? selectedYear,
    int? selectedWeek,
    int? selectedMonth,
    Function(List<String> availableMethods)? onShowMethodSelection,
  }) async {
    if (kIsWeb) {
      print('🚫 Web platform - printer not supported');
      throw Exception('Printing is not supported on web platform. Please use a mobile or desktop app.');
    }

    print('🖨️ Starting sales report print job...');

    try {
      // Test connections in parallel with report generation
      Future<Map<String, bool>> connectionTestFuture = testAllConnections();

      Future<List<int>> reportDataFuture = _generateSalesReportESCPOS(
        reportType: reportType,
        reportData: reportData,
        filters: filters,
        selectedDate: selectedDate,
        selectedYear: selectedYear,
        selectedWeek: selectedWeek,
        selectedMonth: selectedMonth,
      );

      Future<String> reportContentFuture = Future.value(_generateSalesReportContent(
        reportType: reportType,
        reportData: reportData,
        filters: filters,
        selectedDate: selectedDate,
        selectedYear: selectedYear,
        selectedWeek: selectedWeek,
        selectedMonth: selectedMonth,
      ));

      // Wait for all preparations to complete
      List<dynamic> results = await Future.wait([
        connectionTestFuture,
        reportDataFuture,
        reportContentFuture,
      ]);

      Map<String, bool> connectionStatus = results[0];
      List<int> thermalReportData = results[1];
      String reportContent = results[2];

      List<String> availableMethods = [];
      if (connectionStatus['usb'] == true) availableMethods.add('USB');
      if (connectionStatus['bluetooth'] == true) availableMethods.add('Thermal Bluetooth');

      if (availableMethods.isEmpty) {
        print('❌ No printer connections available');
        String errorMessage = 'No thermal printers detected. Please ensure:\n';
        errorMessage += '• A thermal printer is connected via USB or Bluetooth\n';
        errorMessage += '• The printer is powered on\n';
        errorMessage += '• For Bluetooth: The printer is paired with this device\n';
        errorMessage += '• For USB: The printer is properly connected';

        if (onShowMethodSelection != null) {
          onShowMethodSelection(['No printers available']);
        }
        throw Exception(errorMessage);
      }

      // Start connection health monitoring
      _startConnectionHealthMonitoring();

      // Try available methods with pre-generated data
      bool printSuccess = false;
      String lastError = '';

      for (String method in availableMethods) {
        print('🚀 Attempting $method sales report printing...');

        try {
          bool success = await _printSalesReportWithPreGeneratedData(
            method: method,
            reportData: thermalReportData,
            reportContent: reportContent,
          );

          if (success) {
            print('✅ $method sales report printing successful');
            printSuccess = true;
            break;
          } else {
            lastError = '$method printing failed - printer may be offline';
          }
        } catch (e) {
          lastError = '$method printing failed: ${e.toString()}';
          print('❌ $method error: $e');
        }
      }

      if (!printSuccess) {
        print('❌ All available methods failed');
        if (onShowMethodSelection != null) {
          onShowMethodSelection(availableMethods);
        }
        throw Exception('Printing failed on all available methods. Last error: $lastError');
      }

      return true;
    } catch (e) {
      print('❌ Sales report printing error: $e');
      rethrow;
    }
  }

// REPLACE the _printSalesReportWithPreGeneratedData method:
  Future<bool> _printSalesReportWithPreGeneratedData({
    required String method,
    required List<int> reportData,
    required String reportContent,
  }) async {
    try {
      switch (method) {
        case 'USB':
          return await _printUSBSalesReportSuperFast(reportData);
        case 'Thermal Bluetooth':
          return await _printBluetoothSalesReportSuperFast(reportContent);
        default:
          throw Exception('Unknown printing method: $method');
      }
    } catch (e) {
      print('❌ Error in $method printing: $e');
      return false;
    }
  }

  Future<bool> _printUSBSalesReportSuperFast(List<int> reportData) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      throw Exception('USB printing not supported on this platform');
    }

    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1000));
      print('🧪 MOCK: USB sales report printing simulated');
      print('📊 Report data length: ${reportData.length} bytes');
      if (SIMULATE_PRINTER_SUCCESS) {
        return true;
      } else {
        throw Exception('Mock printer simulation failed');
      }
    }

    try {
      // Ensure we have a persistent connection
      if (_persistentUsbPort == null) {
        if (_cachedUsbDevices.isEmpty) {
          _cachedUsbDevices = await UsbSerial.listDevices();
        }
        if (_cachedUsbDevices.isEmpty) {
          throw Exception('No USB devices found. Please connect a USB thermal printer.');
        }

        if (!await _establishUSBConnection(_cachedUsbDevices.first)) {
          throw Exception('Failed to establish USB connection. Please check printer connection.');
        }
      }

      // Print the sales report
      await _persistentUsbPort!.write(Uint8List.fromList(reportData));
      await Future.delayed(Duration(milliseconds: 100));

      print('✅ USB sales report print successful');
      return true;
    } catch (e) {
      print('❌ USB sales report print error: $e');
      await _closeUsbConnection();
      throw Exception('USB printing failed: ${e.toString()}');
    }
  }

// REPLACE the Bluetooth printing method with better error handling:
  Future<bool> _printBluetoothSalesReportSuperFast(String reportContent) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw Exception('Bluetooth printing not supported on this platform');
    }

    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1200));
      print('🧪 MOCK: Bluetooth sales report printing simulated');
      print('📊 Report content preview:');
      print(reportContent.substring(0, math.min(300, reportContent.length)) + '...');
      if (SIMULATE_PRINTER_SUCCESS) {
        return true;
      } else {
        throw Exception('Mock Bluetooth printer simulation failed');
      }
    }

    try {
      // Ensure we have a persistent connection
      if (!_isBluetoothConnected) {
        if (!await _establishBluetoothConnection()) {
          throw Exception('Failed to establish Bluetooth connection. Please check if printer is paired and turned on.');
        }
      }

      // Verify connection is still active
      bool isStillConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isStillConnected) {
        throw Exception('Bluetooth printer is not connected. Please check printer status.');
      }

      // Generate thermal ticket and print immediately
      List<int> ticket = await _generateThermalTicket(reportContent);
      await PrintBluetoothThermal.writeBytes(ticket);

      print('✅ Bluetooth sales report print successful');
      return true;
    } catch (e) {
      print('❌ Bluetooth sales report print error: $e');
      await _closeBluetoothConnection();
      throw Exception('Bluetooth printing failed: ${e.toString()}');
    }
  }

// Generate sales report content for thermal printing
  String _generateSalesReportContent({
    required String reportType,
    required Map<String, dynamic> reportData,
    required Map<String, String> filters,
    String? selectedDate,
    int? selectedYear,
    int? selectedWeek,
    int? selectedMonth,
  }) {
    StringBuffer report = StringBuffer();

    // Header
    report.writeln('================================');
    report.writeln('         THE VILLAGE');
    report.writeln('        RESTAURANT');
    report.writeln('================================');
    report.writeln();

    // Report Title and Date
    report.writeln(reportType.toUpperCase());
    report.writeln('--------------------------------');

    // Period information
    String periodText = _getPeriodText(
        reportData, reportType, selectedDate, selectedYear, selectedWeek,
        selectedMonth);
    report.writeln('Period: $periodText');
    report.writeln('Generated: ${DateTime.now().toString().split('.')[0]}');
    report.writeln('================================');
    report.writeln();

    // Applied Filters
    bool hasFilters = false;
    if (filters['source'] != 'All' || filters['payment'] != 'All' ||
        filters['orderType'] != 'All') {
      hasFilters = true;
      report.writeln('APPLIED FILTERS:');
      report.writeln('--------------------------------');
      if (filters['source'] != 'All') report.writeln(
          'Source: ${filters['source']}');
      if (filters['payment'] != 'All') report.writeln(
          'Payment: ${filters['payment']}');
      if (filters['orderType'] != 'All') report.writeln(
          'Order Type: ${filters['orderType']}');
      report.writeln('================================');
      report.writeln();
    }

    // Summary Section
    report.writeln('SUMMARY:');
    report.writeln('--------------------------------');

    // Total Sales Amount
    final totalSales = reportData['total_sales'] ??
        reportData['total_sales_amount'];
    report.writeln('Total Sales: ${_formatCurrency(totalSales)}');

    // Total Orders Placed
    if (reportData['total_orders_placed'] != null) {
      report.writeln('Total Orders: ${reportData['total_orders_placed']}');
    }

    // Sales Increase
    final salesIncrease = reportData['sales_increase'];
    if (salesIncrease != null) {
      final increase = double.tryParse(salesIncrease.toString()) ?? 0.0;
      final isPositive = increase >= 0;
      report.writeln(
          'Sales ${isPositive ? 'Increase' : 'Decrease'}: ${isPositive
              ? '+'
              : ''}${_formatCurrency(salesIncrease)}');
    }

    // Most Sold Item
    final mostSoldItem = reportData['most_selling_item'] ??
        reportData['most_sold_item'];
    if (mostSoldItem != null) {
      final itemName = mostSoldItem['item_name'] ?? 'Unknown';
      final quantity = mostSoldItem['quantity_sold'] ?? '0';
      report.writeln('Top Item: $itemName ($quantity sold)');
    }

    // Most Sold Type
    final mostSoldType = reportData['most_sold_type'];
    if (mostSoldType != null) {
      final typeName = mostSoldType['type'] ?? 'Unknown';
      final quantity = mostSoldType['quantity_sold'] ?? '0';
      report.writeln('Top Category: $typeName ($quantity sold)');
    }

    report.writeln('================================');
    report.writeln();

    // Sales by Payment Method
    final paymentTypes = reportData['sales_by_payment_type'] as List<dynamic>?;
    if (paymentTypes != null && paymentTypes.isNotEmpty) {
      report.writeln('SALES BY PAYMENT METHOD:');
      report.writeln('--------------------------------');
      for (var payment in paymentTypes) {
        if (payment is Map) {
          final type = payment['payment_type']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = payment['count']?.toString() ?? '0';
          final total = _formatCurrency(payment['total']);
          report.writeln('$type:');
          report.writeln('  Orders: $count');
          report.writeln('  Amount: $total');
          report.writeln();
        }
      }
      report.writeln('================================');
      report.writeln();
    }

    // Sales by Order Type
    final orderTypes = reportData['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes != null && orderTypes.isNotEmpty) {
      report.writeln('SALES BY ORDER TYPE:');
      report.writeln('--------------------------------');
      for (var orderType in orderTypes) {
        if (orderType is Map) {
          final type = orderType['order_type']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = orderType['count']?.toString() ?? '0';
          final total = _formatCurrency(orderType['total']);
          report.writeln('$type:');
          report.writeln('  Orders: $count');
          report.writeln('  Amount: $total');
          report.writeln();
        }
      }
      report.writeln('================================');
      report.writeln();
    }

    // Sales by Order Source
    final orderSources = reportData['sales_by_order_source'] as List<dynamic>?;
    if (orderSources != null && orderSources.isNotEmpty) {
      report.writeln('SALES BY ORDER SOURCE:');
      report.writeln('--------------------------------');
      for (var source in orderSources) {
        if (source is Map) {
          final sourceName = source['source']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = source['count']?.toString() ?? '0';
          final total = _formatCurrency(source['total']);
          report.writeln('$sourceName:');
          report.writeln('  Orders: $count');
          report.writeln('  Amount: $total');
          report.writeln();
        }
      }
      report.writeln('================================');
      report.writeln();
    }

    // Footer
    report.writeln('End of Report');
    report.writeln('================================');

    return report.toString();
  }

// Generate ESC/POS commands for sales report
  Future<List<int>> _generateSalesReportESCPOS({
    required String reportType,
    required Map<String, dynamic> reportData,
    required Map<String, String> filters,
    String? selectedDate,
    int? selectedYear,
    int? selectedWeek,
    int? selectedMonth,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // 80mm paper
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP1252');

    // Header
    bytes += generator.text(
      'THE VILLAGE RESTAURANT',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Report Title and Date
    bytes += generator.text(
      reportType.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
      ),
    );
    bytes += generator.text('--------------------------------');

    // Period information
    String periodText = _getPeriodText(
        reportData, reportType, selectedDate, selectedYear, selectedWeek,
        selectedMonth);
    bytes += generator.text('Period: $periodText');
    bytes +=
        generator.text('Generated: ${DateTime.now().toString().split('.')[0]}');
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Applied Filters
    bool hasFilters = false;
    if (filters['source'] != 'All' || filters['payment'] != 'All' ||
        filters['orderType'] != 'All') {
      hasFilters = true;
      bytes += generator.text(
          'APPLIED FILTERS:', styles: const PosStyles(bold: true));
      bytes += generator.text('--------------------------------');
      if (filters['source'] != 'All')
        bytes += generator.text('Source: ${filters['source']}');
      if (filters['payment'] != 'All')
        bytes += generator.text('Payment: ${filters['payment']}');
      if (filters['orderType'] != 'All')
        bytes += generator.text('Order Type: ${filters['orderType']}');
      bytes += generator.text(
        '================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Summary Section
    bytes += generator.text('SUMMARY:', styles: const PosStyles(bold: true));
    bytes += generator.text('--------------------------------');

    // Total Sales Amount
    final totalSales = reportData['total_sales'] ??
        reportData['total_sales_amount'];
    bytes += generator.row([
      PosColumn(text: 'Total Sales:', width: 7),
      PosColumn(
        text: _formatCurrency(totalSales),
        width: 5,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    // Total Orders Placed
    if (reportData['total_orders_placed'] != null) {
      bytes += generator.row([
        PosColumn(text: 'Total Orders:', width: 7),
        PosColumn(
          text: '${reportData['total_orders_placed']}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Sales Increase
    final salesIncrease = reportData['sales_increase'];
    if (salesIncrease != null) {
      final increase = double.tryParse(salesIncrease.toString()) ?? 0.0;
      final isPositive = increase >= 0;
      bytes += generator.row([
        PosColumn(
            text: 'Sales ${isPositive ? 'Increase' : 'Decrease'}:', width: 7),
        PosColumn(
          text: '${isPositive ? '+' : ''}${_formatCurrency(salesIncrease)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Most Sold Item
    final mostSoldItem = reportData['most_selling_item'] ??
        reportData['most_sold_item'];
    if (mostSoldItem != null) {
      final itemName = mostSoldItem['item_name'] ?? 'Unknown';
      final quantity = mostSoldItem['quantity_sold'] ?? '0';
      bytes += generator.text('Top Item: $itemName ($quantity sold)');
    }

    // Most Sold Type
    final mostSoldType = reportData['most_sold_type'];
    if (mostSoldType != null) {
      final typeName = mostSoldType['type'] ?? 'Unknown';
      final quantity = mostSoldType['quantity_sold'] ?? '0';
      bytes += generator.text('Top Category: $typeName ($quantity sold)');
    }

    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Sales by Payment Method
    final paymentTypes = reportData['sales_by_payment_type'] as List<dynamic>?;
    if (paymentTypes != null && paymentTypes.isNotEmpty) {
      bytes += generator.text(
          'SALES BY PAYMENT METHOD:', styles: const PosStyles(bold: true));
      bytes += generator.text('--------------------------------');
      for (var payment in paymentTypes) {
        if (payment is Map) {
          final type = payment['payment_type']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = payment['count']?.toString() ?? '0';
          final total = _formatCurrency(payment['total']);
          bytes +=
              generator.text('$type:', styles: const PosStyles(bold: true));
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 6),
            PosColumn(
              text: count,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 6),
            PosColumn(
              text: total,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Sales by Order Type
    final orderTypes = reportData['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes != null && orderTypes.isNotEmpty) {
      bytes += generator.text(
          'SALES BY ORDER TYPE:', styles: const PosStyles(bold: true));
      bytes += generator.text('--------------------------------');
      for (var orderType in orderTypes) {
        if (orderType is Map) {
          final type = orderType['order_type']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = orderType['count']?.toString() ?? '0';
          final total = _formatCurrency(orderType['total']);
          bytes +=
              generator.text('$type:', styles: const PosStyles(bold: true));
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 6),
            PosColumn(
              text: count,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 6),
            PosColumn(
              text: total,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Sales by Order Source
    final orderSources = reportData['sales_by_order_source'] as List<dynamic>?;
    if (orderSources != null && orderSources.isNotEmpty) {
      bytes += generator.text(
          'SALES BY ORDER SOURCE:', styles: const PosStyles(bold: true));
      bytes += generator.text('--------------------------------');
      for (var source in orderSources) {
        if (source is Map) {
          final sourceName = source['source']?.toString().toUpperCase() ??
              'UNKNOWN';
          final count = source['count']?.toString() ?? '0';
          final total = _formatCurrency(source['total']);
          bytes += generator.text(
              '$sourceName:', styles: const PosStyles(bold: true));
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 6),
            PosColumn(
              text: count,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 6),
            PosColumn(
              text: total,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Footer
    bytes += generator.text(
      'End of Report',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.emptyLines(3);
    bytes += generator.cut();

    return bytes;
  }

// Helper method to get period text
  String _getPeriodText(Map<String, dynamic> reportData, String reportType,
      String? selectedDate, int? selectedYear, int? selectedWeek,
      int? selectedMonth) {
    switch (reportType) {
      case "Today's Report":
        return DateFormat('yyyy-MM-dd').format(DateTime.now());
      case 'Daily Report':
        return selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      case 'Weekly Report':
        return 'Year: ${selectedYear ?? DateTime
            .now()
            .year}, Week: ${selectedWeek ?? _getWeekNumber(DateTime.now())}';
      case 'Monthly Report':
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        final monthName = months[(selectedMonth ?? DateTime
            .now()
            .month) - 1];
        return 'Year: ${selectedYear ?? DateTime
            .now()
            .year}, Month: $monthName';
      case 'Drivers Report':
        return selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      default:
        final period = reportData['period'];
        if (period != null && period is Map) {
          return '${period['from']} ~ ${period['to']}';
        }
        return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

// Helper method to format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '£0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '£${value.toStringAsFixed(2)}';
  }

// Helper method to get week number
  static int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(date
        .difference(DateTime(date.year, 1, 1))
        .inDays
        .toString()) + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}