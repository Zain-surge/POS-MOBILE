import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'dart:async';
import 'package:epos/services/uk_time_service.dart';

class ActiveOrdersProvider with ChangeNotifier {
  final OrderCountsProvider _orderCountsProvider;
  List<Order> _activeOrders = [];
  bool _isLoading = true;
  String? _error;
  late StreamSubscription _newOrderSocketSubscription;
  late StreamSubscription _acceptedOrderStreamSubscription;
  late StreamSubscription _orderStatusChangedSubscription;

  final Map<int, Timer> _scheduledUpdates = {};
  bool _isDisposed = false;

  // Polling for live updates
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(
    seconds: 30,
  ); // Poll every 30 seconds

  List<Order> get activeOrders => _activeOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ActiveOrdersProvider(this._orderCountsProvider) {
    _fetchAndListenToOrders();
  }

  bool _shouldDisplayWebsiteOrder(Order order) {
    final status = order.status.toLowerCase();
    final source = order.orderSource.toLowerCase();

    if (source != 'website') {
      return false;
    }

    // Don't show cancelled orders
    if (status == 'cancelled' || status == 'red') {
      return false;
    }

    bool shouldShow =
        status == 'pending' ||
        status == 'yellow' ||
        status == 'accepted' ||
        status == 'green' ||
        status == 'ready';
    return shouldShow;
  }

  bool _shouldDisplayEposOrder(Order order) {
    final status = order.status.toLowerCase();
    final source = order.orderSource.toLowerCase();

    if (source != 'epos') {
      return false;
    }

    // First check if the order is paid - if paid, don't show it
    if (order.paidStatus) {
      return false;
    }

    // For unpaid orders, show them unless they are completed/delivered/declined/cancelled
    bool shouldShow =
        ![
          'completed',
          'delivered',
          'declined',
          'blue',
          'cancelled',
          'red',
        ].contains(status);

    return shouldShow;
  }

  //anyorder
  bool _shouldDisplayOrder(Order order) {
    final source = order.orderSource.toLowerCase();
    if (source == 'website') {
      return _shouldDisplayWebsiteOrder(order);
    } else if (source == 'epos') {
      return _shouldDisplayEposOrder(order);
    } else {
      return false;
    }
  }

