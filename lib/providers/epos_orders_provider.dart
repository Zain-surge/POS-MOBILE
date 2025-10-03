// lib/providers/epos_orders_provider.dart - WITH LIVE POLLING

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/services/offline_order_manager.dart';
import 'package:epos/providers/active_orders_provider.dart';
import 'package:epos/services/connectivity_service.dart';
import 'dart:async';

class EposOrdersProvider extends ChangeNotifier {
  List<Order> _allOrders = [];
  bool _isLoading = false;
  String? _error;
  ActiveOrdersProvider? _activeOrdersProvider;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);
  bool _isDisposed = false;

  List<Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EposOrdersProvider() {
    print('🔵 EposOrdersProvider constructor called');
    fetchAllOrders();
    _startPolling();

    // Register for sync completion notifications
    ConnectivityService().addSyncCompletionListener(_onSyncCompleted);
  }

  @override
  void dispose() {
    // Set disposed flag first to prevent any callbacks from triggering notifications
    _isDisposed = true;
    
    // Remove connectivity listener first before stopping polling
    try {
      ConnectivityService().removeSyncCompletionListener(_onSyncCompleted);
    } catch (e) {
      print('⚠️ EposOrdersProvider: Error removing connectivity listener: $e');
      // Continue with disposal even if listener removal fails
    }
    
    // Stop polling after removing listener
    _stopPolling();
    
    super.dispose();
  }

  /// Start automatic polling for live updates
  void _startPolling() {
    print(
      '🔄 Starting live polling every ${_pollingInterval.inSeconds} seconds',
    );
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!_isLoading) {
        _fetchOrdersQuietly();
      }
    });
  }

  /// Stop polling
  void _stopPolling() {
    print('⏹️ Stopping live polling');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Pause polling (useful when app goes to background)
  void pausePolling() {
    print('⏸️ Pausing live polling');
    _stopPolling();
  }

  /// Resume polling (useful when app comes to foreground)
  void resumePolling() {
    print('▶️ Resuming live polling');
    _startPolling();
  }

  /// Handle sync completion - trigger immediate refresh
  void _onSyncCompleted() {
    // Double-check disposal status for extra safety
    if (_isDisposed) {
      print('⚠️ EposOrdersProvider: _onSyncCompleted called after disposal - ignoring');
      return;
    }
    
    print(
      '🔄 EposOrdersProvider: Sync completed, triggering immediate refresh...',
    );
    
    // Additional safety check before calling _fetchOrdersQuietly
    try {
      _fetchOrdersQuietly();
    } catch (e) {
      print('⚠️ EposOrdersProvider: Error in _onSyncCompleted: $e');
    }
  }

  // IMPROVED: Method to set the ActiveOrdersProvider reference
  void setActiveOrdersProvider(ActiveOrdersProvider activeOrdersProvider) {
    print('🔗 setActiveOrdersProvider called');
    print('🔗 Received ActiveOrdersProvider: ${activeOrdersProvider.hashCode}');
    _activeOrdersProvider = activeOrdersProvider;
    print(
      '🔗 ActiveOrdersProvider stored: ${_activeOrdersProvider?.hashCode ?? 'NULL'}',
    );
    print('✅ EposOrdersProvider linked to ActiveOrdersProvider successfully!');
  }

  /// Silent fetch for polling (doesn't show loading indicator)
  Future<void> _fetchOrdersQuietly() async {
    try {
      print("🔄 EposOrdersProvider: Silent polling fetch...");

      // Fetch online orders
      List<Order> fetchedOrders = await OrderApiService.fetchTodayOrders();

      // Add offline orders
      List<Order> offlineOrders =
          OfflineOrderManager.getOfflineOrdersAsOrders();

      // Combine both lists (offline orders first so they appear at top)
      List<Order> combinedOrders = [...offlineOrders, ...fetchedOrders];

      // Check if there are meaningful changes
      bool hasChanges = _hasOrderChanges(_allOrders, combinedOrders);

      if (hasChanges) {
        print("🔄 EposOrdersProvider: Changes detected during polling");
        _allOrders = combinedOrders;
        print(
          "🔵 EposOrdersProvider: Updated cache with ${_allOrders.length} orders via polling.",
        );

        // Notify listeners for live updates
        if (!_isDisposed) notifyListeners();

        // Also refresh ActiveOrdersProvider if linked
        if (_activeOrdersProvider != null) {
          print(
            "🔄 EposOrdersProvider: Refreshing ActiveOrdersProvider due to polling changes...",
          );
          await _activeOrdersProvider!.refreshOrders();
          print(
            "✅ EposOrdersProvider: ActiveOrdersProvider refreshed via polling!",
          );
        }
      } else {
        print("ℹ️ EposOrdersProvider: No changes detected during polling");
      }
    } catch (e) {
      print("❌ EposOrdersProvider: Silent polling error: $e");

      // During polling failures, still update offline orders but preserve online cache
      try {
        List<Order> offlineOrders =
            OfflineOrderManager.getOfflineOrdersAsOrders();
        List<Order> existingOnlineOrders =
            _allOrders
                .where((order) => order.orderSource != 'epos_offline')
                .toList();

        List<Order> combinedOrders = [
          ...offlineOrders,
          ...existingOnlineOrders,
        ];

        // Only update and notify if there are changes
        bool hasChanges = _hasOrderChanges(_allOrders, combinedOrders);
        if (hasChanges) {
          _allOrders = combinedOrders;
          print(
            "📱 EposOrdersProvider: Silent polling failed, preserved cache + updated offline orders",
          );
          if (!_isDisposed) notifyListeners();
        }
      } catch (offlineError) {
        print(
          "❌ EposOrdersProvider: Error updating offline orders during polling: $offlineError",
        );
      }

      // Don't update error state during silent polling to avoid UI disruption
    }
  }

  /// Check if orders have meaningful changes
  bool _hasOrderChanges(List<Order> oldOrders, List<Order> newOrders) {
    if (oldOrders.length != newOrders.length) {
      print(
        "📊 Order count changed: ${oldOrders.length} -> ${newOrders.length}",
      );
      return true;
    }

    // Create maps for efficient comparison
    Map<int, String> oldOrderStatus = {
      for (var order in oldOrders)
        order.orderId: '${order.status}_${order.driverId ?? 0}',
    };
    Map<int, String> newOrderStatus = {
      for (var order in newOrders)
        order.orderId: '${order.status}_${order.driverId ?? 0}',
    };

    // Check for status or driver changes
    for (var orderId in newOrderStatus.keys) {
      if (oldOrderStatus[orderId] != newOrderStatus[orderId]) {
        print(
          "📊 Order $orderId changed: ${oldOrderStatus[orderId]} -> ${newOrderStatus[orderId]}",
        );
        return true;
      }
    }

    // Check for new or removed orders
    Set<int> oldIds = oldOrderStatus.keys.toSet();
    Set<int> newIds = newOrderStatus.keys.toSet();
    if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
      print("📊 Order IDs changed");
      return true;
    }

    return false;
  }

  /// Fetches all today's orders and caches them (with loading indicator)
  Future<void> fetchAllOrders() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    if (!_isDisposed) notifyListeners();

    try {
      print("🔵 EposOrdersProvider: Fetching all today's orders...");

      // Fetch online orders
      List<Order> fetchedOrders = await OrderApiService.fetchTodayOrders();

      // Add offline orders
      List<Order> offlineOrders =
          OfflineOrderManager.getOfflineOrdersAsOrders();

      // Combine both lists (offline orders first so they appear at top)
      List<Order> combinedOrders = [...offlineOrders, ...fetchedOrders];

      // Check if there are new orders compared to current cache
      bool hasChanges = _hasOrderChanges(_allOrders, combinedOrders);

      _allOrders = combinedOrders;
      print(
        "🔵 EposOrdersProvider: Cached ${fetchedOrders.length} online + ${offlineOrders.length} offline orders.",
      );

      // 🚨 CRITICAL FIX: Notify ActiveOrdersProvider when orders change
      if (hasChanges && _activeOrdersProvider != null) {
        print(
          "🔄 EposOrdersProvider: Changes detected, refreshing ActiveOrdersProvider...",
        );
        await _activeOrdersProvider!.refreshOrders();
        print(
          "✅ EposOrdersProvider: ActiveOrdersProvider refreshed successfully!",
        );
      } else if (hasChanges) {
        print(
          "⚠️ EposOrdersProvider: Changes detected but ActiveOrdersProvider is NULL!",
        );
      } else {
        print(
          "ℹ️ EposOrdersProvider: No changes detected, skipping ActiveOrdersProvider refresh",
        );
      }
    } catch (e) {
      print("❌ EposOrdersProvider: Error fetching online orders: $e");

      // Even if online fetch fails, still show offline orders and preserve existing cache
      List<Order> offlineOrders =
          OfflineOrderManager.getOfflineOrdersAsOrders();

      if (_allOrders.isEmpty) {
        // If we have no cached orders, show only offline orders
        _allOrders = offlineOrders;
        print(
          "📱 EposOrdersProvider: Showing ${offlineOrders.length} offline orders only (no cache)",
        );
      } else {
        // Preserve existing cached orders but update offline orders
        List<Order> existingOnlineOrders =
            _allOrders
                .where((order) => order.orderSource != 'epos_offline')
                .toList();
        _allOrders = [...offlineOrders, ...existingOnlineOrders];
        print(
          "📱 EposOrdersProvider: Preserved ${existingOnlineOrders.length} cached orders + ${offlineOrders.length} offline orders",
        );
      }

      _error = 'Failed to fetch online orders: $e';
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Filters cached orders for takeaway screen
  List<Order> getTakeawayOrders(String? subFilter) {
    return _allOrders.where((order) {
      final String orderSourceLower = order.orderSource.toLowerCase();
      final String orderTypeLower = order.orderType.toLowerCase();

      // Include both regular EPOS orders and offline EPOS orders
      if (orderSourceLower != 'epos' && orderSourceLower != 'epos_offline')
        return false;

      if (subFilter?.toLowerCase() == 'takeaway') {
        return orderTypeLower == 'takeaway' || orderTypeLower == 'pickup';
      } else if (subFilter?.toLowerCase() == 'collection') {
        return orderTypeLower == 'collection';
      } else {
        return orderTypeLower == 'takeaway' ||
            orderTypeLower == 'pickup' ||
            orderTypeLower == 'collection';
      }
    }).toList();
  }

  List<Order> getDineInOrders() {
    return _allOrders.where((order) {
      final String orderSourceLower = order.orderSource.toLowerCase();
      final String orderTypeLower = order.orderType.toLowerCase();

      return orderSourceLower == 'epos' &&
          (orderTypeLower == 'dinein' ||
              orderTypeLower == 'dine_in' ||
              orderTypeLower == 'dine in' ||
              orderTypeLower == 'dine-in' ||
              orderTypeLower == 'takeout');
    }).toList();
  }

  List<Order> getDeliveryOrders() {
    return _allOrders.where((order) {
      // Include both regular EPOS orders and offline EPOS orders
      final isEposOrder =
          order.orderSource.toLowerCase() == 'epos' ||
          order.orderSource.toLowerCase() == 'epos_offline';
      return isEposOrder && order.orderType.toLowerCase() == 'delivery';
    }).toList();
  }

  void updateOrderInCache(int orderId, String newStatus) {
    final orderIndex = _allOrders.indexWhere(
      (order) => order.orderId == orderId,
    );
    if (orderIndex != -1) {
      print(
        "🔵 EposOrdersProvider: Updating order $orderId in cache from ${_allOrders[orderIndex].status} to $newStatus",
      );
      _allOrders[orderIndex] = _allOrders[orderIndex].copyWith(
        status: newStatus,
      );
      if (!_isDisposed) notifyListeners();
    }
  }

  void revertOrderInCache(int orderId, String originalStatus) {
    final orderIndex = _allOrders.indexWhere(
      (order) => order.orderId == orderId,
    );
    if (orderIndex != -1) {
      print(
        "🔵 EposOrdersProvider: Reverting order $orderId in cache to $originalStatus",
      );
      _allOrders[orderIndex] = _allOrders[orderIndex].copyWith(
        status: originalStatus,
      );
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    print("🔵 EposOrdersProvider: updateOrderStatus called");
    print("🔵 Order ID: $orderId, New Status: $newStatus");
    print(
      "🔍 Current _activeOrdersProvider: ${_activeOrdersProvider?.hashCode ?? 'NULL'}",
    );

    final orderIndex = _allOrders.indexWhere(
      (order) => order.orderId == orderId,
    );
    if (orderIndex == -1) {
      print("❌ EposOrdersProvider: Order $orderId not found in cache");
      return false;
    }

    final order = _allOrders[orderIndex];
    final originalStatus = order.status;

    // CRITICAL: Prevent status updates on offline orders
    if (originalStatus.toLowerCase() == 'offline' ||
        order.orderSource == 'epos_offline') {
      print(
        "❌ EposOrdersProvider: Cannot update status of offline order $orderId - must sync to backend first",
      );
      print(
        "💡 Suggestion: Use Force Sync to send offline orders to backend first",
      );
      return false;
    }
    final updatedOrder = _allOrders[orderIndex].copyWith(status: newStatus);
    _allOrders[orderIndex] = updatedOrder;
    if (!_isDisposed) notifyListeners();

    print(
      "🟢 Optimistic update applied: Order $orderId status changed from $originalStatus to $newStatus",
    );

    try {
      // Backend update
      String backendStatus = _mapToBackendStatus(newStatus);
      bool success = await OrderApiService.updateOrderStatus(
        orderId,
        backendStatus,
      );

      print("🔵 Backend update success: $success");

      if (!success) {
        // Revert optimistic update on failure
        print(
          "❌ EposOrdersProvider: Backend update failed, reverting order $orderId to $originalStatus",
        );
        revertOrderInCache(orderId, originalStatus);
        return false;
      }

      print(
        "✅ Order $orderId successfully updated to $newStatus both locally and on backend",
      );

      // CRITICAL FIX: Check and trigger ActiveOrdersProvider update
      print("🔍 Checking ActiveOrdersProvider reference...");
      if (_activeOrdersProvider != null) {
        print(
          "🔄 ActiveOrdersProvider found! Hash: ${_activeOrdersProvider!.hashCode}",
        );
        print(
          "🔄 Manually triggering ActiveOrdersProvider update for order $orderId",
        );

        // Create the updated order with all current properties
        final finalUpdatedOrder = _allOrders[orderIndex];
        print(
          "🔄 Sending updated order: ${finalUpdatedOrder.orderId}, status: ${finalUpdatedOrder.status}",
        );

        _activeOrdersProvider!.handleManualOrderUpdate(finalUpdatedOrder);
        print("✅ ActiveOrdersProvider update triggered successfully!");
      } else {
        print("❌ ActiveOrdersProvider reference is NULL!");
        print("❌ This means the linking failed in main.dart");
        print("❌ Check the console for provider creation logs");
      }

      return true;
    } catch (e) {
      print("❌ EposOrdersProvider: Error updating order: $e");
      revertOrderInCache(orderId, originalStatus);
      return false;
    }
  }

  /// Maps internal status to backend status
  String _mapToBackendStatus(String internalStatus) {
    switch (internalStatus.toLowerCase()) {
      case 'pending':
        return 'yellow';
      case 'ready':
        return 'green';
      case 'completed':
        return 'blue';
      default:
        return internalStatus.toLowerCase();
    }
  }

  /// Handle socket updates for real-time sync
  void handleSocketUpdate(Map<String, dynamic> payload) {
    final int? orderId = payload['order_id'] as int?;
    final String? newStatusBackend = payload['new_status'] as String?;
    final int? newDriverId = payload['new_driver_id'] as int?;

    if (orderId == null || newStatusBackend == null) return;

    // Find and update the order in cache
    final orderIndex = _allOrders.indexWhere(
      (order) => order.orderId == orderId,
    );
    if (orderIndex != -1) {
      final String newInternalStatus = _mapFromBackendStatus(newStatusBackend);
      final updatedOrder = _allOrders[orderIndex].copyWith(
        status: newInternalStatus,
        driverId: newDriverId,
      );
      _allOrders[orderIndex] = updatedOrder;
      if (!_isDisposed) notifyListeners();
      print(
        "🔵 EposOrdersProvider: Socket update applied for order $orderId - status: $newInternalStatus",
      );
    } else {
      print(
        "🔵 EposOrdersProvider: Socket update for order $orderId not found in cache, triggering refresh",
      );
      // If order not found, it might be a new order, so refresh
      fetchAllOrders();
    }
  }

  String _mapFromBackendStatus(String backendStatus) {
    switch (backendStatus.toLowerCase()) {
      case 'yellow':
        return 'pending';
      case 'green':
        return 'ready';
      case 'blue':
        return 'completed';
      default:
        return backendStatus;
    }
  }

  /// Force refresh from backend (for pull-to-refresh scenarios)
  Future<void> refresh() async {
    await fetchAllOrders();
  }

  /// Helper method to get an order by ID from cache
  Order? getOrderById(int orderId) {
    try {
      return _allOrders.firstWhere((order) => order.orderId == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Add a new offline order to the orders list
  Future<void> addOfflineOrder(Order offlineOrder) async {
    try {
      // Add the offline order at the beginning of the list
      _allOrders.insert(0, offlineOrder);

      print(
        "📱 EposOrdersProvider: Added offline order ${offlineOrder.transactionId}",
      );

      // Notify listeners to update UI immediately
      if (!_isDisposed) notifyListeners();

      // Also notify ActiveOrdersProvider if linked
      if (_activeOrdersProvider != null) {
        print(
          "🔄 EposOrdersProvider: Notifying ActiveOrdersProvider of new offline order...",
        );
        await _activeOrdersProvider!.refreshOrders();
        print(
          "✅ EposOrdersProvider: ActiveOrdersProvider notified successfully!",
        );
      }
    } catch (e) {
      print("❌ EposOrdersProvider: Error adding offline order: $e");
    }
  }

  /// Clear cache (useful for logout scenarios)
  void clearCache() {
    _allOrders.clear();
    _error = null;
    _stopPolling();
    if (!_isDisposed) notifyListeners();
  }
}
