// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _websiteOrders = [];

  List<Order> get websiteOrders => _websiteOrders;

  OrderProvider() {
    fetchWebsiteOrders();
  }

  Future<void> fetchWebsiteOrders() async {
    print("OrderProvider: Fetching displayable website orders...");
    try {

      List<Order> fetchedOrders = await OrderApiService.fetchTodayOrders();
      _websiteOrders = fetchedOrders.where((order) {
        final isWebsiteSource = order.orderSource.toLowerCase() == 'website';
        final isDisplayableStatus = ['accepted', 'preparing', 'ready', 'delivered', 'blue', 'green'].contains(order.status.toLowerCase());
        return isWebsiteSource && isDisplayableStatus;
      }).toList();
      print("OrderProvider: Fetched ${_websiteOrders.length} displayable website orders.");
      notifyListeners(); // Notify listeners that data has changed
    } catch (e) {
      print("OrderProvider: Error fetching website orders: $e");
    }
  }

  // Method to update a single order's status and refresh the list
  Future<bool> updateAndRefreshOrder(int orderId, String newStatus) async {
    print("OrderProvider: Attempting to update order $orderId to status $newStatus.");
    bool success = await OrderApiService.updateOrderStatus(orderId, newStatus);
    if (success) {
      await fetchWebsiteOrders();
      return true;
    }
    return false;
  }
}