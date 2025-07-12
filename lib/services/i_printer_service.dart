// lib/services/i_printer_service.dart
import 'package:epos/models/printer_device.dart'; // Make sure this path is correct

abstract class IPrinterService {
  // Stream for broadcasting discovered printers
  Stream<List<PrinterDevice>> get onScanResult;
  // Stream for broadcasting connection status changes
  Stream<String> get onConnectionStatusChanged; // e.g., 'Connected', 'Disconnected', 'Scanning', 'Error'

  PrinterDevice? get connectedDevice; // Get the currently connected device

  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> connect(PrinterDevice device);
  Future<void> disconnect();
  Future<bool> printReceipt(List<int> bytes); // For raw bytes (ESC/POS)

  void dispose();
}