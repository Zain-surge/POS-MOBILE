import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'dart:async';

class ActiveOrdersProvider with ChangeNotifier {
  final OrderCountsProvider _orderCountsProvider;
  List<Order> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  late StreamSubscription _newOrderSocketSubscription;
  late StreamSubscription _acceptedOrderStreamSubscription;
  late StreamSubscription _orderStatusChangedSubscription;

  final Map<int, Timer> _scheduledUpdates = {};

  List<Order> get activeOrders => _activeOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ActiveOrdersProvider(this._orderCountsProvider) {
    _fetchAndListenToOrders();
  }

  bool _shouldDisplayWebsiteOrder(Order order) {
    final status = order.status.toLowerCase();
    final source = order.orderSource.toLowerCase();

    print('🔍 _shouldDisplayWebsiteOrder: Order ${order.orderId}, source: $source, status: $status');

    if (source != 'website') {
      return false;
    }

    bool shouldShow = status == 'accepted' || status == 'green' || status == 'ready';

    print('🌐 Website order ${order.orderId}: status="$status" -> shouldShow=$shouldShow');

    if (!shouldShow) {
      print('🚫 Website order ${order.orderId} WILL NOT be displayed (status: $status)');
    }

    return shouldShow;
  }

  bool _shouldDisplayEposOrder(Order order) {
    final status = order.status.toLowerCase();
    final source = order.orderSource.toLowerCase();

    if (source != 'epos') {
      return false;
    }

    bool shouldShow = !['completed', 'delivered', 'declined', 'blue'].contains(status);
    print('🏪 EPOS order ${order.orderId}: status="$status" -> shouldShow=$shouldShow');

    return shouldShow;
  }
//anyorder
  bool _shouldDisplayOrder(Order order) {
    final source = order.orderSource.toLowerCase();

    print('🔍 Checking if order ${order.orderId} should be displayed...');
    print('📋 Order details: source=$source, status=${order.status}, type=${order.orderType}');

    if (source == 'website') {
      return _shouldDisplayWebsiteOrder(order);
    } else if (source == 'epos') {
      return _shouldDisplayEposOrder(order);
    } else {
      print('⚠️ Unknown order source: $source for order ${order.orderId}');
      return false;
    }
  }

  // Schedule color updates for specific orders
  void _scheduleColorUpdatesForOrder(Order order) {
    _scheduledUpdates[order.orderId]?.cancel();

    final DateTime now = DateTime.now();
    final Duration timeSinceCreated = now.difference(order.createdAt);

    const Duration greenToYellowThreshold = Duration(minutes: 30);
    const Duration yellowToRedThreshold = Duration(minutes: 45);

    Timer? nextUpdate;

    if (timeSinceCreated < greenToYellowThreshold) {
      // Schedule update when order becomes yellow (30 minutes)
      final Duration timeUntilYellow = greenToYellowThreshold - timeSinceCreated;
      nextUpdate = Timer(timeUntilYellow, () {
        print('⏰ Order ${order.orderId} becoming YELLOW');
        _calculateAndUpdateCounts();

        // Schedule next update for red (15 minutes later)
        _scheduledUpdates[order.orderId] = Timer(const Duration(minutes: 15), () {
          print('⏰ Order ${order.orderId} becoming RED');
          _calculateAndUpdateCounts();
          _scheduledUpdates.remove(order.orderId);
        });
      });
    } else if (timeSinceCreated < yellowToRedThreshold) {
      // Schedule update when order becomes red (45 minutes)
      final Duration timeUntilRed = yellowToRedThreshold - timeSinceCreated;
      nextUpdate = Timer(timeUntilRed, () {
        print('⏰ Order ${order.orderId} becoming RED');
        _calculateAndUpdateCounts();
        _scheduledUpdates.remove(order.orderId);
      });
    }

    if (nextUpdate != null) {
      _scheduledUpdates[order.orderId] = nextUpdate;
    }
  }