  // Schedule color updates for specific orders
  void _scheduleColorUpdatesForOrder(Order order) {
    _scheduledUpdates[order.orderId]?.cancel();

    final DateTime now = UKTimeService.now();
    final Duration timeSinceCreated = now.difference(order.createdAt);

    const Duration greenToYellowThreshold = Duration(minutes: 30);
    const Duration yellowToRedThreshold = Duration(minutes: 45);

    Timer? nextUpdate;

    if (timeSinceCreated < greenToYellowThreshold) {
      // Schedule update when order becomes yellow (30 minutes)
      final Duration timeUntilYellow =
          greenToYellowThreshold - timeSinceCreated;
      nextUpdate = Timer(timeUntilYellow, () {
        if (!_isDisposed) {
          _calculateAndUpdateCounts();

          // Schedule next update for red (15 minutes later)
          _scheduledUpdates[order.orderId] = Timer(
            const Duration(minutes: 15),
            () {
              if (!_isDisposed) {
                _calculateAndUpdateCounts();
                _scheduledUpdates.remove(order.orderId);
              }
            },
          );
        }
      });
    } else if (timeSinceCreated < yellowToRedThreshold) {
      // Schedule update when order becomes red (45 minutes)
      final Duration timeUntilRed = yellowToRedThreshold - timeSinceCreated;
      nextUpdate = Timer(timeUntilRed, () {
        if (!_isDisposed) {
          print('⏰ Order ${order.orderId} becoming RED');
          _calculateAndUpdateCounts();
          _scheduledUpdates.remove(order.orderId);
        }
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
    // Process the updated order through the same logic as socket updates
    _processIncomingOrder(updatedOrder);
  }

  Future<void> _fetchAndListenToOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final allOrders = await OrderApiService.fetchTodayOrders();
      _activeOrders = _filterActiveOrders(allOrders);
      _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;

      _calculateAndUpdateCounts();

      // Schedule updates for existing orders
      for (var order in _activeOrders) {
        _scheduleColorUpdatesForOrder(order);
      }

      // CRITICAL FIX: Notify listeners AFTER color calculation
      notifyListeners();

      _listenToStreams();
      _startPolling();
    } catch (e) {
      _error = 'Failed to load active orders: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToStreams() {
    _newOrderSocketSubscription = OrderApiService().newOrderStream.listen(
      (newOrder) {
        _processIncomingOrder(newOrder);
      },
      onError:
          (e) => print('❌ ActiveOrdersProvider: Error on newOrderStream: $e'),
    );

    _acceptedOrderStreamSubscription = OrderApiService().acceptedOrderStream
        .listen(
          (acceptedOrder) {
            _processIncomingOrder(acceptedOrder);
          },
          onError:
              (e) => print(
                '❌ ActiveOrdersProvider: Error on acceptedOrderStream: $e',
              ),
        );

    _orderStatusChangedSubscription = OrderApiService()
        .orderStatusOrDriverChangedStream
        .listen(
          (data) {
            _handleOrderStatusChange(data);
          },
          onError:
              (e) => print(
                '❌ ActiveOrdersProvider: Error on orderStatusOrDriverChangedStream: $e',
              ),
        );
  }

  List<Order> _filterActiveOrders(List<Order> orders) {
    final List<Order> filteredOrders = [];

    for (var order in orders) {
      if (_shouldDisplayOrder(order)) {
        filteredOrders.add(order);
      }
    }

    return filteredOrders;
  }

  void _processIncomingOrder(Order order) {
    bool shouldDisplay = _shouldDisplayOrder(order);

    int existingIndex = _activeOrders.indexWhere(
      (o) => o.orderId == order.orderId,
    );
    bool orderWasRemoved = false;

    if (shouldDisplay) {
      if (existingIndex != -1) {
        _cancelScheduledUpdatesForOrder(order.orderId);
        _activeOrders[existingIndex] = order;
        _scheduleColorUpdatesForOrder(order);
      } else {
        _activeOrders.add(order);
        _scheduleColorUpdatesForOrder(order);
      }
    } else {
      if (existingIndex != -1) {
        _cancelScheduledUpdatesForOrder(_activeOrders[existingIndex].orderId);
        _activeOrders.removeAt(existingIndex);
        orderWasRemoved = true;
      }
    }

    _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Force immediate color calculation with detailed logging
    _calculateAndUpdateCountsWithLogging(orderWasRemoved, order.orderId);

    // Add a small delay to ensure state propagation
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Add detailed logging version of color calculation
  void _calculateAndUpdateCountsWithLogging(bool wasRemoval, int orderId) {
    if (_activeOrders.isEmpty) {
      _orderCountsProvider.updateAllCountsAndColors(
        {
          'collection': 0,
          'takeout': 0,
          'dinein': 0,
          'delivery': 0,
          'website': 0,
        },
        {
          'collection': const Color(0xFF8cdd69),
          'takeout': const Color(0xFF8cdd69),
          'dinein': const Color(0xFF8cdd69),
          'delivery': const Color(0xFF8cdd69),
          'website': const Color(0xFF8cdd69),
        },
      );
      return;
    }

    Map<String, int> currentTypeCounts = {
      'collection': 0,
      'takeout': 0,
      'dinein': 0,
      'delivery': 0,
      'website': 0,
    };

    Map<String, List<int>> allPrioritiesForTypes = {
      'collection': [],
      'takeout': [],
      'dinein': [],
      'delivery': [],
      'website': [],
    };

    Map<String, Color> dominantColorsForTypes = {
      'collection': const Color(0xFF8cdd69),
      'takeout': const Color(0xFF8cdd69),
      'dinein': const Color(0xFF8cdd69),
      'delivery': const Color(0xFF8cdd69),
      'website': const Color(0xFF8cdd69),
    };

    const Duration greenToYellowThreshold = Duration(minutes: 30);
    const Duration yellowToRedThreshold = Duration(minutes: 45);

    for (var order in _activeOrders) {
      String orderTypeKey;
      String orderSourceLower = order.orderSource.toLowerCase();
      String orderTypeLower = order.orderType.toLowerCase();

      if (orderSourceLower == 'website') {
        orderTypeKey = 'website';
      } else if (orderSourceLower == 'epos') {
        if (orderTypeLower == 'takeaway' ||
            orderTypeLower == 'pickup' ||
            orderTypeLower == 'collection') {
          orderTypeKey = 'collection';
        } else if (orderTypeLower == 'takeout') {
          orderTypeKey = 'takeout';
        } else if (orderTypeLower == 'dinein') {
          orderTypeKey = 'dinein';
        } else if (orderTypeLower == 'delivery') {
          orderTypeKey = 'delivery';
        } else {
          continue;
        }
      } else {
        continue;
      }

      final DateTime now = UKTimeService.now();
      final Duration timeElapsed = now.difference(order.createdAt);
      int timePriority;

      if (timeElapsed >= yellowToRedThreshold) {
        timePriority = 3; // Red
      } else if (timeElapsed >= greenToYellowThreshold) {
        timePriority = 2; // Yellow
      } else {
        timePriority = 1; // Green
      }

      currentTypeCounts[orderTypeKey] =
          (currentTypeCounts[orderTypeKey] ?? 0) + 1;
      allPrioritiesForTypes[orderTypeKey]!.add(timePriority);
    }

    // Determine the dominant color for each type based on highest priority
    allPrioritiesForTypes.forEach((orderTypeKey, priorities) {
      Color finalColor;

      if (priorities.isEmpty) {
        finalColor = const Color(0xFF8cdd69);
      } else {
        int highestPriority = priorities.reduce((a, b) => a > b ? a : b);

        switch (highestPriority) {
          case 3:
            finalColor = const Color(0xFFff4848); // Red
            break;
          case 2:
            finalColor = const Color(0xFFFFE26B); // Yellow
            break;
          case 1:
          default:
            finalColor = const Color(0xFF8cdd69); // Green
            break;
        }
      }

      dominantColorsForTypes[orderTypeKey] = finalColor;
    });

    // Always update even if values seem the same
    _orderCountsProvider.updateAllCountsAndColors(
      currentTypeCounts,
      dominantColorsForTypes,
    );
  }

  void _calculateAndUpdateCounts() {
    _calculateAndUpdateCountsWithLogging(false, 0);
  }

  // Handle order status changes with improved error handling and immediate processing
  void _handleOrderStatusChange(Map<String, dynamic> data) {
    try {
      final int? orderId = data['order_id'] as int?;

      String? newStatus = data['status'] as String?;
      if (newStatus == null) {
        newStatus = data['new_status'] as String?;
      }

      // Also check for driver changes
      final int? newDriverId =
          data['driver_id'] as int? ?? data['new_driver_id'] as int?;

      if (orderId == null || newStatus == null) {
        print(
          '⚠️ Invalid order status change data - missing order_id or status: $data',
        );
        print('Available keys in data: ${data.keys.toList()}');
        return;
      }

      // Find the existing order in our active orders
      final existingIndex = _activeOrders.indexWhere(
        (order) => order.orderId == orderId,
      );

      if (existingIndex != -1) {
        final existingOrder = _activeOrders[existingIndex];

        String finalStatus = _mapFromBackendStatus(newStatus);

        final updatedOrder = existingOrder.copyWith(
          status: finalStatus,
          driverId: newDriverId,
        );

        // Check if this affects delivery display status
        final isDeliveryOrder =
            (existingOrder.orderSource.toLowerCase() == 'epos' &&
                existingOrder.orderType.toLowerCase() == 'delivery') ||
            (existingOrder.orderSource.toLowerCase() == 'website' &&
                existingOrder.orderType.toLowerCase() == 'delivery');

        if (isDeliveryOrder) {
          final oldDisplayStatus = existingOrder.getDisplayStatusLabel();
          final newDisplayStatus = updatedOrder.getDisplayStatusLabel();
          print(
            '🚚 Delivery Order $orderId: Display status changing from "$oldDisplayStatus" to "$newDisplayStatus"',
          );
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
      final specificOrder =
          allOrders.where((order) => order.orderId == orderId).firstOrNull;

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

  // Start polling for live updates
  void _startPolling() {
    _stopPolling(); // Stop any existing polling
    print('🔄 Starting polling every ${_pollingInterval.inSeconds} seconds');

    _pollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      try {
        await _pollForUpdates();
      } catch (e) {
        print('❌ Polling error: $e');
      }
    });
  }

  // Stop polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    print('⏹️ Stopped polling');
  }

  // Poll for updates without full refresh
  Future<void> _pollForUpdates() async {
    try {
      final allOrders = await OrderApiService.fetchTodayOrders();
      final filteredOrders = _filterActiveOrders(allOrders);

      // Check if there are any changes
      bool hasChanges = false;

      if (filteredOrders.length != _activeOrders.length) {
        hasChanges = true;
      } else {
        // Check if any orders changed
        for (int i = 0; i < filteredOrders.length; i++) {
          final newOrder = filteredOrders[i];
          final existingOrder = _activeOrders.firstWhere(
            (o) => o.orderId == newOrder.orderId,
            orElse:
                () => Order(
                  orderId: -1,
                  paymentType: '',
                  transactionId: '',
                  orderType: '',
                  status: '',
                  createdAt: DateTime.now(),
                  changeDue: 0,
                  orderSource: '',
                  customerName: '',
                  orderTotalPrice: 0,
                  items: [],
                ),
          );

          if (existingOrder.orderId == -1 ||
              existingOrder.status != newOrder.status ||
              existingOrder.paidStatus != newOrder.paidStatus) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges && !_isDisposed) {
        _activeOrders = filteredOrders;
        _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _calculateAndUpdateCounts();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Polling update failed: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _newOrderSocketSubscription.cancel();
    _acceptedOrderStreamSubscription.cancel();
    _orderStatusChangedSubscription.cancel();
    _stopPolling();

    for (var timer in _scheduledUpdates.values) {
      timer.cancel();
    }
    _scheduledUpdates.clear();

    super.dispose();
  }
}
