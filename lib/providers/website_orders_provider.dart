// lib/providers/website_orders_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/services/driver_api_service.dart';
import 'package:epos/services/uk_time_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _websiteOrders = [];
  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isDisposed = false;
  static const Duration _pollingInterval = Duration(
    seconds: 10,
  ); // Poll every 10 seconds

  // Drivers data
  List<Map<String, dynamic>> _driversData = [];
  bool _isLoadingDrivers = false;

  List<Order> get websiteOrders => _websiteOrders;
  bool get isPolling => _isPolling;
  List<Map<String, dynamic>> get driversData => _driversData;
  bool get isLoadingDrivers => _isLoadingDrivers;

  OrderProvider() {
    fetchWebsiteOrders();
    fetchDriversData();
    startPolling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }

  // Start automatic polling
  void startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      fetchWebsiteOrders();
      fetchDriversData();
    });
    print(
      "OrderProvider: Started polling for order updates every ${_pollingInterval.inSeconds} seconds",
    );
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
      List<Order> newWebsiteOrders =
          fetchedOrders.where((order) {
            final isWebsiteSource =
                order.orderSource.toLowerCase() == 'website';
            final isDisplayableStatus = [
              'accepted',
              'preparing',
              'ready',
              'delivered',
              'blue',
              'green',
              'pending',
              'yellow',
              'completed',
              'cancelled',
              'red',
            ].contains(order.status.toLowerCase());
            return isWebsiteSource && isDisplayableStatus;
          }).toList();

      // Only notify listeners if the data actually changed
      if (_hasOrdersChanged(_websiteOrders, newWebsiteOrders)) {
        _websiteOrders = newWebsiteOrders;
        print(
          "OrderProvider: Orders changed - Fetched ${_websiteOrders.length} displayable website orders.",
        );
        notifyListeners(); // Notify listeners that data has changed
      } else {
        print("OrderProvider: No changes detected in orders.");
      }
    } catch (e) {
      print("OrderProvider: Error fetching website orders: $e");
    }
  }

  Future<void> fetchDriversData() async {
    print("OrderProvider: Fetching drivers data...");
    _isLoadingDrivers = true;
    notifyListeners();

    try {
      final today = UKTimeService.now();
      final dateString =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final ordersData = await DriverApiService.getOrdersWithDriver(dateString);
      print(
        "OrderProvider: Raw orders data received: ${ordersData.length} orders",
      );

      // Filter for relevant status orders (ready, green, completed, delivered, blue) and group by driver
      final relevantOrders =
          ordersData.where((orderData) {
            final status = orderData['status']?.toString().toLowerCase() ?? '';
            return [
              'ready',
              'green',
              'completed',
              'delivered',
              'blue',
            ].contains(status);
          }).toList();

      print("OrderProvider: Found ${relevantOrders.length} relevant orders");

      // Group orders by driver
      final Map<String, Map<String, dynamic>> driversMap = {};
      for (final orderData in relevantOrders) {
        final driverName =
            orderData['driver_name']?.toString() ?? 'Unknown Driver';
        final driverId = orderData['driver_id'];
        final driverPhone = orderData['driver_phone']?.toString() ?? '';

        if (!driversMap.containsKey(driverName)) {
          driversMap[driverName] = {
            'driver_name': driverName,
            'driver_id': driverId,
            'driver_phone': driverPhone,
            'orders': <Map<String, dynamic>>[],
          };
        }

        // Add order data with all necessary fields
        (driversMap[driverName]!['orders'] as List<Map<String, dynamic>>).add({
          'order_id': orderData['order_id'],
          'customer_name': orderData['customer_name'],
          'customer_address': orderData['customer_street_address'],
          'customer_city': orderData['customer_city'],
          'customer_county': orderData['customer_county'],
          'postal_code': orderData['customer_postal_code'],
          'total': orderData['total_price'],
          'status': orderData['status'],
          'created_at': orderData['order_time'],
          'driver_id': orderData['driver_id'],
          'driver_name': orderData['driver_name'],
          'items': orderData['items'] ?? [],
        });
      }

      final filteredData = driversMap.values.toList();
      print(
        "OrderProvider: Grouped into ${filteredData.length} drivers with ready orders",
      );

      // Only notify listeners if the data actually changed
      if (_hasDriversDataChanged(_driversData, filteredData)) {
        _driversData = filteredData;
        print(
          "OrderProvider: Drivers data changed - Fetched ${_driversData.length} drivers with ready orders.",
        );
      } else {
        print("OrderProvider: No changes detected in drivers data.");
      }
    } catch (e) {
      print("OrderProvider: Error fetching drivers data: $e");
    } finally {
      _isLoadingDrivers = false;
      notifyListeners(); // Always notify listeners when loading is complete
    }
  }

  // Helper method to check if drivers data has changed
  bool _hasDriversDataChanged(
    List<Map<String, dynamic>> oldData,
    List<Map<String, dynamic>> newData,
  ) {
    if (oldData.length != newData.length) return true;

    for (int i = 0; i < oldData.length; i++) {
      final oldDriver = oldData[i];
      final newDriver = newData[i];

      // Check for changes in driver name or orders count
      if (oldDriver['driver_name'] != newDriver['driver_name'] ||
          (oldDriver['orders'] as List).length !=
              (newDriver['orders'] as List).length) {
        return true;
      }

      // Check for changes in individual orders
      final oldOrders = oldDriver['orders'] as List<dynamic>;
      final newOrders = newDriver['orders'] as List<dynamic>;

      for (int j = 0; j < oldOrders.length; j++) {
        final oldOrder = oldOrders[j];
        final newOrder = newOrders[j];

        if (oldOrder['order_id'] != newOrder['order_id'] ||
            oldOrder['status'] != newOrder['status'] ||
            oldOrder['postal_code'] != newOrder['postal_code']) {
          return true;
        }
      }
    }

    return false;
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
          oldOrder.driverId != newOrder.driverId) {
        // Added driverId comparison
        return true;
      }
    }

    return false;
  }

  // Method to update a single order's status and refresh the list
  Future<bool> updateAndRefreshOrder(int orderId, String newStatus) async {
    print(
      "OrderProvider: Attempting to update order $orderId to status $newStatus.",
    );
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

    print(
      "OrderProvider: Getting display status for order ${order.orderId} - Status: $statusLower, Driver ID: ${order.driverId}, Has Driver: $hasDriver",
    );

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