  // Cancel scheduled updates for removed orders
  void _cancelScheduledUpdatesForOrder(int orderId) {
    _scheduledUpdates[orderId]?.cancel();
    _scheduledUpdates.remove(orderId);
  }

  void handleManualOrderUpdate(Order updatedOrder) {
    print('🔄 ActiveOrdersProvider: Received manual update for order ${updatedOrder.orderId}');
    print('🔄 Updated order status: ${updatedOrder.status}');
    print('🔄 Updated order source: ${updatedOrder.orderSource}');

    // Process the updated order through the same logic as socket updates
    _processIncomingOrder(updatedOrder);
  }

  Future<void> _fetchAndListenToOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('🌐 ActiveOrdersProvider: Starting initial fetch of today\'s orders...');
      final allOrders = await OrderApiService.fetchTodayOrders();

      print('📊 Total orders fetched: ${allOrders.length}');
      for (var order in allOrders) {
        print('📋 Order ${order.orderId}: source=${order.orderSource}, status=${order.status}, type=${order.orderType}');
      }

      _activeOrders = _filterActiveOrders(allOrders);
      _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;

      print('✅ ActiveOrdersProvider: Filtered active orders count: ${_activeOrders.length}');
      for (var order in _activeOrders) {
        print('✅ Active Order: ${order.orderId} (${order.orderSource} - ${order.status})');
      }

      _calculateAndUpdateCounts();

      // Schedule updates for existing orders
      for (var order in _activeOrders) {
        _scheduleColorUpdatesForOrder(order);
      }

      // CRITICAL FIX: Notify listeners AFTER color calculation
      notifyListeners();

