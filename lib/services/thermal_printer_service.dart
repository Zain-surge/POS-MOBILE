// lib/services/thermal_printer_service.dart
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/models/cart_item.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/xprinter_service.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance =
      ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;

  ThermalPrinterService._internal();

  static const bool ENABLE_MOCK_MODE = false;
  static const bool SIMULATE_PRINTER_SUCCESS = false;
  static const bool ENABLE_DRAWER_TEST_MODE = false;
  UsbPort? _persistentUsbPort;
  String? _connectedBluetoothDevice;
  bool _isBluetoothConnected = false;

  // Xprinter SDK integration
  final XprinterService _xprinterService = XprinterService();
  bool _useXprinterSDK = true; // Flag to enable/disable Xprinter SDK

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
  final Map<String, List<int>> _receiptCache = {};

  // Cash drawer settings
  bool _isDrawerOpeningEnabled = true;
  bool _autoOpenOnCashPayment = true;

  // Helper method to check if a field should be excluded from receipt
  bool _shouldExcludeField(String? value) {
    if (value == null || value.isEmpty) return true;

    final trimmedValue = value.trim().toUpperCase();

    // Exclude N/A values
    if (trimmedValue == 'N/A') return true;

    // Exclude default pizza options (case insensitive)
    if (trimmedValue == 'BASE: TOMATO' || trimmedValue == 'CRUST: NORMAL') {
      return true;
    }

    return false;
  }

  // Helper method to wrap text without breaking words in the middle
  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) {
      return [text];
    }

    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';

    for (String word in words) {
      // Check if adding this word would exceed the max width
      String testLine = currentLine.isEmpty ? word : '$currentLine $word';

      if (testLine.length <= maxWidth) {
        currentLine = testLine;
      } else {
        // If current line has content, add it to lines and start new line with this word
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Single word is too long, but don't break it - just put it on its own line
          currentLine = word;
        }
      }
    }

    // Add any remaining content
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  Future<Map<String, bool>> testAllConnections() async {
    print('🧪 Testing all printer connections...');

    // Skip web-specific checks
    if (kIsWeb) {
      print('📱 Web platform detected - skipping native printer checks');
      return {'usb': false, 'bluetooth': false};
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
      return {'usb': false, 'bluetooth': false};
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
    print(
      '   USB: ${testResults['usb'] == true ? "✅ Available" : "❌ Not Available"}',
    );
    print(
      '   Bluetooth: ${testResults['bluetooth'] == true ? "✅ Available" : "❌ Not Available"}',
    );

    return testResults;
  }

  // Add this method for lightweight status checking without sending printer commands
  Future<Map<String, bool>> checkConnectionStatusOnly() async {
    print('🔍 Checking printer connection status (lightweight)...');

    if (kIsWeb) {
      print('📱 Web platform detected - skipping native printer checks');
      return {'usb': false, 'bluetooth': false};
    }

    Map<String, bool> testResults = {'usb': false, 'bluetooth': false};

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
          List<BluetoothInfo> devices =
              await PrintBluetoothThermal.pairedBluetooths;
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
        Duration(milliseconds: 500),
      ); // Simulate connection time
      print(
        '🧪 MOCK: USB printer simulated - ${SIMULATE_PRINTER_SUCCESS ? "Connected" : "Failed"}',
      );
      return SIMULATE_PRINTER_SUCCESS;
    }

    // Try Xprinter SDK first if enabled and on Android
    if (_useXprinterSDK && Platform.isAndroid) {
      try {
        print('🎯 Trying Xprinter SDK for USB connection...');
        final devices = await _xprinterService.getUsbDevices();

        if (devices.isNotEmpty) {
          // Try to connect to the first available device
          final firstDevice = devices.first;
          final devicePath = firstDevice['deviceName'] as String?;

          if (devicePath != null) {
            bool connected = await _xprinterService.connectUsb(devicePath);
            if (connected) {
              print('✅ Xprinter SDK USB connection successful');
              return true;
            }
          }
        }
        print(
          '⚠️ Xprinter SDK connection failed, falling back to legacy method',
        );
      } catch (e) {
        print('⚠️ Xprinter SDK error, falling back to legacy method: $e');
      }
    }

    try {
      if (!await _isUSBSerialAvailable()) return false;

      // Use cached devices if available and recent
      if (_cachedUsbDevices.isEmpty || _isCacheExpired()) {
        _cachedUsbDevices = await UsbSerial.listDevices();
        _lastCacheUpdate = UKTimeService.now();
      }

      if (_cachedUsbDevices.isEmpty) return false;

      // If we already have a persistent connection, test it quickly
      if (_persistentUsbPort != null) {
        try {
          // Quick health check - send minimal data
          await _persistentUsbPort!.write(
            Uint8List.fromList([0x1B, 0x40]),
          ); // ESC @ (initialize)
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
        Duration(milliseconds: 800),
      ); // Simulate connection time
      print(
        '🧪 MOCK: Bluetooth thermal printer simulated - ${SIMULATE_PRINTER_SUCCESS ? "Connected" : "Failed"}',
      );
      return SIMULATE_PRINTER_SUCCESS;
    }

    try {
      if (!await _isBluetoothEnabled()) return false;

      // Use cached devices if available and recent
      if (_cachedThermalDevices.isEmpty || _isCacheExpired()) {
        _cachedThermalDevices = await PrintBluetoothThermal.pairedBluetooths;
        _lastCacheUpdate = UKTimeService.now();
      }

      if (_cachedThermalDevices.isEmpty) return false;

      // If already connected, test connection health
      if (_isBluetoothConnected && _connectedBluetoothDevice != null) {
        try {
          bool isConnected = await PrintBluetoothThermal.connectionStatus;
          if (isConnected) {
            // Send a quick test command
            await PrintBluetoothThermal.writeBytes([
              0x1B,
              0x40,
            ]); // ESC @ (initialize)
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
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    DateTime? orderDateTime,
    Function(List<String> availableMethods)? onShowMethodSelection,
  }) async {
    if (kIsWeb && !ENABLE_DRAWER_TEST_MODE) {
      print('🚫 Web platform - printer not supported');
      return false;
    }

    if (kIsWeb && ENABLE_DRAWER_TEST_MODE) {
      // Auto-open cash drawer disabled - drawer opens only via manual button press
      // if (_autoOpenOnCashPayment &&
      //     paymentType?.toLowerCase() == 'cash' &&
      //     _isDrawerOpeningEnabled) {
      //   print('💰 Auto-opening cash drawer for cash payment (WEB TEST MODE)');
      //   await openCashDrawer(reason: "Cash payment completed - WEB TEST");
      // }

      // Simulate successful printing in test mode
      await Future.delayed(Duration(seconds: 1));
      print('🧪 Web test mode: Receipt printing simulated successfully');
      return true;
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
      paidStatus: paidStatus,
      orderId: orderId,
      deliveryCharge: deliveryCharge,
      isXprinterUSB:
          _useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected,
    );

    Future<String> receiptContentFuture = Future.value(
      _generateReceiptContent(
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
        paidStatus: paidStatus,
        orderId: orderId,
        deliveryCharge: deliveryCharge,
        orderDateTime: orderDateTime,
        isXprinterUSB:
            _useXprinterSDK &&
            Platform.isAndroid &&
            _xprinterService.isConnected,
      ),
    );

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
    if (connectionStatus['bluetooth'] == true)
      availableMethods.add('Thermal Bluetooth');

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

        // Auto-open cash drawer disabled - drawer opens only via manual button press
        // if (_autoOpenOnCashPayment &&
        //     paymentType?.toLowerCase() == 'cash' &&
        //     _isDrawerOpeningEnabled) {
        //   print('💰 Auto-opening cash drawer for cash payment');
        //   await openCashDrawer(reason: "Cash payment completed
        // ");
        // }

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
        return await _printUSBSuperFast(receiptData, receiptContent);
      case 'Thermal Bluetooth':
        return await _printBluetoothSuperFast(receiptContent);
      default:
        return false;
    }
  }

  Future<bool> _printUSBSuperFast(
    List<int> receiptData,
    String receiptContent,
  ) async {
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      throw Exception('USB printing not supported on this platform');
    }

    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 800));
      debugPrint('🧪 MOCK: USB printing simulated (ENHANCED)');
      debugPrint('📄 Receipt data length: ${receiptData.length} bytes');
      return SIMULATE_PRINTER_SUCCESS;
    }

    // Try Xprinter SDK first if enabled and connected
    if (_useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected) {
      try {
        print('🎯 Using Xprinter SDK for USB printing...');

        // CRITICAL FIX: Use plain text receiptContent, NOT ESC/POS bytes
        // The Xprinter SDK expects plain text and handles its own formatting
        // Converting ESC/POS bytes to string causes corrupted text at the start
        bool success = await _xprinterService.printReceipt(receiptContent);

        if (success) {
          print(
            '✅ Xprinter SDK USB printing successful - pound signs should display correctly',
          );
          return true;
        } else {
          print(
            '⚠️ Xprinter SDK printing failed, falling back to legacy method',
          );
        }
      } catch (e) {
        print(
          '⚠️ Xprinter SDK printing error, falling back to legacy method: $e',
        );
      }
    }

    // Legacy USB printing method continues as before...
    try {
      // Enhanced connection verification
      if (_persistentUsbPort == null) {
        print('🔧 USB: No existing connection, establishing new one...');
        if (_cachedUsbDevices.isEmpty) {
          _cachedUsbDevices = await UsbSerial.listDevices();
        }
        if (_cachedUsbDevices.isEmpty) {
          throw Exception(
            'No USB printer devices found. Please check connection and ensure printer is powered on.',
          );
        }

        if (!await _establishUSBConnection(_cachedUsbDevices.first)) {
          throw Exception(
            'Failed to establish USB connection. Please check USB cable and printer power.',
          );
        }
      }

      // Quick connection health check before printing
      try {
        await _persistentUsbPort!.write(
          Uint8List.fromList([0x1B, 0x40]),
        ); // Quick init
        await Future.delayed(Duration(milliseconds: 50));
      } catch (healthError) {
        print('🔧 USB: Connection health check failed, reconnecting...');
        await _closeUsbConnection();

        if (!await _establishUSBConnection(_cachedUsbDevices.first)) {
          throw Exception(
            'Failed to re-establish USB connection after health check failure',
          );
        }
      }

      // Enhanced initialization for Xprinter devices based on manual
      bool isXprinterDevice =
          _cachedUsbDevices.isNotEmpty && _isXprinter(_cachedUsbDevices.first);

      if (isXprinterDevice) {
        print(
          '🎯 Applying Xprinter-specific initialization based on manual specifications...',
        );
        // Send Xprinter-specific initialization commands per manual specs
        List<int> xprinterInit = [
          0x1B, 0x40, // ESC @ (Initialize printer)
          0x1B,
          0x74,
          0x00, // ESC t 0 (Select CP437/Page 0 as per manual - this is critical for £ symbol)
          0x1C, 0x2E, // FS . (Cancel Chinese character mode as shown in manual)
          0x1B, 0x52, 0x00, // ESC R 0 (International character set from manual)
          0x1B, 0x61, 0x00, // ESC a 0 (Left align)
          0x1B, 0x21, 0x00, // ESC ! 0 (Reset character formatting)
        ];

        await _persistentUsbPort!.write(Uint8List.fromList(xprinterInit));
        await Future.delayed(
          Duration(milliseconds: 300),
        ); // Allow time for initialization
        print('✅ Xprinter manual-based initialization completed');
      }

      print('🚀 USB: Starting super-fast print job...');

      // Apply encoding fixes to receipt data if it's an Xprinter device
      List<int> finalReceiptData = receiptData;
      if (isXprinterDevice) {
        print(
          '🔧 Applying Xprinter manual-based encoding fixes to receipt data...',
        );
        String receiptString = String.fromCharCodes(receiptData);
        String fixedString = _applyXprinterEncodingFixes(receiptString);
        finalReceiptData = fixedString.codeUnits;
        print('✅ Receipt data encoding fixes applied');
      }

      // Split large data into chunks for stability (optimized for device type)
      int chunkSize =
          isXprinterDevice
              ? 1024
              : 512; // Larger chunks for Xprinter as per manual specs
      print(
        '📦 Splitting receipt into chunks of $chunkSize bytes for ${isXprinterDevice ? "Xprinter" : "generic"} device',
      );

      for (int i = 0; i < finalReceiptData.length; i += chunkSize) {
        int end =
            (i + chunkSize < finalReceiptData.length)
                ? i + chunkSize
                : finalReceiptData.length;
        List<int> chunk = finalReceiptData.sublist(i, end);

        await _persistentUsbPort!.write(Uint8List.fromList(chunk));

        // Minimal delay between chunks to prevent buffer overflow
        if (i + chunkSize < finalReceiptData.length) {
          await Future.delayed(
            Duration(milliseconds: isXprinterDevice ? 5 : 10),
          ); // Faster for Xprinter
        }
      }

      // Final small delay to ensure completion
      await Future.delayed(Duration(milliseconds: 100));

      print(
        '✅ USB super-fast print completed successfully with Xprinter manual optimizations',
      );
      return true;
    } catch (e) {
      String errorMsg = 'USB printing failed: $e';
      print('❌ USB super-fast print error: $e');
      await _closeUsbConnection();
      throw Exception(errorMsg);
    }
  }

  Future<bool> _printBluetoothSuperFast(String receiptContent) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }
    if (ENABLE_MOCK_MODE) {
      await Future.delayed(Duration(milliseconds: 1000)); // Faster simulation
      print('🧪 MOCK: Bluetooth printing simulated (ENHANCED)');
      return SIMULATE_PRINTER_SUCCESS;
    }

    try {
      // Enhanced connection verification and recovery
      if (!_isBluetoothConnected) {
        print('📱 BT: No existing connection, establishing new one...');
        if (!await _establishBluetoothConnection()) {
          print('❌ BT: Failed to establish connection for printing');
          return false;
        }
      }

      // Connection health check
      try {
        bool isConnected = await PrintBluetoothThermal.connectionStatus;
        if (!isConnected) {
          print('🔧 BT: Connection lost, attempting reconnection...');
          await _closeBluetoothConnection();

          if (!await _establishBluetoothConnection()) {
            return false;
          }
        }
      } catch (healthError) {
        print('🔧 BT: Health check failed, reconnecting...');
        await _closeBluetoothConnection();

        if (!await _establishBluetoothConnection()) {
          return false;
        }
      }

      print('🚀 BT: Starting super-fast print job...');

      // Convert to optimized ESC/POS with chunked transmission
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> ticket = await _convertReceiptContentToESCPOS(
        receiptContent,
        generator,
      );

      // Send in optimized chunks for better stability
      const chunkSize = 256; // Smaller chunks for Bluetooth stability
      for (int i = 0; i < ticket.length; i += chunkSize) {
        int end =
            (i + chunkSize < ticket.length) ? i + chunkSize : ticket.length;
        List<int> chunk = ticket.sublist(i, end);

        await PrintBluetoothThermal.writeBytes(chunk);

        // Small delay between chunks to prevent Bluetooth buffer overflow
        if (i + chunkSize < ticket.length) {
          await Future.delayed(Duration(milliseconds: 50));
        }
      }

      print('✅ Bluetooth super-fast print completed successfully');
      return true;
    } catch (e) {
      print('❌ Bluetooth super-fast print error: $e');
      await _closeBluetoothConnection();
      return false;
    }
  }

  Future<List<int>> _convertReceiptContentToESCPOS(
    String content,
    Generator generator,
  ) async {
    List<int> bytes = [];

    // Initialize printer first to clear any previous state/corrupted data
    bytes += generator.reset();

    bytes += generator.setGlobalCodeTable('CP1252');

    List<String> lines = content.split('\n');

    for (String line in lines) {
      if (line.contains('**') && line.contains('**')) {
        // Handle ONLY the specific bold elements we want
        if (line.contains('Dallas') && line.trim() == '**Dallas**') {
          // Restaurant name - large and bold
          bytes += generator.text(
            'Dallas',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size3,
              width: PosTextSize.size2,
              bold: true,
            ),
          );
        } else if (line.contains('Order #:')) {
          // Order number - bold
          String orderText = line.replaceAll('**', '');
          bytes += generator.text(
            orderText,
            styles: const PosStyles(
              height: PosTextSize.size2,
              width: PosTextSize.size1,
              bold: true,
            ),
          );
        } else if (line.contains('Order Type:')) {
          // Order type - bold
          String orderTypeText = line.replaceAll('**', '');
          bytes += generator.text(
            orderTypeText,
            styles: const PosStyles(bold: true),
          );
        } else if (line.contains('Payment Method:')) {
          // Payment method - bold
          String paymentText = line.replaceAll('**', '');
          bytes += generator.text(
            paymentText,
            styles: const PosStyles(height: PosTextSize.size1, bold: true),
          );
        } else if (line.contains('TOTAL:')) {
          // Total amount - bold
          String totalText = line.replaceAll('**', '');
          if (totalText.contains('£')) {
            // Split the total line for proper alignment
            List<String> parts = totalText.split('£');
            if (parts.length == 2) {
              bytes += generator.row([
                PosColumn(
                  text: parts[0],
                  width: 9,
                  styles: const PosStyles(bold: true),
                ),
                PosColumn(
                  text: '£${parts[1].trim()}',
                  width: 3,
                  styles: const PosStyles(align: PosAlign.right, bold: true),
                ),
              ]);
            } else {
              bytes += generator.text(
                totalText,
                styles: const PosStyles(bold: true),
              );
            }
          } else {
            bytes += generator.text(
              totalText,
              styles: const PosStyles(bold: true),
            );
          }
        } else if (line.trim().contains('x **') && line.contains('**')) {
          // Item names - bold (only the item name part)
          String itemText = line.replaceAll('**', '');
          bytes += generator.text(
            itemText,
            styles: const PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              bold: true,
            ),
          );
        } else if (line.contains('Status: **') &&
            (line.contains('PAID') || line.contains('UNPAID'))) {
          // Payment status (PAID/UNPAID) - bold
          String statusText = line.replaceAll('**', '');
          bytes += generator.text(
            statusText,
            styles: const PosStyles(
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          );
        } else {
          // Remove ** markers but don't make bold (fallback for any other ** text)
          String plainText = line.replaceAll('**', '');
          bytes += generator.text(plainText);
        }
      } else {
        // Regular text - no bold formatting
        if (line.contains('================================================')) {
          bytes += generator.text(
            line,
            styles: const PosStyles(align: PosAlign.center),
          );
        } else if (line.contains('Thank you for your order!')) {
          bytes += generator.text(
            line,
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          );
        } else if (line.trim().isEmpty) {
          bytes += generator.emptyLines(1);
        } else {
          bytes += generator.text(line);
        }
      }
    }

    bytes += generator.emptyLines(2);
    bytes += generator.cut();
    return bytes;
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
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    DateTime? orderDateTime,
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
        paidStatus: paidStatus,
        orderId: orderId,
        deliveryCharge: deliveryCharge,
        orderDateTime: orderDateTime,
        isXprinterUSB:
            _useXprinterSDK &&
            Platform.isAndroid &&
            _xprinterService.isConnected,
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
        paidStatus: paidStatus,
        orderId: orderId,
        deliveryCharge: deliveryCharge,
        isXprinterUSB:
            _useXprinterSDK &&
            Platform.isAndroid &&
            _xprinterService.isConnected,
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

  Future<bool> _establishUSBConnection(UsbDevice device) async {
    print('🔗 USB DEBUGGING: Starting enhanced connection establishment...');

    // Check if this is an Xprinter device for optimized handling
    bool isXprinter = _isXprinter(device);
    if (isXprinter) {
      print(
        '🎯 USB DEBUGGING: Xprinter device detected - using optimized settings',
      );
    }

    print('📄 USB DEBUGGING: Target Device Details:');
    print('   - Name: ${device.deviceName}');
    print(
      '   - VID: 0x${device.vid?.toRadixString(16).padLeft(4, '0').toUpperCase()}',
    );
    print(
      '   - PID: 0x${device.pid?.toRadixString(16).padLeft(4, '0').toUpperCase()}',
    );
    print('   - Manufacturer: ${device.manufacturerName ?? "Unknown"}');
    print('   - Product: ${device.productName ?? "Unknown"}');

    // Close any existing connection first
    if (_persistentUsbPort != null) {
      try {
        await _persistentUsbPort!.close();
      } catch (e) {
        print('🔧 USB DEBUGGING: Closed existing connection');
      }
      _persistentUsbPort = null;
    }

    int maxAttempts = isXprinter ? 5 : 3; // More attempts for Xprinter devices

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('🔧 USB DEBUGGING: Connection attempt $attempt/$maxAttempts');

        print('🔧 USB DEBUGGING: Step 1 - Creating USB port...');
        _persistentUsbPort = await device.create();

        if (_persistentUsbPort == null) {
          print(
            '❌ USB DEBUGGING: Failed to create USB port on attempt $attempt',
          );
          if (attempt < maxAttempts) {
            print('   ⏳ Waiting before retry...');
            await Future.delayed(Duration(milliseconds: 2000));
            continue;
          }
          print('   FINAL FAILURE REASONS:');
          print('     • Device is not available or in use');
          print('     • USB permissions not granted');
          print('     • Hardware connection issue');
          print('   SOLUTIONS:');
          print('     • Disconnect and reconnect USB cable');
          print('     • Restart the printer');
          print('     • Check cable integrity');
          print('     • Grant USB permissions in Android settings');
          return false;
        }
        print('✅ USB DEBUGGING: USB port created successfully');

        print('🔧 USB DEBUGGING: Step 2 - Opening USB port...');
        bool opened = await _persistentUsbPort!.open();

        if (!opened) {
          print('❌ USB DEBUGGING: Failed to open USB port on attempt $attempt');
          if (attempt < maxAttempts) {
            print('   ⏳ Cleaning up and retrying...');
            try {
              await _persistentUsbPort!.close();
            } catch (e) {}
            _persistentUsbPort = null;
            await Future.delayed(Duration(milliseconds: 2000));
            continue;
          }
          print('   FINAL FAILURE REASONS:');
          print('     • Device driver not installed');
          print('     • USB port locked by system');
          print('     • Hardware communication failure');
          print('   SOLUTIONS:');
          print('     • Install appropriate USB-to-Serial drivers');
          print('     • Restart device and try again');
          print('     • Check if printer needs specific drivers');
          _persistentUsbPort = null;
          return false;
        }
        print('✅ USB DEBUGGING: USB port opened successfully');

        print('🔧 USB DEBUGGING: Step 3 - Testing communication...');

        // Enhanced baud rate testing with Xprinter-optimized rates
        List<int> baudRates = [
          115200,
          9600,
          57600,
          38400,
          19200,
          230400,
          460800,
        ];
        bool connectionSuccessful = false;

        for (int baudRate in baudRates) {
          try {
            print('⚡ USB DEBUGGING: Testing baud rate: $baudRate');

            await _persistentUsbPort!.setPortParameters(
              baudRate,
              8, // Data bits
              1, // Stop bits
              0, // Parity (none)
            );

            // Wait for port to stabilize
            await Future.delayed(Duration(milliseconds: 100));
            print('   ✓ Port parameters set successfully');

            print('📤 USB DEBUGGING: Sending printer initialization...');

            // Send comprehensive Xprinter-optimized initialization sequence
            List<int> initSequence = [
              0x1B, 0x40, // ESC @ (initialize printer)
              0x1B, 0x21, 0x00, // ESC ! 0 (reset character formatting)
              0x1B, 0x61, 0x00, // ESC a 0 (left alignment)
              0x1C, 0x2E, // FS . (select Chinese character mode)
              0x1B, 0x74, 0x00, // ESC t 0 (select character table)
              0x1B, 0x52, 0x00, // ESC R 0 (select international character set)
            ];

            await _persistentUsbPort!.write(Uint8List.fromList(initSequence));
            await Future.delayed(Duration(milliseconds: 300));
            print('   ✓ Initialization sequence sent');

            print('📤 USB DEBUGGING: Sending test print command...');
            // Send a simple test that should be visible
            List<int> testCommand = [
              ...('USB Test OK\n').codeUnits,
              0x1B, 0x4A, 0x02, // ESC J 2 (feed 2 lines)
            ];

            await _persistentUsbPort!.write(Uint8List.fromList(testCommand));
            await Future.delayed(Duration(milliseconds: 200));
            print('   ✓ Test command sent successfully');

            connectionSuccessful = true;
            print('🎉 USB DEBUGGING: Connection established successfully!');
            print('   - Working baud rate: $baudRate');
            print(
              '   - Printer should have printed "USB Test OK" and fed paper',
            );
            break;
          } catch (e) {
            print('   ❌ Baud rate $baudRate failed: $e');
            continue;
          }
        }

        if (connectionSuccessful) {
          return true;
        } else {
          print('❌ USB DEBUGGING: All baud rates failed on attempt $attempt');
          if (attempt < maxAttempts) {
            print('   ⏳ Closing connection and retrying...');
            try {
              await _persistentUsbPort!.close();
            } catch (e) {}
            _persistentUsbPort = null;
            await Future.delayed(Duration(milliseconds: 2000));
            continue;
          } else {
            print('   COMMUNICATION FAILED - POSSIBLE CAUSES:');
            print('     • Printer not responding to ESC/POS commands');
            print('     • Wrong printer protocol (not ESC/POS compatible)');
            print('     • Hardware malfunction');
            print('   SOLUTIONS:');
            print('     • Verify printer supports ESC/POS commands');
            print('     • Check printer manual for correct settings');
            print('     • Try different printer or cable');
            await _persistentUsbPort!.close();
            _persistentUsbPort = null;
            return false;
          }
        }
      } catch (e) {
        print(
          '❌ USB DEBUGGING: Connection attempt $attempt failed with error: $e',
        );
        if (_persistentUsbPort != null) {
          try {
            await _persistentUsbPort!.close();
          } catch (closeError) {
            print('   Error closing failed connection: $closeError');
          }
          _persistentUsbPort = null;
        }

        if (attempt < maxAttempts) {
          print('   ⏳ Waiting before next attempt...');
          await Future.delayed(Duration(milliseconds: 2000));
        }
      }
    }

    print('❌ USB DEBUGGING: All connection attempts exhausted');
    return false;
  }

  Future<bool> _establishBluetoothConnection() async {
    print('📱 BT DEBUGGING: Starting enhanced Bluetooth connection...');

    try {
      if (_cachedThermalDevices.isEmpty) {
        print('📱 BT DEBUGGING: No cached devices, fetching paired devices...');
        _cachedThermalDevices = await PrintBluetoothThermal.pairedBluetooths;
      }

      if (_cachedThermalDevices.isEmpty) {
        print('❌ BT DEBUGGING: No paired Bluetooth devices found');
        print('   SOLUTIONS:');
        print('     • Go to Android Bluetooth settings');
        print('     • Pair with your thermal printer first');
        print('     • Ensure printer is in pairing mode');
        return false;
      }

      print(
        '📱 BT DEBUGGING: Found ${_cachedThermalDevices.length} paired devices:',
      );
      for (int i = 0; i < _cachedThermalDevices.length; i++) {
        var device = _cachedThermalDevices[i];
        print('   Device $i: ${device.name} (${device.macAdress})');
      }

      // Disconnect any existing connection with retry
      if (_isBluetoothConnected) {
        print('📱 BT DEBUGGING: Disconnecting existing connection...');
        for (int i = 0; i < 3; i++) {
          try {
            await PrintBluetoothThermal.disconnect;
            await Future.delayed(Duration(milliseconds: 500));

            bool stillConnected = await PrintBluetoothThermal.connectionStatus;
            if (!stillConnected) {
              print('✅ BT DEBUGGING: Successfully disconnected');
              break;
            }
            print('⏳ BT DEBUGGING: Disconnect attempt ${i + 1}/3...');
          } catch (e) {
            print('⚠️ BT DEBUGGING: Disconnect attempt ${i + 1} error: $e');
          }
        }

        _isBluetoothConnected = false;
        _connectedBluetoothDevice = null;
        await Future.delayed(Duration(milliseconds: 1000));
      }

      // Find the best printer device
      BluetoothInfo? printer = _findThermalPrinterDevice(_cachedThermalDevices);

      if (printer == null) {
        print(
          '⚠️ BT DEBUGGING: No obvious thermal printer found, using first device',
        );
        printer = _cachedThermalDevices.first;
      } else {
        print('🎯 BT DEBUGGING: Selected thermal printer: ${printer.name}');
      }

      print(
        '📱 BT DEBUGGING: Attempting connection to ${printer.name} (${printer.macAdress})',
      );

      // Connection with retries and better error handling
      bool connected = false;
      int maxAttempts = 4;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          print('📱 BT DEBUGGING: Connection attempt $attempt/$maxAttempts...');

          // Longer timeout for connection
          connected = await PrintBluetoothThermal.connect(
            macPrinterAddress: printer.macAdress,
          ).timeout(Duration(seconds: 8));

          if (connected) {
            print('✅ BT DEBUGGING: Connection established!');

            // Verify connection is actually working
            await Future.delayed(Duration(milliseconds: 500));
            bool statusCheck = await PrintBluetoothThermal.connectionStatus;

            if (statusCheck) {
              print('✅ BT DEBUGGING: Connection verified');
              break;
            } else {
              print('⚠️ BT DEBUGGING: Connection status check failed');
              connected = false;
            }
          }

          if (!connected && attempt < maxAttempts) {
            print('⏳ BT DEBUGGING: Connection failed, waiting before retry...');
            await Future.delayed(Duration(milliseconds: 2000));
          }
        } catch (e) {
          print('❌ BT DEBUGGING: Connection attempt $attempt error: $e');
          connected = false;

          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 2000));
          }
        }
      }

      if (!connected) {
        print('❌ BT DEBUGGING: All connection attempts failed');
        print('   TROUBLESHOOTING:');
        print('     • Ensure printer is turned ON');
        print('     • Check if printer is already connected to another device');
        print('     • Try restarting the printer');
        print('     • Re-pair the printer in Bluetooth settings');
        print('     • Ensure printer is within range');
        return false;
      }

      _isBluetoothConnected = true;
      _connectedBluetoothDevice = printer.macAdress;

      // Enhanced initialization with better error handling
      try {
        print('📱 BT DEBUGGING: Sending initialization commands...');

        // Comprehensive initialization sequence
        List<List<int>> initCommands = [
          [0x1B, 0x40], // ESC @ (initialize)
          [0x1B, 0x61, 0x00], // ESC a 0 (left align)
          [0x1B, 0x21, 0x00], // ESC ! 0 (reset formatting)
        ];

        for (var command in initCommands) {
          await PrintBluetoothThermal.writeBytes(command);
          await Future.delayed(Duration(milliseconds: 100));
        }

        print('✅ BT DEBUGGING: Initialization completed');

        // Test communication
        print('📱 BT DEBUGGING: Testing communication...');
        List<int> testData = ('BT Test OK\n').codeUnits + [0x1B, 0x4A, 0x01];
        await PrintBluetoothThermal.writeBytes(testData);

        print('🎉 BT DEBUGGING: Bluetooth connection fully established!');
        print('   - Device: ${printer.name}');
        print('   - MAC: ${printer.macAdress}');
        print('   - Printer should have printed "BT Test OK"');

        return true;
      } catch (e) {
        print('❌ BT DEBUGGING: Initialization failed: $e');
        _isBluetoothConnected = false;
        _connectedBluetoothDevice = null;

        try {
          await PrintBluetoothThermal.disconnect;
        } catch (disconnectError) {
          print('Error during cleanup disconnect: $disconnectError');
        }

        return false;
      }
    } catch (e) {
      print('❌ BT DEBUGGING: Bluetooth connection establishment failed: $e');
      _isBluetoothConnected = false;
      _connectedBluetoothDevice = null;
      return false;
    }
  }

  void _startConnectionHealthMonitoring() {
    if (_isMonitoringConnection) return;

    _isMonitoringConnection = true;
    _connectionHealthTimer = Timer.periodic(Duration(seconds: 15), (
      timer,
    ) async {
      if (!_isMonitoringConnection) {
        timer.cancel();
        return;
      }

      // Enhanced USB connection health check
      if (_persistentUsbPort != null) {
        try {
          // Quick heartbeat test
          await _persistentUsbPort!.write(Uint8List.fromList([0x1B, 0x40]));
          await Future.delayed(Duration(milliseconds: 100));
          print('🔧 USB connection health: OK');
        } catch (e) {
          print('🔧 USB connection health: FAILED - $e');
          print('🔧 Attempting USB auto-recovery...');

          await _closeUsbConnection();

          // Auto-recovery attempt
          if (_cachedUsbDevices.isNotEmpty) {
            bool recovered = await _establishUSBConnection(
              _cachedUsbDevices.first,
            );
            if (recovered) {
              print('✅ USB auto-recovery successful');
            } else {
              print('❌ USB auto-recovery failed');
            }
          }
        }
      }

      // Enhanced Bluetooth connection health check
      if (_isBluetoothConnected) {
        try {
          bool isConnected = await PrintBluetoothThermal.connectionStatus;
          if (!isConnected) {
            print('🔧 Bluetooth connection health: DISCONNECTED');
            print('🔧 Attempting Bluetooth auto-recovery...');

            await _closeBluetoothConnection();

            // Auto-recovery attempt
            bool recovered = await _establishBluetoothConnection();
            if (recovered) {
              print('✅ Bluetooth auto-recovery successful');
            } else {
              print('❌ Bluetooth auto-recovery failed');
            }
          } else {
            // Send heartbeat to ensure connection is truly active
            await PrintBluetoothThermal.writeBytes([0x1B, 0x40]);
            print('🔧 Bluetooth connection health: OK');
          }
        } catch (e) {
          print('🔧 Bluetooth connection health: FAILED - $e');
          print('🔧 Attempting Bluetooth auto-recovery...');

          await _closeBluetoothConnection();

          bool recovered = await _establishBluetoothConnection();
          if (recovered) {
            print('✅ Bluetooth auto-recovery successful');
          } else {
            print('❌ Bluetooth auto-recovery failed');
          }
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
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    DateTime? orderDateTime,
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
      paidStatus: paidStatus,
      orderId: orderId,
      deliveryCharge: deliveryCharge,
      isXprinterUSB:
          _useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected,
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
      paidStatus: paidStatus,
      orderId: orderId,
      deliveryCharge: deliveryCharge,
      orderDateTime: orderDateTime,
      isXprinterUSB:
          _useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected,
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
    return UKTimeService.now().difference(_lastCacheUpdate!) > CACHE_VALIDITY;
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
    print('🧹 Cleaning up all printer connections...');

    // Stop monitoring first
    _stopConnectionHealthMonitoring();

    // Enhanced USB cleanup with retry
    if (_persistentUsbPort != null) {
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await _persistentUsbPort!.close();
          print('✅ USB connection closed (attempt $attempt)');
          break;
        } catch (e) {
          print('⚠️ USB close attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }
      _persistentUsbPort = null;
    }

    // Enhanced Bluetooth cleanup with retry
    if (_isBluetoothConnected) {
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await PrintBluetoothThermal.disconnect;
          print('✅ Bluetooth connection closed (attempt $attempt)');
          break;
        } catch (e) {
          print('⚠️ Bluetooth close attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }
      _isBluetoothConnected = false;
      _connectedBluetoothDevice = null;
    }

    print('🧹 Connection cleanup completed');
  }

  void _clearCache() {
    _cachedThermalDevices.clear();
    _cachedUsbDevices.clear();
    _receiptCache.clear();
    _lastCacheUpdate = null;
  }

  // ===== CASH DRAWER FUNCTIONALITY =====

  /// Opens the cash drawer using ESC/POS commands
  /// Returns true if the command was sent successfully, throws exception on error
  Future<bool> openCashDrawer({String reason = "Manual open"}) async {
    if (!_isDrawerOpeningEnabled) {
      throw Exception('Cash drawer functionality is disabled in settings');
    }

    if (kIsWeb && !ENABLE_DRAWER_TEST_MODE) {
      throw Exception('Cash drawer not supported on web platform');
    }

    if (kIsWeb && ENABLE_DRAWER_TEST_MODE) {
      print('💰 Cash drawer opened (TEST MODE) - Reason: $reason');
      await Future.delayed(Duration(seconds: 1));
      return true;
    }

    print('💰 Opening cash drawer: $reason');

    // TEST MODE: Simulate cash drawer opening for development
    if (ENABLE_DRAWER_TEST_MODE) {
      print('🧪 TEST MODE: Simulating cash drawer opening...');
      await Future.delayed(
        Duration(milliseconds: 500),
      ); // Simulate operation time
      print('✅ TEST MODE: Cash drawer opened successfully (simulated)');
      return true;
    }

    // Try Xprinter SDK first if enabled and connected
    if (_useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected) {
      try {
        print('🎯 Using Xprinter SDK to open cash drawer...');
        bool success = await _xprinterService.openCashBox();

        if (success) {
          print('✅ Xprinter SDK cash drawer opened successfully');
          return true;
        } else {
          print(
            '⚠️ Xprinter SDK cash drawer failed, falling back to legacy method',
          );
        }
      } catch (e) {
        print(
          '⚠️ Xprinter SDK cash drawer error, falling back to legacy method: $e',
        );
      }
    }

    // Enhanced ESC/POS cash drawer commands - try multiple variations
    List<List<int>> drawerCommands = [
      // Standard ESC/POS command
      [0x1B, 0x70, 0x00, 0x19, 0x19], // ESC p m t1 t2
      // Alternative command for different drawer types
      [0x1B, 0x70, 0x00, 0x32, 0x96], // Longer pulse
      // Direct printer-specific command
      [0x10, 0x14, 0x01, 0x00, 0x05], // DLE DC4 command
    ];

    // Try to send command via available connection
    bool success = false;
    String lastError = '';

    // Try each drawer command variation
    for (int cmdIndex = 0; cmdIndex < drawerCommands.length; cmdIndex++) {
      List<int> drawerCommand = drawerCommands[cmdIndex];
      print(
        '💰 Trying drawer command ${cmdIndex + 1}/${drawerCommands.length}',
      );

      try {
        // First try USB connection
        if (_persistentUsbPort != null) {
          success = await _sendDrawerCommandUSB(drawerCommand);
          if (success) {
            print('✅ Cash drawer opened via USB with command ${cmdIndex + 1}');
            return true;
          }
        }

        // Then try Bluetooth connection
        if (_isBluetoothConnected) {
          success = await _sendDrawerCommandBluetooth(drawerCommand);
          if (success) {
            print(
              '✅ Cash drawer opened via Bluetooth with command ${cmdIndex + 1}',
            );
            return true;
          }
        }

        // Finally try establishing new connections
        success = await _openDrawerWithNewConnection(drawerCommand);
        if (success) {
          print(
            '✅ Cash drawer opened with new connection using command ${cmdIndex + 1}',
          );
          return true;
        }
      } catch (e) {
        lastError = e.toString();
        print('⚠️ Command ${cmdIndex + 1} failed: $e');
        continue;
      }
    }

    // If we get here, all attempts failed
    String errorMsg =
        'Failed to open cash drawer after trying all methods. Last error: $lastError. Please check printer connection and ensure drawer is properly connected.';
    print('❌ $errorMsg');
    throw Exception(errorMsg);
  }

  Future<bool> _sendDrawerCommandUSB(List<int> command) async {
    try {
      if (_persistentUsbPort == null) {
        print('❌ USB drawer: No active USB connection');
        throw Exception('USB connection not available for cash drawer');
      }

      print(
        '💰 USB: Sending cash drawer command: ${command.map((e) => '0x${e.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(' ')}',
      );

      // For Xprinter SDK, try to use SDK method if available
      if (_useXprinterSDK &&
          Platform.isAndroid &&
          _xprinterService.isConnected) {
        try {
          print('🎯 Attempting cash drawer via Xprinter SDK...');
          bool success = await _xprinterService.openCashBox();

          if (success) {
            print('✅ Xprinter SDK cash drawer opened successfully');
            return true;
          } else {
            print(
              '⚠️ Xprinter SDK cash drawer failed, using direct USB command...',
            );
          }
        } catch (e) {
          print(
            '⚠️ Xprinter SDK cash drawer error, using direct USB command: $e',
          );
        }
      }

      // Send the drawer command directly via USB
      await _persistentUsbPort!.write(Uint8List.fromList(command));

      // Wait for command execution and verify
      await Future.delayed(Duration(milliseconds: 200));

      // Send additional pulse for stubborn drawers
      List<int> extraPulse = [0x1B, 0x70, 0x00, 0x32, 0x96]; // Longer pulse
      await _persistentUsbPort!.write(Uint8List.fromList(extraPulse));
      await Future.delayed(Duration(milliseconds: 100));

      print('✅ USB: Cash drawer command sent successfully');
      return true;
    } catch (e) {
      String errorMsg = 'USB cash drawer command failed: $e';
      print('❌ $errorMsg');
      throw Exception(errorMsg);
    }
  }

  /// Send drawer command via Bluetooth
  Future<bool> _sendDrawerCommandBluetooth(List<int> command) async {
    try {
      if (!_isBluetoothConnected) return false;

      await PrintBluetoothThermal.writeBytes(command);
      await Future.delayed(
        Duration(milliseconds: 100),
      ); // Wait for command execution
      return true;
    } catch (e) {
      print('❌ Bluetooth drawer command error: $e');
      return false;
    }
  }

  /// Try to establish a new connection and send drawer command
  Future<bool> _openDrawerWithNewConnection(List<int> command) async {
    // Test available connections
    Map<String, bool> connections = await testAllConnections();

    // Try USB first
    if (connections['usb'] == true) {
      try {
        if (_cachedUsbDevices.isEmpty) {
          _cachedUsbDevices = await UsbSerial.listDevices();
        }
        if (_cachedUsbDevices.isNotEmpty) {
          bool connected = await _establishUSBConnection(
            _cachedUsbDevices.first,
          );
          if (connected) {
            return await _sendDrawerCommandUSB(command);
          }
        }
      } catch (e) {
        print('❌ USB connection for drawer failed: $e');
      }
    }

    // Try Bluetooth
    if (connections['bluetooth'] == true) {
      try {
        bool connected = await _establishBluetoothConnection();
        if (connected) {
          return await _sendDrawerCommandBluetooth(command);
        }
      } catch (e) {
        print('❌ Bluetooth connection for drawer failed: $e');
      }
    }

    return false;
  }

  /// Test if cash drawer can be opened (check printer connections)
  Future<bool> canOpenDrawer() async {
    if (!_isDrawerOpeningEnabled) return false;
    if (kIsWeb) return false;

    // TEST MODE: Always return true for development testing
    if (ENABLE_DRAWER_TEST_MODE) {
      print('🧪 TEST MODE: Cash drawer is available (simulated)');
      return true;
    }

    // Quick check for existing connections
    if (_persistentUsbPort != null || _isBluetoothConnected) {
      return true;
    }

    // Check if any printers are available (without sending commands to prevent auto-printing)
    Map<String, bool> connections = await checkConnectionStatusOnly();
    return connections['usb'] == true || connections['bluetooth'] == true;
  }

  /// Configure cash drawer settings
  void setCashDrawerSettings({
    bool? enableDrawerOpening,
    bool? autoOpenOnCashPayment,
  }) {
    if (enableDrawerOpening != null) {
      _isDrawerOpeningEnabled = enableDrawerOpening;
      print(
        '💰 Drawer opening ${enableDrawerOpening ? "enabled" : "disabled"}',
      );
    }

    if (autoOpenOnCashPayment != null) {
      _autoOpenOnCashPayment = autoOpenOnCashPayment;
      print(
        '💰 Auto-open on cash payment ${autoOpenOnCashPayment ? "enabled" : "disabled"}',
      );
    }
  }

  /// Get current cash drawer settings
  Map<String, bool> getCashDrawerSettings() {
    return {
      'enabled': _isDrawerOpeningEnabled,
      'autoOpenOnCashPayment': _autoOpenOnCashPayment,
    };
  }

  // Cleanup method
  Future<void> dispose() async {
    _stopConnectionHealthMonitoring();
    await _closeAllConnections();
    _clearCache();
  }

  Future<bool> _isUSBSerialAvailable() async {
    print('🔍 USB DEBUGGING: Checking USB Serial availability...');

    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
      print(
        '❌ USB DEBUGGING: Platform not supported (${Platform.operatingSystem})',
      );
      return false;
    }

    try {
      // Request USB permissions for Android FIRST
      if (Platform.isAndroid) {
        print('📱 USB DEBUGGING: Requesting Android USB permissions...');
        await _requestUSBPermissions();

        // Add delay to ensure permissions are processed
        await Future.delayed(Duration(milliseconds: 500));
      }

      print('🔍 USB DEBUGGING: Listing USB devices...');

      // Try multiple times with delays - sometimes first attempt fails
      List<UsbDevice> devices = [];
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          devices = await UsbSerial.listDevices();
          print(
            '✅ USB DEBUGGING: Attempt $attempt - Found ${devices.length} USB devices',
          );

          if (devices.isNotEmpty) break;

          if (attempt < 3) {
            print('⏳ USB DEBUGGING: No devices found, waiting before retry...');
            await Future.delayed(Duration(milliseconds: 1000));
          }
        } catch (e) {
          print('⚠️ USB DEBUGGING: Attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 1000));
          }
        }
      }

      if (devices.isEmpty) {
        print('❌ USB DEBUGGING: No USB devices detected after 3 attempts!');
        print('   TROUBLESHOOTING STEPS:');
        print('   1. Ensure USB printer is connected and powered ON');
        print('   2. Check USB cable integrity (try different cable)');
        print('   3. Try different USB port');
        print('   4. For Android: Enable "USB Debugging" in Developer Options');
        print('   5. For Android: Check "Allow USB debugging" popup');
        print('   6. Restart the printer and try again');
        print('   7. Check if printer needs specific drivers');
        return false;
      }

      // Debug print device details with enhanced analysis
      for (int i = 0; i < devices.length; i++) {
        var device = devices[i];
        print('📄 USB DEBUGGING: Device $i Details:');
        print('   - Device Name: ${device.deviceName}');
        print(
          '   - VID: 0x${device.vid?.toRadixString(16).padLeft(4, '0').toUpperCase()}',
        );
        print(
          '   - PID: 0x${device.pid?.toRadixString(16).padLeft(4, '0').toUpperCase()}',
        );
        print('   - Manufacturer: ${device.manufacturerName ?? "Unknown"}');
        print('   - Product Name: ${device.productName ?? "Unknown"}');
        print('   - Serial: ${device.serial ?? "Unknown"}');

        // Enhanced printer compatibility analysis
        bool isCompatible = _analyzePrinterCompatibility(device);
        if (isCompatible) {
          print('🎯 USB DEBUGGING: This device is likely compatible!');
        }
      }

      return devices.isNotEmpty;
    } on MissingPluginException catch (e) {
      print('❌ USB DEBUGGING: USB Serial plugin not available: $e');
      print('   - Make sure usb_serial plugin is properly installed');
      print('   - Check pubspec.yaml for correct plugin version');
      return false;
    } on PlatformException catch (e) {
      print('❌ USB DEBUGGING: Platform exception: $e');
      print('   - This may be a permissions issue');
      print('   - Try restarting the app with USB already connected');
      return false;
    } catch (e) {
      print('❌ USB DEBUGGING: USB Serial availability check error: $e');
      return false;
    }
  }

  bool _isXprinter(UsbDevice device) {
    // Check VID/PID for known Xprinter devices
    if (device.vid != null && device.pid != null) {
      List<int> xprinterVids = [
        11575, // 0x2D37 - Official Xprinter VID from USB-IF
        0x0416,
        0x1234,
        0x0525,
        0x28E9,
        0x6790,
        0x519C, // Additional/alternative VIDs
      ];
      if (xprinterVids.contains(device.vid)) {
        return true;
      }
    }

    // Check device names for Xprinter indicators
    String deviceName = (device.deviceName).toLowerCase();
    String manufacturer = (device.manufacturerName ?? '').toLowerCase();
    String product = (device.productName ?? '').toLowerCase();

    return manufacturer.contains('xprinter') ||
        manufacturer.contains('x-printer') ||
        manufacturer.contains('xp-printer') ||
        manufacturer.contains('gao xing') ||
        product.contains('xprinter') ||
        product.contains('x-printer') ||
        product.contains('xp-') ||
        deviceName.contains('xprinter') ||
        deviceName.contains('x-printer');
  }

  bool _analyzePrinterCompatibility(UsbDevice device) {
    // Expanded thermal printer VID/PIDs database
    final Map<int, List<int>> knownPrinters = {
      // Epson thermal printers
      0x04b8: [0x0202, 0x0203, 0x0208, 0x020E, 0x0210, 0x0219],
      // Brother thermal printers
      0x04f9: [0x2040, 0x2041, 0x2042, 0x2048, 0x204A, 0x204D],
      // Star Micronics
      0x0456: [0x0808, 0x0809, 0x080A, 0x080B, 0x080C],
      // Citizen thermal printers
      0x1FC9: [0x2016, 0x2017, 0x2018],
      // Various generic thermal printers
      0x0483: [0x5740, 0x5741],
      // Bixolon thermal printers
      0x0419: [0x3FF0, 0x3FF1, 0x3FF2],
      // Custom/Generic thermal printers (common VIDs)
      0x1A86: [
        0x7523,
        0x5523,
      ], // CH340 USB-Serial chips (common in thermal printers)
      0x10C4: [0xEA60], // CP210x USB-Serial chips
      0x067B: [0x2303], // PL2303 USB-Serial chips
      // Xprinter thermal printers (comprehensive list)
      0x0416: [
        0x5011,
        0x5012,
        0x5013,
        0x5014,
        0x5015,
      ], // Common Xprinter VID/PIDs
      0x1234: [
        0x5678,
        0x5679,
        0x567A,
        0x567B,
        0x567C,
      ], // Alternative Xprinter IDs
      0x0525: [0xA4A7, 0xA4A8, 0xA4A9, 0xA4AA], // Some Xprinter models
      0x28E9: [0x028A, 0x028B, 0x028C], // Additional Xprinter models
      0x6790: [0x29C1, 0x29C2, 0x29C3], // Newer Xprinter models
      0x519C: [0x5781, 0x5782, 0x5783], // Xprinter XP series
      // Additional generic thermal printer chips
      0x1CBE: [0x0003], // Generic thermal printer chips
      0x2E28: [0x0001, 0x0002], // More generic IDs
    };

    bool isKnownPrinter = false;

    if (device.vid != null && device.pid != null) {
      isKnownPrinter = knownPrinters[device.vid]?.contains(device.pid) ?? false;
    }

    // Also check by device name/manufacturer
    String deviceName = (device.deviceName).toLowerCase();
    String manufacturer = (device.manufacturerName ?? '').toLowerCase();
    String product = (device.productName ?? '').toLowerCase();

    bool nameIndicatesPrinter =
        deviceName.contains('printer') ||
        deviceName.contains('thermal') ||
        deviceName.contains('pos') ||
        deviceName.contains('receipt') ||
        manufacturer.contains('printer') ||
        manufacturer.contains('thermal') ||
        manufacturer.contains('epson') ||
        manufacturer.contains('brother') ||
        manufacturer.contains('star') ||
        manufacturer.contains('citizen') ||
        manufacturer.contains('bixolon') ||
        manufacturer.contains('xprinter') ||
        manufacturer.contains('x-printer') ||
        manufacturer.contains('xp-printer') ||
        manufacturer.contains('gprinter') ||
        manufacturer.contains('gao xing') ||
        product.contains('printer') ||
        product.contains('thermal') ||
        product.contains('xprinter') ||
        product.contains('x-printer') ||
        product.contains('xp-') ||
        product.contains('gp-') ||
        product.contains('pos') ||
        product.contains('receipt') ||
        product.toLowerCase().contains('80mm') ||
        product.toLowerCase().contains('58mm');

    // Check for common USB-Serial converter chips used in thermal printers
    bool isSerialConverter =
        manufacturer.contains('ch340') ||
        manufacturer.contains('cp210') ||
        manufacturer.contains('pl2303') ||
        manufacturer.contains('ftdi') ||
        product.contains('usb serial') ||
        product.contains('uart');

    if (isKnownPrinter) {
      print('✅ USB DEBUGGING: Device is a KNOWN thermal printer!');
      return true;
    } else if (nameIndicatesPrinter) {
      print(
        '✅ USB DEBUGGING: Device name/manufacturer suggests thermal printer',
      );
      return true;
    } else if (isSerialConverter) {
      print(
        '🔧 USB DEBUGGING: Device appears to be USB-Serial converter (commonly used by thermal printers)',
      );
      return true;
    } else {
      print('⚠️ USB DEBUGGING: Device may not be a thermal printer');
      print('   - VID/PID not in known database');
      print('   - Name doesn\'t clearly indicate printer');
      print('   - May still work if it supports ESC/POS commands');
      return false;
    }
  }

  Future<void> _requestUSBPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      print('📱 USB DEBUGGING: Requesting comprehensive USB permissions...');

      // Request all relevant permissions for USB access
      List<Permission> usbPermissions = [
        Permission.storage,
        Permission.manageExternalStorage,
        // Add location permission as some Android versions need it for USB
        Permission.location,
      ];

      // Request permissions one by one for better debugging
      for (Permission permission in usbPermissions) {
        PermissionStatus status = await permission.status;
        print('   Permission ${permission.toString()}: ${status.toString()}');

        if (status != PermissionStatus.granted) {
          PermissionStatus newStatus = await permission.request();
          print(
            '   After request ${permission.toString()}: ${newStatus.toString()}',
          );
        }
      }

      // For Android API 23+, we might need to request USB permission at runtime
      if (Platform.isAndroid) {
        print('   ✅ USB permissions processing completed');
      }
    } catch (e) {
      print('❌ Error requesting USB permissions: $e');
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
    print(
      '🔍 BT DEBUGGING: Analyzing ${devices.length} devices for thermal printer...',
    );

    // Prioritized keywords for thermal printer detection
    List<List<String>> printerKeywords = [
      // High priority - very likely to be thermal printers
      ['thermal', 'receipt'],
      ['pos', 'printer'],
      ['rp-', 'rpp-'], // Common thermal printer model prefixes
      ['tm-', 'tsp-'], // Epson and Star model prefixes
      ['spp-'], // Samsung printer prefix
      // Medium priority - likely printers
      ['printer'],
      ['print'],

      // Brand names
      ['epson', 'star', 'citizen', 'bixolon', 'brother'],
    ];

    BluetoothInfo? bestMatch = null;
    int bestPriority = -1;

    for (BluetoothInfo device in devices) {
      String deviceName = device.name.toLowerCase();
      print('   Analyzing: ${device.name}');

      for (int priority = 0; priority < printerKeywords.length; priority++) {
        List<String> keywords = printerKeywords[priority];

        for (String keyword in keywords) {
          if (deviceName.contains(keyword)) {
            print('     ✓ Match found: "$keyword" (priority $priority)');

            if (priority < bestPriority || bestMatch == null) {
              bestMatch = device;
              bestPriority = priority;
              print('     🎯 New best match!');
            }
            break;
          }
        }

        if (bestPriority != -1 && priority > bestPriority) {
          break; // No need to check lower priority if we have a high priority match
        }
      }
    }

    if (bestMatch != null) {
      print('🏆 BT DEBUGGING: Best thermal printer match: ${bestMatch.name}');
    } else {
      print('⚠️ BT DEBUGGING: No obvious thermal printer detected');
    }

    return bestMatch;
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
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    DateTime? orderDateTime,
    bool isXprinterUSB = false,
  }) {
    StringBuffer receipt = StringBuffer();

    // Use full 80mm paper width (48 characters)
    receipt.writeln('================================================');
    receipt.writeln('                   **Dallas**'); // Bold restaurant name
    receipt.writeln('================================================');
    DateTime displayDateTime = orderDateTime ?? UKTimeService.now();
    receipt.writeln(
      'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(displayDateTime)}',
    );
    if (orderId != null) {
      receipt.writeln('**Order #: $orderId**'); // Bold order number
    }
    receipt.writeln(
      '**Order Type: ${orderType.toUpperCase()}**',
    ); // Bold order type
    receipt.writeln('================================================');
    receipt.writeln();

    // Customer Details Section
    if (!_shouldExcludeField(customerName)) {
      receipt.writeln('CUSTOMER DETAILS:');
      receipt.writeln('------------------------------------------------');
      receipt.writeln('Name: $customerName');

      if (!_shouldExcludeField(phoneNumber)) {
        receipt.writeln('Phone: $phoneNumber');
      }

      // Address details for delivery orders
      if (orderType.toLowerCase() == 'delivery') {
        if (!_shouldExcludeField(streetAddress)) {
          receipt.writeln('Address: $streetAddress');
        }
        if (!_shouldExcludeField(city)) {
          receipt.writeln('City: $city');
        }
        if (!_shouldExcludeField(postalCode)) {
          receipt.writeln('Postcode: $postalCode');
        }
      }

      receipt.writeln('================================================');
      receipt.writeln();
    }

    receipt.writeln('ITEMS:');
    receipt.writeln('------------------------------------------------');

    for (CartItem item in cartItems) {
      // Use the actual pricePerUnit from cart item (includes options/customizations)
      double itemPricePerUnit = item.pricePerUnit;
      double itemTotal = itemPricePerUnit * item.quantity;

      // Format item line with name and price on same line
      String itemName = '${item.quantity}x **${item.foodItem.name}**';
      String itemPrice = '${itemTotal.toStringAsFixed(2)}';

      // Calculate padding to align price to the right (48 char width)
      int availableWidth = 48;
      int nameLength = itemName.length; // Use actual string length
      int priceLength = itemPrice.length;
      int padding = availableWidth - nameLength - priceLength;
      if (padding < 1) padding = 1; // Minimum 1 space

      receipt.writeln('$itemName${' ' * padding}$itemPrice');

      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          if (!_shouldExcludeField(option)) {
            // Check if option contains line breaks (deals formatting)
            if (option.contains('\n')) {
              // Split by line breaks and print each line
              List<String> lines = option.split('\n');
              for (String line in lines) {
                // Word wrap each line to prevent mid-word breaking
                List<String> wrappedLines = _wrapText('  + ${line.trim()}', 48);
                for (String wrappedLine in wrappedLines) {
                  receipt.writeln(wrappedLine);
                }
              }
            } else {
              // Word wrap single options to prevent mid-word breaking
              List<String> wrappedLines = _wrapText('  + $option', 48);
              for (String wrappedLine in wrappedLines) {
                receipt.writeln(wrappedLine);
              }
            }
          }
        }
      }

      if (!_shouldExcludeField(item.comment)) {
        // Word wrap comments to prevent mid-word breaking
        List<String> wrappedLines = _wrapText('  Note: ${item.comment}', 48);
        for (String wrappedLine in wrappedLines) {
          receipt.writeln(wrappedLine);
        }
      }
      receipt.writeln();
    }

    receipt.writeln('------------------------------------------------');

    // Show delivery charges for delivery orders before subtotal
    if (orderType.toLowerCase() == 'delivery' &&
        deliveryCharge != null &&
        deliveryCharge > 0) {
      String label = 'Delivery Charges:';
      String amount = deliveryCharge.toStringAsFixed(2);
      int padding = 48 - label.length - amount.length;
      if (padding < 1) padding = 1;
      receipt.writeln('$label${' ' * padding}$amount');
    }

    // Right-align subtotal
    String subtotalLabel = 'Subtotal:';
    String subtotalAmount = subtotal.toStringAsFixed(2);
    int subtotalPadding = 48 - subtotalLabel.length - subtotalAmount.length;
    if (subtotalPadding < 1) subtotalPadding = 1;
    receipt.writeln('$subtotalLabel${' ' * subtotalPadding}$subtotalAmount');

    receipt.writeln('================================================');

    // Right-align total (accounting for ** markers and GBP prefix)
    String totalLabel = '**TOTAL:';
    String totalAmount = 'GBP ${totalCharge.toStringAsFixed(2)}**';
    int totalPadding =
        48 - totalLabel.length - totalAmount.length + 4; // +4 for ** markers
    if (totalPadding < 1) totalPadding = 1;
    receipt.writeln('$totalLabel${' ' * totalPadding}$totalAmount');

    receipt.writeln('================================================');

    // Payment Status Section
    receipt.writeln();
    receipt.writeln('PAYMENT STATUS:');
    receipt.writeln('------------------------------------------------');
    if (!_shouldExcludeField(paymentType)) {
      receipt.writeln('**Payment Method: $paymentType**'); // Bold payment type
    }

    // Simple payment status logic: only use paid_status
    String paymentStatus = (paidStatus == true) ? 'PAID' : 'UNPAID';

    // Show payment details based on payment type and status
    if (paidStatus == true) {
      if (paymentType != null &&
          paymentType.toLowerCase() == 'cash' &&
          changeDue > 0) {
        String amountReceivedText =
            isXprinterUSB
                ? 'Amount Received:  GBP ${(totalCharge + changeDue).toStringAsFixed(2)}'
                : 'Amount Received:  GBP${(totalCharge + changeDue).toStringAsFixed(2)}';
        String changeDueText =
            isXprinterUSB
                ? 'Change Due:       GBP ${changeDue.toStringAsFixed(2)}'
                : 'Change Due:       GBP${changeDue.toStringAsFixed(2)}';
        receipt.writeln(amountReceivedText);
        receipt.writeln(changeDueText);
      }
    }

    receipt.writeln(
      'Status: **$paymentStatus**',
    ); // Bold payment status (PAID/UNPAID)
    receipt.writeln('================================================');

    receipt.writeln();
    receipt.writeln('Thank you for your order!');
    receipt.writeln('================================================');

    return receipt.toString();
  }

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
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    bool isXprinterUSB = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // 80mm paper width
    List<int> bytes = [];

    // Initialize printer first to clear any previous state/corrupted data
    bytes += generator.reset();

    bytes += generator.setGlobalCodeTable('CP1252');

    // Bold restaurant name
    bytes += generator.text(
      'Dallas',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size3,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    // Add gap between TEST and separator line
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(UKTimeService.now())}',
    );

    // Bold order number
    if (orderId != null) {
      bytes += generator.text(
        'Order #: $orderId',
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
    }

    // Bold order type
    bytes += generator.text(
      'Order Type: ${orderType.toUpperCase()}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Customer Details Section - NOT BOLD
    if (!_shouldExcludeField(customerName)) {
      bytes += generator.text(
        'CUSTOMER DETAILS:',
        styles: const PosStyles(
          height: PosTextSize.size3,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        '------------------------------------------------',
      );
      bytes += generator.text(
        'Name: $customerName',
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );

      if (!_shouldExcludeField(phoneNumber)) {
        bytes += generator.text(
          'Phone: $phoneNumber',
          styles: const PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        );
      }

      // Address details for delivery orders
      if (orderType.toLowerCase() == 'delivery') {
        if (!_shouldExcludeField(streetAddress)) {
          bytes += generator.text(
            'Address: $streetAddress',
            styles: const PosStyles(
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          );
        }
        if (!_shouldExcludeField(city)) {
          bytes += generator.text(
            'City: $city',
            styles: const PosStyles(
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          );
        }
        if (!_shouldExcludeField(postalCode)) {
          bytes += generator.text(
            'Postcode: $postalCode',
            styles: const PosStyles(
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          );
        }
      }

      bytes += generator.text(
        '================================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // ITEMS section - NOT BOLD
    bytes += generator.text(
      'ITEMS:',
      styles: const PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text('------------------------------------------------');

    for (CartItem item in cartItems) {
      // Use the actual pricePerUnit from cart item (includes options/customizations)
      double itemPricePerUnit = item.pricePerUnit;
      double itemTotal = itemPricePerUnit * item.quantity;

      // Item name and price on same line - using established 42-char format
      String quantityAndName = '${item.quantity}x ${item.foodItem.name}';
      String priceText =
          isXprinterUSB
              ? '${itemTotal.toStringAsFixed(2)}'
              : '${itemTotal.toStringAsFixed(2)}';

      // Use same logic as _fixXprinterLineFormatting for consistency
      int totalWidth = 42; // Based on manual's 72mm paper width
      int nameLength = quantityAndName.length;
      int priceLength = priceText.length;
      int paddingNeeded = totalWidth - nameLength - priceLength;

      if (paddingNeeded < 1) paddingNeeded = 1; // Minimum 1 space

      String formattedLine = '$quantityAndName${' ' * paddingNeeded}$priceText';

      bytes += generator.text(
        formattedLine,
        styles: const PosStyles(bold: true),
      );

      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          if (!_shouldExcludeField(option)) {
            // Check if option contains line breaks (deals formatting)
            if (option.contains('\n')) {
              // Split by line breaks and print each line
              List<String> lines = option.split('\n');
              for (String line in lines) {
                // Word wrap each line to prevent mid-word breaking
                List<String> wrappedLines = _wrapText('  + ${line.trim()}', 42);
                for (String wrappedLine in wrappedLines) {
                  bytes += generator.text(wrappedLine);
                }
              }
            } else {
              // Word wrap single options to prevent mid-word breaking
              List<String> wrappedLines = _wrapText('  + $option', 42);
              for (String wrappedLine in wrappedLines) {
                bytes += generator.text(wrappedLine);
              }
            }
          }
        }
      }

      if (!_shouldExcludeField(item.comment)) {
        // Word wrap comments to prevent mid-word breaking
        List<String> wrappedLines = _wrapText('  Note: ${item.comment}', 42);
        for (String wrappedLine in wrappedLines) {
          bytes += generator.text(wrappedLine);
        }
      }
      bytes += generator.emptyLines(1);
    }

    bytes += generator.text('------------------------------------------------');

    // Show delivery charges for delivery orders before subtotal
    if (orderType.toLowerCase() == 'delivery' &&
        deliveryCharge != null &&
        deliveryCharge > 0) {
      String deliveryChargeText =
          isXprinterUSB
              ? '${deliveryCharge.toStringAsFixed(2)}'
              : '${deliveryCharge.toStringAsFixed(2)}';
      bytes += generator.row([
        PosColumn(
          text: 'Delivery Charges:',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: deliveryChargeText,
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    String subtotalText =
        isXprinterUSB
            ? '${subtotal.toStringAsFixed(2)}'
            : '${subtotal.toStringAsFixed(2)}';
    bytes += generator.row([
      PosColumn(
        text: 'Subtotal:',
        width: 8,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: subtotalText,
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Bold total amount
    String totalText =
        isXprinterUSB
            ? 'GBP ${totalCharge.toStringAsFixed(2)}'
            : 'GBP${totalCharge.toStringAsFixed(2)}';
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL:',
        width: 8,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: totalText,
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Payment Status Section - NOT BOLD except specific elements
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'PAYMENT STATUS:',
      styles: const PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text('------------------------------------------------');

    // Bold payment method
    if (!_shouldExcludeField(paymentType)) {
      bytes += generator.text(
        'Payment Method: $paymentType',
        styles: const PosStyles(height: PosTextSize.size1, bold: true),
      );
    }

    // Simple payment status logic: only use paid_status
    String paymentStatus = (paidStatus == true) ? 'PAID' : 'UNPAID';

    // Show payment details for paid orders
    if (paymentStatus == 'PAID' &&
        paymentType != null &&
        paymentType.toLowerCase() == 'cash' &&
        changeDue > 0) {
      String amountReceivedText =
          isXprinterUSB
              ? 'GBP ${(totalCharge + changeDue).toStringAsFixed(2)}'
              : 'GBP${(totalCharge + changeDue).toStringAsFixed(2)}';
      String changeDueText =
          isXprinterUSB
              ? 'GBP ${changeDue.toStringAsFixed(2)}'
              : 'GBP${changeDue.toStringAsFixed(2)}';
      bytes += generator.row([
        PosColumn(text: 'Amount Received:', width: 9),
        PosColumn(
          text: amountReceivedText,
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Change Due:', width: 9),
        PosColumn(
          text: changeDueText,
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Bold payment status (PAID/UNPAID)
    bytes += generator.text(
      'Status: $paymentStatus',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Thank you for your order!',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text(
      '================================================',
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
      throw Exception(
        'Printing is not supported on web platform. Please use a mobile or desktop app.',
      );
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

      Future<String> reportContentFuture = Future.value(
        _generateSalesReportContent(
          reportType: reportType,
          reportData: reportData,
          filters: filters,
          selectedDate: selectedDate,
          selectedYear: selectedYear,
          selectedWeek: selectedWeek,
          selectedMonth: selectedMonth,
        ),
      );

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
      if (connectionStatus['bluetooth'] == true)
        availableMethods.add('Thermal Bluetooth');

      if (availableMethods.isEmpty) {
        print('❌ No printer connections available');
        String errorMessage = 'No thermal printers detected. Please ensure:\n';
        errorMessage +=
            '• A thermal printer is connected via USB or Bluetooth\n';
        errorMessage += '• The printer is powered on\n';
        errorMessage +=
            '• For Bluetooth: The printer is paired with this device\n';
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
        throw Exception(
          'Printing failed on all available methods. Last error: $lastError',
        );
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
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux)) {
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

    // Try Xprinter SDK first if enabled and connected
    if (_useXprinterSDK && Platform.isAndroid && _xprinterService.isConnected) {
      try {
        print('🎯 Using Xprinter SDK for USB sales report printing...');
        String reportString = String.fromCharCodes(reportData);

        // Apply comprehensive encoding fixes for Xprinter
        String fixedReportString = _applyXprinterEncodingFixes(reportString);

        bool success = await _xprinterService.printReceipt(fixedReportString);

        if (success) {
          print(
            '✅ Xprinter SDK USB sales report printing successful with encoding fixes',
          );
          return true;
        } else {
          print(
            '⚠️ Xprinter SDK sales report printing failed, falling back to legacy method',
          );
        }
      } catch (e) {
        print(
          '⚠️ Xprinter SDK sales report printing error, falling back to legacy method: $e',
        );
      }
    }

    try {
      // Ensure we have a persistent connection
      if (_persistentUsbPort == null) {
        if (_cachedUsbDevices.isEmpty) {
          _cachedUsbDevices = await UsbSerial.listDevices();
        }
        if (_cachedUsbDevices.isEmpty) {
          throw Exception(
            'No USB devices found. Please connect a USB thermal printer.',
          );
        }

        if (!await _establishUSBConnection(_cachedUsbDevices.first)) {
          throw Exception(
            'Failed to establish USB connection. Please check printer connection.',
          );
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
      print(
        reportContent.substring(0, math.min(300, reportContent.length)) + '...',
      );
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
          throw Exception(
            'Failed to establish Bluetooth connection. Please check if printer is paired and turned on.',
          );
        }
      }

      // Verify connection is still active
      bool isStillConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isStillConnected) {
        throw Exception(
          'Bluetooth printer is not connected. Please check printer status.',
        );
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
    report.writeln('             TEST');
    report.writeln('================================');
    report.writeln();

    // Report Title and Date
    report.writeln(reportType.toUpperCase());
    report.writeln('--------------------------------');

    // Period information
    String periodText = _getPeriodText(
      reportData,
      reportType,
      selectedDate,
      selectedYear,
      selectedWeek,
      selectedMonth,
    );
    report.writeln('Period: $periodText');
    report.writeln(
      'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(UKTimeService.now())}',
    );
    report.writeln('================================');
    report.writeln();

    // Applied Filters
    if (filters['source'] != 'All' ||
        filters['payment'] != 'All' ||
        filters['orderType'] != 'All') {
      report.writeln('APPLIED FILTERS:');
      report.writeln('--------------------------------');
      if (filters['source'] != 'All')
        report.writeln('Source: ${filters['source']}');
      if (filters['payment'] != 'All')
        report.writeln('Payment: ${filters['payment']}');
      if (filters['orderType'] != 'All')
        report.writeln('Order Type: ${filters['orderType']}');
      report.writeln('================================');
      report.writeln();
    }

    // Summary Section
    report.writeln('SUMMARY:');
    report.writeln('--------------------------------');

    // Total Sales Amount
    final totalSales =
        reportData['total_sales'] ?? reportData['total_sales_amount'];
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
        'Sales ${isPositive ? 'Increase' : 'Decrease'}: ${isPositive ? '+' : ''}${_formatCurrency(salesIncrease)}',
      );
    }

    // Most Sold Item
    final mostSoldItem =
        reportData['most_selling_item'] ?? reportData['most_sold_item'];
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
          final type =
              payment['payment_type']?.toString().toUpperCase() ?? 'UNKNOWN';
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
          final type =
              orderType['order_type']?.toString().toUpperCase() ?? 'UNKNOWN';
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
          final sourceName =
              source['source']?.toString().toUpperCase() ?? 'UNKNOWN';
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
    final generator = Generator(
      PaperSize.mm80,
      profile,
    ); // 80mm paper width // 80mm paper
    List<int> bytes = [];

    // Initialize printer first to clear any previous state/corrupted data
    bytes += generator.reset();

    bytes += generator.setGlobalCodeTable('CP1252');

    // Header
    bytes += generator.text(
      'Dallas',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size3,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Report Title and Date
    bytes += generator.text(
      reportType.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text('------------------------------------------------');

    // Period information
    String periodText = _getPeriodText(
      reportData,
      reportType,
      selectedDate,
      selectedYear,
      selectedWeek,
      selectedMonth,
    );
    bytes += generator.text('Period: $periodText');
    bytes += generator.text(
      'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(UKTimeService.now())}',
    );
    bytes += generator.text(
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Applied Filters
    if (filters['source'] != 'All' ||
        filters['payment'] != 'All' ||
        filters['orderType'] != 'All') {
      bytes += generator.text(
        'APPLIED FILTERS:',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        '------------------------------------------------',
      );
      if (filters['source'] != 'All')
        bytes += generator.text('Source: ${filters['source']}');
      if (filters['payment'] != 'All')
        bytes += generator.text('Payment: ${filters['payment']}');
      if (filters['orderType'] != 'All')
        bytes += generator.text('Order Type: ${filters['orderType']}');
      bytes += generator.text(
        '================================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Summary Section
    bytes += generator.text(
      'SUMMARY:',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text('------------------------------------------------');

    // Total Sales Amount
    final totalSales =
        reportData['total_sales'] ?? reportData['total_sales_amount'];
    bytes += generator.row([
      PosColumn(text: 'Total Sales:', width: 9),
      PosColumn(
        text: _formatCurrency(totalSales),
        width: 3,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    // Total Orders Placed
    if (reportData['total_orders_placed'] != null) {
      bytes += generator.row([
        PosColumn(text: 'Total Orders:', width: 9),
        PosColumn(
          text: '${reportData['total_orders_placed']}',
          width: 3,
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
          text: 'Sales ${isPositive ? 'Increase' : 'Decrease'}:',
          width: 9,
        ),
        PosColumn(
          text: '${isPositive ? '+' : ''}${_formatCurrency(salesIncrease)}',
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Most Sold Item
    final mostSoldItem =
        reportData['most_selling_item'] ?? reportData['most_sold_item'];
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
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // Sales by Payment Method
    final paymentTypes = reportData['sales_by_payment_type'] as List<dynamic>?;
    if (paymentTypes != null && paymentTypes.isNotEmpty) {
      bytes += generator.text(
        'SALES BY PAYMENT METHOD:',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );
      bytes += generator.text(
        '------------------------------------------------',
      );
      for (var payment in paymentTypes) {
        if (payment is Map) {
          final type =
              payment['payment_type']?.toString().toUpperCase() ?? 'UNKNOWN';
          final count = payment['count']?.toString() ?? '0';
          final total = _formatCurrency(payment['total']);
          bytes += generator.text(
            '$type:',
            styles: const PosStyles(bold: true),
          );
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 9),
            PosColumn(
              text: count,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 9),
            PosColumn(
              text: total,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Sales by Order Type
    final orderTypes = reportData['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes != null && orderTypes.isNotEmpty) {
      bytes += generator.text(
        'SALES BY ORDER TYPE:',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );
      bytes += generator.text(
        '------------------------------------------------',
      );
      for (var orderType in orderTypes) {
        if (orderType is Map) {
          final type =
              orderType['order_type']?.toString().toUpperCase() ?? 'UNKNOWN';
          final count = orderType['count']?.toString() ?? '0';
          final total = _formatCurrency(orderType['total']);
          bytes += generator.text(
            '$type:',
            styles: const PosStyles(bold: true),
          );
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 9),
            PosColumn(
              text: count,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 9),
            PosColumn(
              text: total,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================================',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
    }

    // Sales by Order Source
    final orderSources = reportData['sales_by_order_source'] as List<dynamic>?;
    if (orderSources != null && orderSources.isNotEmpty) {
      bytes += generator.text(
        'SALES BY ORDER SOURCE:',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );
      bytes += generator.text(
        '------------------------------------------------',
      );
      for (var source in orderSources) {
        if (source is Map) {
          final sourceName =
              source['source']?.toString().toUpperCase() ?? 'UNKNOWN';
          final count = source['count']?.toString() ?? '0';
          final total = _formatCurrency(source['total']);
          bytes += generator.text(
            '$sourceName:',
            styles: const PosStyles(bold: true),
          );
          bytes += generator.row([
            PosColumn(text: '  Orders:', width: 9),
            PosColumn(
              text: count,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: '  Amount:', width: 9),
            PosColumn(
              text: total,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.text(
        '================================================',
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
      '================================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.emptyLines(3);
    bytes += generator.cut();

    return bytes;
  }

  // Helper method to get period text
  String _getPeriodText(
    Map<String, dynamic> reportData,
    String reportType,
    String? selectedDate,
    int? selectedYear,
    int? selectedWeek,
    int? selectedMonth,
  ) {
    switch (reportType) {
      case "Today's Report":
        return DateFormat('dd/MM/yyyy').format(UKTimeService.now());
      case 'Daily Report':
        return selectedDate ??
            DateFormat('dd/MM/yyyy').format(UKTimeService.now());
      case 'Weekly Report':
        return 'Year: ${selectedYear ?? DateTime.now().year}, Week: ${selectedWeek ?? _getWeekNumber(UKTimeService.now())}';
      case 'Monthly Report':
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final monthName = months[(selectedMonth ?? DateTime.now().month) - 1];
        return 'Year: ${selectedYear ?? DateTime.now().year}, Month: $monthName';
      case 'Drivers Report':
        return selectedDate ??
            DateFormat('dd/MM/yyyy').format(UKTimeService.now());
      default:
        final period = reportData['period'];
        if (period != null && period is Map) {
          return '${period['from']} ~ ${period['to']}';
        }
        return DateFormat('dd/MM/yyyy').format(UKTimeService.now());
    }
  }

  // Helper method to format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '${value.toStringAsFixed(2)}';
  }

  // Helper method to get week number
  static int _getWeekNumber(DateTime date) {
    int dayOfYear =
        int.parse(
          date.difference(DateTime(date.year, 1, 1)).inDays.toString(),
        ) +
        1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  String _applyXprinterEncodingFixes(String content) {
    print(
      '🔧 Applying Xprinter-specific character encoding fixes based on manual...',
    );

    String fixedContent = content;

    // Based on Xprinter manual - using CP437 (Code Page 0) as default
    // Manual shows support for multiple code pages with CP437 as standard
    final Map<String, String> encodingFixes = {
      // Currency symbols - CRITICAL for your pound sign issue
      // From manual: CP437 character set mappings
      '£': '\u009C', // CP437 code 156 for pound sign - direct hex escape
      '€': String.fromCharCode(0xEE), // Code 238 in CP437 - Euro sign
      '¥': String.fromCharCode(0x9D), // Code 157 in CP437 - Yen sign
      '¢': String.fromCharCode(0x9B), // Code 155 in CP437 - Cent sign
      '\$': String.fromCharCode(0x24), // Code 36 - Dollar sign
      // Manual shows extensive character support - adding problematic ones
      '°': String.fromCharCode(0xF8), // Code 248 - Degree symbol
      '·': String.fromCharCode(0xFA), // Code 250 - Middle dot
      '×': String.fromCharCode(0x78), // Code 120 - 'x' for multiplication
      '÷': String.fromCharCode(0xF6), // Code 246 - Division sign
      // Accented characters from manual's character set
      'á': String.fromCharCode(0xA0), // Code 160
      'é': String.fromCharCode(0x82), // Code 130
      'í': String.fromCharCode(0xA1), // Code 161
      'ó': String.fromCharCode(0xA2), // Code 162
      'ú': String.fromCharCode(0xA3), // Code 163
      'ñ': String.fromCharCode(0xA4), // Code 164
      // Quote marks - ensure standard ASCII
      '"': String.fromCharCode(
        0x22,
      ), // Left double quotation mark (U+201C) -> standard quote
      ''': String.fromCharCode(0x27), // Left single quotation mark (U+2018) -> apostrophe
''': String.fromCharCode(
        0x27,
      ), // Right single quotation mark (U+2019) -> apostrophe
    };

    // Apply all encoding fixes
    encodingFixes.forEach((unicode, encoded) {
      if (fixedContent.contains(unicode)) {
        print(
          '   Fixing character: $unicode -> CP437 code ${encoded.codeUnits[0]}',
        );
        fixedContent = fixedContent.replaceAll(unicode, encoded);
      }
    });

    // Additional pound sign fix for stubborn cases
    if (fixedContent.contains('£')) {
      print(
        '🔥 CRITICAL: Found remaining £ symbols, applying emergency fix...',
      );
      // Convert to bytes, replace pound sign bytes, convert back
      List<int> bytes = fixedContent.codeUnits;
      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i] == 0xC2 && i + 1 < bytes.length && bytes[i + 1] == 0xA3) {
          // UTF-8 encoding of £ (0xC2 0xA3) -> CP437 (0x9C)
          bytes[i] = 0x9C;
          bytes.removeAt(i + 1);
          print('   Emergency fix: UTF-8 £ (0xC2A3) -> CP437 (0x9C)');
        } else if (bytes[i] == 0xA3) {
          // Latin-1 encoding of £ (0xA3) -> CP437 (0x9C)
          bytes[i] = 0x9C;
          print('   Emergency fix: Latin-1 £ (0xA3) -> CP437 (0x9C)');
        }
      }
      fixedContent = String.fromCharCodes(bytes);
    }

    // Apply line formatting fixes based on manual's 72mm paper width (42 characters)
    fixedContent = _fixXprinterLineFormatting(fixedContent);

    print('✅ Xprinter manual-based encoding fixes applied');
    return fixedContent;
  }

  String _fixXprinterLineFormatting(String content) {
    print(
      '🔧 Fixing Xprinter line formatting for 72mm paper width (42 characters)...',
    );

    List<String> lines = content.split('\n');
    List<String> fixedLines = [];

    for (String line in lines) {
      // Fix item lines with quantity, name, and price
      if (line.contains('x ') &&
          line.contains('£') &&
          !line.contains('Order #:')) {
        // Extract components: "1x SHAWARMA BURGER                     £25.49"
        RegExp itemPattern = RegExp(r'(\d+x\s+)(.+?)\s*(£[\d.]+)$');
        Match? match = itemPattern.firstMatch(line.trim());

        if (match != null) {
          String quantity = match.group(1)!; // "1x "
          String itemName = match.group(2)!.trim(); // "SHAWARMA BURGER"
          String price = match.group(3)!; // "£25.49"

          // Create properly formatted line for 42-character width (72mm paper as per manual)
          // Format: "1x ITEM_NAME                £PRICE"
          String quantityAndName = '$quantity$itemName';
          int totalWidth = 42; // Based on manual's 72mm paper width
          int nameLength = quantityAndName.length;
          int priceLength = price.length;
          int paddingNeeded = totalWidth - nameLength - priceLength;

          if (paddingNeeded < 1) paddingNeeded = 1; // Minimum 1 space

          String formattedLine = '$quantityAndName${' ' * paddingNeeded}$price';
          fixedLines.add(formattedLine);
          print('   Fixed item line: "$line" -> "$formattedLine"');
        } else {
          fixedLines.add(line);
        }
      }
      // Fix total lines alignment
      else if (line.contains('TOTAL:') && line.contains('£')) {
        RegExp totalPattern = RegExp(r'(TOTAL:\s*)(£[\d.]+)');
        Match? match = totalPattern.firstMatch(line.trim());

        if (match != null) {
          String totalLabel = 'TOTAL:';
          String amount = match.group(2)!;

          int totalWidth = 42;
          int labelLength = totalLabel.length;
          int amountLength = amount.length;
          int paddingNeeded = totalWidth - labelLength - amountLength;

          if (paddingNeeded < 1) paddingNeeded = 1;

          String formattedLine = '$totalLabel${' ' * paddingNeeded}$amount';
          fixedLines.add(formattedLine);
          print('   Fixed total line: "$line" -> "$formattedLine"');
        } else {
          fixedLines.add(line);
        }
      }
      // Fix subtotal lines
      else if (line.contains('Subtotal:') && line.contains('£')) {
        RegExp subtotalPattern = RegExp(r'(Subtotal:\s*)(£[\d.]+)');
        Match? match = subtotalPattern.firstMatch(line.trim());

        if (match != null) {
          String label = 'Subtotal:';
          String amount = match.group(2)!;

          int totalWidth = 42;
          int labelLength = label.length;
          int amountLength = amount.length;
          int paddingNeeded = totalWidth - labelLength - amountLength;

          if (paddingNeeded < 1) paddingNeeded = 1;

          String formattedLine = '$label${' ' * paddingNeeded}$amount';
          fixedLines.add(formattedLine);
        } else {
          fixedLines.add(line);
        }
      }
      // Fix delivery charges lines
      else if (line.contains('Delivery Charges:') && line.contains('£')) {
        RegExp deliveryPattern = RegExp(r'(Delivery Charges:\s*)(£[\d.]+)');
        Match? match = deliveryPattern.firstMatch(line.trim());

        if (match != null) {
          String label = 'Delivery Charges:';
          String amount = match.group(2)!;

          int totalWidth = 42;
          int labelLength = label.length;
          int amountLength = amount.length;
          int paddingNeeded = totalWidth - labelLength - amountLength;

          if (paddingNeeded < 1) paddingNeeded = 1;

          String formattedLine = '$label${' ' * paddingNeeded}$amount';
          fixedLines.add(formattedLine);
        } else {
          fixedLines.add(line);
        }
      } else {
        // Keep other lines as-is
        fixedLines.add(line);
      }
    }

    String result = fixedLines.join('\n');
    print('✅ Line formatting fixes applied for 72mm paper width');
    return result;
  }
}
