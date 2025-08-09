import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'services/api_service.dart';

class SalesReportScreen extends StatefulWidget {
  final int initialBottomNavItemIndex;

  const SalesReportScreen({
    Key? key,
    this.initialBottomNavItemIndex = 5,
  }) : super(key: key);

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late int _selectedBottomNavItem;
  Map<String, dynamic>? _salesReport;
  bool _isLoadingSalesReport = false;

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    _loadSalesReport();
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

  List<PieChartSectionData> _buildPaymentTypeChartData() {
    if (_salesReport == null || _salesReport!['sales_by_payment_type'] == null) {
      return [];
    }

    final List<dynamic> paymentTypes = _salesReport!['sales_by_payment_type'];

    // Merge duplicate payment types (case insensitive)
    Map<String, double> mergedPaymentTypes = {};
    for (var item in paymentTypes) {
      String paymentType = item['payment_type'].toString().toLowerCase();
      if (paymentType.contains('cash') || paymentType.contains('card')) {
        String normalizedType = paymentType.contains('cash') ? 'Cash' : 'Card';
        double total = double.tryParse(item['total'].toString()) ?? 0.0;
        mergedPaymentTypes[normalizedType] = (mergedPaymentTypes[normalizedType] ?? 0.0) + total;
      }
    }

    final colors = [
      Colors.black,
      Colors.grey[600]!,
      Colors.grey[400]!,
      Colors.grey[300]!,
    ];

    final totalSales = mergedPaymentTypes.values.fold(0.0, (sum, total) => sum + total);

    return mergedPaymentTypes.entries.map((entry) {
      final index = mergedPaymentTypes.keys.toList().indexOf(entry.key);
      final total = entry.value;
      final percentage = totalSales > 0 ? (total / totalSales * 100) : 0.0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: total,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Future<void> _downloadSalesReportPDF() async {
    if (_salesReport == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Date: ${DateTime.now().toString().split(' ')[0]}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Sales: £${_salesReport!['total_sales']}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Payment Breakdown:',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              ...(() {
                final List<dynamic> paymentTypes = _salesReport!['sales_by_payment_type'] as List? ?? [];
                Map<String, double> mergedPaymentTypes = {};

                for (var item in paymentTypes) {
                  String paymentType = item['payment_type'].toString().toLowerCase();
                  if (paymentType.contains('cash') || paymentType.contains('card')) {
                    String normalizedType = paymentType.contains('cash') ? 'Cash' : 'Card';
                    double total = double.tryParse(item['total'].toString()) ?? 0.0;
                    mergedPaymentTypes[normalizedType] = (mergedPaymentTypes[normalizedType] ?? 0.0) + total;
                  }
                }

                return mergedPaymentTypes.entries.map((entry) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  child: pw.Text(
                    '${entry.key}: £${entry.value.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ));
              })(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Centered Header with larger size
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Sales Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoadingSalesReport
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6CE6)),
                ),
              )
                  : _salesReport == null
                  ? const Center(
                child: Text(
                  'No sales data available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Data Cards (Two sub-columns side by side)
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          // Labels Column
                          Expanded(
                            child: Column(
                              children: [
                                _buildLabelCard('Date'),
                                const SizedBox(height: 16),
                                _buildLabelCard('Total Sales'),
                                const SizedBox(height: 16),
                                // Filter and merge payment types
                                ...(() {
                                  final List<dynamic> paymentTypes = _salesReport!['sales_by_payment_type'] as List? ?? [];
                                  Map<String, double> mergedPaymentTypes = {};

                                  for (var item in paymentTypes) {
                                    String paymentType = item['payment_type'].toString().toLowerCase();
                                    if (paymentType.contains('cash') || paymentType.contains('card')) {
                                      String normalizedType = paymentType.contains('cash') ? 'Cash' : 'Card';
                                      double total = double.tryParse(item['total'].toString()) ?? 0.0;
                                      mergedPaymentTypes[normalizedType] = (mergedPaymentTypes[normalizedType] ?? 0.0) + total;
                                    }
                                  }

                                  return mergedPaymentTypes.entries.map((entry) =>
                                      Column(
                                        children: [
                                          _buildLabelCard(entry.key),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                  );
                                })(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Amounts Column
                          Expanded(
                            child: Column(
                              children: [
                                _buildAmountCard(DateTime.now().toString().split(' ')[0]),
                                const SizedBox(height: 16),
                                _buildAmountCard(_salesReport!['total_sales'].toString()),
                                const SizedBox(height: 16),
                                // Filter and merge payment amounts
                                ...(() {
                                  final List<dynamic> paymentTypes = _salesReport!['sales_by_payment_type'] as List? ?? [];
                                  Map<String, double> mergedPaymentTypes = {};

                                  for (var item in paymentTypes) {
                                    String paymentType = item['payment_type'].toString().toLowerCase();
                                    if (paymentType.contains('cash') || paymentType.contains('card')) {
                                      String normalizedType = paymentType.contains('cash') ? 'Cash' : 'Card';
                                      double total = double.tryParse(item['total'].toString()) ?? 0.0;
                                      mergedPaymentTypes[normalizedType] = (mergedPaymentTypes[normalizedType] ?? 0.0) + total;
                                    }
                                  }

                                  return mergedPaymentTypes.entries.map((entry) =>
                                      Column(
                                        children: [
                                          _buildAmountCard(entry.value.toString()),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                  );
                                })(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Right Column - Chart and Download Button
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Pie Chart without white container
                          SizedBox(
                            height: 350,
                            child: PieChart(
                              PieChartData(
                                sections: _buildPaymentTypeChartData(),
                                centerSpaceRadius: 50,
                                sectionsSpace: 3,
                                startDegreeOffset: -90,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Download Button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: ElevatedButton(
                              onPressed: _downloadSalesReportPDF,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Download',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelCard(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          color: Color(0xFFCB6CE6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAmountCard(String amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        amount.contains('£') ? amount : (amount.contains('-') ? amount : '£ $amount'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}