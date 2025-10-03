import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/services/xprinter_service.dart';

class XprinterTestScreen extends StatefulWidget {
  const XprinterTestScreen({super.key});

  @override
  State<XprinterTestScreen> createState() => _XprinterTestScreenState();
}

class _XprinterTestScreenState extends State<XprinterTestScreen> {
  final XprinterService _xprinterService = XprinterService();
  List<Map<String, dynamic>> _usbDevices = [];
  String? _connectedDevice;
  bool _isConnected = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  void _addLog(String message) {
    setState(() {
      _log += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
    print(message);
  }

  Future<void> _refreshDevices() async {
    try {
      _addLog('🔍 Searching for USB devices...');
      final devices = await _xprinterService.getUsbDevices();
      setState(() {
        _usbDevices = devices;
        _isConnected = _xprinterService.isConnected;
        _connectedDevice = _xprinterService.connectedDevice;
      });
      _addLog('📱 Found ${devices.length} USB devices');
      
      for (var device in devices) {
        _addLog('   - ${device['deviceName']} (VID: ${device['vendorId']}, PID: ${device['productId']})');
      }
    } catch (e) {
      _addLog('❌ Error getting USB devices: $e');
    }
  }

  Future<void> _connectToDevice(String devicePath) async {
    try {
      _addLog('🔗 Connecting to $devicePath...');
      bool success = await _xprinterService.connectUsb(devicePath);
      
      setState(() {
        _isConnected = success;
        _connectedDevice = success ? devicePath : null;
      });
      
      if (success) {
        _addLog('✅ Connected successfully to $devicePath');
      } else {
        _addLog('❌ Failed to connect to $devicePath');
      }
    } catch (e) {
      _addLog('❌ Connection error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      _addLog('🔌 Disconnecting...');
      bool success = await _xprinterService.disconnect();
      
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
      });
      
      if (success) {
        _addLog('✅ Disconnected successfully');
      } else {
        _addLog('❌ Disconnect failed');
      }
    } catch (e) {
      _addLog('❌ Disconnect error: $e');
    }
  }

  Future<void> _testPrint() async {
    if (!_isConnected) {
      _addLog('❌ Not connected to printer');
      return;
    }

    try {
      _addLog('🖨️ Testing print functionality...');
      
      String testReceipt = 'XPRINTER TEST\n' +
          '================\n' +
          'Date: ${DateTime.now()}\n' +
          'Order: TEST-001\n' +
          '----------------\n' +
          'Test Item 1  £10.00\n' +
          'Test Item 2   £5.50\n' +
          '----------------\n' +
          'TOTAL:       £15.50\n' +
          '----------------\n' +
          'Thank you!\n' +
          '================\n\n\n';

      bool success = await _xprinterService.printReceipt(testReceipt);
      
      if (success) {
        _addLog('✅ Test print completed successfully');
      } else {
        _addLog('❌ Test print failed');
      }
    } catch (e) {
      _addLog('❌ Print error: $e');
    }
  }

  Future<void> _testCashDrawer() async {
    if (!_isConnected) {
      _addLog('❌ Not connected to printer');
      return;
    }

    try {
      _addLog('💰 Testing cash drawer...');
      bool success = await _xprinterService.openCashBox();
      
      if (success) {
        _addLog('✅ Cash drawer opened successfully');
      } else {
        _addLog('❌ Cash drawer failed to open');
      }
    } catch (e) {
      _addLog('❌ Cash drawer error: $e');
    }
  }

  Future<void> _checkStatus() async {
    if (!_isConnected) {
      _addLog('❌ Not connected to printer');
      return;
    }

    try {
      _addLog('📊 Checking printer status...');
      final status = await _xprinterService.getPrinterStatus();
      
      if (status != null) {
        _addLog('✅ Status: Connected=${status['connected']}, Code=${status['statusCode']}');
      } else {
        _addLog('❌ Failed to get printer status');
      }
    } catch (e) {
      _addLog('❌ Status check error: $e');
    }
  }

  void _clearLog() {
    setState(() {
      _log = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xprinter SDK Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearLog,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Log',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Status
            Card(
              color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.error,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected 
                            ? 'Connected to: $_connectedDevice' 
                            : 'Not connected',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Control buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _refreshDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Devices'),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _disconnect : null,
                  icon: const Icon(Icons.power_off),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _testPrint : null,
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _testCashDrawer : null,
                  icon: const Icon(Icons.payment),
                  label: const Text('Open Drawer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _checkStatus : null,
                  icon: const Icon(Icons.info),
                  label: const Text('Check Status'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // USB Devices List
            if (_usbDevices.isNotEmpty) ...[
              Text(
                'Available USB Devices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                child: ListView.builder(
                  itemCount: _usbDevices.length,
                  itemBuilder: (context, index) {
                    final device = _usbDevices[index];
                    final devicePath = device['deviceName'] as String;
                    final isConnectedDevice = devicePath == _connectedDevice;
                    
                    return Card(
                      color: isConnectedDevice ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.usb,
                          color: isConnectedDevice ? Colors.blue : Colors.grey,
                        ),
                        title: Text(devicePath),
                        subtitle: Text(
                          'VID: ${device['vendorId']} PID: ${device['productId']}\n'
                          '${device['manufacturerName'] ?? 'Unknown'} - ${device['productName'] ?? 'Unknown'}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: isConnectedDevice || _isConnected
                            ? null
                            : () => _connectToDevice(devicePath),
                          child: Text(
                            isConnectedDevice ? 'Connected' : 'Connect',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnectedDevice ? Colors.blue : null,
                            foregroundColor: isConnectedDevice ? Colors.white : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Log area
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Log',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: SingleChildScrollView(
                            child: Text(
                              _log.isEmpty ? 'No activity yet...' : _log,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}