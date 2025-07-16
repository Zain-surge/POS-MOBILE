import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';

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
  Map<String, dynamic>? _salesReport;
  bool _isLoadingSalesReport = false;

  // Settings states
  bool _bluetoothEnabled = false;
  bool _wifiEnabled = false;
  bool _shopOpen = false;
  bool _showDeliveryMenu = false;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingOffers = false;
  // Shop timings
  String _shopOpenTime = "09:00";
  String _shopCloseTime = "21:00";

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load shop status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleShopStatus(bool value) async {
    // Optimistic update
    setState(() {
      _shopOpen = value;
    });

    try {
      final message = await ApiService.toggleShopStatus(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _shopOpen = !value;
      });
      print('Error toggling shop status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle shop status: $e'),
          backgroundColor: Colors.red,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load offers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingOffers = false;
      });
    }
  }

  Future<void> _updateOfferStatus(String offerText, bool value, StateSetter setDialogState) async {
    // Find and update the offer immediately (optimistic update)
    final offerIndex = _offers.indexWhere((offer) => offer['offer_text'] == offerText);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Revert the optimistic update on error
      if (offerIndex != -1) {
        final revertedOffers = List<Map<String, dynamic>>.from(_offers);
        revertedOffers[offerIndex]['value'] = !value; // Revert to original state

        setState(() {
          _offers = revertedOffers;
        });

        setDialogState(() {
          _offers = revertedOffers;
        });
      }

      print('Error updating offer status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update offer status: $e'),
          backgroundColor: Colors.red,
        ),
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
                child: _isLoadingOffers
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : _offers.isEmpty
                    ? const Center(
                  child: Text(
                    'No offers available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
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
                          color: offer['value']
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer['offer_text'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isLocked
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  offer['value'] ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: offer['value']
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
                                inactiveThumbColor: Colors.grey.shade400,
                                inactiveTrackColor: Colors.grey.shade300,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      final openMinutes = openTime!.hour * 60 + openTime!.minute;
                      final closeMinutes = closeTime!.hour * 60 + closeTime!.minute;

                      if (closeMinutes <= openMinutes) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Closing time must be greater than opening time'),
                            backgroundColor: Colors.red,
                          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
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
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateShopTimings(TimeOfDay openTime, TimeOfDay closeTime) async {
    final openTimeStr = "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}";
    final closeTimeStr = "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}";

    // Optimistic update
    setState(() {
      _shopOpenTime = openTimeStr;
      _shopCloseTime = closeTimeStr;
    });

    try {
      final message = await ApiService.updateShopTimings(openTimeStr, closeTimeStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Revert on error - reload from server
      _loadShopStatus();
      print('Error updating shop timings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update shop timings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSalesReport() async {
    setState(() {
      _isLoadingSalesReport = true;
    });

    try {
      final salesReport = await ApiService.getSalesReport();
      setState(() {
        _salesReport = salesReport;
      });
    } catch (e) {
      print('Error loading sales report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sales report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingSalesReport = false;
      });
    }
  }

  Future<void> _generateSalesReportPDF() async {
    if (_salesReport == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sales Report - ${_salesReport!['date']}',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),

              pw.Text('Total Sales: \$${_salesReport!['total_sales']}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),

              pw.Text('Sales by Payment Type:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...(_salesReport!['sales_by_payment_type'] as List).map((item) =>
                  pw.Text('${item['payment_type']}: ${item['count']} orders - \$${item['total']}')),
              pw.SizedBox(height: 20),

              pw.Text('Sales by Order Type:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...(_salesReport!['sales_by_order_type'] as List).map((item) =>
                  pw.Text('${item['order_type']}: ${item['count']} orders - \$${item['total']}')),
              pw.SizedBox(height: 20),

              pw.Text('Sales by Order Source:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...(_salesReport!['sales_by_order_source'] as List).map((item) =>
                  pw.Text('${item['source']}: ${item['count']} orders - \$${item['total']}')),
              pw.SizedBox(height: 20),

              if (_salesReport!['most_selling_item'] != null) ...[
                pw.Text('Most Selling Item:',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('${_salesReport!['most_selling_item']['item_name']}: ${_salesReport!['most_selling_item']['quantity_sold']} sold - \$${_salesReport!['most_selling_item']['total_sales']}'),
              ],
            ],
          );
        },
      ),
    );

    try {
      // Mobile-only approach using path_provider
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sales_report_${_salesReport!['date']}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report for ${_salesReport!['date']}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and shared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSalesReportDialog() async {
    await _loadSalesReport();

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
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assessment,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sales Report',
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
                height: 500,
                child: _isLoadingSalesReport
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
                    : _salesReport == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sales data available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Cards
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildReportCard('Date', _salesReport!['date'], Colors.blue),
                            const SizedBox(height: 8),
                            _buildReportCard('Total Sales', '\$${_salesReport!['total_sales']}', Colors.green),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Payment Types Section
                      _buildSectionHeader('Payment Types', Icons.payment, Colors.purple),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          children: (_salesReport!['sales_by_payment_type'] as List).map((item) =>
                              _buildReportItem('${item['payment_type']}', '${item['count']} orders', '\$${item['total']}', Colors.purple)
                          ).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Order Types Section
                      _buildSectionHeader('Order Types', Icons.shopping_cart, Colors.orange),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: (_salesReport!['sales_by_order_type'] as List).map((item) =>
                              _buildReportItem('${item['order_type']}', '${item['count']} orders', '\$${item['total']}', Colors.orange)
                          ).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Order Sources Section
                      _buildSectionHeader('Order Sources', Icons.source, Colors.teal),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          children: (_salesReport!['sales_by_order_source'] as List).map((item) =>
                              _buildReportItem('${item['source']}', '${item['count']} orders', '\$${item['total']}', Colors.teal)
                          ).toList(),
                        ),
                      ),

                      if (_salesReport!['most_selling_item'] != null) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader('Most Selling Item', Icons.star, Colors.amber),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_salesReport!['most_selling_item']['item_name']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_salesReport!['most_selling_item']['quantity_sold']} sold',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${_salesReport!['most_selling_item']['total_sales']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                if (_salesReport != null)
                  ElevatedButton.icon(
                    onPressed: _generateSalesReportPDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(String title, String count, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReportItem() {
    return GestureDetector(
      onTap: _showSalesReportDialog,
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
              'Sales Report',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assessment,
                        color: Colors.blue.shade600,
                        size: 16,
                      ),
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
      setState(() {
        _bluetoothEnabled = isEnabled;
      });

      // Listen to Bluetooth state changes
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
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
        Map<Permission, PermissionStatus> statuses = await [
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
          setState(() {
            _bluetoothEnabled = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth turned on successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          print('Failed to turn on Bluetooth programmatically: $e');
          _navigateToBluetoothSettings();
        }
      } else {
        // Try to turn off Bluetooth
        try {
          await FlutterBluePlus.turnOff();
          setState(() {
            _bluetoothEnabled = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth turned off successfully'),
              backgroundColor: Colors.orange,
            ),
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
          content: const Text('Unable to control Bluetooth from the app. Would you like to open device settings to manage Bluetooth?'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                child:
                Column(
                  children: [
                    _buildSettingItem(
                      title: 'Bluetooth',
                      value: _bluetoothEnabled,
                      onChanged: _toggleBluetooth,
                    ),
                    _buildSettingItem(
                      title: 'Wi-fi',
                      value: _wifiEnabled,
                      onChanged: (value) {
                        setState(() {
                          _wifiEnabled = value;
                        });
                      },
                    ),
                    _buildSettingItem(
                      title: 'Shop Open/Close',
                      value: _shopOpen,
                      onChanged: _toggleShopStatus,
                    ),
                    _buildShopTimingsItem(),
                    _buildOffersItem(),
                    _buildSalesReportItem(), // Add this line
                    _buildSettingItem(
                      title: 'Show delivery menu',
                      value: _showDeliveryMenu,
                      onChanged: (value) {
                        setState(() {
                          _showDeliveryMenu = value;
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