      _listenToStreams();
    } catch (e) {
      _error = 'Failed to load active orders: $e';
      _isLoading = false;
      print('❌ ActiveOrdersProvider: Error during initial fetch: $_error');
      notifyListeners();
    }
  }

  void _listenToStreams() {
    _newOrderSocketSubscription = OrderApiService().newOrderStream.listen((newOrder) {
      print('📦 ActiveOrdersProvider: Received new order from stream: ${newOrder.orderId}');
      print('📦 New order details: source=${newOrder.orderSource}, status=${newOrder.status}');
      _processIncomingOrder(newOrder);
    }, onError: (e) => print('❌ ActiveOrdersProvider: Error on newOrderStream: $e'));

    _acceptedOrderStreamSubscription = OrderApiService().acceptedOrderStream.listen((acceptedOrder) {
      print('✅ ActiveOrdersProvider: Received accepted order from stream: ${acceptedOrder.orderId}');
      print('✅ Accepted order details: source=${acceptedOrder.orderSource}, status=${acceptedOrder.status}');
      _processIncomingOrder(acceptedOrder);
    }, onError: (e) => print('❌ ActiveOrdersProvider: Error on acceptedOrderStream: $e'));

    _orderStatusChangedSubscription = OrderApiService().orderStatusOrDriverChangedStream.listen((data) {
      print('🔄 ActiveOrdersProvider: Received order status change: $data');
      _handleOrderStatusChange(data);
    }, onError: (e) => print('❌ ActiveOrdersProvider: Error on orderStatusOrDriverChangedStream: $e'));
  }

  List<Order> _filterActiveOrders(List<Order> orders) {
    print('🔍 === FILTERING ACTIVE ORDERS ===');
    print('🔍 Total orders to filter: ${orders.length}');

    final List<Order> filteredOrders = [];

    for (var order in orders) {
      print('🔍 Checking Order ${order.orderId}...');

      if (_shouldDisplayOrder(order)) {
        filteredOrders.add(order);
        print('✅ Order ${order.orderId} ADDED to active orders');
      } else {
        print('❌ Order ${order.orderId} EXCLUDED from active orders');
      }
    }

    print('📊 === FILTER COMPLETE ===');
    print('📊 Orders to display: ${filteredOrders.length}');
    print('📊 Website orders in list: ${filteredOrders.where((o) => o.orderSource.toLowerCase() == 'website').length}');
    print('📊 EPOS orders in list: ${filteredOrders.where((o) => o.orderSource.toLowerCase() == 'epos').length}');

    return filteredOrders;
  }

  void _processIncomingOrder(Order order) {
    print('🔄 === PROCESSING INCOMING ORDER ===');
    print('🔄 Order ID: ${order.orderId}');
    print('🔄 Order source: ${order.orderSource}');
    print('🔄 Order status: ${order.status}');
    print('🔄 Order type: ${order.orderType}');

    bool shouldDisplay = _shouldDisplayOrder(order);
    print('🔄 Should display: $shouldDisplay');

    int existingIndex = _activeOrders.indexWhere((o) => o.orderId == order.orderId);
    bool orderWasRemoved = false;
    bool orderWasUpdated = false;

    if (shouldDisplay) {
      if (existingIndex != -1) {
        print('🔄 Updating existing order in active list');
        _cancelScheduledUpdatesForOrder(order.orderId);
        _activeOrders[existingIndex] = order;
        _scheduleColorUpdatesForOrder(order);
        orderWasUpdated = true;
      } else {
        print('➕ Adding new order to active list');
        _activeOrders.add(order);
        _scheduleColorUpdatesForOrder(order);
      }
    } else {
      if (existingIndex != -1) {
        print('❌ Removing order from active list');
        _cancelScheduledUpdatesForOrder(_activeOrders[existingIndex].orderId);
        _activeOrders.removeAt(existingIndex);
        orderWasRemoved = true;
      } else {
        print('ℹ️ Order was not in active list and should not be added');
      }
    }

    _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('📊 Current active orders count after processing: ${_activeOrders.length}');
    print('📊 Website orders in active list: ${_activeOrders.where((o) => o.orderSource.toLowerCase() == 'website').length}');

    // Force immediate color calculation with detailed logging
    _calculateAndUpdateCountsWithLogging(orderWasRemoved, order.orderId);

    // Add a small delay to ensure state propagation
    Future.microtask(() {
      notifyListeners();
      print('🔔 ActiveOrdersProvider notifyListeners() called');
    });

    print('🔄 === PROCESSING COMPLETE ===');
  }

  // Add detailed logging version of color calculation
  void _calculateAndUpdateCountsWithLogging(bool wasRemoval, int orderId) {
    print('🎨 === STARTING COLOR CALCULATION ===');
    print('🎨 Triggered by: ${wasRemoval ? "REMOVAL" : "UPDATE"} of order $orderId');
    print('🎨 Current active orders count: ${_activeOrders.length}');

    if (_activeOrders.isEmpty) {
      print('🎨 No active orders - setting all to default green');
      _orderCountsProvider.updateAllCountsAndColors(
          {'takeaway': 0, 'takeout': 0, 'dinein': 0, 'delivery': 0, 'website': 0},
          {
            'takeaway': const Color(0xFF8cdd69),
            'takeout': const Color(0xFF8cdd69),
            'dinein': const Color(0xFF8cdd69),
            'delivery': const Color(0xFF8cdd69),
            'website': const Color(0xFF8cdd69),
          }
      );
      print('🎨 === COLOR CALCULATION COMPLETE (EMPTY) ===');
      return;
    }

    Map<String, int> currentTypeCounts = {
      'takeaway': 0, 'takeout': 0, 'dinein': 0, 'delivery': 0, 'website': 0,
    };

    Map<String, List<int>> allPrioritiesForTypes = {
      'takeaway': [], 'takeout': [], 'dinein': [], 'delivery': [], 'website': [],
    };

    Map<String, Color> dominantColorsForTypes = {
      'takeaway': const Color(0xFF8cdd69),
      'takeout': const Color(0xFF8cdd69),
      'dinein': const Color(0xFF8cdd69),
      'delivery': const Color(0xFF8cdd69),
      'website': const Color(0xFF8cdd69),
    };

    const Duration greenToYellowThreshold = Duration(minutes: 30);
    const Duration yellowToRedThreshold = Duration(minutes: 45);

    print('Analyzing ${_activeOrders.length} active orders:');

    for (var order in _activeOrders) {
      String orderTypeKey;
      String orderSourceLower = order.orderSource.toLowerCase();
      String orderTypeLower = order.orderType.toLowerCase();

      if (orderSourceLower == 'website') {
        orderTypeKey = 'website';
      } else if (orderSourceLower == 'epos') {
        if (orderTypeLower == 'takeaway' || orderTypeLower == 'pickup' || orderTypeLower == 'collection') {
          orderTypeKey = 'takeaway';
        } else if (orderTypeLower == 'takeout') {
          orderTypeKey = 'takeout';
        } else if (orderTypeLower == 'dinein') {
          orderTypeKey = 'dinein';
        } else if (orderTypeLower == 'delivery') {
          orderTypeKey = 'delivery';
        } else {
          print('Unknown order type: $orderTypeLower for order ${order.orderId}');
          continue;
        }
      } else {
        print('⚠️ Unknown order source: $orderSourceLower for order ${order.orderId}');
        continue;
      }

      final DateTime now = DateTime.now();
      final Duration timeElapsed = now.difference(order.createdAt);
      int timePriority;
      String colorName;

      if (timeElapsed >= yellowToRedThreshold) {
        timePriority = 3; // Red
        colorName = 'RED';
      } else if (timeElapsed >= greenToYellowThreshold) {
        timePriority = 2; // Yellow
        colorName = 'YELLOW';
      } else {
        timePriority = 1; // Green
        colorName = 'GREEN';
      }

      print('📋 Order ${order.orderId} ($orderTypeKey): $colorName (${timeElapsed.inMinutes} min old)');

      currentTypeCounts[orderTypeKey] = (currentTypeCounts[orderTypeKey] ?? 0) + 1;
      allPrioritiesForTypes[orderTypeKey]!.add(timePriority);
    }

    print('📊 Raw counts: $currentTypeCounts');

    // Determine the dominant color for each type based on highest priority
    allPrioritiesForTypes.forEach((orderTypeKey, priorities) {
      Color finalColor;
      String finalColorName;

      if (priorities.isEmpty) {
        finalColor = const Color(0xFF8cdd69);
        finalColorName = 'GREEN (default)';
      } else {
        int highestPriority = priorities.reduce((a, b) => a > b ? a : b);

        switch (highestPriority) {
          case 3:
            finalColor = const Color(0xFFff4848); // Red
            finalColorName = 'RED';
            break;
          case 2:
            finalColor = const Color(0xFFFFE26B); // Yellow
            finalColorName = 'YELLOW';
            break;
          case 1:
          default:
            finalColor = const Color(0xFF8cdd69); // Green
            finalColorName = 'GREEN';
            break;
        }
      }

      dominantColorsForTypes[orderTypeKey] = finalColor;
      print('🎨 Final color for $orderTypeKey: $finalColorName (priorities: $priorities)');
    });

    print('📊 Final counts to send: $currentTypeCounts');
    print('🎨 Final colors to send: ${dominantColorsForTypes.map((k, v) => MapEntry(k, v == const Color(0xFF8cdd69) ? 'GREEN' : v == const Color(0xFFFFE26B) ? 'YELLOW' : 'RED'))}');

    // Always update even if values seem the same
    _orderCountsProvider.updateAllCountsAndColors(currentTypeCounts, dominantColorsForTypes);

    print('✅ OrderCountsProvider.updateAllCountsAndColors() called');
    print('🎨 === COLOR CALCULATION COMPLETE ===');
  }

  void _calculateAndUpdateCounts() {
    _calculateAndUpdateCountsWithLogging(false, 0);
  }

  // Handle order status changes with improved error handling and immediate processing
  void _handleOrderStatusChange(Map<String, dynamic> data) {
    try {
      print('🔄 === HANDLING ORDER STATUS CHANGE ===');
      print('🔄 Raw status change data: $data');

      final int? orderId = data['order_id'] as int?;

      String? newStatus = data['status'] as String?;
      if (newStatus == null) {
        newStatus = data['new_status'] as String?;
      }

      // Also check for driver changes
      final int? newDriverId = data['driver_id'] as int? ?? data['new_driver_id'] as int?;

      if (orderId == null || newStatus == null) {
        print('⚠️ Invalid order status change data - missing order_id or status: $data');
        print('Available keys in data: ${data.keys.toList()}');
        return;
      }

      print('🔄 Processing status change for order $orderId: $newStatus');

      // Find the existing order in our active orders
      final existingIndex = _activeOrders.indexWhere((order) => order.orderId == orderId);

      if (existingIndex != -1) {
        final existingOrder = _activeOrders[existingIndex];
        print('🔄 Found existing order ${orderId} in active list');

        // Handle driver-only updates (when status doesn't change but driver is assigned)
        String finalStatus = newStatus != null ? _mapFromBackendStatus(newStatus) : existingOrder.status;

        final updatedOrder = existingOrder.copyWith(
          status: finalStatus,
          driverId: newDriverId,
        );

        print('🔄 Order $orderId status changed from ${existingOrder.status} to $finalStatus');

        // Check if this affects delivery display status
        final isDeliveryOrder = (existingOrder.orderSource.toLowerCase() == 'epos' && existingOrder.orderType.toLowerCase() == 'delivery') ||
            (existingOrder.orderSource.toLowerCase() == 'website' && existingOrder.orderType.toLowerCase() == 'delivery');

        if (isDeliveryOrder) {
          final oldDisplayStatus = existingOrder.getDisplayStatusLabel();
          final newDisplayStatus = updatedOrder.getDisplayStatusLabel();
          print('🚚 Delivery Order $orderId: Display status changing from "$oldDisplayStatus" to "$newDisplayStatus"');
        }

        _processIncomingOrder(updatedOrder);
      } else {
        print('⚠️ Order $orderId not found in active orders for status change');
        _fetchSpecificOrder(orderId);
      }

      print('🔄 === STATUS CHANGE HANDLING COMPLETE ===');
    } catch (e) {
      print('❌ Error processing order status change: $e');
      print('Data that caused the error: $data');
    }
  }

  // Add method to map backend status to internal status
  String _mapFromBackendStatus(String backendStatus) {
    switch (backendStatus.toLowerCase()) {
      case 'yellow':
        return 'pending';
      case 'green':
        return 'ready';
      case 'blue':
        return 'completed';
      case 'red':
        return 'urgent';
      default:
        return backendStatus;
    }
  }

  // Better error handling for specific order fetching
  Future<void> _fetchSpecificOrder(int orderId) async {
    try {
      print('🔍 Fetching specific order $orderId...');
      final allOrders = await OrderApiService.fetchTodayOrders();
      final specificOrder = allOrders.where((order) => order.orderId == orderId).firstOrNull;

      if (specificOrder != null) {
        print('✅ Found order $orderId, processing...');
        _processIncomingOrder(specificOrder);
      } else {
        print('⚠️ Order $orderId not found in today\'s orders');
      }
    } catch (e) {
      print('❌ Failed to fetch specific order $orderId: $e');
    }
  }

  Future<void> refreshOrders() async {
    print('🔄 === REFRESHING ORDERS ===');
    for (var timer in _scheduledUpdates.values) {
      timer.cancel();
    }
    _scheduledUpdates.clear();
    return _fetchAndListenToOrders();
  }

  @override
  void dispose() {
    _newOrderSocketSubscription.cancel();
    _acceptedOrderStreamSubscription.cancel();
    _orderStatusChangedSubscription.cancel();

    for (var timer in _scheduledUpdates.values) {
      timer.cancel();
    }
    _scheduledUpdates.clear();

    super.dispose();
  }
}