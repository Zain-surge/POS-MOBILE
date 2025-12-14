import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service class for Xprinter SDK integration
class XprinterService {
  static const MethodChannel _channel = MethodChannel('xprinter_sdk');

  static final XprinterService _instance = XprinterService._internal();
  factory XprinterService() => _instance;
  XprinterService._internal();

  bool _isConnected = false;
  String? _connectedDevice;

  /// Get list of available USB devices
  ///
  Future<List<Map<String, dynamic>>> getUsbDevices() async {
    try {
      if (kDebugMode) {
        print('🔍 XprinterService: Getting USB devices...');
      }

      final List<dynamic> devices = await _channel.invokeMethod(
        'getUsbDevices',
      );
      final List<Map<String, dynamic>> usbDevices =
          devices.map((device) => Map<String, dynamic>.from(device)).toList();

      if (kDebugMode) {
        print('📱 XprinterService: Found ${usbDevices.length} USB devices');
        for (var device in usbDevices) {
          print(
            '   - ${device['deviceName']} (Path: ${device['devicePath']}, VID: ${device['vendorId']}, PID: ${device['productId']})',
          );
        }
      }

      return usbDevices;
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error getting USB devices: $e');
      }
      rethrow;
    }
  }

  /// Connect to USB printer
  Future<bool> connectUsb(String devicePath) async {
    try {
      if (kDebugMode) {
        print('🔗 XprinterService: Connecting to USB device: $devicePath');
      }

      final bool connected = await _channel.invokeMethod('connectUsb', {
        'devicePath': devicePath,
      });

      if (connected) {
        _isConnected = true;
        _connectedDevice = devicePath;
        if (kDebugMode) {
          print('✅ XprinterService: Successfully connected to USB printer');
        }
      } else {
        if (kDebugMode) {
          print('❌ XprinterService: Failed to connect to USB printer');
        }
      }

      return connected;
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error connecting USB printer: $e');
      }
      return false;
    }
  }

  /// Disconnect from printer
  Future<bool> disconnect() async {
    try {
      if (kDebugMode) {
        print('🔌 XprinterService: Disconnecting from printer...');
      }

      final bool disconnected = await _channel.invokeMethod('disconnect');

      if (disconnected) {
        _isConnected = false;
        _connectedDevice = null;
        if (kDebugMode) {
          print('✅ XprinterService: Successfully disconnected');
        }
      }

      return disconnected;
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error disconnecting: $e');
      }
      return false;
    }
  }

  /// Print receipt data
  Future<bool> printReceipt(String receiptData) async {
    try {
      if (!_isConnected) {
        throw Exception('Printer not connected');
      }

      if (kDebugMode) {
        print('🖨️ XprinterService: Printing receipt...');
      }

      final bool printed = await _channel.invokeMethod('printReceipt', {
        'receiptData': receiptData,
      });

      if (kDebugMode) {
        if (printed) {
          print('✅ XprinterService: Receipt printed successfully');
        } else {
          print('❌ XprinterService: Failed to print receipt');
        }
      }

      return printed;
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error printing receipt: $e');
      }
      return false;
    }
  }

  /// Open cash drawer
  Future<bool> openCashBox({
    int pinNum = 0, // 0=PIN_TWO, 1=PIN_FIVE
    int onTime = 30,
    int offTime = 255,
  }) async {
    try {
      if (!_isConnected) {
        throw Exception('Printer not connected');
      }

      final bool opened = await _channel.invokeMethod('openCashBox', {
        'pinNum': pinNum,
        'onTime': onTime,
        'offTime': offTime,
      });

      if (kDebugMode) {
        if (opened) {
          print('💰 XprinterService: Cash box opened successfully');
        } else {
          print('❌ XprinterService: Failed to open cash box');
        }
      }

      return opened;
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error opening cash box: $e');
      }
      return false;
    }
  }

  /// Get printer status
  Future<Map<String, dynamic>?> getPrinterStatus() async {
    try {
      if (!_isConnected) {
        return {'connected': false, 'statusCode': -1};
      }

      final Map<dynamic, dynamic> status = await _channel.invokeMethod(
        'printerStatus',
      );
      return Map<String, dynamic>.from(status);
    } catch (e) {
      if (kDebugMode) {
        print('❌ XprinterService: Error getting printer status: $e');
      }
      return null;
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get connectedDevice => _connectedDevice;

  /// Apply Xprinter-specific character encoding fixes for proper display
  /// This ensures pound signs and other special characters display correctly
}
