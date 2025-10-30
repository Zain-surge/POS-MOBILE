import 'package:flutter/foundation.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';

enum PaidStatusFilter { all, paid, unpaid }

class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

class OrderHistoryProvider with ChangeNotifier {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _selectedDate;

  PaidStatusFilter _paidStatusFilter = PaidStatusFilter.all;
  String? _orderSourceFilter;
  String? _paymentTypeFilter;
  String? _orderTypeFilter;

  static const Set<String> _uppercaseTokens = {
    'epos',
    'pos',
    'uk',
    'id',
    'qr',
    'n/a',
    'pdq',
  };

  List<Order> get orders => List.unmodifiable(_filteredOrders);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get selectedDate => _selectedDate;
  PaidStatusFilter get paidStatusFilter => _paidStatusFilter;
  String? get orderSourceFilter => _orderSourceFilter;
  String? get paymentTypeFilter => _paymentTypeFilter;
  String? get orderTypeFilter => _orderTypeFilter;
  int get totalOrdersCount => _allOrders.length;

  List<FilterOption> get availableOrderSourceOptions =>
      _buildOptions((order) => order.orderSource);

  List<FilterOption> get availablePaymentTypeOptions =>
      _buildOptions((order) => order.paymentType);

  List<FilterOption> get availableOrderTypeOptions =>
      _buildOptions((order) => order.orderType);

  /// Fetch orders for a specific date
  Future<void> fetchOrdersByDate(DateTime date) async {
    _isLoading = true;
    _error = null;
    _selectedDate = date;
    notifyListeners();

    try {
      final orders = await OrderApiService.fetchOrdersByDate(date);
      _allOrders = List<Order>.from(orders);
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applyFilters(notify: false);
      _error = null;
    } catch (e) {
      _error = 'Failed to load orders: $e';
      _allOrders = [];
      _filteredOrders = [];
      print('OrderHistoryProvider: Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPaidStatusFilter(PaidStatusFilter filter) {
    if (_paidStatusFilter == filter) return;
    _paidStatusFilter = filter;
    _applyFilters();
  }

  void setOrderSourceFilter(String? source) {
    if (_orderSourceFilter == source) return;
    _orderSourceFilter = source;
    _applyFilters();
  }

  void setPaymentTypeFilter(String? paymentType) {
    if (_paymentTypeFilter == paymentType) return;
    _paymentTypeFilter = paymentType;
    _applyFilters();
  }

  void setOrderTypeFilter(String? orderType) {
    if (_orderTypeFilter == orderType) return;
    _orderTypeFilter = orderType;
    _applyFilters();
  }

  /// Clear the current orders and selected date
  void clearOrders() {
    _allOrders = [];
    _filteredOrders = [];
    _selectedDate = null;
    _error = null;
    _resetFilters(notify: false);
    notifyListeners();
  }

  void _applyFilters({bool notify = true}) {
    final availableSourceValues =
        availableOrderSourceOptions.map((option) => option.value).toSet();
    if (_orderSourceFilter != null &&
        !availableSourceValues.contains(_orderSourceFilter)) {
      _orderSourceFilter = null;
    }

    final availablePaymentValues =
        availablePaymentTypeOptions.map((option) => option.value).toSet();
    if (_paymentTypeFilter != null &&
        !availablePaymentValues.contains(_paymentTypeFilter)) {
      _paymentTypeFilter = null;
    }

    final availableOrderTypeValues =
        availableOrderTypeOptions.map((option) => option.value).toSet();
    if (_orderTypeFilter != null &&
        !availableOrderTypeValues.contains(_orderTypeFilter)) {
      _orderTypeFilter = null;
    }

    final filtered =
        _allOrders.where((order) {
          if (_paidStatusFilter == PaidStatusFilter.paid && !order.paidStatus) {
            return false;
          }
          if (_paidStatusFilter == PaidStatusFilter.unpaid &&
              order.paidStatus) {
            return false;
          }

          if (_orderSourceFilter != null) {
            final source = _normalize(order.orderSource);
            if (source != _orderSourceFilter) {
              return false;
            }
          }

          if (_paymentTypeFilter != null) {
            final paymentType = _normalize(order.paymentType);
            if (paymentType != _paymentTypeFilter) {
              return false;
            }
          }

          if (_orderTypeFilter != null) {
            final orderType = _normalize(order.orderType);
            if (orderType != _orderTypeFilter) {
              return false;
            }
          }

          return true;
        }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _filteredOrders = filtered;

    if (notify) {
      notifyListeners();
    }
  }

  void _resetFilters({bool notify = true}) {
    _paidStatusFilter = PaidStatusFilter.all;
    _orderSourceFilter = null;
    _paymentTypeFilter = null;
    _orderTypeFilter = null;
    if (notify) {
      _applyFilters();
    }
  }

  List<FilterOption> _buildOptions(String? Function(Order order) extractor) {
    final options = <String, String>{};

    for (final order in _allOrders) {
      final rawValue = extractor(order);
      if (rawValue == null) continue;
      final trimmedValue = rawValue.trim();
      if (trimmedValue.isEmpty) continue;

      final normalizedValue = _normalize(trimmedValue);
      if (normalizedValue.isEmpty) continue;

      options.putIfAbsent(normalizedValue, () => _formatLabel(trimmedValue));
    }

    final result =
        options.entries
            .map((entry) => FilterOption(value: entry.key, label: entry.value))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    return result;
  }

  String _normalize(String? value) {
    if (value == null) return '';
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String _formatLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Unknown';

    final sanitized = trimmed.replaceAll(RegExp(r'[_\-]+'), ' ');
    final tokens = sanitized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);

    return tokens
        .map((token) {
          final lower = token.toLowerCase();
          if (_uppercaseTokens.contains(lower)) {
            return lower.toUpperCase();
          }
          if (token.length == 1) {
            return token.toUpperCase();
          }
          return token[0].toUpperCase() + token.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
