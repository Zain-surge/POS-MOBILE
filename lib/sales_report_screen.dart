// lib/sales_report_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'providers/sales_report_provider.dart';
import 'widgets/items_table_widget.dart';
import 'widgets/postal_codes_table_widget.dart';
import 'widgets/sales_report_receipt_dialog.dart';
import 'package:epos/services/uk_time_service.dart';

// ─── Colour palette (consistent with POS app aesthetic) ─────────────────────
class _C {
  // Semantic colours – used sparingly for values/icons only
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF3D9FF); // matches app pill colour
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const orange = Color(0xFFEA580C);
  static const yellow = Color(0xFFCA8A04);
  static const teal = Color(0xFF0D9488);
  static const blue = Color(0xFF1D4ED8);
  // Shared text colours
  static const text = Color(0xFF111827); // black87
  static const textSec = Color(0xFF6B7280); // grey.shade600
  static const divider = Color(0xFFE5E7EB); // grey.shade200
}

// ─── Source-mode enum ────────────────────────────────────────────────────────
enum _Src { overall, pos, website }

// ─── Helper: parsed-order model ──────────────────────────────────────────────
class _Order {
  final double price, discount;
  final String status, paymentType, orderSource, orderType;
  const _Order({
    required this.price,
    required this.discount,
    required this.status,
    required this.paymentType,
    required this.orderSource,
    this.orderType = '',
  });

  bool get isCancelled {
    final s = status.toLowerCase();
    return s == 'red' || s == 'cancelled' || s == 'refunded';
  }

  bool get isActive => !isCancelled;
  bool get isCompleted => status.toLowerCase() == 'blue';
  bool get isPending =>
      status.toLowerCase() == 'yellow' || status.toLowerCase() == 'green';
}

// ─── Computed stats bag ───────────────────────────────────────────────────────
class _Stats {
  final int totalOrders, cancelledCount, completedCount, pendingCount;
  final double cancelledAmount,
      totalSales,
      totalDiscount,
      cashSales,
      posCard,
      stripeCard,
      unpaid,
      paidoutsTotal,
      salesGrowthPct,
      salesIncrease,
      compPeriodSales;

