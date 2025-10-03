// lib/providers/sales_report_provider.dart (Updated)

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/thermal_printer_service.dart';
import 'package:epos/services/uk_time_service.dart';

class SalesReportProvider with ChangeNotifier {
  // Current tab index
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;
  bool _isThermalPrinting = false;
  bool get isThermalPrinting => _isThermalPrinting;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isGeneratingPdf = false;
  bool get isGeneratingPdf => _isGeneratingPdf;

  // Data storage
  Map<String, dynamic>? _todaysReport;
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;
  Map<String, dynamic>? _monthlyReport;
  Map<String, dynamic>? _driverReport;

  Map<String, dynamic>? get todaysReport => _todaysReport;
  Map<String, dynamic>? get dailyReport => _dailyReport;
  Map<String, dynamic>? get weeklyReport => _weeklyReport;
  Map<String, dynamic>? get monthlyReport => _monthlyReport;
  Map<String, dynamic>? get driverReport => _driverReport;

  // Filter states - Start with defaults that work with API
  String _sourceFilter = 'All';
  String _paymentFilter = 'All';
  String _orderTypeFilter = 'All';

  String get sourceFilter => _sourceFilter;
  String get paymentFilter => _paymentFilter;
  String get orderTypeFilter => _orderTypeFilter;

  // Date/Time selections
  DateTime _selectedDate = UKTimeService.now();
  int _selectedYear = UKTimeService.now().year;
  int _selectedWeek = _getWeekNumber(UKTimeService.now());
  int _selectedMonth = UKTimeService.now().month;

  DateTime get selectedDate => _selectedDate;
  int get selectedYear => _selectedYear;
  int get selectedWeek => _selectedWeek;
  int get selectedMonth => _selectedMonth;

  // Items visibility
  bool _showItems = false;
  bool get showItems => _showItems;

  // Paid Outs visibility
  bool _showPaidOuts = false;
  bool get showPaidOuts => _showPaidOuts;

  // Postal Codes visibility
  bool _showPostalCodes = false;
  bool get showPostalCodes => _showPostalCodes;

  // Error handling
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Initialization flag to ensure data loads immediately
  bool _isInitialized = false;

  // Helper method to calculate week number
  static int _getWeekNumber(DateTime date) {
    int dayOfYear =
        int.parse(
          date.difference(DateTime(date.year, 1, 1)).inDays.toString(),
        ) +
        1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // Initialization method to be called from screen
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing SalesReportProvider...');
    _isInitialized = true;

    // Load today's report immediately for default tab
    if (_currentTabIndex == 0) {
      await loadTodaysReport();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setCurrentTab(int index) {
    if (_currentTabIndex == index) return;

    print('📊 Switching to tab $index');
    _currentTabIndex = index;
    _showItems = false;
    _showPaidOuts = false;
    _showPostalCodes = false;
    _errorMessage = null;

    // UPDATED: No PIN requirement, direct access to all tabs
    notifyListeners();

    // Load appropriate data immediately when switching tabs
    if (_isInitialized) {
      switch (index) {
        case 0:
          loadTodaysReport();
          break;
        case 1:
          loadDailyReport();
          break;
        case 2:
          loadWeeklyReport();
          break;
        case 3:
          loadMonthlyReport();
          break;
        case 4:
          loadDriverReport();
          break;
      }
    }
  }

  // REMOVED: validatePin method as PIN is handled at screen level

  void setFilters({String? source, String? payment, String? orderType}) {
    bool needsRefresh = false;

    if (source != null && source != _sourceFilter) {
      _sourceFilter = source;
      needsRefresh = true;
      print('🔍 Source filter changed to: $source');
    }

    if (payment != null && payment != _paymentFilter) {
      _paymentFilter = payment;
      needsRefresh = true;
      print('🔍 Payment filter changed to: $payment');
    }

    if (orderType != null && orderType != _orderTypeFilter) {
      _orderTypeFilter = orderType;
      needsRefresh = true;
      print('🔍 Order type filter changed to: $orderType');
    }

    if (needsRefresh) {
      print('🔄 Applying filters and refreshing data...');
      notifyListeners();
      // Immediate refresh with new filters
      _refreshCurrentReportWithFilters();
    }
  }

  // Method to refresh with filters applied
  Future<void> _refreshCurrentReportWithFilters() async {
    if (_isLoading) return;

    switch (_currentTabIndex) {
      case 0:
        await loadTodaysReport();
        break;
      case 1:
        await loadDailyReport();
        break;
      case 2:
        await loadWeeklyReport();
        break;
      case 3:
        await loadMonthlyReport();
        break;
      case 4:
        await loadDriverReport(); // Driver report doesn't use filters
        break;
    }
  }

  // Date/Time setters
  void setSelectedDate(DateTime date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      notifyListeners();
    }
  }

  void setSelectedYear(int year) {
    if (_selectedYear != year) {
      _selectedYear = year;
      notifyListeners();
    }
  }

  void setSelectedWeek(int week) {
    if (_selectedWeek != week) {
      _selectedWeek = week;
      notifyListeners();
    }
  }

  void setSelectedMonth(int month) {
    if (_selectedMonth != month) {
      _selectedMonth = month;
      notifyListeners();
    }
  }

  // Toggle items visibility
  void toggleShowItems() {
    _showItems = !_showItems;
    notifyListeners();
  }

  // Toggle paid outs visibility
  void toggleShowPaidOuts() {
    _showPaidOuts = !_showPaidOuts;
    notifyListeners();
  }

  // Toggle postal codes visibility
  void toggleShowPostalCodes() {
    _showPostalCodes = !_showPostalCodes;
    notifyListeners();
  }

  Future<void> loadTodaysReport() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        '🔄 Loading today\'s report with filters - Source: $_sourceFilter, Payment: $_paymentFilter, OrderType: $_orderTypeFilter',
      );

