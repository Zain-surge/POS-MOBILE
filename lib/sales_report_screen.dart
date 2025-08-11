// lib/sales_report_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'providers/sales_report_provider.dart';
import 'custom_bottom_nav_bar.dart';
import 'widgets/items_table_widget.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // FIXED: Initialize provider properly after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }


  Future<void> _initializeProvider() async {
    if (_isInitialized) return;

    _isInitialized = true;
    final provider = Provider.of<SalesReportProvider>(context, listen: false);
    provider.setCurrentTab(0);

    await provider.initialize();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showPinDialog(BuildContext context) {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
              Text(
                'Enter PIN',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
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
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  counterText: '',
                ),
                onSubmitted: (pin) => _validatePin(context, pin),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _cancelPin(context),
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
                      onPressed: () => _validatePin(context, _pinController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Submit',
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

  void _validatePin(BuildContext context, String pin) {
    if (pin == '2840') {
      Navigator.of(context).pop();
      Provider.of<SalesReportProvider>(context, listen: false).validatePin(pin);
    } else {
      _showErrorMessage('Invalid PIN');
      _pinController.clear();
    }
  }

  void _cancelPin(BuildContext context) {
    Navigator.of(context).pop();
    Provider.of<SalesReportProvider>(context, listen: false).setCurrentTab(0);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesReportProvider>(
      builder: (context, provider, child) {
        // Show PIN dialog when required
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.isPinRequired) {
            _showPinDialog(context);
          }
        });

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Add Back Button Header
                    _buildHeader(),

                    // Tab Navigation
                    _buildTabNavigation(provider),

                    // Content based on current tab
                    Expanded(
                      child: _buildTabContent(provider),
                    ),
                  ],
                ),
              ),

              // Blur overlay when PIN is required
              if (provider.isPinRequired)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
            ],
          ),
          // Remove bottomNavigationBar completely
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
          // Sales Report title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Sales Report',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Empty space to balance the layout
          const SizedBox(width: 52), // Same width as back button + padding
        ],
      ),
    );
  }

  Widget _buildTabNavigation(SalesReportProvider provider) {
    final tabs = [
      "Today's Report",
      "Daily Report",
      "Weekly Report",
      "Monthly Report",
      "Drivers Report",
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isSelected = provider.currentTabIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setCurrentTab(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 11,
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

  Widget _buildTabContent(SalesReportProvider provider) {
    if (provider.isPinRequired) {
      return Container(); // Empty when PIN required
    }

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (provider.currentTabIndex) {
      case 0:
        return _buildTodaysReport(provider);
      case 1:
        return _buildDailyReport(provider);
      case 2:
        return _buildWeeklyReport(provider);
      case 3:
        return _buildMonthlyReport(provider);
      case 4:
        return _buildDriverReport(provider);
      default:
        return Container();
    }
  }

  Widget _buildTodaysReport(SalesReportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Today's Report Title
          _buildReportTitle("Today's Report"),
          const SizedBox(height: 20),

          // Filters
          _buildFilters(provider),
          const SizedBox(height: 20),

          // Main Content
          _buildMainContent(provider),
          const SizedBox(height: 20),

          // Items section
          _buildItemsSection(provider),
        ],
      ),
    );
  }

  Widget _buildDailyReport(SalesReportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Date selector and action buttons
          _buildDateSelector(provider),
          const SizedBox(height: 20),

          // Daily Report Title
          _buildReportTitle("Daily Report"),
          const SizedBox(height: 20),

          // Filters
          _buildFilters(provider),
          const SizedBox(height: 20),

          // Main Content
          _buildMainContent(provider),
          const SizedBox(height: 20),

          // Items section
          _buildItemsSection(provider),
        ],
      ),
    );
  }

  Widget _buildWeeklyReport(SalesReportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Year and Week selector with action buttons
          _buildWeekSelector(provider),
          const SizedBox(height: 20),

          // Weekly Report Title
          _buildReportTitle("Weekly Report"),
          const SizedBox(height: 20),

          // Filters
          _buildFilters(provider),
          const SizedBox(height: 20),

          // Main Content
          _buildMainContent(provider),
          const SizedBox(height: 20),

          // Items section
          _buildItemsSection(provider),
        ],
      ),
    );
  }

  Widget _buildMonthlyReport(SalesReportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Year and Month selector with action buttons
          _buildMonthSelector(provider),
          const SizedBox(height: 20),

          // Monthly Report Title
          _buildReportTitle("Monthly Report"),
          const SizedBox(height: 20),

          // Filters
          _buildFilters(provider),
          const SizedBox(height: 20),

          // Main Content
          _buildMainContent(provider),
          const SizedBox(height: 20),

          // Items section
          _buildItemsSection(provider),
        ],
      ),
    );
  }

  Widget _buildDriverReport(SalesReportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Date selector for driver report
          _buildDriverDateSelector(provider),
          const SizedBox(height: 40),

          // Driver Reports Content
          _buildDriverReportContent(provider),
        ],
      ),
    );
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

  Widget _buildDateSelector(SalesReportProvider provider) {
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
          provider.isGeneratingPdf ? 'Generating...' : 'Download PDF',
          provider.isGeneratingPdf ? null : () => _downloadPdf(context, provider),
        ),
      ],
    );
  }

  Widget _buildWeekSelector(SalesReportProvider provider) {
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
          'Week No.:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),

        // Week selector with increment/decrement buttons
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrease week button
              InkWell(
                onTap: () {
                  if (provider.selectedWeek > 1) {
                    provider.setSelectedWeek(provider.selectedWeek - 1);
                  } else if (provider.selectedYear > 2020) {
                    // Go to previous year, last week (52 or 53)
                    provider.setSelectedYear(provider.selectedYear - 1);
                    provider.setSelectedWeek(52); // Most years have 52 weeks
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: (provider.selectedWeek > 1 || provider.selectedYear > 2020)
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ),

              // Week number display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: Text(
                  provider.selectedWeek.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              // Increase week button
              InkWell(
                onTap: () {
                  final currentYear = DateTime.now().year;
                  final currentWeek = _getWeekNumber(DateTime.now());

                  if (provider.selectedYear < currentYear) {
                    // Not current year, can go up to week 52
                    if (provider.selectedWeek < 52) {
                      provider.setSelectedWeek(provider.selectedWeek + 1);
                    } else {
                      // Go to next year, week 1
                      provider.setSelectedYear(provider.selectedYear + 1);
                      provider.setSelectedWeek(1);
                    }
                  } else if (provider.selectedYear == currentYear) {
                    // Current year, can't go beyond current week
                    if (provider.selectedWeek < currentWeek) {
                      provider.setSelectedWeek(provider.selectedWeek + 1);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: _canIncreaseWeek(provider)
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 15),
        _buildActionButton('Get Report', () => provider.loadWeeklyReport()),
        const SizedBox(width: 10),
        _buildActionButton(
          provider.isGeneratingPdf ? 'Generating...' : 'Download PDF',
          provider.isGeneratingPdf ? null : () => _downloadPdf(context, provider),
        ),
      ],
    );
  }

// Helper method to check if week can be increased
  bool _canIncreaseWeek(SalesReportProvider provider) {
    final currentYear = DateTime.now().year;
    final currentWeek = _getWeekNumber(DateTime.now());

    if (provider.selectedYear < currentYear) {
      return provider.selectedWeek < 52;
    } else if (provider.selectedYear == currentYear) {
      return provider.selectedWeek < currentWeek;
    }
    return false;
  }

// Helper method to get week number (same as in provider)
  static int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(date.difference(DateTime(date.year, 1, 1)).inDays.toString()) + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
  Widget _buildMonthSelector(SalesReportProvider provider) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
              items: months.asMap().entries.map((entry) {
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
          provider.isGeneratingPdf ? 'Generating...' : 'Download PDF',
          provider.isGeneratingPdf ? null : () => _downloadPdf(context, provider),
        ),
      ],
    );
  }

  Widget _buildDriverDateSelector(SalesReportProvider provider) {
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
          provider.isGeneratingPdf ? 'Generating...' : 'Download PDF',
          provider.isGeneratingPdf ? null : () => _downloadPdf(context, provider),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, SalesReportProvider provider) async {
    final date = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      provider.setSelectedDate(date);
    }
  }

  Widget _buildActionButton(String text, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? Colors.black : Colors.grey.shade400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, SalesReportProvider provider) async {
    try {
      await provider.generatePdf();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF generated and shared successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate PDF: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // FIXED: Get dynamic filter options from API data
  List<String> _getSourceOptions(SalesReportProvider provider) {
    return provider.getAvailableSourceOptions();
  }

  List<String> _getPaymentOptions(SalesReportProvider provider) {
    return provider.getAvailablePaymentOptions();
  }

  List<String> _getOrderTypeOptions(SalesReportProvider provider) {
    return provider.getAvailableOrderTypeOptions();
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
    // Ensure current value is in options, if not reset to 'All'
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
              items: options.map((option) {
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

  Widget _buildMainContent(SalesReportProvider provider) {
    // Show loading indicator while data is being fetched
    if (provider.isLoading) {
      return Container(
        height: 300,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final report = provider.getCurrentReport();

    // Show no data message only after loading is complete and no data is available
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Summary
        Expanded(
          flex: 1,
          child: _buildSummaryCard(provider),
        ),
        const SizedBox(width: 20),
        // Right side - Charts
        Expanded(
          flex: 2,
          child: _buildChartsSection(provider),
        ),
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
          _buildSummaryItem('Period:', _getPeriodText(provider, report), Colors.purple),
          _buildSummaryItem('Total Sales Amount:', _getFormattedAmount(report?['total_sales'] ?? report?['total_sales_amount']), Colors.purple),
          if (report?['total_orders_placed'] != null)
            _buildSummaryItem('Total Orders Placed:', report!['total_orders_placed'].toString(), Colors.purple),
          _buildSummaryItem('Sales Growth (vs. Last Week):', _getGrowthText(report), Colors.purple),
          _buildSummaryItem('Sales Growth (vs. Last Week):', _getGrowthAmount(report), Colors.purple),
          _buildSummaryItem('Most Sold Item:', _getMostSoldItem(report), Colors.purple),
          if (provider.currentTabIndex != 4)
            _buildSummaryItem('Most Sold Category:', _getMostSoldCategory(report), Colors.purple),
          _buildSummaryItem('Most Delivered Area:', _getMostDeliveredArea(report), Colors.purple),
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
            Expanded(
              child: _buildGrowthChart(report),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildPaymentMethodsChart(report),
            ),
          ],
        ),
        const SizedBox(height: 30),
        // Bottom row charts
        Row(
          children: [
            Expanded(
              child: _buildOrderTypesChart(report),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildOrderSourcesChart(report),
            ),
          ],
        ),
      ],
    );
  }

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
              color: const Color(0xFF40E0D0), // Cyan/Turquoise color
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
    final paymentTypes = report?['sales_by_payment_type'] as List<dynamic>? ?? [];

    // Get actual payment type names from data
    final paymentLabels = paymentTypes
        .where((payment) => payment is Map && payment['payment_type'] != null)
        .map((payment) => payment['payment_type'].toString().toUpperCase())
        .where((label) => label.isNotEmpty)
        .toList();

    // Use actual labels or defaults
    final labels = paymentLabels.isNotEmpty ? paymentLabels : ['CARD', 'CASH', 'COD'];

    // Generate colors dynamically based on number of payment types
    final colors = <Color>[];
    final baseColors = [
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF40E0D0), // Cyan
      const Color(0xFF6C5CE7), // Purple
      const Color(0xFF00B894), // Green
      const Color(0xFFFFD93D), // Yellow
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
            painter: PieChartPainter(
              data: paymentData,
              colors: colors,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildChartLegend([
          for (int i = 0; i < labels.length && i < colors.length; i++)
            {
              'label': labels[i],
              'color': colors[i],
            },
        ]),
      ],
    );
  }

  Widget _buildOrderTypesChart(Map<String, dynamic>? report) {
    final orderTypeData = _getOrderTypesData(report);
    final orderTypes = _getOrderTypeLabels(report);

    // Generate colors dynamically
    const colors = [
      Color(0xFF6C5CE7), // Purple
      Color(0xFFA29BFE), // Light purple
      Color(0xFF74B9FF), // Blue
      Color(0xFF81ECEC), // Light cyan
      Color(0xFFFFD93D), // Yellow
      Color(0xFFFF6B6B), // Red
      Color(0xFF00B894), // Green
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

    // Generate colors dynamically
    const colors = [
      Color(0xFF00B894), // Green
      Color(0xFF00CEC9), // Teal
      Color(0xFF74B9FF), // Blue
      Color(0xFF6C5CE7), // Purple
      Color(0xFFFF6B6B), // Red
      Color(0xFFFFD93D), // Yellow
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
      children: items.map((item) {
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
              ElevatedButton(
                onPressed: provider.toggleShowItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ],
          ),
        ),

        // Show items table when toggled
        if (provider.showItems) ...[
          const SizedBox(height: 20),
          ItemsTableWidget(report: provider.getCurrentReport()),
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
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
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
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
            ),
            child: Row(
              children: headers.map((header) {
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: rowData.map((cellData) {
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

  // FIXED: Helper methods for data processing based on actual API structure
  String _getPeriodText(SalesReportProvider provider, Map<String, dynamic>? report) {
    if (report == null) return 'N/A';

    switch (provider.currentTabIndex) {
      case 0:
        return report['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      case 1:
        return report['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(provider.selectedDate);
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

  List<double> _getPaymentMethodsData(Map<String, dynamic>? report) {
    if (report == null) return [0.5, 0.5];

    final paymentTypes = report['sales_by_payment_type'] as List<dynamic>?;
    if (paymentTypes == null || paymentTypes.isEmpty) return [0.5, 0.5];

    final Map<String, double> paymentAmounts = {};
    double totalAmount = 0;

    // Process all payment types
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

    // Convert to list of percentages
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
      final amount = double.tryParse(orderType['total']?.toString() ?? '0') ?? 0;
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
        .where((orderType) => orderType is Map && orderType['order_type'] != null)
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
      Color(0xFF6C5CE7), // Purple
      Color(0xFFA29BFE), // Light purple
      Color(0xFF74B9FF), // Blue
      Color(0xFF81ECEC), // Light cyan
      Color(0xFFFFD93D), // Yellow
      Color(0xFFFF6B6B), // Red
      Color(0xFF00B894), // Green
    ];

    return labels.asMap().entries.map((entry) {
      final index = entry.key;
      final label = entry.value;
      return {
        'label': label,
        'color': colors[index % colors.length],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getSourceLegend(List<String> labels) {
    const colors = [
      Color(0xFF00B894), // Green
      Color(0xFF00CEC9), // Teal
      Color(0xFF74B9FF), // Blue
      Color(0xFF6C5CE7), // Purple
      Color(0xFFFF6B6B), // Red
      Color(0xFFFFD93D), // Yellow
    ];

    return labels.asMap().entries.map((entry) {
      final index = entry.key;
      final label = entry.value;
      return {
        'label': label,
        'color': colors[index % colors.length],
      };
    }).toList();
  }
}

// Custom Painters for Charts
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
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
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

  PieChartPainter({
    required this.data,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length && i < colors.length; i++) {
      final sweepAngle = 2 * math.pi * data[i];
      final paint = Paint()
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