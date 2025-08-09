// lib/providers/website_orders_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _websiteOrders = [];
  Timer? _pollingTimer;
  bool _isPolling = false;
  static const Duration _pollingInterval = Duration(seconds: 10); // Poll every 10 seconds

  List<Order> get websiteOrders => _websiteOrders;
  bool get isPolling => _isPolling;

  OrderProvider() {
    fetchWebsiteOrders();
    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  // Start automatic polling
  void startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      fetchWebsiteOrders();
    });
    print("OrderProvider: Started polling for order updates every ${_pollingInterval.inSeconds} seconds");
  }

  // Stop automatic polling
  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      _isPolling = false;
      print("OrderProvider: Stopped polling for order updates");
    }
  }

  // Restart polling (useful for manual refresh)
  void restartPolling() {
    stopPolling();
    startPolling();
  }

  Future<void> fetchWebsiteOrders() async {
    print("OrderProvider: Fetching displayable website orders...");
    try {
      List<Order> fetchedOrders = await OrderApiService.fetchTodayOrders();
      List<Order> newWebsiteOrders = fetchedOrders.where((order) {
        final isWebsiteSource = order.orderSource.toLowerCase() == 'website';
        final isDisplayableStatus = ['accepted', 'preparing', 'ready', 'delivered', 'blue', 'green', 'pending', 'yellow', 'completed', 'cancelled', 'red'].contains(order.status.toLowerCase());
        return isWebsiteSource && isDisplayableStatus;
      }).toList();

      // Only notify listeners if the data actually changed
      if (_hasOrdersChanged(_websiteOrders, newWebsiteOrders)) {
        _websiteOrders = newWebsiteOrders;
        print("OrderProvider: Orders changed - Fetched ${_websiteOrders.length} displayable website orders.");
        notifyListeners(); // Notify listeners that data has changed
      } else {
        print("OrderProvider: No changes detected in orders.");
      }
    } catch (e) {
      print("OrderProvider: Error fetching website orders: $e");
    }
  }

  // Enhanced helper method to check if orders have actually changed
  bool _hasOrdersChanged(List<Order> oldOrders, List<Order> newOrders) {
    if (oldOrders.length != newOrders.length) return true;

    for (int i = 0; i < oldOrders.length; i++) {
      final oldOrder = oldOrders[i];
      final newOrder = newOrders[i];

      // Check for changes in critical fields including driverId
      if (oldOrder.orderId != newOrder.orderId ||
          oldOrder.status != newOrder.status ||
          oldOrder.orderTotalPrice != newOrder.orderTotalPrice ||
          oldOrder.items.length != newOrder.items.length ||
          oldOrder.driverId != newOrder.driverId) { // Added driverId comparison
        return true;
      }
    }

    return false;
  }

  // Method to update a single order's status and refresh the list
  Future<bool> updateAndRefreshOrder(int orderId, String newStatus) async {
    print("OrderProvider: Attempting to update order $orderId to status $newStatus.");
    bool success = await OrderApiService.updateOrderStatus(orderId, newStatus);
    if (success) {
      // Force immediate refresh after status update
      await fetchWebsiteOrders();
      return true;
    }
    return false;
  }

  // Method to manually refresh orders (useful for pull-to-refresh)
  Future<void> refreshOrders() async {
    print("OrderProvider: Manual refresh triggered");
    await fetchWebsiteOrders();
  }

  // Helper method to determine the display status for delivery orders
  String getDeliveryDisplayStatus(Order order) {
    final String statusLower = order.status.toLowerCase();
    final bool hasDriver = order.driverId != null && order.driverId != 0;

    print("OrderProvider: Getting display status for order ${order.orderId} - Status: $statusLower, Driver ID: ${order.driverId}, Has Driver: $hasDriver");

    if (order.orderType.toLowerCase() == 'delivery') {
      switch (statusLower) {
        case 'green':
        case 'ready':
          if (hasDriver) {
            return 'On Its Way'; // Driver assigned and order is ready = on its way
          } else {
            return 'Ready'; // No driver assigned yet
          }
        case 'blue':
        case 'completed':
          if (hasDriver) {
            return 'Completed'; // Driver completed the delivery
          } else {
            return 'Completed'; // Fallback
          }
        case 'yellow':
        case 'pending':
        case 'accepted':
          return 'Pending';
        case 'red':
        case 'cancelled':
          return 'Cancelled';
        default:
          return order.statusLabel; // Fallback to original status label
      }
    } else {
      // For non-delivery orders, use existing logic
      switch (statusLower) {
        case 'yellow':
        case 'pending':
        case 'accepted':
          return 'Pending';
        case 'green':
        case 'ready':
        case 'preparing':
          return 'Ready';
        case 'blue':
        case 'completed':
        case 'delivered':
          return 'Completed';
        case 'red':
        case 'cancelled':
          return 'Cancelled';
        default:
          return order.statusLabel;
      }
    }
  }
}