  const _Stats({
    required this.totalOrders,
    required this.cancelledCount,
    required this.completedCount,
    required this.pendingCount,
    required this.cancelledAmount,
    required this.totalSales,
    required this.totalDiscount,
    required this.cashSales,
    required this.posCard,
    required this.stripeCard,
    required this.unpaid,
    required this.paidoutsTotal,
    required this.salesGrowthPct,
    required this.salesIncrease,
    required this.compPeriodSales,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});
  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _init = false;
  _Src _src = _Src.overall;
  bool _showStats = false; // hidden by default per web reference
  bool _showPostalCodes = false;
  bool _showItems = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_init) return;
    _init = true;
    final p = Provider.of<SalesReportProvider>(context, listen: false);
    p.setCurrentTab(0);
    await p.initialize();
  }

  // ── Parse all orders from raw report ───────────────────────────────────────
  List<_Order> _parseOrders(Map<String, dynamic> r) {
    final raw = r['orders'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .whereType<Map>()
        .map(
          (o) => _Order(
            price: _d(o['total_price']),
            discount: _d(o['discount']),
            status: (o['status'] ?? '').toString(),
            paymentType: (o['payment_type'] ?? '').toString().toLowerCase(),
            orderSource: (o['order_source'] ?? '').toString().toLowerCase(),
            orderType: (o['order_type'] ?? '').toString().toLowerCase(),
          ),
        )
        .toList();
  }

  // ── Filter orders by source mode ────────────────────────────────────────────
  List<_Order> _filtered(List<_Order> all) {
    switch (_src) {
      case _Src.pos:
        return all.where((o) => o.orderSource == 'epos').toList();
      case _Src.website:
        return all.where((o) => o.orderSource == 'website').toList();
      case _Src.overall:
        return all;
    }
  }

  // ── Compute stats from filtered orders ──────────────────────────────────────
  _Stats _computeStats(Map<String, dynamic> report) {
    final raw = _parseOrders(report);
    final orders = _filtered(raw);

    // If no order details → fall back to legacy pre-computed fields
    if (raw.isEmpty) {
      return _statsFromLegacy(report);
    }

    final cancelled = orders.where((o) => o.isCancelled).toList();
    final active = orders.where((o) => o.isActive).toList();
    final completed = active.where((o) => o.isCompleted).toList();
    final pending = active.where((o) => o.isPending).toList();

    double sum(List<_Order> list, double Function(_Order) fn) =>
        list.fold(0.0, (s, o) => s + fn(o));

    final totalSales = sum(active, (o) => o.price);
    final totalDiscount = sum(active, (o) => o.discount);
    final cancelledAmt = sum(cancelled, (o) => o.price);

    final cash = sum(
      active.where((o) => o.paymentType.contains('cash')).toList(),
      (o) => o.price,
    );

    final posCardOrders =
        active
            .where((o) => o.paymentType == 'card' && o.orderSource == 'epos')
            .toList();
    final posCard =
        sum(posCardOrders, (o) => o.price) -
        sum(posCardOrders, (o) => o.discount) -
        sum(
          cancelled
              .where((o) => o.paymentType == 'card' && o.orderSource == 'epos')
              .toList(),
          (o) => o.price,
        );

    final stripe = sum(
      active
          .where(
            (o) =>
                (o.paymentType == 'card' && o.orderSource == 'website') ||
                o.paymentType == 'card_through_link',
          )
          .toList(),
      (o) => o.price,
    );

    final unpaid = sum(
      active.where((o) => o.paymentType.isEmpty).toList(),
      (o) => o.price,
    );

    final paidoutsTotal = _src == _Src.overall ? _paidoutsSum(report) : 0.0;

    final comp = _d(report['comparison_period_sales']);
    final growthAmt = totalSales - comp;
    final growthPct = comp > 0 ? (growthAmt / comp * 100) : 0.0;

    return _Stats(
      totalOrders: orders.length,
      cancelledCount: cancelled.length,
      completedCount: completed.length,
      pendingCount: pending.length,
      cancelledAmount: cancelledAmt,
      totalSales: totalSales,
      totalDiscount: totalDiscount,
      cashSales: cash,
      posCard: posCard,
      stripeCard: stripe,
      unpaid: unpaid,
      paidoutsTotal: paidoutsTotal,
      salesGrowthPct: growthPct,
      salesIncrease: growthAmt,
      compPeriodSales: comp,
    );
  }

  // ── Legacy pre-computed fields (old API) ────────────────────────────────────
  _Stats _statsFromLegacy(Map<String, dynamic> r) {
    final totalSales = _d(r['total_sales'] ?? r['total_sales_amount']);
    final comp = _d(r['comparison_period_sales']);
    final growthAmt = _d(r['sales_increase']);
    final growthPct = _d(r['sales_growth_percentage']);
    return _Stats(
      totalOrders: r['total_orders_placed'] ?? r['total_orders'] ?? 0,
      cancelledCount: r['cancelled_orders_count'] ?? 0,
      completedCount: r['completed_orders_count'] ?? 0,
      pendingCount: r['pending_orders_count'] ?? 0,
      cancelledAmount: _d(r['total_cancelled'] ?? r['cancelled_orders_amount']),
      totalSales: totalSales,
      totalDiscount: _d(r['total_discount'] ?? r['discount']),
      cashSales: _d(r['total_cash'] ?? _payAmt(r, 'cash')),
      posCard: _d(r['total_card'] ?? _payAmt(r, 'card')),
      stripeCard: _d(r['total_stripe'] ?? _payAmt(r, 'stripe')),
      unpaid: _d(r['total_unpaid']),
      paidoutsTotal: _paidoutsSum(r),
      salesGrowthPct: growthPct,
      salesIncrease: growthAmt,
      compPeriodSales: comp,
    );
  }

  double _paidoutsSum(Map<String, dynamic> r) {
    final list = r['paidouts'] as List<dynamic>?;
    if (list != null)
      return list.whereType<Map>().fold(0.0, (s, p) => s + _d(p['amount']));
    return _d(r['total_paidouts'] ?? r['paidouts_total']);
  }

  double _payAmt(Map<String, dynamic> r, String type) {
    final list = r['sales_by_payment_type'] as List<dynamic>? ?? [];
    for (final p in list) {
      if (p is Map &&
          (p['payment_type'] ?? '').toString().toLowerCase() == type) {
        return _d(p['total']);
      }
    }
    return 0;
  }

  // ── Analytics section: overall / pos / website ──────────────────────────────
  Map<String, dynamic>? _analytics(Map<String, dynamic> r) {
    final a = r['analytics'];
    if (a is Map<String, dynamic>) {
      final key =
          _src == _Src.pos
              ? 'pos'
              : _src == _Src.website
              ? 'website'
              : 'overall';
      final section = a[key];
      if (section is Map<String, dynamic>) return section;
      // fallback to overall
      final ov = a['overall'];
      if (ov is Map<String, dynamic>) return ov;
    }
    return null; // old API: analytics not nested
  }

  // Summary card data from analytics (new) or legacy top-level fields (old)
  String _mostSoldItemName(Map<String, dynamic> r) {
    final a = _analytics(r);
    final item =
        a?['most_sold_item'] ?? r['most_selling_item'] ?? r['most_sold_item'];
    return item is Map ? (item['item_name']?.toString() ?? 'N/A') : 'N/A';
  }

  int _mostSoldItemQty(Map<String, dynamic> r) {
    final a = _analytics(r);
    final item =
        a?['most_sold_item'] ?? r['most_selling_item'] ?? r['most_sold_item'];
    return item is Map
        ? (int.tryParse(item['quantity_sold']?.toString() ?? '') ?? 0)
        : 0;
  }

  double? _mostSoldItemPct(Map<String, dynamic> r) {
    final a = _analytics(r);
    final item =
        a?['most_sold_item'] ?? r['most_selling_item'] ?? r['most_sold_item'];
    if (item is Map) {
      final g =
          item['percentage_increase'] ??
          item['growth_percentage'] ??
          item['percentage_change'];
      return g != null ? _d(g) : null;
    }
    return null;
  }

  String _mostSoldCatName(Map<String, dynamic> r) {
    final a = _analytics(r);
    final c = a?['most_sold_type'] ?? r['most_sold_type'];
    return c is Map ? (c['type']?.toString() ?? 'N/A') : 'N/A';
  }

  int _mostSoldCatQty(Map<String, dynamic> r) {
    final a = _analytics(r);
    final c = a?['most_sold_type'] ?? r['most_sold_type'];
    return c is Map
        ? (int.tryParse(c['quantity_sold']?.toString() ?? '') ?? 0)
        : 0;
  }

  double? _mostSoldCatPct(Map<String, dynamic> r) {
    final a = _analytics(r);
    final c = a?['most_sold_type'] ?? r['most_sold_type'];
    if (c is Map) {
      final g =
          c['percentage_increase'] ??
          c['growth_percentage'] ??
          c['percentage_change'];
      return g != null ? _d(g) : null;
    }
    return null;
  }

  String _mostDelivCode(Map<String, dynamic> r) {
    final a = _analytics(r);
    final x =
        a?['most_delivered_postal_code'] ?? r['most_delivered_postal_code'];
    return x is Map ? (x['postal_code']?.toString() ?? 'N/A') : 'N/A';
  }

  int _mostDelivCount(Map<String, dynamic> r) {
    final a = _analytics(r);
    final x =
        a?['most_delivered_postal_code'] ?? r['most_delivered_postal_code'];
    return x is Map
        ? (int.tryParse(x['delivery_count']?.toString() ?? '') ?? 0)
        : 0;
  }

  // Items sold list for the ItemsTableWidget (from analytics section or top-level)
  Map<String, dynamic>? _itemsReport(Map<String, dynamic> r) {
    final a = _analytics(r);
    if (a != null && a['all_items_sold'] is List) return a;
    if (r['all_items_sold'] is List) return r;
    return r; // pass-through so widget handles empty state
  }

  // Items count for badge
  int _itemsCount(Map<String, dynamic> r) {
    final a = _analytics(r);
    if (a != null) {
      final l = a['all_items_sold'];
      if (l is List) return l.length;
    }
    final l = r['all_items_sold'];
    return l is List ? l.length : 0;
  }

  // Metric card totals always from ALL orders (not filtered)
  (double total, double pos, double web) _topMetrics(Map<String, dynamic> r) {
    final all = _parseOrders(r);
    if (all.isEmpty) {
      // legacy path
      final sources = r['sales_by_order_source'] as List<dynamic>? ?? [];
      double p = 0, w = 0;
      for (final s in sources) {
        if (s is! Map) continue;
        final src = (s['source'] ?? '').toString().toLowerCase();
        final v = _d(s['total']);
        if (src == 'website')
          w += v;
        else
          p += v;
      }
      final total = _d(r['total_sales'] ?? r['total_sales_amount']);
      return (total, p + w == 0 ? total : p, w);
    }
    final active = all.where((o) => o.isActive).toList();
    double total = 0, pos = 0, web = 0;
    for (final o in active) {
      total += o.price;
      if (o.orderSource == 'epos')
        pos += o.price;
      else if (o.orderSource == 'website')
        web += o.price;
    }
    return (total, pos, web);
  }

  // Postal count
  int _postalCount(Map<String, dynamic> r) {
    final l = r['deliveries_by_postal_code'];
    return l is List ? l.length : 0;
  }

  // Chart data from orders
  List<(String, double)> _paymentBreakdown(Map<String, dynamic> r) {
    final all = _parseOrders(r);
    final filt = _filtered(all).where((o) => o.isActive).toList();
    if (all.isEmpty) {
      // legacy
      final list = r['sales_by_payment_type'] as List<dynamic>? ?? [];
      return list
          .whereType<Map>()
          .where((p) => _d(p['total']) > 0)
          .map<(String, double)>(
            (p) => (
              p['payment_type']?.toString().toUpperCase() ?? 'OTHER',
              _d(p['total']),
            ),
          )
          .toList();
    }
    final map = <String, double>{};
    for (final o in filt) {
      final k = o.paymentType.isEmpty ? 'UNPAID' : o.paymentType.toUpperCase();
      map[k] = (map[k] ?? 0) + o.price;
    }
    return map.entries.map((e) => (e.key, e.value)).toList();
  }

  List<(String, double)> _orderTypeBreakdown(Map<String, dynamic> r) {
    final all = _parseOrders(r);
    final filt = _filtered(all).where((o) => o.isActive).toList();
    if (all.isEmpty) {
      final list = r['sales_by_order_type'] as List<dynamic>? ?? [];
      return list
          .whereType<Map>()
          .where((p) => _d(p['total']) > 0)
          .map<(String, double)>(
            (p) => (
              p['order_type']?.toString().toUpperCase() ?? '',
              _d(p['total']),
            ),
          )
          .toList();
    }

    final map = <String, double>{};
    for (final o in filt) {
      final k = o.orderType.isEmpty ? 'UNKNOWN' : o.orderType.toUpperCase();
      map[k] = (map[k] ?? 0) + o.price;
    }
    return map.entries.map((e) => (e.key, e.value)).toList();
  }

  List<(String, double)> _sourceBreakdown(Map<String, dynamic> r) {
    final all = _parseOrders(r);
    final filt = _filtered(all).where((o) => o.isActive).toList();
    if (all.isEmpty) {
      final list =
          (r['sales_by_order_source'] ?? r['sales_by_source'])
              as List<dynamic>? ??
          [];
      return list
          .whereType<Map>()
          .where((p) => _d(p['total']) > 0)
          .map<(String, double)>(
            (p) => (
              p['source']?.toString().toUpperCase() ?? '',
              _d(p['total']),
            ),
          )
          .toList();
    }
    final map = <String, double>{};
    for (final o in filt) {
      final k = o.orderSource.isEmpty ? 'UNKNOWN' : o.orderSource.toUpperCase();
      map[k] = (map[k] ?? 0) + o.price;
    }
    return map.entries.map((e) => (e.key, e.value)).toList();
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
  static int? _i(dynamic v) => int.tryParse(v?.toString() ?? '');
  static String _fmt(double v) => '£${v.toStringAsFixed(2)}';

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<SalesReportProvider>(
      builder:
          (ctx, provider, _) => Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: SafeArea(
              child: Column(
                children: [
                  _header(provider),
                  Expanded(
                    child:
                        provider.isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: _C.purple,
                              ),
                            )
                            : _body(provider),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ─── Header (matches SettingsScreen / OrderHistoryScreen style) ─────────────
  Widget _header(SalesReportProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // Back button – matches order_history_screen.dart style
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
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Purple pill title – matches app pattern
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _C.purpleLight,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        "Today's Sales Report",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Print button
              GestureDetector(
                onTap: () => _showPrintDialog(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh button
              GestureDetector(
                onTap:
                    () =>
                        Provider.of<SalesReportProvider>(
                          context,
                          listen: false,
                        ).refreshCurrentReport(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 0, thickness: 2, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color clr, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.divider),
          ),
          child: Icon(icon, color: clr, size: 18),
        ),
      );

  // ─── Print dialog launcher ─────────────────────────────────────────────────
  void _showPrintDialog() {
    final provider = Provider.of<SalesReportProvider>(context, listen: false);
    final report = provider.getCurrentReport();
    if (report == null || report.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No report data to print.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final stats = _buildReceiptStats(report);
    SalesReportReceiptDialog.show(
      context,
      report: report,
      stats: stats,
      onPrint: (String receiptContent) => provider.printThermalReport(receiptOverride: receiptContent).then((_) => true),
    );

  }

  // ─── Build SalesReceiptStats from raw report ────────────────────────────────
  /// Computes per-source (EPOS / Website) payment type breakdowns plus totals.
  SalesReceiptStats _buildReceiptStats(Map<String, dynamic> report) {
    final orders = _parseOrders(report);

    if (orders.isEmpty) {
      // Fallback to legacy summary when order details are not available.
      final cs = _statsFromLegacy(report);
      final (posTotal, webTotal) = _sourceTotalsFromReport(report);
      final grossSales = cs.totalSales + cs.totalDiscount + cs.cancelledAmount;
      final net =
          grossSales - cs.totalDiscount - cs.paidoutsTotal - cs.cancelledAmount;

      return SalesReceiptStats(
        eposPayments: const <String, double>{},
        webPayments: const <String, double>{},
        eposTotal: posTotal,
        webTotal: webTotal,
        totalSales: grossSales,
        totalDiscount: cs.totalDiscount,
        paidoutsTotal: cs.paidoutsTotal,
        cancelledAmount: cs.cancelledAmount,
        netTotal: net,
        totalOrders: cs.totalOrders,
        completedCount: cs.completedCount,
        cancelledCount: cs.cancelledCount,
        pendingCount: cs.pendingCount,
      );
    }

    // Payment breakdown by source
    final eposMap = <String, double>{};
    final webMap = <String, double>{};

    for (final o in orders) {
      if (o.isCancelled) continue; // only count active orders in payment totals
      final src = o.orderSource.toLowerCase();
      final pt = o.paymentType.isEmpty ? 'unknown' : o.paymentType;
      if (src == 'epos') {
        eposMap[pt] = (eposMap[pt] ?? 0) + o.price;
      } else if (src == 'website') {
        webMap[pt] = (webMap[pt] ?? 0) + o.price;
      } else {
        // Any other source (app, etc.) goes into EPOS bucket
        eposMap[pt] = (eposMap[pt] ?? 0) + o.price;
      }
    }

    final eposTotal = eposMap.values.fold(0.0, (a, b) => a + b);
    final webTotal = webMap.values.fold(0.0, (a, b) => a + b);

    // Aggregate numbers: prefer report totals when present to avoid status-mapping errors.
    final cs = _computeStats(report);
    final reportTotalSales = _d(
      report['total_sales'] ?? report['total_sales_amount'],
    );
    final reportDiscount = _d(report['total_discount'] ?? report['discount']);
    final reportCancelled = _d(
      report['total_cancelled'] ?? report['cancelled_orders_amount'],
    );
    final reportPaidouts = _d(
      report['total_paidouts'] ?? report['paidouts_total'],
    );

    final totalSales = reportTotalSales > 0 ? reportTotalSales : cs.totalSales;
    final totalDiscount =
        reportDiscount > 0 ? reportDiscount : cs.totalDiscount;
    final cancelledAmount =
        reportCancelled > 0 ? reportCancelled : cs.cancelledAmount;
    final paidoutsTotal =
        reportPaidouts > 0 ? reportPaidouts : cs.paidoutsTotal;

    final grossSales = totalSales + totalDiscount + cancelledAmount;
    final net = grossSales - totalDiscount - paidoutsTotal - cancelledAmount;

    final totalOrders = _i(
      report['total_orders_placed'] ?? report['total_orders'],
    );
    final completedCount = _i(report['completed_orders_count']);
    final cancelledCount = _i(report['cancelled_orders_count']);
    final pendingCount = _i(report['pending_orders_count']);

    return SalesReceiptStats(
      eposPayments: eposMap,
      webPayments: webMap,
      eposTotal: eposTotal,
      webTotal: webTotal,
      totalSales: grossSales,
      totalDiscount: totalDiscount,
      paidoutsTotal: paidoutsTotal,
      cancelledAmount: cancelledAmount,
      netTotal: net,
      totalOrders: totalOrders ?? cs.totalOrders,
      completedCount: completedCount ?? cs.completedCount,
      cancelledCount: cancelledCount ?? cs.cancelledCount,
      pendingCount: pendingCount ?? cs.pendingCount,
    );
  }

  (double posTotal, double webTotal) _sourceTotalsFromReport(
    Map<String, dynamic> report,
  ) {
    final sources =
        (report['sales_by_order_source'] ?? report['sales_by_source'])
            as List<dynamic>? ??
        [];
    double pos = 0.0;
    double web = 0.0;
    for (final s in sources) {
      if (s is! Map) continue;
      final src = (s['source'] ?? '').toString().toLowerCase();
      final total = _d(s['total']);
      if (src == 'website') {
        web += total;
      } else {
        // Any non-website source counts as POS/EPOS bucket
        pos += total;
      }
    }
    if (pos == 0.0 && web == 0.0) {
      final total = _d(report['total_sales'] ?? report['total_sales_amount']);
      pos = total;
    }
    return (pos, web);
  }

  // ─── Body ─────────────────────────────────────────────────────────────────
  Widget _body(SalesReportProvider provider) {
    final report = provider.getCurrentReport();
    if (report == null || report.isEmpty) return _empty(provider);

    final stats = _computeStats(report);
    final (total, pos, web) = _topMetrics(report);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Three metric cards
          _metricRow(total, pos, web),
          const SizedBox(height: 12),

          // 2. Overall / POS / Website + Show Stats
          _filterRow(),
          const SizedBox(height: 12),

          // 3. 9-card stats grid (toggleable)
          if (_showStats) ...[
            _statsGrid(stats, report),
            const SizedBox(height: 14),
          ],

          // 4. Summary | Analytics — flex-based, no fixed width
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _summaryCard(report, stats)),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _analyticsCard(report)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Deliveries by Postal Code
          _expandable(
            icon: Icons.location_on_rounded,
            iconColor: Colors.grey.shade600,
            iconBg: Colors.grey.shade100,
            title: 'Deliveries by Postal Code',
            badge: '${_postalCount(report)} locations',
            isVisible: _showPostalCodes,
            onToggle:
                () => setState(() => _showPostalCodes = !_showPostalCodes),
            child: PostalCodesTableWidget(report: report),
          ),
          const SizedBox(height: 10),

          // 6. All Items Sold
          _expandable(
            icon: Icons.inventory_2_rounded,
            iconColor: Colors.grey.shade600,
            iconBg: Colors.grey.shade100,
            title: 'All Items Sold',
            badge: '${_itemsCount(report)} items',
            isVisible: _showItems,
            onToggle: () => setState(() => _showItems = !_showItems),
            child: ItemsTableWidget(report: _itemsReport(report)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _empty(SalesReportProvider p) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _C.purpleLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.analytics_outlined,
            size: 52,
            color: _C.purple,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No data available for today',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _C.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Check back later or try refreshing',
          style: GoogleFonts.poppins(fontSize: 12, color: _C.textSec),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: p.refreshCurrentReport,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            'Refresh',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );

  // ─── 1. Metric row ────────────────────────────────────────────────────────
  Widget _metricRow(double total, double pos, double web) => Row(
    children: [
      Expanded(
        child: _MetricCard(
          icon: Icons.attach_money_rounded,
          label: 'Total Sales',
          value: _fmt(total),
          accentColor: _C.purple,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _MetricCard(
          icon: Icons.point_of_sale_rounded,
          label: 'POS Sales',
          value: _fmt(pos),
          accentColor: Colors.blue.shade700,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _MetricCard(
          icon: Icons.language_rounded,
          label: 'Website Sales',
          value: _fmt(web),
          accentColor: _C.green,
        ),
      ),
    ],
  );

  // ─── 2. Filter row ────────────────────────────────────────────────────────
  Widget _filterRow() => Row(
    children: [
      _chip('Overall', _src == _Src.overall, () => _setSrc(_Src.overall)),
      const SizedBox(width: 8),
      _chip('POS', _src == _Src.pos, () => _setSrc(_Src.pos)),
      const SizedBox(width: 8),
      _chip('Website', _src == _Src.website, () => _setSrc(_Src.website)),
      const Spacer(),
      // Show/Hide Stats — keeps web-style orange button
      GestureDetector(
        onTap: () => setState(() => _showStats = !_showStats),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showStats ? Icons.visibility_off : Icons.bar_chart_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _showStats ? 'Hide Stats' : 'Show Stats',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  void _setSrc(_Src s) {
    if (_src == s) return;
    setState(() => _src = s);
  }

  // Chip style matches ChoiceChip pattern in rest of app: black selected, grey unselected
  Widget _chip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? Colors.black87 : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      );

  // ─── 3. Stats grid ────────────────────────────────────────────────────────
  Widget _statsGrid(_Stats s, Map<String, dynamic> r) {
    final items = [
      _SI('Total Orders', s.totalOrders.toString(), Colors.black87),
      _SI(
        'Cancelled Orders',
        '${s.cancelledCount}  ${_fmt(s.cancelledAmount)}',
        _C.red,
      ),
      _SI('Completed Orders', s.completedCount.toString(), _C.green),
      _SI('Pending Orders', s.pendingCount.toString(), _C.yellow),
      _SI('Total Cash', _fmt(s.cashSales), _C.purple),
      _SI('Total POS Card', _fmt(s.posCard), Colors.blue.shade700),
      _SI('Total Stripe Card', _fmt(s.stripeCard), _C.teal),
      _SI('Unpaid Orders', _fmt(s.unpaid), _C.orange),
      if (_src == _Src.overall)
        _SI('Total Paidouts', _fmt(s.paidoutsTotal), _C.orange),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        // 5 columns → compact cards matching the web UI
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (_, i) => _statCard(items[i]),
    );
  }

  // Compact stat card — small padding, no wasted space
  Widget _statCard(_SI item) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          item.value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: item.valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  // ─── 4. Summary column ────────────────────────────────────────────────────
  Widget _summaryCard(Map<String, dynamic> r, _Stats s) => _SectionCard(
    header: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _C.purpleLight,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            'Summary',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    ),
    child: Column(
      children: [
        _summaryInfoRow(
          Icons.calendar_today_rounded,
          _C.blue,
          'Period',
          DateFormat('dd-MM-yyyy').format(UKTimeService.now()),
          GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
        ),
        const SizedBox(height: 8),
        _summaryInfoRow(
          Icons.shopping_bag_rounded,
          _C.blue,
          'Total Orders',
          s.totalOrders.toString(),
          GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _C.blue,
          ),
        ),
        const SizedBox(height: 8),
        _growthRow(s),
        const SizedBox(height: 8),
        _insightRow(
          Icons.star_rounded,
          const Color(0xFFD97706),
          'Most Sold Item',
          _mostSoldItemName(r),
          '${_mostSoldItemQty(r)} sold',
          _mostSoldItemPct(r),
        ),
        const SizedBox(height: 8),
        _insightRow(
          Icons.category_rounded,
          _C.purple,
          'Most Sold Category',
          _mostSoldCatName(r),
          '${_mostSoldCatQty(r)} sold',
          _mostSoldCatPct(r),
        ),
        const SizedBox(height: 8),
        _insightRow(
          Icons.location_on_rounded,
          _C.blue,
          'Most Delivered Area',
          _mostDelivCode(r),
          '${_mostDelivCount(r)} deliveries',
          null,
        ),
        const SizedBox(height: 8),
        _salesDetailsCard(r, s),
      ],
    ),
  );

  Widget _summaryInfoRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    TextStyle valueStyle,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
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
              Text(value, style: valueStyle),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _growthRow(_Stats s) {
    final pos = s.salesGrowthPct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: _C.textSec, size: 13),
              const SizedBox(width: 4),
              Text(
                'Sales Growth',
                style: GoogleFonts.poppins(fontSize: 10, color: _C.textSec),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pos ? '+' : ''}${s.salesGrowthPct.toStringAsFixed(2)}%',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: pos ? _C.green : _C.red,
            ),
          ),
          Text(
            '${pos ? '+' : ''}${_fmt(s.salesIncrease)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pos ? _C.green : _C.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(
    IconData icon,
    Color iconColor,
    String title,
    String name,
    String qty,
    double? pct,
  ) {
    final pos = (pct ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey.shade600, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 10, color: _C.textSec),
                ),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
                Text(
                  qty,
                  style: GoogleFonts.poppins(fontSize: 11, color: _C.textSec),
                ),
                if (pct != null)
                  Text(
                    '${pos ? '+' : ''}${pct.toStringAsFixed(2)}% vs last period',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: pos ? _C.green : _C.red,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesDetailsCard(Map<String, dynamic> r, _Stats s) {
    final grossSales = s.totalSales + s.totalDiscount + s.cancelledAmount;
    final net =
        grossSales - s.totalDiscount - s.paidoutsTotal - s.cancelledAmount;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0x4D7C3AED),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '£ Sales Details',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _dr('Total Sales:', _fmt(grossSales)),
            const Divider(color: Colors.white12, height: 6),
            _dr('Total Discount:', _fmt(s.totalDiscount), sub: true),
            const Divider(color: Colors.white12, height: 6),
            _dr('Total Paidouts:', _fmt(s.paidoutsTotal), sub: true),
            const Divider(color: Colors.white12, height: 6),
            _dr('Cancelled Orders:', _fmt(s.cancelledAmount), sub: true),
            const Divider(color: Colors.white24, height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Sales:',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _fmt(net),
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dr(String label, String value, {bool sub = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: sub ? Colors.white60 : Colors.white,
          ),
        ),
      ],
    ),
  );

  // ─── 5. Analytics card ────────────────────────────────────────────────────
  Widget _analyticsCard(Map<String, dynamic> r) {
    final payBreak = _paymentBreakdown(r);
    final typeBreak = _orderTypeBreakdown(r);
    final srcBreak = _sourceBreakdown(r);
    final growthAmt = _computeStats(r).salesIncrease;

    return _SectionCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _C.purpleLight,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'Analytics Overview',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _growthDonut(growthAmt),
          _donut('Payment Methods', payBreak, const [
            Color(0xFF3B82F6),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
          ]),
          _donut('Order Types', typeBreak, const [
            Color(0xFF8B5CF6),
            Color(0xFFA78BFA),
            Color(0xFF93C5FD),
            Color(0xFF6EE7B7),
          ]),
          _donut('Order Sources', srcBreak, const [
            Color(0xFFEF4444),
            Color(0xFF3B82F6),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
          ]),
        ],
      ),
    );
  }

  Widget _growthDonut(double amt) {
    final pos = amt >= 0;
    final progress = (amt.abs() / 200).clamp(0.05, 0.95);
    return Column(
      children: [
        Text(
          'Sales Growth',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _C.textSec,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: 120,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              color: pos ? _C.green : _C.red,
              bg: Colors.grey.shade200,
            ),
            child: Center(
              child: Text(
                _fmt(amt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pos ? _C.green : _C.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_fmt(amt.abs())} ${pos ? 'more' : 'less'}\nvs last period',
          style: GoogleFonts.poppins(fontSize: 9, color: _C.textSec),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _donut(
    String title,
    List<(String, double)> data,
    List<Color> palette,
  ) {
    double total = data.fold(0.0, (s, e) => s + e.$2);
    if (total == 0) total = 1;
    final fractions = data.map((e) => e.$2 / total).toList();
    final labels = data.map((e) => e.$1).toList();
    final colors = List.generate(
      data.length,
      (i) => palette[i % palette.length],
    );
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _C.textSec,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: 120,
          child: CustomPaint(
            painter: _PiePainter(data: fractions, colors: colors),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: List.generate(
            labels.length,
            (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  labels[i],
                  style: GoogleFonts.poppins(fontSize: 9, color: _C.textSec),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 6. Expandable section ────────────────────────────────────────────────
  Widget _expandable({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String badge,
    required bool isVisible,
    required VoidCallback onToggle,
    required Widget child,
  }) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.grey.shade600, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    badge,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Show/Hide button — consistent black pill matching the filter chips
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isVisible ? 'Hide' : 'Show',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (isVisible) ...[const SizedBox(height: 8), child],
    ],
  );
}

// ─── Small data model for stats grid ─────────────────────────────────────────
class _SI {
  final String label, value;
  final Color valueColor; // card is always white — no bg field
  const _SI(this.label, this.value, this.valueColor);
}

// ─── Reusable section card ────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget header, child;
  const _SectionCard({required this.header, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 10),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 10),

        child,
      ],
    ),
  );
}

// ─── Metric card widget ────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color accentColor;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Chart painters ───────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color, bg;
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bg,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

class _PiePainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  const _PiePainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final c = Offset(size.width / 2, size.height / 2);
    final outRadius = size.width / 2;
    final innRadius = outRadius * 0.55;

    // For a donut, we draw strokes along the middle radius
    final strokeRadius = innRadius + (outRadius - innRadius) / 2;
    final strokeWidth = outRadius - innRadius;

    double start = -math.pi / 2;

    // Special fallback for 100% single slice to avoid 360 arc calculation bugs
    if (data.length == 1 && data[0] >= 0.99) {
      canvas.drawCircle(
        c,
        strokeRadius,
        Paint()
          ..color = colors[0]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    // Multiple slices
    for (int i = 0; i < data.length && i < colors.length; i++) {
      double sweep = 2 * math.pi * data[i];
      // Prevent full 360 collapse just in case
      if (sweep >= 2 * math.pi - 0.001) sweep = 2 * math.pi - 0.001;

      canvas.drawArc(
        Rect.fromCircle(center: c, radius: strokeRadius),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      start += sweep;
    }

    // Draw white gaps between items
    if (data.length > 1) {
      start = -math.pi / 2;
      final gapPaint =
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
      for (int i = 0; i < data.length; i++) {
        double sweep = 2 * math.pi * data[i];
        canvas.drawLine(
          Offset(
            c.dx + innRadius * math.cos(start),
            c.dy + innRadius * math.sin(start),
          ),
          Offset(
            c.dx + outRadius * math.cos(start),
            c.dy + outRadius * math.sin(start),
          ),
          gapPaint,
        );
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}
