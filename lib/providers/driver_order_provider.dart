// lib/providers/driver_order_provider.dart - ENHANCED with better live updates

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/driver_api_service.dart';
import '../models/order.dart';
import 'package:epos/services/uk_time_service.dart';

class DriverOrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _colorUpdateTimer; // New timer for live color updates
  String _selectedDate = DateFormat('yyyy-MM-dd').format(UKTimeService.now());
  bool _isDisposed = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedDate => _selectedDate;

  // Start polling for live updates with enhanced frequency
  void startPolling() {
    _pollTimer?.cancel();
    _colorUpdateTimer?.cancel();

    loadOrders(); // Load immediately

    // Poll for new data every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      loadOrders(
        showLoading: false,
      ); // Don't show loading indicator for polling
    });

    // Update colors every 60 seconds for live time-based changes
    _colorUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _updateColorsLive();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _colorUpdateTimer?.cancel();
  }

  // Method to update colors live without fetching new data
  void _updateColorsLive() {
    if (!_isDisposed) {
      // Just notify listeners to trigger color recalculation
      // The statusColor getter will automatically calculate new colors based on current time
      print('🎨 Live color update triggered at ${UKTimeService.now()}');
      notifyListeners();
    }
  }

  void setSelectedDate(String date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      loadOrders();
    }
  }

  Future<void> loadOrders({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      if (!_isDisposed) notifyListeners();
    }

    try {
      final ordersData = await DriverApiService.getOrdersWithDriver(
        _selectedDate,
      );

      List<Order> newOrders =
          ordersData.map((orderData) {
            // Parse items exactly as API provides
            List<Map<String, dynamic>> items = [];
            if (orderData['items'] != null) {
              items =
                  (orderData['items'] as List)
                      .map((item) {
                        return {
                          'item_name': item['item_name'] ?? 'Unknown Item',
                          'quantity': item['quantity'] ?? 1,
                          'item_total_price':
                              item['total_price'] ??
                              '0.00', // Keep as string from API
                          'item_description': item['description'] ?? '',
                          'item_type': 'food',
                        };
                      })
                      .toList()
                      .cast<Map<String, dynamic>>();
            }

            // Create order JSON that exactly matches your working order structure
            final orderJson = {
              'order_id': orderData['order_id'],
              'payment_type': 'cod',
              'transaction_id': orderData['order_id'].toString(),
              'order_type': 'delivery',
              'driver_id':
                  orderData['driver_id'], // Ensure this is not null for assigned orders
              'status': orderData['status'],
              'created_at': _parseOrderTime(orderData['order_time']),
              'change_due': null,
              'order_source': 'driver_portal',
              'customer_name': orderData['driver_name'], // Driver name for card
              'customer_email':
                  orderData['customer_name'], // Customer name for dialog
              'phone_number': orderData['driver_phone'],
              'street_address': orderData['customer_street_address'],
              'city': orderData['customer_city'],
              'county': orderData['customer_county'],
              'postal_code': orderData['customer_postal_code'],
              'order_total_price':
                  orderData['total_price'], // Keep as string from API
              'order_extra_notes': '',
              'items': items,
            };

            return Order.fromJson(orderJson);
          }).toList();

      // Check if orders have actually changed to avoid unnecessary rebuilds
      bool ordersChanged = false;
      if (_orders.length != newOrders.length) {
        ordersChanged = true;
      } else {
        for (int i = 0; i < _orders.length; i++) {
          final oldOrder = _orders[i];
          final newOrder = newOrders[i];

          if (oldOrder.orderId != newOrder.orderId ||
              oldOrder.status != newOrder.status ||
              oldOrder.driverId != newOrder.driverId) {
            ordersChanged = true;
            break;
          }
        }
      }

      _orders = newOrders;
      _error = null;

      if (ordersChanged) {
        print('📊 Orders changed - triggering UI update');
      }
    } catch (e) {
      print('Error loading driver orders: $e');
      _error = e.toString();
      if (!showLoading) {
        return;
      }
      _orders = [];
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      // Always notify listeners to ensure UI updates
      if (!_isDisposed) notifyListeners();
    }
  }

  String _parseOrderTime(String orderTime) {
    try {
      // Convert time like "14:30:25" to full datetime for today
      final today = UKTimeService.now();
      final timeParts = orderTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      final orderDateTime = DateTime(
        today.year,

        today.month,
        today.day,
        hour,
        minute,
        second,
      );

      return orderDateTime.toIso8601String();
    } catch (e) {
      print('Error parsing order time: $e');
      return UKTimeService.now().toIso8601String();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }
}
