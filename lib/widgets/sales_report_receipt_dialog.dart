// lib/widgets/sales_report_receipt_dialog.dart
//
// Thermal-style receipt PREVIEW + PRINT for the daily sales report.
// Shows payment breakdown by order source (EPOS / Website), then totals.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:flutter/foundation.dart';

// ─── Public stats model (built by the caller) ─────────────────────────────────
class SalesReceiptStats {
  final Map<String, double> eposPayments; // payment-type → amount for EPOS
  final Map<String, double> webPayments; // payment-type → amount for Website
  final double eposTotal;
  final double webTotal;
  final double totalSales;
  final double totalDiscount;
  final double paidoutsTotal;
  final double cancelledAmount;
  final double netTotal;
  final int totalOrders;
  final int completedCount;
  final int cancelledCount;
  final int pendingCount;

  const SalesReceiptStats({
    required this.eposPayments,
    required this.webPayments,
    required this.eposTotal,
    required this.webTotal,
    required this.totalSales,
    required this.totalDiscount,
    required this.paidoutsTotal,
    required this.cancelledAmount,
    required this.netTotal,
    required this.totalOrders,
    required this.completedCount,
    required this.cancelledCount,
    required this.pendingCount,
  });
}

// ─── Dialog widget ────────────────────────────────────────────────────────────
class SalesReportReceiptDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final SalesReceiptStats stats;
  /// Called when user taps Print. Should return true on success, throw on failure.
  final Future<bool> Function(String)? onPrint;

  const SalesReportReceiptDialog({
    super.key,
    required this.report,
    required this.stats,
    this.onPrint,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> report,
    required SalesReceiptStats stats,
    Future<bool> Function(String)? onPrint,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SalesReportReceiptDialog(
        report: report,
        stats: stats,
        onPrint: onPrint,
      ),
    );
  }

  @override
  State<SalesReportReceiptDialog> createState() =>
      _SalesReportReceiptDialogState();
}

class _SalesReportReceiptDialogState extends State<SalesReportReceiptDialog> {
  bool _isPrinting = false;
  String? _printResult;

  static const _width = 48;
  static const _div = '================================================';
  static const _thin = '------------------------------------------------';

  // ── Build receipt plain-text ───────────────────────────────────────────────
  String _buildReceipt() {
    final s = widget.stats;
    final now = UKTimeService.now();
    final buf = StringBuffer();

    buf.writeln(_div);
    buf.writeln(_centre('**TVP**'));
    buf.writeln(_div);
    buf.writeln('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}');
    buf.writeln(_centre('**DAILY SALES REPORT**'));
    buf.writeln(_div);
    buf.writeln('');

    // EPOS
    buf.writeln('EPOS (POS) SALES');
    buf.writeln(_thin);
    for (final e in s.eposPayments.entries) {
      buf.writeln(_row('  ${_fmtType(e.key)}:', _money(e.value)));
    }
    if (s.eposPayments.isEmpty) buf.writeln('  No EPOS orders');
    buf.writeln(_row('  EPOS Total:', _money(s.eposTotal)));
    buf.writeln('');

    // Website
    buf.writeln('WEBSITE SALES');
    buf.writeln(_thin);
    for (final e in s.webPayments.entries) {
      buf.writeln(_row('  ${_fmtType(e.key)}:', _money(e.value)));
    }
    if (s.webPayments.isEmpty) buf.writeln('  No Website orders');
    buf.writeln(_row('  Website Total:', _money(s.webTotal)));
    buf.writeln('');

    // Totals
    buf.writeln(_div);
    buf.writeln(_row('TOTAL SALES:', _money(s.totalSales)));
    buf.writeln(_thin);
    buf.writeln(_row('  Discounts:', '-${_money(s.totalDiscount)}'));
    buf.writeln(_row('  Paid Outs:', '-${_money(s.paidoutsTotal)}'));
    buf.writeln(_row('  Cancelled:', '-${_money(s.cancelledAmount)}'));
    buf.writeln(_thin);
    buf.writeln(_row('** NET TOTAL: **', _money(s.netTotal)));
    buf.writeln(_div);
    buf.writeln('');

    // Order summary
    buf.writeln('ORDER SUMMARY');
    buf.writeln(_thin);
    buf.writeln(_row('  Total Orders:', s.totalOrders.toString()));
    buf.writeln(_row('  Completed:', s.completedCount.toString()));
    buf.writeln(_row('  Cancelled:', s.cancelledCount.toString()));
    buf.writeln(_row('  Pending:', s.pendingCount.toString()));
    buf.writeln(_div);
    buf.writeln('');
    buf.writeln(_centre('Thank you!'));
    buf.writeln(_div);

    return buf.toString();
  }

  String _centre(String s) {
    final pad = ((_width - s.length) / 2).floor().clamp(0, _width);
    return '${' ' * pad}$s';
  }

  String _row(String label, String value) {
    final space = (_width - label.length - value.length).clamp(1, _width);
    return '$label${' ' * space}$value';
  }

  String _money(double v) => 'GBP ${v.toStringAsFixed(2)}';

