import 'package:flutter/foundation.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';

class OrderHistoryProvider with ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _selectedDate;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get selectedDate => _selectedDate;

  /// Fetch orders for a specific date
  Future<void> fetchOrdersByDate(DateTime date) async {
    _isLoading = true;
    _error = null;
    _selectedDate = date;
    notifyListeners();

    try {
      final orders = await OrderApiService.fetchOrdersByDate(date);
      _orders = orders;
      // Sort by creation time (newest first)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _error = null;
    } catch (e) {
      _error = 'Failed to load orders: $e';
      _orders = [];
      print('❌ OrderHistoryProvider: Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the current orders and selected date
  void clearOrders() {
    _orders = [];
    _selectedDate = null;
    _error = null;
    notifyListeners();
  }
}
