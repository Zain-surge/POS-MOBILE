import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int initialBottomNavItemIndex;

  const SettingsScreen({
    Key? key,
    this.initialBottomNavItemIndex = 5,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _selectedBottomNavItem;

  // Settings states
  bool _bluetoothEnabled = false;
  bool _wifiEnabled = false;
  bool _autoOpenCashDrawer = false;
  bool _printReceipt3x = false;
  bool _showDeliveryMenu = false;
  bool _mediaVolume = false;
  bool _keyboard = false;

  // Bluetooth related
  List<BluetoothDevice> _availableDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Check if Bluetooth is enabled
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      setState(() {
        _bluetoothEnabled = isEnabled ?? false;
      });

      // Get connected devices
      if (_bluetoothEnabled) {
        _getConnectedDevices();
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _getConnectedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _availableDevices = devices;
      });
    } catch (e) {
      print('Error getting connected devices: $e');
    }
  }

  Future<void> _toggleBluetooth(bool value) async {
    try {
      // Request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetooth] != PermissionStatus.granted) {
        _showPermissionDialog();
        return;
      }

      if (value) {
        bool? result = await FlutterBluetoothSerial.instance.requestEnable();
        if (result == true) {
          setState(() {
            _bluetoothEnabled = true;
          });
          _startDeviceDiscovery();
        }
      } else {
        await FlutterBluetoothSerial.instance.requestDisable();
        setState(() {
          _bluetoothEnabled = false;
          _availableDevices.clear();
          _connectedDevice = null;
        });
      }
    } catch (e) {
      print('Error toggling Bluetooth: $e');
      _showErrorDialog('Failed to toggle Bluetooth: $e');
    }
  }

  Future<void> _startDeviceDiscovery() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _availableDevices.clear();
    });

    try {
      // Get bonded devices first
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _availableDevices.addAll(bondedDevices);
      });

      // Start discovery for new devices
      FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        setState(() {
          if (!_availableDevices.any((device) => device.address == result.device.address)) {
            _availableDevices.add(result.device);
          }
        });
      }).onDone(() {
        setState(() {
          _isScanning = false;
        });
      });
    } catch (e) {
      print('Error during device discovery: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name ?? device.address}'),
          backgroundColor: Colors.green,
        ),
      );

      // Store connection for later use
      // You might want to save this connection in a provider or service

    } catch (e) {
      print('Error connecting to device: $e');
      setState(() {
        _isConnecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.name ?? device.address}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text('Bluetooth permissions are required to use this feature. Please enable them in settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showBluetoothDevices() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bluetooth Devices'),
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: _availableDevices.isEmpty
                    ? const Center(
                  child: Text('No devices found. Make sure Bluetooth is enabled.'),
                )
                    : ListView.builder(
                  itemCount: _availableDevices.length,
                  itemBuilder: (context, index) {
                    final device = _availableDevices[index];
                    final isConnected = _connectedDevice?.address == device.address;

                    return ListTile(
                      leading: Icon(
                        Icons.bluetooth,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.address),
                      trailing: isConnected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : _isConnecting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : IconButton(
                        icon: const Icon(Icons.connect_without_contact),
                        onPressed: () => _connectToDevice(device),
                      ),
                      onTap: isConnected ? null : () => _connectToDevice(device),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!_isScanning) {
                      _startDeviceDiscovery();
                    }
                  },
                  child: Text(_isScanning ? 'Scanning...' : 'Refresh'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Transform.scale(
              scale: 1.3,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.yellow,
                activeTrackColor: Colors.purple.shade300,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade300,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Menu icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Toggle switches (decorative, matching the image)
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.0,
                        child: Switch(
                          value: false,
                          onChanged: null,
                          activeColor: Colors.yellow,
                          inactiveThumbColor: Colors.grey.shade400,
                          inactiveTrackColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 1.0,
                        child: Switch(
                          value: true,
                          onChanged: null,
                          activeColor: Colors.yellow,
                          activeTrackColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Settings List
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSettingItem(
                      title: 'Bluetooth',
                      value: _bluetoothEnabled,
                      onChanged: _toggleBluetooth,
                      onTap: _bluetoothEnabled ? _showBluetoothDevices : null,
                    ),
                    _buildSettingItem(
                      title: 'Wi-fi',
                      value: _wifiEnabled,
                      onChanged: (value) {
                        setState(() {
                          _wifiEnabled = value;
                        });
                        // Add Wi-Fi logic here
                      },
                    ),
                    _buildSettingItem(
                      title: 'Auto open cash drawer',
                      value: _autoOpenCashDrawer,
                      onChanged: (value) {
                        setState(() {
                          _autoOpenCashDrawer = value;
                        });
                      },
                    ),
                    _buildSettingItem(
                      title: 'Print receipt 3x',
                      value: _printReceipt3x,
                      onChanged: (value) {
                        setState(() {
                          _printReceipt3x = value;
                        });
                      },
                    ),
                    _buildSettingItem(
                      title: 'Show delivery menu',
                      value: _showDeliveryMenu,
                      onChanged: (value) {
                        setState(() {
                          _showDeliveryMenu = value;
                        });
                      },
                    ),
                    _buildSettingItem(
                      title: 'Media volume',
                      value: _mediaVolume,
                      onChanged: (value) {
                        setState(() {
                          _mediaVolume = value;
                        });
                      },
                    ),
                    _buildSettingItem(
                      title: 'Keyboard',
                      value: _keyboard,
                      onChanged: (value) {
                        setState(() {
                          _keyboard = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey,
        ),
        Container(
          height: 90,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Nav Item 0: Takeaway Orders
              BottomNavItem(
                image: 'TakeAway.png',
                index: 0,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 0;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'takeaway',
                          initialBottomNavItemIndex: 0,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 1: Dine-In Orders
              BottomNavItem(
                image: 'DineIn.png',
                index: 1,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 1;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'dinein',
                          initialBottomNavItemIndex: 1,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 2: Delivery Orders
              BottomNavItem(
                image: 'Delivery.png',
                index: 2,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 2;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'delivery',
                          initialBottomNavItemIndex: 2,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 3: Website Orders
              BottomNavItem(
                image: 'web.png',
                index: 3,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 3;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => WebsiteOrdersScreen(
                          initialBottomNavItemIndex: 3,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 4: Home
              BottomNavItem(
                image: 'home.png',
                index: 4,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 4;
                    Navigator.pushReplacementNamed(context, '/service-selection');
                  });
                },
              ),
              // Nav Item 5: More (Current Screen)
              BottomNavItem(
                image: 'More.png',
                index: 5,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 5;
                    // Already on Settings screen, no navigation needed
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}