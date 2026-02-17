// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:epos/services/offline_storage_service.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/models/offline_order.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  final List<Function(bool)> _listeners = [];
  final List<Function()> _syncCompletionListeners = [];

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity status
    await _checkInitialConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('❌ Connectivity monitoring error: $error');
      },
    );

    print('🌐 ConnectivityService initialized');
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      print(
        '🌐 DEBUG: Initial connectivity check results: ${results.map((r) => r.name).join(', ')}',
      );
      await _updateConnectivityStatus(results);
      print('🌐 DEBUG: Initial connectivity status set to: $_isOnline');
    } catch (e) {
      print('❌ Error checking initial connectivity: $e');
      _isOnline = false;
      print('🌐 DEBUG: Setting connectivity to false due to error');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    await _updateConnectivityStatus(results);
  }

  Future<void> _updateConnectivityStatus(
    List<ConnectivityResult> results,
  ) async {
    final wasOnline = _isOnline;
    // Check if any connection is available (not none)
    _isOnline =
        results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    print(
      '🌐 Connectivity changed: ${results.map((r) => r.name).join(', ')} (Online: $_isOnline)',
    );

    // Save connectivity status
    await OfflineStorageService.saveConnectivityStatus(_isOnline);

    // Notify listeners
    _notifyListeners();

    // If we just came back online, try to sync pending orders
    if (!wasOnline && _isOnline) {
      print('🔄 Connection restored, attempting to sync offline orders...');
      // Small delay to let UI update and show sync button
      await Future.delayed(const Duration(milliseconds: 100));
      await _syncOfflineOrders();
    }
  }

  // Add connectivity listener
  void addListener(Function(bool isOnline) listener) {
    _listeners.add(listener);
  }

  // Remove connectivity listener
  void removeListener(Function(bool isOnline) listener) {
    _listeners.remove(listener);
  }

  // Add sync completion listener
  void addSyncCompletionListener(Function() listener) {
    _syncCompletionListeners.add(listener);
  }

  // Remove sync completion listener
  void removeSyncCompletionListener(Function() listener) {
    _syncCompletionListeners.remove(listener);
  }

  // Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener(_isOnline);
      } catch (e) {
        print('❌ Error notifying connectivity listener: $e');
      }
    }
  }

  // Notify sync completion listeners
  void _notifySyncCompletion() {
    for (final listener in _syncCompletionListeners) {
      try {
        listener();
      } catch (e) {
        print('❌ Error notifying sync completion listener: $e');
      }
    }
  }

  // Sync offline orders when connection is restored
  Future<void> _syncOfflineOrders() async {
    if (_isSyncing || !_isOnline) {
      return;
    }

    _isSyncing = true;
    print('🔄 Starting offline orders sync...');
    _notifyListeners(); // Notify that sync started

    try {
      final pendingOrders = OfflineStorageService.getPendingOrders();

      print('🔍 Checking for pending orders to sync...');
      print('🔍 Found ${pendingOrders.length} pending orders');

      // Debug: Show details of pending orders
      for (final order in pendingOrders) {
        print(
          '🔍 Pending order: ${order.transactionId} (Status: ${order.status})',
        );
      }

      if (pendingOrders.isEmpty) {
        print('✅ No pending orders to sync');
        _isSyncing = false;
        return;
      }

      print('📤 Syncing ${pendingOrders.length} pending orders...');

      int successCount = 0;
      int failureCount = 0;

      for (final order in pendingOrders) {
        try {
          await _syncSingleOrder(order);
          successCount++;
        } catch (e) {
          print('❌ Failed to sync order ${order.transactionId}: $e');
          await OfflineStorageService.markOrderAsFailed(
            order.localId,
            e.toString(),
          );
          failureCount++;
        }

        // Small delay between syncs to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('✅ Sync completed: $successCount succeeded, $failureCount failed');

      // Cleanup old synced orders
      await OfflineStorageService.cleanupOldOrders();

      // Notify listeners about sync completion to trigger UI refresh
      _notifyListeners();

      // Notify sync completion listeners for immediate refresh
      if (successCount > 0) {
        print(
          '🔄 Notifying sync completion listeners for immediate refresh...',
        );
        _notifySyncCompletion();
      }
    } catch (e) {
      print('❌ Error during offline orders sync: $e');
    } finally {
      _isSyncing = false;
      _notifyListeners(); // Notify that sync ended
    }
  }

  Future<void> _syncSingleOrder(OfflineOrder order) async {
    print('📤 Processing offline order: ${order.transactionId}');
    print(
      '📤 Order details: ${order.customerName}, ${order.orderType}, £${order.orderTotalPrice}',
    );

    try {
      // Build order data in the same format as the app normally uses
      final orderData = _buildOrderDataFromOfflineOrder(order);
      print('📤 Built order data for API: ${orderData['transaction_id']}');

      // Use the existing ApiService.createOrderFromMap method
      // This ensures the order goes through the same validation and processing
      print('dY"\x0f Calling ApiService.createOrderFromMap...');
      final orderResponse = await ApiService.createOrderFromMap(orderData);
      final orderId = orderResponse.orderId ?? '';
      final orderNumber = orderResponse.orderNumber;
      print(
        'dY"\x0f API call completed, received orderId: $orderId, orderNumber: ${orderNumber ?? "N/A"}',
      );

      if (orderId.isNotEmpty) {
        // Extract numeric ID if possible, otherwise use 0 as placeholder
        int numericOrderId = 0;
        try {
          numericOrderId = int.tryParse(orderId) ?? 0;
        } catch (e) {
          // orderId might be a message, not a number
          print('Order ID is not numeric: $orderId');
        }

        await OfflineStorageService.markOrderAsSynced(
          order.localId,
          numericOrderId,
        );
        final orderNumberLog =
            orderNumber != null ? ' (Order #: ' + orderNumber + ')' : '';
        print(
          '?o. Offline order ${order.transactionId} processed successfully with ID: $orderId' +
              orderNumberLog,
        );
      } else {
        throw Exception('API returned empty order ID');
      }
    } catch (e) {
      print('❌ Failed to process offline order ${order.transactionId}: $e');
      throw Exception('Failed to process offline order: $e');
    }
  }

  Map<String, dynamic> _buildOrderDataFromOfflineOrder(OfflineOrder order) {
    final String paymentTypeLower = order.paymentType.toLowerCase();
    final bool paidStatus =
        paymentTypeLower != 'unpaid' &&
        !paymentTypeLower.contains('cod') &&
        !paymentTypeLower.contains('cash on delivery');
    final double amountReceived = paidStatus ? order.orderTotalPrice : 0.0;

    // Convert OfflineOrder back to the format expected by ApiService.createOrderFromMap
    return {
      "guest": {
        "name": order.customerName,
        "email": order.customerEmail ?? "N/A",
        "phone_number": order.phoneNumber ?? "N/A",
        "street_address": order.streetAddress ?? "N/A",
        "city": order.city ?? "N/A",
        "county": order.city ?? "N/A",
        "postal_code": order.postalCode ?? "N/A",
      },
      "transaction_id": order.transactionId,
      "payment_type": order.paymentType,
      "paid_status": paidStatus,
      "amount_received": amountReceived,
      "discount_percentage": 0.0, // No discount for offline orders
      "order_type": order.orderType,
      "order_source":
          "EPOS", // Backend expects uppercase EPOS for synced offline orders
      "status":
          "yellow", // Backend expects "yellow" status (displays as "Pending" in UI)
      "total_price": order.orderTotalPrice,
      "original_total_price": order.orderTotalPrice,
      "discount_amount": 0.0,
      "order_extra_notes": order.orderExtraNotes ?? "",
      "change_due": order.changeDue,
      "items":
          order.items
              .map(
                (item) => {
                  "item_id": item.foodItem.id,
                  "quantity": item.quantity,
                  "description": _buildDescriptionForOfflineItem(item),
                  "price_per_unit": item.pricePerUnit,
                  "total_price": item.totalPrice,
                  "comment": item.comment,
                  "extra_amount": 0.0,
                  "extra_reason": "",
                },
              )
              .toList(),
    };
  }

  String _buildDescriptionForOfflineItem(OfflineCartItem item) {
    final List<String> options =
        item.selectedOptions
            ?.map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList() ??
        [];

    final StringBuffer buffer = StringBuffer(item.foodItem.name);
    for (final option in options) {
      buffer.writeln();
      buffer.write(option);
    }
    return buffer.toString();
  }

  // Sync a specific offline order by transaction ID
  Future<bool> syncSingleOfflineOrder(String transactionId) async {
    if (!_isOnline) {
      print('❌ Cannot sync: device is offline');
      return false;
    }

    if (_isSyncing) {
      print('⏳ Sync already in progress...');
      return false;
    }

    try {
      // Find the offline order by transaction ID
      final offlineOrders = OfflineStorageService.getAllOfflineOrders();
      final order = offlineOrders.firstWhere(
        (order) =>
            order.transactionId == transactionId && order.status == 'pending',
        orElse:
            () => throw Exception('Offline order not found or already synced'),
      );

      print('🔄 Starting sync for single offline order: $transactionId');
      _isSyncing = true;
      _notifyListeners();

      await _syncSingleOrder(order);

      print('✅ Single order sync completed for: $transactionId');
      _notifySyncCompletion();
      return true;
    } catch (e) {
      print('❌ Error syncing single offline order: $e');
      throw e;
    } finally {
      _isSyncing = false;
      _notifyListeners();
    }
  }

  // Force sync now (can be called manually)
  Future<bool> forceSyncNow() async {
    print('🔄 Force sync requested...');
    print('🔄 Current status: online=$_isOnline, syncing=$_isSyncing');

    if (!_isOnline) {
      print('❌ Cannot sync: device is offline');
      return false;
    }

    if (_isSyncing) {
      print('⏳ Sync already in progress...');
      return false;
    }

    // DEBUGGING: Check orders before sync
    final pendingBefore = OfflineStorageService.getPendingOrders();
    print('📊 DEBUG: Orders before sync: ${pendingBefore.length}');
    for (final order in pendingBefore) {
      print(
        '📊 DEBUG: Before sync - Order ${order.transactionId}, Status: ${order.status}',
      );
    }

    print('🔄 Starting forced sync...');
    await _syncOfflineOrders();
    // Note: _syncOfflineOrders handles its own notifications

    // DEBUGGING: Check orders after sync
    final pendingAfter = OfflineStorageService.getPendingOrders();
    final allAfter = OfflineStorageService.getAllOfflineOrders();
    print(
      '📊 DEBUG: Orders after sync - Pending: ${pendingAfter.length}, Total: ${allAfter.length}',
    );
    for (final order in allAfter) {
      print(
        '📊 DEBUG: After sync - Order ${order.transactionId}, Status: ${order.status}',
      );
    }

    print('🔄 Forced sync completed');

    // Check if any orders were actually synced and notify for immediate refresh
    final pendingAfterFinal = OfflineStorageService.getPendingOrders();
    if (pendingBefore.length > pendingAfterFinal.length) {
      print(
        '🔄 Manual sync had success, notifying completion listeners for immediate refresh...',
      );
      _notifySyncCompletion();
    }

    return true;
  }

  // Check if we have internet connectivity
  Future<bool> hasInternetConnection() async {
    if (!_isOnline) {
      return false;
    }

    try {
      // Simple connectivity check without adding new API endpoints
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          !results.every((result) => result == ConnectivityResult.none);
    } catch (e) {
      print('❌ Internet connectivity test failed: $e');
      return false;
    }
  }

  // Get connectivity status info
  Map<String, dynamic> getConnectivityInfo() {
    final pendingCount = OfflineStorageService.getPendingOrdersCount();

    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'pending_orders_count': pendingCount,
      'last_connectivity_check': DateTime.now().toIso8601String(),
    };
  }

  // Dispose of resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _listeners.clear();
    print('🌐 ConnectivityService disposed');
  }
}