      // Convert filter values for API - match exact case from dropdown
      final sourceParam = _sourceFilter != 'All' ? _sourceFilter : null;
      final paymentParam = _paymentFilter != 'All' ? _paymentFilter : null;
      final orderTypeParam =
          _orderTypeFilter != 'All' ? _orderTypeFilter : null;

      final report = await ApiService.getTodaysReport(
        source: sourceParam,
        payment: paymentParam,
        orderType: orderTypeParam,
      );
      print('✅ Today\'s report loaded with filters');

      _todaysReport = report;
      print('📊 Today\'s report data keys: ${report.keys.toList()}');
    } catch (e) {
      _errorMessage = 'Failed to load today\'s report: ${e.toString()}';
      print('❌ Error loading today\'s report: $e');
      _todaysReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDailyReport() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        '🔄 Loading daily report for ${DateFormat('yyyy-MM-dd').format(_selectedDate)} with filters',
      );

      final sourceParam = _sourceFilter != 'All' ? _sourceFilter : null;
      final paymentParam = _paymentFilter != 'All' ? _paymentFilter : null;
      final orderTypeParam =
          _orderTypeFilter != 'All' ? _orderTypeFilter : null;

      final report = await ApiService.getDailyReport(
        _selectedDate,
        source: sourceParam,
        payment: paymentParam,
        orderType: orderTypeParam,
      );
      print('✅ Daily report loaded with filters');

      _dailyReport = report;
    } catch (e) {
      _errorMessage = 'Failed to load daily report: ${e.toString()}';
      print('❌ Error loading daily report: $e');
      _dailyReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWeeklyReport() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 Loading weekly report for Date: $_selectedDate with filters');

      final sourceParam = _sourceFilter != 'All' ? _sourceFilter : null;
      final paymentParam = _paymentFilter != 'All' ? _paymentFilter : null;
      final orderTypeParam =
          _orderTypeFilter != 'All' ? _orderTypeFilter : null;

      final report = await ApiService.getWeeklyReport(
        _selectedDate, // Changed from (_selectedYear, _selectedWeek) to (_selectedDate)
        source: sourceParam,
        payment: paymentParam,
        orderType: orderTypeParam,
      );
      print('✅ Weekly report loaded with filters');

      _weeklyReport = report;
    } catch (e) {
      _errorMessage = 'Failed to load weekly report: ${e.toString()}';
      print('❌ Error loading weekly report: $e');
      _weeklyReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonthlyReport() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        '🔄 Loading monthly report for Year: $_selectedYear, Month: $_selectedMonth with filters',
      );

      final sourceParam = _sourceFilter != 'All' ? _sourceFilter : null;
      final paymentParam = _paymentFilter != 'All' ? _paymentFilter : null;
      final orderTypeParam =
          _orderTypeFilter != 'All' ? _orderTypeFilter : null;

      final report = await ApiService.getMonthlyReport(
        _selectedYear,
        _selectedMonth,
        source: sourceParam,
        payment: paymentParam,
        orderType: orderTypeParam,
      );
      print('✅ Monthly report loaded with filters');

      _monthlyReport = report;
    } catch (e) {
      _errorMessage = 'Failed to load monthly report: ${e.toString()}';
      print('❌ Error loading monthly report: $e');
      _monthlyReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDriverReport() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        '🔄 Loading driver report for ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );

      final report = await ApiService.getDriverReport(_selectedDate);

      _driverReport = report;
      print('✅ Driver report loaded successfully');
    } catch (e) {
      _errorMessage = 'Failed to load driver report: ${e.toString()}';
      print('❌ Error loading driver report: $e');
      _driverReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get current report data
  Map<String, dynamic>? getCurrentReport() {
    switch (_currentTabIndex) {
      case 0:
        return _todaysReport;
      case 1:
        return _dailyReport;
      case 2:
        return _weeklyReport;
      case 3:
        return _monthlyReport;
      case 4:
        return _driverReport;
      default:
        return null;
    }
  }

  // Get current report title
  String getReportTitle() {
    switch (_currentTabIndex) {
      case 0:
        return "Today's Report";
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

  Future<void> printThermalReport() async {
    final currentReport = getCurrentReport();
    if (currentReport == null) {
      throw Exception(
        'No report data available for printing. Please load the report first.',
      );
    }

    if (_isThermalPrinting) {
      print('⚠️ Thermal printing already in progress');
      return;
    }

    _isThermalPrinting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final filters = {
        'source': _sourceFilter,
        'payment': _paymentFilter,
        'orderType': _orderTypeFilter,
      };

      String? selectedDateString;
      int? selectedYearValue;
      int? selectedWeekValue;
      int? selectedMonthValue;

      // Prepare parameters based on current tab
      switch (_currentTabIndex) {
        case 0: // Today's Report
          selectedDateString = DateFormat(
            'yyyy-MM-dd',
          ).format(UKTimeService.now());
          break;
        case 1: // Daily Report
          selectedDateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
          break;
        case 2: // Weekly Report
          selectedYearValue = _selectedYear;
          selectedWeekValue = _selectedWeek;
          break;
        case 3: // Monthly Report
          selectedYearValue = _selectedYear;
          selectedMonthValue = _selectedMonth;
          break;
        case 4: // Driver Report
          selectedDateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
          break;
        default:
          throw Exception('Invalid report type for thermal printing');
      }

      // Attempt to print the report
      bool printSuccess = false;

      try {
        printSuccess = await ThermalPrinterService()
            .printSalesReportWithUserInteraction(
              reportType: getReportTitle(),
              reportData: currentReport,
              filters: filters,
              selectedDate: selectedDateString,
              selectedYear: selectedYearValue,
              selectedWeek: selectedWeekValue,
              selectedMonth: selectedMonthValue,
              onShowMethodSelection: (availableMethods) {
                print('Available printing methods: $availableMethods');
                if (availableMethods.isEmpty ||
                    availableMethods.first == 'No printers available') {
                  _errorMessage =
                      'No thermal printers detected. Please connect a printer and try again.';
                } else {
                  _errorMessage =
                      'Printing failed on available methods: ${availableMethods.join(', ')}';
                }
              },
            );
      } catch (e) {
        printSuccess = false;

        // Handle specific error types
        String errorMessage = e.toString();
        if (errorMessage.contains('Web platform')) {
          _errorMessage =
              'Thermal printing is not supported in web browsers. Please use the mobile or desktop app.';
        } else if (errorMessage.contains('No thermal printers detected')) {
          _errorMessage =
              'No thermal printers found. Please ensure your printer is connected and powered on.';
        } else if (errorMessage.contains('not supported on this platform')) {
          _errorMessage =
              'Thermal printing is not supported on this device platform.';
        } else if (errorMessage.contains('Failed to establish')) {
          _errorMessage =
              'Could not connect to printer. Please check printer connection and try again.';
        } else if (errorMessage.contains('not connected')) {
          _errorMessage =
              'Printer connection lost. Please check printer status and try again.';
        } else {
          _errorMessage =
              'Printing failed: ${errorMessage.replaceAll('Exception: ', '')}';
        }

        print('❌ Error printing thermal report: $e');
      }

      if (printSuccess) {
        print('✅ Thermal report printed successfully');
        _errorMessage = null; // Clear any previous errors
      } else {
        // If no specific error message was set, use a generic one
        _errorMessage ??=
            'Printing failed. Please check printer connection and try again.';
        throw Exception(_errorMessage!);
      }
    } catch (e) {
      // This catch handles any exceptions thrown in the try block above
      _errorMessage ??=
          'Failed to print thermal report: ${e.toString().replaceAll('Exception: ', '')}';
      print('❌ Error in thermal report printing: $e');
      rethrow;
    } finally {
      _isThermalPrinting = false;
      notifyListeners();
    }
  }

  // UPDATED: Data validation helpers
  bool canPrintThermal() {
    return hasCurrentReportData() && !_isThermalPrinting && !_isLoading;
  }

  // Data validation helpers
  bool hasCurrentReportData() {
    final report = getCurrentReport();
    return report != null && report.isNotEmpty;
  }

  // Get items count for current report
  int getItemsCount() {
    final report = getCurrentReport();
    if (report == null) return 0;

    final items = report['all_items_sold'];
    if (items is List) return items.length;
    return 0;
  }

  List<String> getAvailableSourceOptions() {
    final report = getCurrentReport();
    final options = ['All'];

    final sources = report?['sales_by_order_source'] as List<dynamic>?;
    if (sources != null && sources.isNotEmpty) {
      final sourceNames =
          sources
              .where((source) => source is Map && source['source'] != null)
              .map((source) => source['source'].toString())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

      sourceNames.sort();
      options.addAll(sourceNames);
    }

    if (options.length == 1) {
      options.addAll(['website', 'app', 'phone']);
    }

    return options;
  }

  List<String> getAvailablePaymentOptions() {
    final report = getCurrentReport();
    final options = ['All'];

    final payments = report?['sales_by_payment_type'] as List<dynamic>?;
    if (payments != null && payments.isNotEmpty) {
      final paymentNames =
          payments
              .where(
                (payment) => payment is Map && payment['payment_type'] != null,
              )
              .map((payment) => payment['payment_type'].toString())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

      paymentNames.sort();
      options.addAll(paymentNames);
    }

    if (options.length == 1) {
      options.addAll(['cash', 'card']);
    }

    return options;
  }

  List<String> getAvailableOrderTypeOptions() {
    final report = getCurrentReport();
    final options = ['All'];

    final orderTypes = report?['sales_by_order_type'] as List<dynamic>?;
    if (orderTypes != null && orderTypes.isNotEmpty) {
      final orderTypeNames =
          orderTypes
              .where(
                (orderType) =>
                    orderType is Map && orderType['order_type'] != null,
              )
              .map((orderType) => orderType['order_type'].toString())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

      orderTypeNames.sort();
      options.addAll(orderTypeNames);
    }

    if (options.length == 1) {
      options.addAll(['delivery', 'pickup', 'dine-in']);
    }

    return options;
  }

  void resetAllData() {
    _currentTabIndex = 0;
    _isLoading = false;
    _isGeneratingPdf = false;
    _todaysReport = null;
    _dailyReport = null;
    _weeklyReport = null;
    _monthlyReport = null;
    _driverReport = null;
    _sourceFilter = 'All';
    _paymentFilter = 'All';
    _orderTypeFilter = 'All';
    _selectedDate = UKTimeService.now();
    _selectedYear = UKTimeService.now().year;
    _selectedWeek = _getWeekNumber(UKTimeService.now());
    _selectedMonth = UKTimeService.now().month;
    _showItems = false;
    _showPaidOuts = false;
    _showPostalCodes = false;
    _errorMessage = null;
    _isInitialized = false;
    notifyListeners();
  }

  // Force refresh current report (useful for pull-to-refresh)
  Future<void> refreshCurrentReport() async {
    // Clear current report data to show fresh loading state
    switch (_currentTabIndex) {
      case 0:
        _todaysReport = null;
        break;
      case 1:
        _dailyReport = null;
        break;
      case 2:
        _weeklyReport = null;
        break;
      case 3:
        _monthlyReport = null;
        break;
      case 4:
        _driverReport = null;
        break;
    }

    notifyListeners();
    await _refreshCurrentReportWithFilters();
  }

  @override
  void dispose() {
    print('🗑️ SalesReportProvider disposed');
    super.dispose();
  }
}
