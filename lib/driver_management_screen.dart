// lib/screens/driver_management_screen.dart

import 'package:epos/widgets/live_updating_pill.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/driver_api_service.dart';
import '../providers/driver_order_provider.dart';
import '../models/order.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/custom_popup_service.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Driver Management',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
              const SizedBox(height: 20),
              // Tab buttons
              Row(
                children: [
                  Expanded(child: _buildTabButton('Add Driver', 0)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildTabButton('Deactivate Driver', 1)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildTabButton('Driver Portal', 2)),
                ],
              ),
              const SizedBox(height: 20),
              // Content
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return const AddDriverTab();
      case 1:
        return const DeactivateDriverTab();
      case 2:
        return ChangeNotifierProvider(
          create: (context) => DriverOrderProvider()..startPolling(),
          child: const DriverPortalTab(),
        );
      default:
        return const AddDriverTab();
    }
  }
}

class AddDriverTab extends StatefulWidget {
  const AddDriverTab({Key? key}) : super(key: key);

  @override
  State<AddDriverTab> createState() => _AddDriverTabState();
}

class _AddDriverTabState extends State<AddDriverTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add New Driver',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nameController,
                        hintText: 'NAME',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        hintText: 'EMAIL',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _usernameController,
                        hintText: 'USERNAME',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _passwordController,
                        hintText: 'PASSWORD',
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  hintText: 'PHONE NUMBER',
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _clearForm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addDriver,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Add Driver',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.green),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.red,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _phoneController.clear();
  }

  Future<void> _addDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await DriverApiService.createDriver(
        name: _nameController.text,
        email: _emailController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      );

      if (mounted) {
        CustomPopupService.show(
          context,
          "Driver created successfully",
          type: PopupType.success,
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          "Failed to create driver ! ",
          type: PopupType.failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class DeactivateDriverTab extends StatefulWidget {
  const DeactivateDriverTab({Key? key}) : super(key: key);

  @override
  State<DeactivateDriverTab> createState() => _DeactivateDriverTabState();
}

class _DeactivateDriverTabState extends State<DeactivateDriverTab> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    if (mounted) {
      setState(() {
        _isButtonEnabled = _usernameController.text.trim().isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deactivate Driver',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Username',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _usernameController.clear();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading || !_isButtonEnabled ? null : _deactivateDriver,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Deactivate',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deactivateDriver() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DriverApiService.deactivateDriver(_usernameController.text.trim());

      if (mounted) {
        CustomPopupService.show(
          context,
          "Driver deactivated successfully",
          type: PopupType.success,
        );
        _usernameController.clear();
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          "Failed to deactivate order !",
          type: PopupType.failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_updateButtonState);
    _usernameController.dispose();
    super.dispose();
  }
}

class DriverPortalTab extends StatefulWidget {
  const DriverPortalTab({Key? key}) : super(key: key);

  @override
  State<DriverPortalTab> createState() => _DriverPortalTabState();
}

class _DriverPortalTabState extends State<DriverPortalTab>
    with TickerProviderStateMixin {
  DateTime _selectedDate = UKTimeService.now();
  late AnimationController _colorAnimationController;

  @override
  void initState() {
    super.initState();
    _colorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _colorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverOrderProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Select Date:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${provider.error}',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadOrders(),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : provider.orders.isEmpty
                  ? Center(
                child: Text(
                  'No orders found for selected date',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _buildOrdersGrid(provider.orders),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersGrid(List<Order> orders) {
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<List<Order>> orderRows = [];
    for (int i = 0; i < orders.length; i += 3) {
      orderRows.add(orders.skip(i).take(3).toList());
    }
    return Column(
      children: orderRows.map((orderRow) => _buildOrderRow(orderRow)).toList(),
    );
  }

  Widget _buildOrderRow(List<Order> orders) {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.symmetric(vertical: 20),
        ),
        Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i < orders.length)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildOrderUnit(orders[i]),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              if (i < 2)
                Container(
                  width: 1,
                  height: 100,
                  color: Colors.grey.shade300,
                ),
            ],
          ],
        ),
        Container(
          height: 1,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.symmetric(vertical: 20),
        ),
      ],
    );
  }

  Widget _buildOrderUnit(Order order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Driver name pill with live updates
        LiveUpdatingPill(
          text: order.customerName,
          order: order,
          onTap: () => _showOrderDetails(order),
        ),
        const SizedBox(width: 40),
        // Postal code pill with live updates
        LiveUpdatingPill(
          text: order.postalCode ?? 'N/A',
          order: order,
          onTap: () => _showOrderDetails(order),
        ),
      ],
    );
  }

  void _showOrderDetails(Order order) {

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.orderId}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Order details content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Information
                        _buildDetailSection(
                          'Customer Information',
                          [
                            _buildDetailRow(
                                'Name', order.customerEmail ?? 'N/A'),
                            // This now contains customer_name
                            _buildDetailRow(
                                'Phone', order.phoneNumber ?? 'N/A'),
                            _buildDetailRow(
                                'Address', _buildFullAddress(order)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Order Information
                        _buildDetailSection(
                          'Order Information',
                          [
                            _buildDetailRow('Status', order.statusLabel),
                            _buildDetailRow('Total', '£${order.orderTotalPrice}'),
                            _buildDetailRow('Time',
                                DateFormat('HH:mm - dd/MM/yyyy').format(
                                    order.createdAt)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Items
                        _buildDetailSection(
                          'Items',
                          order.items.map((item) => _buildItemRow(item))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                '${item.quantity}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '£${item.totalPrice}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _buildFullAddress(Order order) {
    final parts = <String>[];
    if (order.streetAddress?.isNotEmpty == true) parts.add(
        order.streetAddress!);
    if (order.city?.isNotEmpty == true) parts.add(order.city!);
    if (order.county?.isNotEmpty == true) parts.add(order.county!);
    if (order.postalCode?.isNotEmpty == true) parts.add(order.postalCode!);
    return parts.isNotEmpty ? parts.join(', ') : 'No address provided';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: UKTimeService.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      final provider = Provider.of<DriverOrderProvider>(context, listen: false);
      provider.setSelectedDate(DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}