// lib/screens/admin_portal_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/sales_report_provider.dart';
import '../providers/driver_order_provider.dart';
import '../services/driver_api_service.dart';
import '../models/order.dart';
import '../widgets/live_updating_pill.dart';
import '../widgets/items_table_widget.dart';
import '../widgets/paidouts_table_widget.dart';
import '../widgets/postal_codes_table_widget.dart';
import 'package:epos/config/security_config.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/custom_popup_service.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({Key? key}) : super(key: key);

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isPinValidated = false;
  bool _isInitialized = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Show PIN dialog immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPinDialog();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showPinDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 48,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Admin Portal',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter PIN to access admin features',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        letterSpacing: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      counterText: '',
                    ),
                    onSubmitted: (pin) => _validatePin(pin),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop(); // Go back to settings
                          },
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _validatePin(_pinController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Access',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _validatePin(String pin) {
    if (pin == SecurityConfig.adminPin) {
      Navigator.of(context).pop();
      setState(() {
        _isPinValidated = true;
      });
      _initializeProvider();
    } else {
      _showErrorMessage('Invalid PIN. Please try again.');
      _pinController.clear();
    }
  }

  Future<void> _initializeProvider() async {
    if (_isInitialized) return;

    _isInitialized = true;
    final provider = Provider.of<SalesReportProvider>(context, listen: false);
    await provider.initialize();
    await provider.loadDailyReport();
    await provider.loadWeeklyReport();
    await provider.loadMonthlyReport();
    await provider.loadDriverReport();
  }

  void _showErrorMessage(String message) {
    CustomPopupService.show(
      context,
      message,
      type: PopupType.failure, // Failure type use karein
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPinValidated) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 100,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Admin Portal',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Authentication Required',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<SalesReportProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Tab Navigation
                _buildTabNavigation(),

                // Content
                Expanded(child: _buildTabContent()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Admin Portal title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Admin Portal',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Empty space to balance the layout
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    final tabs = [
      "Daily Report",
      "Weekly Report",
      "Monthly Report",
      "Drivers Report",
      "Driver Management",
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children:
            tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final title = entry.value;
              final isSelected = _selectedTab == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSalesReportTab(1); // Daily
      case 1:
        return _buildSalesReportTab(2); // Weekly
      case 2:
        return _buildSalesReportTab(3); // Monthly
      case 3:
        return _buildSalesReportTab(4); // Driver Report
      case 4:
        return _buildDriverManagement(); // Driver Management - moved to last
      default:
        return _buildSalesReportTab(1); // Default to Daily
    }
  }

  Widget _buildDriverManagement() {
    return AdminDriverManagement();
  }

  Widget _buildSalesReportTab(int reportType) {
    return AdminSalesReport(reportType: reportType);
  }
}

// Driver Management Component for Admin Portal
class AdminDriverManagement extends StatefulWidget {
  @override
  State<AdminDriverManagement> createState() => _AdminDriverManagementState();
}

