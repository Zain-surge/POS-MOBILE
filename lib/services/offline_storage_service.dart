// lib/services/offline_storage_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:epos/models/offline_order.dart';
import 'package:epos/models/cart_item.dart';
import 'package:uuid/uuid.dart';

class OfflineStorageService {
  static const String _offlineOrdersBoxName = 'offline_orders';
  static const String _orderCounterBoxName = 'order_counter';
  static const String _connectivityBoxName = 'connectivity_status';

  static Box<OfflineOrder>? _offlineOrdersBox;
  static Box? _orderCounterBox;
  static Box? _connectivityBox;

  // Initialize Hive and register adapters
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(OfflineOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OfflineCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(OfflineFoodItemAdapter());
    }

    // Open boxes
    _offlineOrdersBox = await Hive.openBox<OfflineOrder>(_offlineOrdersBoxName);
    _orderCounterBox = await Hive.openBox(_orderCounterBoxName);
    _connectivityBox = await Hive.openBox(_connectivityBoxName);

    print('🗃️ OfflineStorageService initialized successfully');
  }

  // Get offline orders box
  static Box<OfflineOrder> get offlineOrdersBox {
    if (_offlineOrdersBox == null || !_offlineOrdersBox!.isOpen) {
      throw Exception(
        'OfflineStorageService not initialized. Call initialize() first.',
      );
    }
    return _offlineOrdersBox!;
  }

  // Get order counter box
  static Box get orderCounterBox {
    if (_orderCounterBox == null || !_orderCounterBox!.isOpen) {
      throw Exception(
        'OfflineStorageService not initialized. Call initialize() first.',
      );
    }
    return _orderCounterBox!;
  }

  // Get connectivity box
  static Box get connectivityBox {
    if (_connectivityBox == null || !_connectivityBox!.isOpen) {
      throw Exception(
        'OfflineStorageService not initialized. Call initialize() first.',
      );
    }
    return _connectivityBox!;
  }

  // Generate a unique transaction ID for offline orders
  static String generateOfflineTransactionId() {
    final counter =
        orderCounterBox.get('offline_counter', defaultValue: 0) as int;
    final newCounter = counter + 1;
    orderCounterBox.put('offline_counter', newCounter);

    // Format: OFFLINE_YYYYMMDD_HHMMSS_COUNTER
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    return 'OFFLINE_${dateStr}_${timeStr}_${newCounter.toString().padLeft(3, '0')}';
  }

  // Save order to offline storage
  static Future<String> saveOfflineOrder({
    required List<CartItem> cartItems,
    required String paymentType,
    required String orderType,
    required double orderTotalPrice,
    String? orderExtraNotes,
    required String customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    required double changeDue,
    String? transactionIdOverride,
  }) async {
    try {
      if (transactionIdOverride != null && transactionIdOverride.isNotEmpty) {
        final existing =
            offlineOrdersBox.values.where((order) {
              return order.transactionId == transactionIdOverride;
            }).isNotEmpty;
        if (existing) {
          print(
            '🛑 Duplicate offline save blocked for transaction_id: $transactionIdOverride',
          );
          return transactionIdOverride;
        }
      }

      final localId = const Uuid().v4();
      final String transactionId =
          (transactionIdOverride != null && transactionIdOverride.isNotEmpty)
              ? transactionIdOverride
              : generateOfflineTransactionId();

      final offlineOrder = OfflineOrder.fromCartItems(
        localId: localId,
        transactionId: transactionId,
        paymentType: paymentType,
        orderType: orderType,
        cartItems: cartItems,
        orderTotalPrice: orderTotalPrice,
        orderExtraNotes: orderExtraNotes,
        customerName: customerName,
        customerEmail: customerEmail,
        phoneNumber: phoneNumber,
        streetAddress: streetAddress,
        city: city,
        postalCode: postalCode,
        changeDue: changeDue,
      );

      await offlineOrdersBox.put(localId, offlineOrder);

      print('💾 Order saved offline: $transactionId (Local ID: $localId)');
      print(
        '📦 Items: ${cartItems.length}, Total: £${orderTotalPrice.toStringAsFixed(2)}',
      );

      return transactionId;
    } catch (e) {
      print('❌ Error saving offline order: $e');
      throw Exception('Failed to save order offline: $e');
    }
  }

  // Get all pending offline orders
  static List<OfflineOrder> getPendingOrders() {
    try {
      return offlineOrdersBox.values
          .where((order) => order.status == 'pending')
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      print('❌ Error getting pending orders: $e');
      return [];
    }
  }

  // Get all offline orders (for debugging/admin)
  static List<OfflineOrder> getAllOfflineOrders() {
    try {
      return offlineOrdersBox.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Error getting all offline orders: $e');
      return [];
    }
  }

  // Update order status
  static Future<void> updateOrderStatus({
    required String localId,
    required String status,
    String? syncError,
    int? serverId,
  }) async {
    try {
      final order = offlineOrdersBox.get(localId);
      if (order != null) {
        final updatedOrder = order.copyWith(
          status: status,
          syncAttempts:
              status == 'failed'
                  ? (order.syncAttempts ?? 0) + 1
                  : order.syncAttempts,
          syncError: syncError,
          serverId: serverId,
        );

        await offlineOrdersBox.put(localId, updatedOrder);
        print('📝 Order $localId status updated to: $status');
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
    }
  }

  // Mark order as synced
  static Future<void> markOrderAsSynced(String localId, int serverId) async {
    await updateOrderStatus(
      localId: localId,
      status: 'synced',
      serverId: serverId,
    );
  }

  // Mark order as failed to sync
  static Future<void> markOrderAsFailed(String localId, String error) async {
    await updateOrderStatus(
      localId: localId,
      status: 'failed',
      syncError: error,
    );
  }

  // Delete synced orders older than specified days
  static Future<void> cleanupOldOrders({int olderThanDays = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      final ordersToDelete = <String>[];

      for (final order in offlineOrdersBox.values) {
        if (order.status == 'synced' && order.createdAt.isBefore(cutoffDate)) {
          ordersToDelete.add(order.localId);
        }
      }

      for (final localId in ordersToDelete) {
        await offlineOrdersBox.delete(localId);
      }

      if (ordersToDelete.isNotEmpty) {
        print('🧹 Cleaned up ${ordersToDelete.length} old synced orders');
      }
    } catch (e) {
      print('❌ Error cleaning up old orders: $e');
    }
  }

  // Get count of pending orders
  static int getPendingOrdersCount() {
    try {
      return offlineOrdersBox.values
          .where((order) => order.status == 'pending')
          .length;
    } catch (e) {
      print('❌ Error getting pending orders count: $e');
      return 0;
    }
  }

  // Save connectivity status
  static Future<void> saveConnectivityStatus(bool isOnline) async {
    try {
      await connectivityBox.put('is_online', isOnline);
      await connectivityBox.put(
        'last_updated',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('❌ Error saving connectivity status: $e');
    }
  }

  // Get last known connectivity status
  static bool getLastConnectivityStatus() {
    try {
      return connectivityBox.get('is_online', defaultValue: true) as bool;
    } catch (e) {
      print('❌ Error getting connectivity status: $e');
      return true; // Default to online if error
    }
  }

  // Close all boxes (cleanup)
  static Future<void> dispose() async {
    try {
      await _offlineOrdersBox?.close();
      await _orderCounterBox?.close();
      await _connectivityBox?.close();
      print('🗃️ OfflineStorageService disposed');
    } catch (e) {
      print('❌ Error disposing OfflineStorageService: $e');
    }
  }

  // Export orders for debugging (returns JSON string)
  static String exportOrdersForDebugging() {
    try {
      final orders = getAllOfflineOrders();
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_orders': orders.length,
        'pending_orders': orders.where((o) => o.status == 'pending').length,
        'synced_orders': orders.where((o) => o.status == 'synced').length,
        'failed_orders': orders.where((o) => o.status == 'failed').length,
        'orders':
            orders
                .map(
                  (order) => {
                    'local_id': order.localId,
                    'transaction_id': order.transactionId,
                    'status': order.status,
                    'created_at': order.createdAt.toIso8601String(),
                    'total_price': order.orderTotalPrice,
                    'sync_attempts': order.syncAttempts,
                    'sync_error': order.syncError,
                    'server_id': order.serverId,
                  },
                )
                .toList(),
      };

      return exportData.toString();
    } catch (e) {
      return 'Export failed: $e';
    }
  }
}
