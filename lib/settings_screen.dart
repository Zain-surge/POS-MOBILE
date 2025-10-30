// lib/settings_screen.dart (Updated with Driver Settings)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'admin_portal_screen.dart';
import 'package:epos/services/custom_popup_service.dart';
import 'edit_items_screen.dart';
import 'order_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int initialBottomNavItemIndex;

  const SettingsScreen({Key? key, this.initialBottomNavItemIndex = 5})
    : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _selectedBottomNavItem;

  // Settings states
  bool _bluetoothEnabled = false;
  bool _shopOpen = false;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingOffers = false;
  // Shop timings
  String _shopOpenTime = "09:00";
  String _shopCloseTime = "21:00";
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    _initializeBluetooth();
    _loadShopStatus();
    _loadOffers();
  }

  Future<void> _loadShopStatus() async {
    try {
      final shopStatus = await ApiService.getShopStatus();
      setState(() {
        _shopOpen = shopStatus['shop_open'] ?? false;
        _shopOpenTime = shopStatus['shop_open_time'] ?? "09:00:00";
        _shopCloseTime = shopStatus['shop_close_time'] ?? "21:00:00";

        // Remove seconds from time format if present
        if (_shopOpenTime.length > 5) {
          _shopOpenTime = _shopOpenTime.substring(0, 5);
        }
        if (_shopCloseTime.length > 5) {
          _shopCloseTime = _shopCloseTime.substring(0, 5);
        }
      });
    } catch (e) {
      print('Error loading shop status: $e');
      CustomPopupService.show(
        context,
        'Failed to load Shop status',
        type: PopupType.failure,
      );
    }
  }

  Future<void> _toggleShopStatus(bool value) async {
    // Optimistic update
    setState(() {
      _shopOpen = value;
    });

    try {
      print('🏪 Attempting to toggle shop status to: $value');
      final message = await ApiService.toggleShopStatus(value);
      print('🏪 Shop status toggle successful: $message');

      CustomPopupService.show(
        context,
        message.isNotEmpty
            ? message
            : (value ? 'Shop opened successfully' : 'Shop closed successfully'),
        type: PopupType.success,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _shopOpen = !value;
      });
      print('🏪 Error toggling shop status: $e');
      CustomPopupService.show(
        context,
        'Failed to toggle shop status: $e',
        type: PopupType.failure,
      );
    }
  }

  String _formatTime(String time) {
    if (time.length == 5) {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    }
    return time;
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoadingOffers = true;
    });

    try {
      final offers = await ApiService.getOffers();
      setState(() {
        _offers = offers;
      });
    } catch (e) {
      print('Error loading offers: $e');
      CustomPopupService.show(
        context,
        'Failed to load offers',
        type: PopupType.failure,
      );
    } finally {
      setState(() {
        _isLoadingOffers = false;
      });
    }
  }

  Future<void> _updateOfferStatus(
    String offerText,
    bool value,
    StateSetter setDialogState,
  ) async {
    // Find and update the offer immediately (optimistic update)
    final offerIndex = _offers.indexWhere(
      (offer) => offer['offer_text'] == offerText,
    );
    if (offerIndex != -1) {
      final updatedOffers = List<Map<String, dynamic>>.from(_offers);
      updatedOffers[offerIndex]['value'] = value;

      // Update both main state and dialog state immediately
      setState(() {
        _offers = updatedOffers;
      });

      setDialogState(() {
        _offers = updatedOffers;
      });
    }

    try {
      final result = await ApiService.updateOfferStatus(offerText, value);

      // Update with server response if different
      if (result.containsKey('offers')) {
        final serverOffers = result['offers'].cast<Map<String, dynamic>>();
        setState(() {
          _offers = serverOffers;
        });

        setDialogState(() {
          _offers = serverOffers;
        });
      }

      String message = result['message'] ?? 'Offer status updated successfully';
      CustomPopupService.show(context, message, type: PopupType.success);
    } catch (e) {
      // Revert the optimistic update on error
      if (offerIndex != -1) {
        final revertedOffers = List<Map<String, dynamic>>.from(_offers);
        revertedOffers[offerIndex]['value'] =
            !value; // Revert to original state

        setState(() {
          _offers = revertedOffers;
        });

        setDialogState(() {
          _offers = revertedOffers;
        });
      }

      print('Error updating offer status: $e');
      CustomPopupService.show(
        context,
        'Failed to update offer status',
        type: PopupType.failure, // Failure type use karein
      );
    }
  }

  Future<void> _showOffersDialog() async {
    await _loadOffers(); // Load offers first

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Manage Offers',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child:
                    _isLoadingOffers
                        ? const Center(child: CircularProgressIndicator())
                        : _offers.isEmpty
                        ? const Center(
                          child: Text(
                            'No offers available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          itemCount: _offers.length,
                          itemBuilder: (context, index) {
                            final offer = _offers[index];
                            final isLocked = offer['locked'] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      offer['value']
                                          ? Colors.green.shade300
                                          : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          offer['offer_text'] ?? '',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isLocked
                                                    ? Colors.grey.shade600
                                                    : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          offer['value']
                                              ? 'Active'
                                              : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                offer['value']
                                                    ? Colors.green.shade700
                                                    : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isLocked)
                                    Icon(
                                      Icons.lock,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    )
                                  else
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: offer['value'] ?? false,
                                        onChanged: (value) {
                                          _updateOfferStatus(
                                            offer['offer_text'] ?? '',
                                            value,
                                            setDialogState, // Pass the dialog state setter
                                          );
                                        },
                                        activeColor: Colors.green,
                                        activeTrackColor: Colors.green.shade300,
                                        inactiveThumbColor:
                                            Colors.grey.shade400,
                                        inactiveTrackColor:
                                            Colors.grey.shade300,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTimingsDialog() async {
    TimeOfDay? openTime = TimeOfDay(
      hour: int.parse(_shopOpenTime.split(':')[0]),
      minute: int.parse(_shopOpenTime.split(':')[1]),
    );
    TimeOfDay? closeTime = TimeOfDay(
      hour: int.parse(_shopCloseTime.split(':')[0]),
      minute: int.parse(_shopCloseTime.split(':')[1]),
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: Colors.purple.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Shop Timings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    _buildTimeCard(
                      title: 'Opening Time',
                      time: openTime,
                      icon: Icons.wb_sunny,
                      color: Colors.orange,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: openTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: Colors.white,
                                  hourMinuteTextColor: Colors.black87,
                                  hourMinuteColor: Colors.orange.shade50,
                                  dialHandColor: Colors.orange,
                                  dialBackgroundColor: Colors.orange.shade50,
                                  entryModeIconColor: Colors.orange,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            openTime = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTimeCard(
                      title: 'Closing Time',
                      time: closeTime,
                      icon: Icons.nights_stay,
                      color: Colors.indigo,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: closeTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: Colors.white,
                                  hourMinuteTextColor: Colors.black87,
                                  hourMinuteColor: Colors.indigo.shade50,
                                  dialHandColor: Colors.indigo,
                                  dialBackgroundColor: Colors.indigo.shade50,
                                  entryModeIconColor: Colors.indigo,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            closeTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (openTime != null && closeTime != null) {
                      // Validate that close time is greater than open time
                      final openMinutes =
                          openTime!.hour * 60 + openTime!.minute;
                      final closeMinutes =
                          closeTime!.hour * 60 + closeTime!.minute;

                      if (closeMinutes <= openMinutes) {
                        CustomPopupService.show(
                          context,
                          "Closing time must be greater than opening time",
                          type: PopupType.failure, // Failure type use karein
                        );
                        return;
                      }

                      Navigator.of(context).pop();
                      await _updateShopTimings(openTime!, closeTime!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineItemsItem() {
    return GestureDetector(
      onTap: _showEditItemsScreen,
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
            const Text(
              'Edit Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditItemsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditItemsScreen()),
    );
  }

  Widget _buildOffersItem() {
    return GestureDetector(
      onTap: _showOffersDialog,
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
            const Text(
              'Add Offers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String title,
    required TimeOfDay? time,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time?.format(context) ?? 'Not set',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _updateShopTimings(
    TimeOfDay openTime,
    TimeOfDay closeTime,
  ) async {
    final openTimeStr =
        "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}";
    final closeTimeStr =
        "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}";

    // Optimistic update
    setState(() {
      _shopOpenTime = openTimeStr;
      _shopCloseTime = closeTimeStr;
    });

    try {
      final message = await ApiService.updateShopTimings(
        openTimeStr,
        closeTimeStr,
      );
      CustomPopupService.show(context, message, type: PopupType.success);
    } catch (e) {
      // Revert on error - reload from server
      _loadShopStatus();
      print('Error updating shop timings: $e');
      CustomPopupService.show(
        context,
        'Failed to update shop status',
        type: PopupType.failure,
      );
    }
  }

  Widget _buildTodaysSalesReportItem() {
    return GestureDetector(
      onTap: () {
        // Use named route navigation to leverage the global SalesReportProvider
        Navigator.of(context).pushNamed('/sales-report');
      },
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
            const Text(
              "Today's Sales Report",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        print("Bluetooth not supported by this device");
        return;
      }

      // Check if Bluetooth is enabled
      bool isEnabled = await FlutterBluePlus.isOn;
      if (!mounted) return;
      setState(() {
        _bluetoothEnabled = isEnabled;
      });

      // Listen to Bluetooth state changes
      _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((
        BluetoothAdapterState state,
      ) {
        if (!mounted) return;
        setState(() {
          _bluetoothEnabled = state == BluetoothAdapterState.on;
        });
      });
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _toggleBluetooth(bool value) async {
    try {
      if (value) {
        // Request permissions first
        Map<Permission, PermissionStatus> statuses =
            await [
              Permission.bluetooth,
              Permission.bluetoothConnect,
              Permission.bluetoothScan,
              Permission.location,
            ].request();

        if (statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
          _showPermissionDialog();
          return;
        }

        // Try to turn on Bluetooth
        try {
          await FlutterBluePlus.turnOn();
          if (!mounted) return;
          setState(() {
            _bluetoothEnabled = true;
          });

          CustomPopupService.show(
            context,
            'Bluetooth turned on successfully',
            type: PopupType.success,
          );
        } catch (e) {
          print('Failed to turn on Bluetooth programmatically: $e');
          _navigateToBluetoothSettings();
        }
      } else {
        // Try to turn off Bluetooth
        try {
          await FlutterBluePlus.turnOff();
          if (!mounted) return;
          setState(() {
            _bluetoothEnabled = false;
          });
          CustomPopupService.show(
            context,
            'Bluetooth turned off successfully',
            type: PopupType.success,
          );
        } catch (e) {
          print('Failed to turn off Bluetooth programmatically: $e');
          _navigateToBluetoothSettings();
        }
      }
    } catch (e) {
      print('Error toggling Bluetooth: $e');
      _navigateToBluetoothSettings();
    }
  }

  void _navigateToBluetoothSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Settings'),
          content: const Text(
            'Unable to control Bluetooth from the app. Would you like to open device settings to manage Bluetooth?',
          ),
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
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'Bluetooth permissions are required to use this feature. Please enable them in settings.',
          ),
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
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Transform.scale(
              scale: 1.3,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: Colors.green,
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

  Widget _buildAdminPortalItem() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AdminPortalScreen()),
        );
      },
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
            const Text(
              'Admin Portal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.red.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Protected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistoryItem() {
    return GestureDetector(
      onTap: _showOrderHistoryScreen,
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
            const Text(
              'Order History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.blue.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View Past',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
    );
  }

  Widget _buildShopTimingsItem() {
    return GestureDetector(
      onTap: _showTimingsDialog,
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
            const Text(
              'Shop Timings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.purple.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatTime(_shopOpenTime)} - ${_formatTime(_shopCloseTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothStateSubscription?.cancel();
    super.dispose();
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
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
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
                    ),
                    _buildSettingItem(
                      title: 'Shop Open/Close',
                      value: _shopOpen,
                      onChanged: _toggleShopStatus,
                    ),
                    _buildShopTimingsItem(),
                    _buildOffersItem(),
                    _buildOfflineItemsItem(),
                    _buildTodaysSalesReportItem(), // UPDATED: Only today's report
                    _buildOrderHistoryItem(), // NEW: Order History
                    _buildAdminPortalItem(), // UPDATED: Admin Portal instead of Driver Settings
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedBottomNavItem,
        showDivider: true,
        onItemSelected: (index) {
          setState(() {
            _selectedBottomNavItem = index;
          });
        },
      ),
    );
  }
}