  String _fmtType(String s) => s
      .split(RegExp(r'[_ ]'))
      .map(
        (w) =>
            w.isEmpty
                ? ''
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');

  // ── Print ──────────────────────────────────────────────────────────────────
  Future<void> _print() async {
    if (kIsWeb) {
      setState(
        () => _printResult = '⚠️ Printing not supported in the browser.',
      );
      return;
    }

    setState(() {
      _isPrinting = true;
      _printResult = null;
    });

    try {
      bool success = false;

      if (widget.onPrint != null) {
        // Delegate to the provider's printThermalReport — same path as the
        // working print button on other screens, but with our layout.
        success = await widget.onPrint!(_buildReceipt());
      } else {
        // Fallback: call the service directly with receiptOverride.
        success = await ThermalPrinterService()
            .printSalesReportWithUserInteraction(
              reportType: "Today's Report",
              reportData: widget.report,
              filters: const {
                'source': 'All',
                'payment': 'All',
                'orderType': 'All',
              },
              receiptOverride: _buildReceipt(),
              onShowMethodSelection: (methods) {
                print('Sales report dialog: available methods: $methods');
              },
            );
      }

      setState(
        () =>
            _printResult =
                success
                    ? '✅ Printed successfully!'
                    : '❌ Print failed — check printer connection.',
      );
    } catch (e) {
      setState(
        () => _printResult = '❌ ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final receipt = _buildReceipt();
    final s = widget.stats;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _dialogHeader(context),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top badges
                    Row(
                      children: [
                        _Badge(
                          'EPOS Sales',
                          '£${s.eposTotal.toStringAsFixed(2)}',
                          Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        _Badge(
                          'Website Sales',
                          '£${s.webTotal.toStringAsFixed(2)}',
                          const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 10),
                        _Badge(
                          'Net Total',
                          '£${s.netTotal.toStringAsFixed(2)}',
                          const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment breakdown table
                    _PaymentTable(epos: s.eposPayments, web: s.webPayments),
                    const SizedBox(height: 14),

                    // Totals card
                    _TotalsCard(stats: s),
                    const SizedBox(height: 14),

                    // Raw thermal preview
                    Text(
                      'Thermal Receipt Preview',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        receipt,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Print result banner
            if (_printResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color:
                    _printResult!.startsWith('✅')
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                child: Text(
                  _printResult!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _printResult!.startsWith('✅')
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                  ),
                ),
              ),

            // Footer
            _dialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _dialogHeader(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3D9FF),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            'Sales Receipt Preview',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const Spacer(),
        Text(
          DateFormat('dd MMM yyyy').format(UKTimeService.now()),
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
          ),
        ),
      ],
    ),
  );

  Widget _dialogFooter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _isPrinting ? null : _print,
          icon:
              _isPrinting
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.print_rounded, size: 16),
          label: Text(
            _isPrinting ? 'Printing…' : 'Print Receipt',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ],
    ),
  );
}

// ─── Reusable badge ───────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Badge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Payment table ─────────────────────────────────────────────────────────────
class _PaymentTable extends StatelessWidget {
  final Map<String, double> epos, web;
  const _PaymentTable({required this.epos, required this.web});

  String _fmtType(String s) => s
      .split(RegExp(r'[_ ]'))
      .map(
        (w) =>
            w.isEmpty
                ? ''
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final allTypes = {...epos.keys, ...web.keys}.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Payment Type',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'EPOS',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Website',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, color: Colors.grey.shade200),

          // Data rows
          if (allTypes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No order data available',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ...allTypes.expand((type) {
            final e = epos[type] ?? 0.0;
            final w = web[type] ?? 0.0;
            return [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _fmtType(type),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '£${e.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              e > 0
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '£${w.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              w > 0
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '£${(e + w).toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 0, color: Colors.grey.shade100),
            ];
          }),

          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Subtotal',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '£${epos.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '£${web.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '£${(epos.values.fold(0.0, (a, b) => a + b) + web.values.fold(0.0, (a, b) => a + b)).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Totals breakdown card ─────────────────────────────────────────────────────
class _TotalsCard extends StatelessWidget {
  final SalesReceiptStats stats;
  const _TotalsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _TRow(
            'Total Sales',
            '£${s.totalSales.toStringAsFixed(2)}',
            bold: true,
          ),
          _divider(),
          _TRow(
            'Discounts',
            '-£${s.totalDiscount.toStringAsFixed(2)}',
            sub: true,
          ),
          _divider(),
          _TRow(
            'Paid Outs',
            '-£${s.paidoutsTotal.toStringAsFixed(2)}',
            sub: true,
          ),
          _divider(),
          _TRow(
            'Cancelled Orders',
            '-£${s.cancelledAmount.toStringAsFixed(2)}',
            sub: true,
          ),
          Divider(color: Colors.white30, height: 20),
          _TRow(
            'Net Total',
            '£${s.netTotal.toStringAsFixed(2)}',
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(color: Colors.white12, height: 12);
}

class _TRow extends StatelessWidget {
  final String label, value;
  final bool bold, sub, large;
  const _TRow(
    this.label,
    this.value, {
    this.bold = false,
    this.sub = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: large ? 2 : 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: large ? 14 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: sub ? Colors.white60 : Colors.white,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: large ? 18 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: sub ? Colors.white60 : Colors.white,
          ),
        ),
      ],
    ),
  );
}
