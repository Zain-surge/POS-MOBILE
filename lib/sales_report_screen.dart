// lib/sales_report_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'providers/sales_report_provider.dart';
import 'widgets/items_table_widget.dart';
import 'widgets/paidouts_table_widget.dart';
import 'widgets/postal_codes_table_widget.dart';
import 'package:epos/services/uk_time_service.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  Future<void> _initializeProvider() async {
    if (_isInitialized) return;

    _isInitialized = true;
    final provider = Provider.of<SalesReportProvider>(context, listen: false);
    // Set to today's report only
    provider.setCurrentTab(0);
    await provider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesReportProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Header with back button
                _buildHeader(),

                // Today's Report Content
                Expanded(child: _buildTodaysReport(provider)),
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
          // Today's Sales Report title
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
                  const Icon(Icons.today, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Sales Report",
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

  Widget _buildTodaysReport(SalesReportProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

  List<String> _getSourceOptions(SalesReportProvider provider) {
    return provider.getAvailableSourceOptions();
  }

  List<String> _getPaymentOptions(SalesReportProvider provider) {
    return provider.getAvailablePaymentOptions();
  }

  List<String> _getOrderTypeOptions(SalesReportProvider provider) {
    return provider.getAvailableOrderTypeOptions();
  }

  Widget _buildMainContent(SalesReportProvider provider) {
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
                'No data available for today',
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

    // Debug: Print report data to see what we're getting from API
    print('SalesReport: Report data keys: ${report?.keys.toList()}');
    if (report != null) {
      print('SalesReport: paidouts value: ${report['paidouts']}');
      print('SalesReport: total_discount value: ${report['total_discount']}');
    }

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
            'Date:',
            DateFormat('dd/MM/yyyy').format(UKTimeService.now()),
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
          if (_hasDiscountData(report))
            _buildSummaryItem(
              'Total Discount:',
              _getFormattedAmount(_getDiscountValue(report)),
              Colors.red,
            ),
          if (_hasPaidOutsData(report))
            _buildSummaryItem(
              'Total Paid Outs:',
              _getFormattedAmount(_getPaidOutsValue(report)),
              Colors.orange,
            ),
          // Net Sales calculation (Total Sales - Paid Outs)
          _buildSummaryItem(
            'Net Sales:',
            _getNetSalesAmount(report),
            Colors.green,
          ),
          const Divider(),
          _buildSummaryItem(
            'Sales Growth (vs. Last Week):',
            _getGrowthText(report),
            Colors.purple,
          ),
          _buildSummaryItem(
            'Growth Amount:',
            _getGrowthAmount(report),
            Colors.purple,
          ),
          _buildSummaryItem(
            'Most Sold Item:',
            _getMostSoldItem(report),
            Colors.purple,
          ),
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
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: provider.toggleShowPaidOuts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                  provider.showPaidOuts ? 'Hide Paid Outs' : 'Show Paid Outs',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: provider.toggleShowPostalCodes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                  provider.showPostalCodes ? 'Hide Postal Codes' : 'Show Postal Codes',
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

        // Show paid outs table when toggled
        if (provider.showPaidOuts) ...[
          const SizedBox(height: 20),
          PaidOutsTableWidget(report: provider.getCurrentReport()),
        ],

        // Show postal codes table when toggled
        if (provider.showPostalCodes) ...[
          const SizedBox(height: 20),
          PostalCodesTableWidget(report: provider.getCurrentReport()),
        ],
      ],
    );
  }

  // Helper methods for data processing
  String _getFormattedAmount(dynamic amount) {
    if (amount == null) return '£0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '£${value.toStringAsFixed(2)}';
  }

  String _getNetSalesAmount(Map<String, dynamic>? report) {
    if (report == null) return '£0.00';

    final totalSales =
        double.tryParse(
          (report['total_sales'] ?? report['total_sales_amount'] ?? 0)
              .toString(),
        ) ??
        0.0;
    final paidOuts = _getPaidOutsValue(report);
    final paidOutsAmount = double.tryParse(paidOuts.toString()) ?? 0.0;
    final netSales = totalSales - paidOutsAmount;

    return '£${netSales.toStringAsFixed(2)}';
  }

  bool _hasDiscountData(Map<String, dynamic>? report) {
    if (report == null) return false;

    final discountValue = _getDiscountValue(report);
    final amount = double.tryParse(discountValue.toString()) ?? 0.0;
    return amount > 0;
  }

  dynamic _getDiscountValue(Map<String, dynamic>? report) {
    if (report == null) return 0;

    // Try different possible field names for discount
    return report['total_discount'] ??
        report['discount'] ??
        report['total_discounts'] ??
        report['discounts_total'] ??
        0;
  }

  bool _hasPaidOutsData(Map<String, dynamic>? report) {
    if (report == null) return false;

    // Check if we have paidouts as a list (which is the actual API structure)
    if (report['paidouts'] is List &&
        (report['paidouts'] as List).isNotEmpty) {
      return true;
    }
    
    // Check other possible list formats
    if (report['paidouts_details'] is List &&
        (report['paidouts_details'] as List).isNotEmpty) {
      return true;
    }
    if (report['paid_outs'] is List &&
        (report['paid_outs'] as List).isNotEmpty) {
      return true;
    }
    if (report['paidouts_list'] is List &&
        (report['paidouts_list'] as List).isNotEmpty) {
      return true;
    }

    // Check if we have a total paid outs value > 0
    final paidOutsValue = _getPaidOutsValue(report);
    final amount = double.tryParse(paidOutsValue.toString()) ?? 0.0;
    return amount > 0;
  }

  dynamic _getPaidOutsValue(Map<String, dynamic>? report) {
    if (report == null) return 0;

    // If paidouts is a list (which it is according to the API), calculate total
    if (report['paidouts'] is List) {
      final paidOutsList = report['paidouts'] as List<dynamic>;
      double total = 0.0;
      for (var paidOut in paidOutsList) {
        if (paidOut is Map && paidOut['amount'] != null) {
          final amount = double.tryParse(paidOut['amount'].toString()) ?? 0.0;
          total += amount;
        }
      }
      return total;
    }

    // Try different possible field names for paid outs (fallback)
    return report['paid_outs'] ??
        report['total_paidouts'] ??
        report['paidouts_total'] ??
        0;
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
