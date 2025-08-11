// lib/services/pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndShareSalesReport({
    required String reportType,
    required Map<String, dynamic> reportData,
    required Map<String, String> filters,
    String? selectedDate,
    int? selectedYear,
    int? selectedWeek,
    int? selectedMonth,
  }) async {
    try {
      final pdf = pw.Document();

      // Add pages to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            _buildHeader(reportType, selectedDate, selectedYear, selectedWeek, selectedMonth),
            pw.SizedBox(height: 20),
            _buildFiltersSection(filters),
            pw.SizedBox(height: 20),
            _buildSummarySection(reportData),
            pw.SizedBox(height: 20),
            _buildChartsDataSection(reportData),
            pw.SizedBox(height: 20),
            _buildItemsSection(reportData),
          ],
        ),
      );

      // Save and share PDF using printing library
      await _saveAndSharePdf(pdf, reportType);
    } catch (e) {
      print('Error generating PDF: $e');
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static Future<void> generateAndShareDriverReport({
    required Map<String, dynamic> reportData,
    required String selectedDate,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            _buildDriverReportHeader(selectedDate),
            pw.SizedBox(height: 20),
            _buildDriverDeliveryLocationsTable(reportData),
            pw.SizedBox(height: 30),
            _buildDriverOrderSummaryTable(reportData),
          ],
        ),
      );

      await _saveAndSharePdf(pdf, 'Driver Report');
    } catch (e) {
      print('Error generating driver report PDF: $e');
      throw Exception('Failed to generate driver report PDF: $e');
    }
  }

  static pw.Widget _buildHeader(
      String reportType,
      String? selectedDate,
      int? selectedYear,
      int? selectedWeek,
      int? selectedMonth,
      ) {
    String periodText = '';

    switch (reportType) {
      case "Today's Report":
        periodText = 'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
        break;
      case 'Daily Report':
        periodText = 'Date: ${selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now())}';
        break;
      case 'Weekly Report':
        periodText = 'Year: ${selectedYear ?? DateTime.now().year}, Week: ${selectedWeek ?? _getWeekNumber(DateTime.now())}';
        break;
      case 'Monthly Report':
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        final monthName = months[(selectedMonth ?? DateTime.now().month) - 1];
        periodText = 'Year: ${selectedYear ?? DateTime.now().year}, Month: $monthName';
        break;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'THE VILLAGE RESTAURANT',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          reportType,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          periodText,
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDriverReportHeader(String selectedDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'THE VILLAGE RESTAURANT',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Driver Report',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Date: $selectedDate',
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFiltersSection(Map<String, String> filters) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Applied Filters',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Source: ${filters['source'] ?? 'All'}'),
              ),
              pw.Expanded(
                child: pw.Text('Payment: ${filters['payment'] ?? 'All'}'),
              ),
              pw.Expanded(
                child: pw.Text('Order Type: ${filters['orderType'] ?? 'All'}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(Map<String, dynamic> reportData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildSummaryRow('Period:', _getPeriodText(reportData)),
          _buildSummaryRow('Total Sales Amount:', _getFormattedAmount(reportData['total_sales'] ?? reportData['total_sales_amount'])),
          if (reportData['total_orders_placed'] != null)
            _buildSummaryRow('Total Orders Placed:', reportData['total_orders_placed'].toString()),
          _buildSummaryRow('Sales Growth (%):', _getGrowthText(reportData)),
          _buildSummaryRow('Sales Growth (Amount):', _getGrowthAmount(reportData)),
          _buildSummaryRow('Most Sold Item:', _getMostSoldItem(reportData)),
          if (reportData['most_sold_type'] != null)
            _buildSummaryRow('Most Sold Category:', _getMostSoldCategory(reportData)),
          _buildSummaryRow('Most Delivered Area:', _getMostDeliveredArea(reportData)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildChartsDataSection(Map<String, dynamic> reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Breakdown by Categories',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 15),

        // Payment Methods Data
        _buildDataTable(
          'Payment Methods',
          ['Payment Type', 'Count', 'Total Amount'],
          _getPaymentMethodsTableData(reportData),
        ),
        pw.SizedBox(height: 15),

        // Order Types Data
        _buildDataTable(
          'Order Types',
          ['Order Type', 'Count', 'Total Amount'],
          _getOrderTypesTableData(reportData),
        ),
        pw.SizedBox(height: 15),

        // Order Sources Data
        _buildDataTable(
          'Order Sources',
          ['Source', 'Count', 'Total Amount'],
          _getOrderSourcesTableData(reportData),
        ),
      ],
    );
  }

  static pw.Widget _buildDataTable(String title, List<String> headers, List<List<String>> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: headers.map((header) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
              ).toList(),
            ),
            // Data rows
            ...rows.map((row) =>
                pw.TableRow(
                  children: row.map((cell) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cell),
                      ),
                  ).toList(),
                ),
            ).toList(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsSection(Map<String, dynamic> reportData) {
    final items = reportData['all_items_sold'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      return pw.Text('No items sold during this period.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'All Items Sold (${items.length} items)',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                'Item Name',
                'Type',
                'Qty Sold',
                'Total Sales',
                'Orders'
              ].map((header) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ).toList(),
            ),
            // Data rows
            ...items.take(20).map((item) => // Limit to first 20 items for PDF
            pw.TableRow(
              children: [
                item['item_name']?.toString().toUpperCase() ?? 'N/A',
                _formatType(item['type']?.toString() ?? ''),
                item['total_quantity_sold']?.toString() ?? '0',
                _formatCurrency(item['total_item_sales']),
                item['orders_containing_item']?.toString() ?? '0',
              ].map((cell) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      cell,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
              ).toList(),
            ),
            ).toList(),
          ],
        ),
        if (items.length > 20)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Note: Only showing first 20 items. Total items: ${items.length}',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildDriverDeliveryLocationsTable(Map<String, dynamic> reportData) {
    final locations = reportData['driver_delivery_locations'] as List<dynamic>? ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Driver Delivery Locations',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        if (locations.isEmpty)
          pw.Text('No delivery locations found.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  'Driver Name',
                  'Street Address',
                  'City',
                  'County'
                ].map((header) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                ).toList(),
              ),
              // Data rows
              ...locations.map((location) =>
                  pw.TableRow(
                    children: [
                      location['driver_name']?.toString() ?? 'N/A',
                      location['street_address']?.toString() ?? 'N/A',
                      location['city']?.toString() ?? 'N/A',
                      location['county']?.toString() ?? 'N/A',
                    ].map((cell) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(cell),
                        ),
                    ).toList(),
                  ),
              ).toList(),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildDriverOrderSummaryTable(Map<String, dynamic> reportData) {
    final summary = reportData['driver_order_summary'] as List<dynamic>? ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Driver Order Summary',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        if (summary.isEmpty)
          pw.Text('No driver orders found.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  'Driver Name',
                  'Total Orders'
                ].map((header) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                ).toList(),
              ),
              // Data rows
              ...summary.map((driver) =>
                  pw.TableRow(
                    children: [
                      driver['driver_name']?.toString() ?? 'N/A',
                      driver['total_orders']?.toString() ?? '0',
                    ].map((cell) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(cell),
                        ),
                    ).toList(),
                  ),
              ).toList(),
            ],
          ),
      ],
    );
  }

  static Future<void> _saveAndSharePdf(pw.Document pdf, String reportType) async {
    try {
      final Uint8List bytes = await pdf.save();
      final String fileName = '${reportType.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      // Use printing library to share the PDF
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
        subject: reportType,
      );
    } catch (e) {
      print('Error saving and sharing PDF: $e');
      throw Exception('Failed to save and share PDF: $e');
    }
  }

  // Helper methods
  static String _getPeriodText(Map<String, dynamic> reportData) {
    return reportData['date'] ??
        (reportData['period'] != null
            ? '${reportData['period']['from']} ~ ${reportData['period']['to']}'
            : DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  static String _getFormattedAmount(dynamic amount) {
    if (amount == null) return '£0.00';
    return '£${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? '0.00'}';
  }

  static String _formatCurrency(dynamic amount) {
    if (amount == null) return '£0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '£${value.toStringAsFixed(2)}';
  }

  static String _getGrowthText(Map<String, dynamic> reportData) {
    final growth = reportData['sales_growth_percentage'];
    if (growth == null) return 'N/A';
    final isPositive = growth >= 0;
    return '${isPositive ? '+' : ''}${growth.toStringAsFixed(2)}%';
  }

  static String _getGrowthAmount(Map<String, dynamic> reportData) {
    final increase = reportData['sales_increase'];
    if (increase == null) return 'N/A';
    final isPositive = increase >= 0;
    return '${isPositive ? '+' : ''}${_formatCurrency(increase)}';
  }

  static String _getMostSoldItem(Map<String, dynamic> reportData) {
    final item = reportData['most_selling_item'] ?? reportData['most_sold_item'];
    if (item == null) return 'N/A';
    final name = item['item_name'] ?? 'Unknown';
    final quantity = item['quantity_sold'] ?? '0';
    return '$name ($quantity sold)';
  }

  static String _getMostSoldCategory(Map<String, dynamic> reportData) {
    final category = reportData['most_sold_type'];
    if (category == null) return 'N/A';
    final type = category['type'] ?? 'Unknown';
    final quantity = category['quantity_sold'] ?? '0';
    return '$type ($quantity sold)';
  }

  static String _getMostDeliveredArea(Map<String, dynamic> reportData) {
    final area = reportData['most_delivered_postal_code'];
    if (area == null) return 'N/A';
    final postalCode = area['postal_code'] ?? 'Unknown';
    final deliveries = area['delivery_count'] ?? '0';
    return '$postalCode ($deliveries deliveries)';
  }

  static String _formatType(String type) {
    if (type.isEmpty) return 'N/A';
    return type.substring(0, 1).toUpperCase() + type.substring(1).toLowerCase();
  }

  static List<List<String>> _getPaymentMethodsTableData(Map<String, dynamic> reportData) {
    final paymentTypes = reportData['sales_by_payment_type'] as List<dynamic>? ?? [];
    return paymentTypes.map((payment) => [
      payment['payment_type']?.toString().toUpperCase() ?? 'N/A',
      payment['count']?.toString() ?? '0',
      _formatCurrency(payment['total']),
    ]).toList();
  }

  static List<List<String>> _getOrderTypesTableData(Map<String, dynamic> reportData) {
    final orderTypes = reportData['sales_by_order_type'] as List<dynamic>? ?? [];
    return orderTypes.map((orderType) => [
      orderType['order_type']?.toString().toUpperCase() ?? 'N/A',
      orderType['count']?.toString() ?? '0',
      _formatCurrency(orderType['total']),
    ]).toList();
  }

  static List<List<String>> _getOrderSourcesTableData(Map<String, dynamic> reportData) {
    final sources = reportData['sales_by_order_source'] as List<dynamic>? ?? [];
    return sources.map((source) => [
      source['source']?.toString().toUpperCase() ?? 'N/A',
      source['count']?.toString() ?? '0',
      _formatCurrency(source['total']),
    ]).toList();
  }

  static int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(date.difference(DateTime(date.year, 1, 1)).inDays.toString()) + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}