class _AdminDriverManagementState extends State<AdminDriverManagement> {
  int _selectedDriverTab = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Driver Management sub-tabs
          Row(
            children: [
              Expanded(child: _buildDriverTabButton('Add Driver', 0)),
              const SizedBox(width: 4),
              Expanded(child: _buildDriverTabButton('Deactivate Driver', 1)),
              const SizedBox(width: 4),
              Expanded(child: _buildDriverTabButton('Driver Portal', 2)),
            ],
          ),
          const SizedBox(height: 20),
          // Content
          Expanded(child: _buildDriverTabContent()),
        ],
      ),
    );
  }

  Widget _buildDriverTabButton(String title, int index) {
    final isSelected = _selectedDriverTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDriverTab = index;
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

  Widget _buildDriverTabContent() {
    switch (_selectedDriverTab) {
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
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isLoading
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
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
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
        errorStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
        phoneNumber:
            _phoneController.text.isNotEmpty ? _phoneController.text : null,
      );

      if (mounted) {
        CustomPopupService.show(
          context,
          'Driver created successfully',
          type: PopupType.success,
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to create driver',
          type: PopupType.failure, // Failure type use karein
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
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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
                    onPressed:
                        _isLoading || !_isButtonEnabled
                            ? null
                            : _deactivateDriver,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
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
          'Driver deactivated successfully',
          type: PopupType.success,
        );
        _usernameController.clear();
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to deactivate driver',
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
                      horizontal: 16,
                      vertical: 8,
                    ),
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
              child:
                  provider.isLoading
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
                Container(width: 1, height: 100, color: Colors.grey.shade300),
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
                        _buildDetailSection('Customer Information', [
                          _buildDetailRow('Name', order.customerEmail ?? 'N/A'),
                          // This now contains customer_name
                          _buildDetailRow('Phone', order.phoneNumber ?? 'N/A'),
                          _buildDetailRow('Address', _buildFullAddress(order)),
                        ]),
                        const SizedBox(height: 20),
                        // Order Information
                        _buildDetailSection('Order Information', [
                          _buildDetailRow('Status', order.statusLabel),
                          _buildDetailRow('Total', '£${order.orderTotalPrice}'),
                          _buildDetailRow(
                            'Time',
                            DateFormat(
                              'HH:mm - dd/MM/yyyy',
                            ).format(order.createdAt),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Items
                        _buildDetailSection(
                          'Items',
                          order.items
                              .map((item) => _buildItemRow(item))
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
          child: Column(children: children),
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
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
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
    if (order.streetAddress?.isNotEmpty == true)
      parts.add(order.streetAddress!);
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

class AdminSalesReport extends StatelessWidget {
  final int reportType;

  const AdminSalesReport({Key? key, required this.reportType})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesReportProvider>(
      builder: (context, provider, child) {
        // Set the correct tab index for the provider
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.currentTabIndex != reportType) {
            provider.setCurrentTab(reportType);
          }
        });

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Date/Period selectors based on report type
              _buildDateSelector(
                context,
                provider,
                reportType,
              ), // Pass context here
              const SizedBox(height: 20),

              // Report Title
              _buildReportTitle(_getReportTitle(reportType)),
              const SizedBox(height: 20),

              // Filters (not for driver report)
              if (reportType != 4) ...[
                _buildFilters(provider),
                const SizedBox(height: 20),
              ],

              // Main Content
              _buildMainContent(provider, reportType),
              const SizedBox(height: 20),

              // Items section (not for driver report)
              if (reportType != 4) _buildItemsSection(provider),
            ],
          ),
        );
      },
    );
  }

  String _getReportTitle(int reportType) {
    switch (reportType) {
      case 1:
        return 'Daily Report';
      case 2:
        return 'Weekly Report';
      case 3:
        return 'Monthly Report';
      case 4:
        return 'Drivers Report';
      default:
        return 'Report';
    }
  }

  Widget _buildDateSelector(
    BuildContext context,
    SalesReportProvider provider,
    int reportType,
  ) {
    switch (reportType) {
      case 1:
        return _buildDailyDateSelector(context, provider);
      case 2:
        return _buildWeeklySelector(context, provider);
      case 3:
        return _buildMonthlySelector(context, provider);
      case 4:
        return _buildDriverDateSelector(context, provider);
      default:
        return Container();
    }
  }

  Widget _buildDailyDateSelector(
    BuildContext context,
    SalesReportProvider provider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Select Date:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _selectDate(context, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(provider.selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.calendar_today, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        _buildActionButton('Get Report', () => provider.loadDailyReport()),
        const SizedBox(width: 10),
        _buildActionButton(
          provider.isThermalPrinting ? 'Printing...' : 'Print Report',
          provider.isThermalPrinting
              ? null
              : () => _printThermalReport(context, provider),
        ),
      ],
    );
  }

  Widget _buildWeeklySelector(
    BuildContext context,
    SalesReportProvider provider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Select Date:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _selectDate(context, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(provider.selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.calendar_today, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        _buildActionButton('Get Report', () => provider.loadWeeklyReport()),
        const SizedBox(width: 10),
        _buildActionButton(
          provider.isThermalPrinting ? 'Printing...' : 'Print Report',
          provider.isThermalPrinting
              ? null
              : () => _printThermalReport(context, provider),
        ),
      ],
    );
  }

  Widget _buildMonthlySelector(
    BuildContext context,
    SalesReportProvider provider,
  ) {
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Year:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            provider.selectedYear.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          'Month:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: provider.selectedMonth,
              items:
                  months.asMap().entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key + 1,
                      child: Text(
                        entry.value,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (month) {
                if (month != null) {
                  provider.setSelectedMonth(month);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 15),
        _buildActionButton('Get Report', () => provider.loadMonthlyReport()),
        const SizedBox(width: 10),
        _buildActionButton(
          provider.isThermalPrinting ? 'Printing...' : 'Print Report',
          provider.isThermalPrinting
              ? null
              : () => _printThermalReport(context, provider),
        ),
      ],
    );
  }

  Widget _buildDriverDateSelector(
    BuildContext context,
    SalesReportProvider provider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Select Date:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _selectDate(context, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(provider.selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.calendar_today, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        _buildActionButton('Get Report', () => provider.loadDriverReport()),
        const SizedBox(width: 10),
        _buildActionButton(
          provider.isThermalPrinting ? 'Printing...' : 'Print Report',
          provider.isThermalPrinting
              ? null
              : () => _printThermalReport(context, provider),
        ),
      ],
    );
  }

  // UPDATE the _selectDate method to accept context parameter:
  Future<void> _selectDate(
    BuildContext context,
    SalesReportProvider provider,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: UKTimeService.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
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
    if (picked != null) {
      provider.setSelectedDate(picked);
    }
  }

  Widget _buildActionButton(String text, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            onPressed != null ? Colors.black : Colors.grey.shade400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _printThermalReport(
    BuildContext context,
    SalesReportProvider provider,
  ) async {
    try {
      await provider.printThermalReport();

      // Show success message if we have a context
      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Report printed successfully',
          type: PopupType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Failed to print report',
          type: PopupType.failure,
        );
      }
    }
  }

  Widget _buildReportTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFilters(SalesReportProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            'Filter by Source:',
            provider.sourceFilter,
            _getSourceOptions(provider),
            (value) => provider.setFilters(source: value),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildFilterDropdown(
            'Filter by Payment Type:',
            provider.paymentFilter,
            _getPaymentOptions(provider),
            (value) => provider.setFilters(payment: value),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildFilterDropdown(
            'Filter by Order Type:',
            provider.orderTypeFilter,
            _getOrderTypeOptions(provider),
            (value) => provider.setFilters(orderType: value),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    final currentValue = options.contains(value) ? value : 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              items:
                  options.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(SalesReportProvider provider, int reportType) {
    if (provider.isLoading) {
      return Container(
        height: 300,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final report = provider.getCurrentReport();

    if (report == null || report.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No data available for this period',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => provider.refreshCurrentReport(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (reportType == 4) {
      // Driver report has different layout
      return _buildDriverReportContent(provider);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Summary
        Expanded(flex: 1, child: _buildSummaryCard(provider)),
        const SizedBox(width: 20),
        // Right side - Charts
        Expanded(flex: 2, child: _buildChartsSection(provider)),
      ],
    );
  }

  Widget _buildSummaryCard(SalesReportProvider provider) {
    final report = provider.getCurrentReport();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildSummaryItem(
            'Period:',
            _getPeriodText(provider, report),
            Colors.purple,
          ),
          _buildSummaryItem(
            'Total Sales Amount:',
            _getFormattedAmount(
              report?['total_sales'] ?? report?['total_sales_amount'],
            ),
            Colors.purple,
          ),
          if (report?['total_orders_placed'] != null)
            _buildSummaryItem(
              'Total Orders Placed:',
              report!['total_orders_placed'].toString(),
              Colors.purple,
            ),
          if (_hasPaidOutsData(report))
            _buildSummaryItem(
              'Total Paid Outs:',
              '-${_getFormattedAmount(_getPaidOutsValue(report))}',
              Colors.red,
            ),
          if (_hasDiscountData(report))
            _buildSummaryItem(
              'Total Discount:',
              '-${_getFormattedAmount(report?['total_discount'])}',
              Colors.orange,
            ),
          if (_hasPaidOutsData(report) || _hasDiscountData(report))
            _buildSummaryItem(
              'Net Sales Amount:',
              _getFormattedAmount(_getNetSalesAmount(report)),
              Colors.green,
            ),
          _buildSummaryItem(
            'Sales Growth (vs. Last Week):',
            _getGrowthText(report),
            Colors.purple,
          ),
          _buildSummaryItem(
            'Sales Growth (vs. Last Week):',
            _getGrowthAmount(report),
            Colors.purple,
          ),
          _buildSummaryItem(
            'Most Sold Item:',
            _getMostSoldItem(report),
            Colors.purple,
          ),
          if (provider.currentTabIndex != 4)
            _buildSummaryItem(
              'Most Sold Category:',
              _getMostSoldCategory(report),
              Colors.purple,
            ),
          _buildSummaryItem(
            'Most Delivered Area:',
            _getMostDeliveredArea(report),
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(SalesReportProvider provider) {
    final report = provider.getCurrentReport();

    return Column(
      children: [
        // Top row charts
        Row(
          children: [
            Expanded(child: _buildGrowthChart(report)),
            const SizedBox(width: 20),
            Expanded(child: _buildPaymentMethodsChart(report)),
          ],
        ),
        const SizedBox(height: 30),
        // Bottom row charts
        Row(
          children: [
            Expanded(child: _buildOrderTypesChart(report)),
            const SizedBox(width: 20),
            Expanded(child: _buildOrderSourcesChart(report)),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsSection(SalesReportProvider provider) {
    final itemsCount = provider.getItemsCount();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Items Sold ($itemsCount items)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: provider.toggleShowItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      provider.showItems ? 'Hide Items' : 'Show Items',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_hasPaidOutsData(provider.getCurrentReport())) ...[
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: provider.toggleShowPaidOuts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        provider.showPaidOuts
                            ? 'Hide Paid Outs'
                            : 'Show Paid Outs',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (_hasPostalCodesData(provider.getCurrentReport())) ...[
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: provider.toggleShowPostalCodes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        provider.showPostalCodes
                            ? 'Hide Postal Codes'
                            : 'Show Postal Codes',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (provider.showItems) ...[
          const SizedBox(height: 20),
          ItemsTableWidget(report: provider.getCurrentReport()),
        ],
        if (provider.showPaidOuts) ...[
          const SizedBox(height: 20),
          PaidOutsTableWidget(report: provider.getCurrentReport()),
        ],
        if (provider.showPostalCodes) ...[
          const SizedBox(height: 20),
          PostalCodesTableWidget(report: provider.getCurrentReport()),
        ],
      ],
    );
  }

  Widget _buildDriverReportContent(SalesReportProvider provider) {
    final report = provider.driverReport;

    if (report == null) {
      return Center(
        child: Text(
          'No driver report data available',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: [
        // Driver Delivery Locations
        _buildDriverTable(
          'Driver Delivery Locations',
          ['Driver Name', 'Street Address', 'City', 'County'],
          report['driver_delivery_locations'] ?? [],
          (item) => [
            item['driver_name']?.toString() ?? 'N/A',
            item['street_address']?.toString() ?? 'N/A',
            item['city']?.toString() ?? 'N/A',
            item['county']?.toString() ?? 'N/A',
          ],
        ),

        const SizedBox(height: 40),

        // Driver Order Summary
        _buildDriverTable(
          'Driver Order Summary',
          ['Driver Name', 'Total Orders'],
          report['driver_order_summary'] ?? [],
          (item) => [
            item['driver_name']?.toString() ?? 'N/A',
            item['total_orders']?.toString() ?? '0',
          ],
        ),
      ],
    );
  }

  Widget _buildDriverTable(
    String title,
    List<String> headers,
    List<dynamic> data,
    List<String> Function(dynamic) rowMapper,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade200),
            child: Row(
              children:
                  headers.map((header) {
                    return Expanded(
                      child: Text(
                        header,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          // Data rows
          if (data.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No data available',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            ...data.map((item) {
              final rowData = rowMapper(item);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children:
                      rowData.map((cellData) {
                        return Expanded(
                          child: Text(
                            cellData,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // Helper methods
  List<String> _getSourceOptions(SalesReportProvider provider) {
    return provider.getAvailableSourceOptions();
  }

  List<String> _getPaymentOptions(SalesReportProvider provider) {
    return provider.getAvailablePaymentOptions();
  }

  List<String> _getOrderTypeOptions(SalesReportProvider provider) {
    return provider.getAvailableOrderTypeOptions();
  }

  String _getPeriodText(
    SalesReportProvider provider,
    Map<String, dynamic>? report,
  ) {
    if (report == null) return 'N/A';

    switch (provider.currentTabIndex) {
      case 1:
        return report['date']?.toString() ??
            DateFormat('yyyy-MM-dd').format(provider.selectedDate);
      case 2:
        final period = report['period'];
        if (period != null && period is Map) {
          return '${period['from']} ~ ${period['to']}';
        }
        return 'Week ${provider.selectedWeek}, ${provider.selectedYear}';
      case 3:
        final period = report['period'];
        if (period != null && period is Map) {
          return '${period['from']} ~ ${period['to']}';
        }
        return 'Month ${provider.selectedMonth}, ${provider.selectedYear}';
      default:
        return 'N/A';
    }
  }

  String _getFormattedAmount(dynamic amount) {
    if (amount == null) return '£0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '£${value.toStringAsFixed(2)}';
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0.0£';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '${value.toStringAsFixed(1)}£';
  }

  String _getGrowthText(Map<String, dynamic>? report) {
    if (report == null) return 'N/A';
    final growth = report['sales_growth_percentage'];
    if (growth == null) return 'N/A';
    final value = double.tryParse(growth.toString()) ?? 0.0;
    final isPositive = value >= 0;
    return '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}%';
  }

  String _getGrowthAmount(Map<String, dynamic>? report) {
    if (report == null) return 'N/A';
    final increase = report['sales_increase'];
    if (increase == null) return 'N/A';
    final value = double.tryParse(increase.toString()) ?? 0.0;
    final isPositive = value >= 0;
    return '${isPositive ? '+' : ''}${_formatCurrency(increase)}';
  }

  String _getMostSoldItem(Map<String, dynamic>? report) {
    if (report == null) return 'N/A';
    final item = report['most_selling_item'] ?? report['most_sold_item'];
    if (item == null) return 'N/A';
    final name = item['item_name']?.toString() ?? 'Unknown';
    final quantity = item['quantity_sold']?.toString() ?? '0';
    return '$name ($quantity sold)';
  }

  String _getMostSoldCategory(Map<String, dynamic>? report) {
    if (report == null) return 'N/A';
    final category = report['most_sold_type'];
    if (category == null) return 'N/A';
    final type = category['type']?.toString() ?? 'Unknown';
    final quantity = category['quantity_sold']?.toString() ?? '0';
    return '$type ($quantity sold)';
  }

  String _getMostDeliveredArea(Map<String, dynamic>? report) {
    if (report == null) return 'N/A';
    final area = report['most_delivered_postal_code'];
    if (area == null) return 'N/A';
    final postalCode = area['postal_code']?.toString() ?? 'Unknown';
    final deliveries = area['delivery_count']?.toString() ?? '0';
    return '$postalCode ($deliveries deliveries)';
  }

  // Chart building methods
  Widget _buildGrowthChart(Map<String, dynamic>? report) {
    final growthAmount = report?['sales_increase'] ?? 0.0;
    final isPositive = (growthAmount is num) ? growthAmount >= 0 : true;

    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          child: CustomPaint(
            painter: DonutChartPainter(
              value: isPositive ? 0.7 : 0.3,
              color: const Color(0xFF40E0D0),
              backgroundColor: Colors.grey.shade200,
            ),
            child: Center(
              child: Text(
                '${isPositive ? '+' : ''}${_formatCurrency(growthAmount)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatCurrency(growthAmount)} more than last week',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsChart(Map<String, dynamic>? report) {
    final paymentData = _getPaymentMethodsData(report);
    final paymentTypes =
        report?['sales_by_payment_type'] as List<dynamic>? ?? [];

    final paymentLabels =
        paymentTypes
            .where(
              (payment) => payment is Map && payment['payment_type'] != null,
            )
            .map((payment) => payment['payment_type'].toString().toUpperCase())
            .where((label) => label.isNotEmpty)
            .toList();

    final labels =
        paymentLabels.isNotEmpty ? paymentLabels : ['CARD', 'CASH', 'COD'];

    final colors = <Color>[];
    final baseColors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF40E0D0),
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFFFFD93D),
    ];

    for (int i = 0; i < labels.length; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }

    return Column(
      children: [
        Text(
          'Payment Methods',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 80,
          width: 80,
          child: CustomPaint(
            painter: PieChartPainter(data: paymentData, colors: colors),
          ),
        ),
        const SizedBox(height: 8),
        _buildChartLegend([
          for (int i = 0; i < labels.length && i < colors.length; i++)
            {'label': labels[i], 'color': colors[i]},
        ]),
      ],
    );
  }

  Widget _buildOrderTypesChart(Map<String, dynamic>? report) {
    final orderTypeData = _getOrderTypesData(report);
    final orderTypes = _getOrderTypeLabels(report);

    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFFA29BFE),
      Color(0xFF74B9FF),
      Color(0xFF81ECEC),
      Color(0xFFFFD93D),
      Color(0xFFFF6B6B),
      Color(0xFF00B894),
    ];

    return Column(
      children: [
        Text(
          'Order Types',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 80,
          width: 80,
          child: CustomPaint(
            painter: PieChartPainter(
              data: orderTypeData,
              colors: colors.take(orderTypes.length).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildChartLegend(_getOrderTypeLegend(orderTypes)),
      ],
    );
  }

  Widget _buildOrderSourcesChart(Map<String, dynamic>? report) {
    final sourceData = _getOrderSourcesData(report);
    final sources = _getSourceLabels(report);

    const colors = [
      Color(0xFF00B894),
      Color(0xFF00CEC9),
      Color(0xFF74B9FF),
      Color(0xFF6C5CE7),
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
    ];

    return Column(
      children: [
        Text(
          'Order Sources',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 80,
          width: 80,
          child: CustomPaint(
            painter: PieChartPainter(
              data: sourceData,
              colors: colors.take(sources.length).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildChartLegend(_getSourceLegend(sources)),
      ],
    );
  }

  Widget _buildChartLegend(List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children:
          items.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item['label'],
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  // Data processing methods
  List<double> _getPaymentMethodsData(Map<String, dynamic>? report) {
    if (report == null) return [0.5, 0.5];

    final paymentTypes = report['sales_by_payment_type'] as List<dynamic>?;
    if (paymentTypes == null || paymentTypes.isEmpty) return [0.5, 0.5];

    final Map<String, double> paymentAmounts = {};
    double totalAmount = 0;

    for (var payment in paymentTypes) {
      if (payment is! Map) continue;
      final type = payment['payment_type']?.toString() ?? '';
      final total = double.tryParse(payment['total']?.toString() ?? '0') ?? 0;

      if (type.isNotEmpty && total > 0) {
        paymentAmounts[type] = total;
        totalAmount += total;
      }
    }

    if (totalAmount == 0 || paymentAmounts.isEmpty) return [0.5, 0.5];

    return paymentAmounts.values.map((amount) => amount / totalAmount).toList();
  }

  List<double> _getOrderTypesData(Map<String, dynamic>? report) {
    if (report == null) return [1.0];

    final orderTypes = report['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes == null || orderTypes.isEmpty) return [1.0];

    final List<double> amounts = [];
    double total = 0;

    for (var orderType in orderTypes) {
      if (orderType is! Map) continue;
      final amount =
          double.tryParse(orderType['total']?.toString() ?? '0') ?? 0;
      if (amount > 0) {
        amounts.add(amount);
        total += amount;
      }
    }

    if (total == 0 || amounts.isEmpty) return [1.0];

    return amounts.map((amount) => amount / total).toList();
  }

  List<String> _getOrderTypeLabels(Map<String, dynamic>? report) {
    if (report == null) return [];

    final orderTypes = report['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes == null || orderTypes.isEmpty) return [];

    return orderTypes
        .where(
          (orderType) => orderType is Map && orderType['order_type'] != null,
        )
        .map((orderType) => orderType['order_type'].toString().toUpperCase())
        .where((label) => label.isNotEmpty)
        .toList();
  }

  List<String> _getSourceLabels(Map<String, dynamic>? report) {
    if (report == null) return [];

    final sources = report['sales_by_order_source'] as List<dynamic>?;
    if (sources == null || sources.isEmpty) return [];

    return sources
        .whereType<Map>()
        .map((source) => source['source']?.toString().toUpperCase() ?? '')
        .where((label) => label.isNotEmpty)
        .toList();
  }

  List<double> _getOrderSourcesData(Map<String, dynamic>? report) {
    if (report == null) return [1.0];

    final sources = report['sales_by_order_source'] as List<dynamic>?;
    if (sources == null || sources.isEmpty) return [1.0];

    final List<double> amounts = [];
    double total = 0;

    for (var source in sources) {
      if (source is! Map) continue;
      final amount = double.tryParse(source['total']?.toString() ?? '0') ?? 0;
      if (amount > 0) {
        amounts.add(amount);
        total += amount;
      }
    }

    if (total == 0 || amounts.isEmpty) return [1.0];

    return amounts.map((amount) => amount / total).toList();
  }

  List<Map<String, dynamic>> _getOrderTypeLegend(List<String> labels) {
    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFFA29BFE),
      Color(0xFF74B9FF),
      Color(0xFF81ECEC),
      Color(0xFFFFD93D),
      Color(0xFFFF6B6B),
      Color(0xFF00B894),
    ];

    return labels.asMap().entries.map((entry) {
      final index = entry.key;
      final label = entry.value;
      return {'label': label, 'color': colors[index % colors.length]};
    }).toList();
  }

  List<Map<String, dynamic>> _getSourceLegend(List<String> labels) {
    const colors = [
      Color(0xFF00B894),
      Color(0xFF00CEC9),
      Color(0xFF74B9FF),
      Color(0xFF6C5CE7),
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
    ];

    return labels.asMap().entries.map((entry) {
      final index = entry.key;
      final label = entry.value;
      return {'label': label, 'color': colors[index % colors.length]};
    }).toList();
  }

  // Helper methods for paid outs functionality
  bool _hasPaidOutsData(Map<String, dynamic>? report) {
    if (report == null) return false;

    final paidouts = report['paidouts'];
    if (paidouts is List && paidouts.isNotEmpty) {
      return true;
    }

    if (paidouts != null && paidouts is! List) {
      final amount = double.tryParse(paidouts.toString()) ?? 0.0;
      return amount > 0;
    }

    return false;
  }

  bool _hasPostalCodesData(Map<String, dynamic>? report) {
    if (report == null) return false;

    final postalCodes = report['deliveries_by_postal_code'];
    if (postalCodes is List && postalCodes.isNotEmpty) {
      return true;
    }

    return false;
  }

  bool _hasDiscountData(Map<String, dynamic>? report) {
    if (report == null) return false;
    final discount = report['total_discount'];
    if (discount == null) return false;
    final amount = double.tryParse(discount.toString()) ?? 0.0;
    return amount > 0;
  }

  double _getPaidOutsValue(Map<String, dynamic>? report) {
    if (report == null) return 0.0;

    final paidouts = report['paidouts'];

    if (paidouts is List) {
      double total = 0.0;
      for (final paidOut in paidouts) {
        if (paidOut is Map) {
          final amount = paidOut['amount'] ?? 0;
          if (amount is String) {
            total += double.tryParse(amount) ?? 0.0;
          } else if (amount is num) {
            total += amount.toDouble();
          }
        }
      }
      return total;
    }

    if (paidouts is String) {
      return double.tryParse(paidouts) ?? 0.0;
    } else if (paidouts is num) {
      return paidouts.toDouble();
    }

    return 0.0;
  }

  double _getNetSalesAmount(Map<String, dynamic>? report) {
    if (report == null) return 0.0;

    final totalSales =
        double.tryParse(
          (report['total_sales'] ?? report['total_sales_amount'] ?? 0)
              .toString(),
        ) ??
        0.0;

    final paidOuts = _getPaidOutsValue(report);

    final discount =
        double.tryParse((report['total_discount'] ?? 0).toString()) ?? 0.0;

    return totalSales - paidOuts - discount;
  }
}

// Custom Painters for Charts (same as in sales_report_screen.dart)
class DonutChartPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;

  DonutChartPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    // Background circle
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Progress arc
    final progressPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;

  PieChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length && i < colors.length; i++) {
      final sweepAngle = 2 * math.pi * data[i];
      final paint =
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
