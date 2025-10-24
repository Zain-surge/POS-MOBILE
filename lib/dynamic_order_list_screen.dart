// lib/dynamic_order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'package:epos/providers/epos_orders_provider.dart';
import 'package:epos/providers/food_items_provider.dart';
import 'package:epos/providers/active_orders_provider.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'package:epos/circular_timer_widget.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/custom_popup_service.dart';
import 'package:epos/services/connectivity_service.dart';
import 'models/cart_item.dart';
import 'models/food_item.dart';
import 'package:intl/intl.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class DynamicOrderListScreen extends StatefulWidget {
  final String orderType;
  final int initialBottomNavItemIndex;

  const DynamicOrderListScreen({
    Key? key,
    required this.orderType,
    required this.initialBottomNavItemIndex,
  }) : super(key: key);

  @override
  State<DynamicOrderListScreen> createState() => _DynamicOrderListScreenState();
}

class _DynamicOrderListScreenState extends State<DynamicOrderListScreen>
    with WidgetsBindingObserver {
  // Helper method to check if an option should be excluded (same logic as thermal printer)
  bool _shouldExcludeOption(String? value) {
    if (value == null || value.isEmpty) return true;

    final trimmedValue = value.trim().toUpperCase();

    // Exclude N/A values
    if (trimmedValue == 'N/A') return true;

    // Exclude default pizza options (case insensitive)
    if (trimmedValue == 'BASE: TOMATO' || trimmedValue == 'CRUST: NORMAL') {
      return true;
    }

    return false;
  }

  List<Order> activeOrders = [];
  List<Order> completedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String? pickcollect;
  String? dineinFilter;
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  Timer? _reloadDebounceTimer;
  Timer? _printerStatusTimer;
  Timer? _colorUpdateTimer;
  DateTime? _lastPrinterCheck;
  Map<String, bool>? _cachedPrinterStatus;
  final ScrollController _scrollController = ScrollController();

  late StreamSubscription<Map<String, dynamic>> _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;

    // Initialize filters based on order type
    if (widget.orderType.toLowerCase() == 'collection') {
      pickcollect = null;
    } else if (widget.orderType.toLowerCase() == 'dinein') {
      dineinFilter = null;
    }

    _loadOrdersFromProvider();
    _initializeSocketListener();
    _startPrinterStatusChecking();
    _startColorUpdateTimer();
  }

  void _startPrinterStatusChecking() {
    _checkPrinterStatus();

    // Check every 2 minutes instead of 30 seconds to reduce printer communication
    _printerStatusTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkPrinterStatus();
    });
  }

  void _startColorUpdateTimer() {
    // Update colors every 60 seconds to refresh order card colors based on elapsed time
    _colorUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        setState(() {
          // This setState will trigger rebuild and recalculate colors for all orders
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(
      context,
      listen: false,
    );

    switch (state) {
      case AppLifecycleState.resumed:
        eposOrdersProvider.resumePolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        eposOrdersProvider.pausePolling();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _initializeSocketListener() {
    final orderApiService = OrderApiService();
    _orderStatusSubscription = orderApiService.orderStatusOrDriverChangedStream
        .listen((payload) {
          _handleOrderStatusOrDriverChange(payload);
        });
  }

  void _handleOrderStatusOrDriverChange(Map<String, dynamic> payload) {
    final int? orderId = payload['order_id'] as int?;
    final String? newStatusBackend = payload['new_status'] as String?;
    final int? newDriverId = payload['new_driver_id'] as int?;

    if (orderId == null || newStatusBackend == null) {
      return;
    }

    // Update the provider cache first
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(
      context,
      listen: false,
    );
    eposOrdersProvider.handleSocketUpdate(payload);

    setState(() {
      int? orderIndexInActive = activeOrders.indexWhere(
        (order) => order.orderId == orderId,
      );
      int? orderIndexInCompleted = completedOrders.indexWhere(
        (order) => order.orderId == orderId,
      );

      Order? targetOrder;

      // Determine the new INTERNAL status for the Order model
      String newInternalStatus;
      switch (newStatusBackend) {
        case 'yellow':
          newInternalStatus = 'pending';
          break;
        case 'green':
          newInternalStatus = 'ready';
          break;
        case 'blue':
          newInternalStatus = 'completed';
          break;
        default:
          newInternalStatus = newStatusBackend;
      }

      // Find the order and remove it from its current list
      if (orderIndexInActive != -1) {
        targetOrder = activeOrders.removeAt(orderIndexInActive);
      } else if (orderIndexInCompleted != -1) {
        targetOrder = completedOrders.removeAt(orderIndexInCompleted);
      } else {
        debugPrint(
          'Socket: Order with ID $orderId not found in current lists. Attempting full reload.',
        );
        _loadOrdersFromProvider();
        return;
      }

      // ✅ CRITICAL FIX: Create updated order with both status and driver changes
      Order updatedOrder = targetOrder.copyWith(
        status: newInternalStatus,
        driverId: newDriverId, // This is crucial for "On Its Way" logic
      );

      // ✅ NEW: Check if this is a delivery order and handle special display logic
      final isDeliveryOrder =
          ((updatedOrder.orderSource.toLowerCase() == 'epos' ||
                  updatedOrder.orderSource.toLowerCase() == 'epos_offline') &&
              updatedOrder.orderType.toLowerCase() == 'delivery') ||
          (updatedOrder.orderSource.toLowerCase() == 'website' &&
              updatedOrder.orderType.toLowerCase() == 'delivery');

      // Enhanced re-categorization logic
      bool shouldBeCompleted = false;

      if (isDeliveryOrder) {
        // For delivery orders, completed means status is 'blue' OR status is 'delivered'
        shouldBeCompleted =
            (newInternalStatus == 'completed' ||
                newInternalStatus == 'blue' ||
                newInternalStatus == 'delivered');

        // ✅ IMPORTANT: Log the delivery status transition
        if (newInternalStatus == 'ready' && newDriverId != null) {
          debugPrint(
            '🚚 Delivery Order ${orderId}: Driver ${newDriverId} assigned - Status should show "On Its Way"',
          );
        } else if (shouldBeCompleted) {
          debugPrint(
            '✅ Delivery Order ${orderId}: Completed - Status should show "Completed"',
          );
        }
      } else {
        // For non-delivery orders, use original logic
        shouldBeCompleted =
            (newInternalStatus == 'completed' ||
                newInternalStatus == 'blue' ||
                newInternalStatus == 'delivered');
      }

      if (shouldBeCompleted) {
        completedOrders.add(updatedOrder);
        completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        activeOrders.add(updatedOrder);
        _sortActiveOrdersByPriority();
      }

      // If the selected order was the one that changed, update _selectedOrder
      if (_selectedOrder?.orderId == orderId) {
        _selectedOrder = updatedOrder;
        // ✅ CRITICAL: Force UI refresh for selected order display
        debugPrint(
          '🔄 Selected order updated - forcing display refresh for order ${orderId}',
        );
      }

      // Adjust selected order if current selected disappears
      if (_selectedOrder == null ||
          (!activeOrders.any((o) => o.orderId == _selectedOrder!.orderId) &&
              !completedOrders.any(
                (o) => o.orderId == _selectedOrder!.orderId,
              ))) {
        _selectedOrder =
            activeOrders.isNotEmpty
                ? activeOrders.first
                : (completedOrders.isNotEmpty ? completedOrders.first : null);
      }

      debugPrint(
        "Socket: Order ${orderId} updated. Internal status: ${updatedOrder.status}, Driver ID: ${updatedOrder.driverId}",
      );
      debugPrint(
        "🎯 Display status will be: ${updatedOrder.getDisplayStatusLabel()}",
      );
    });
  }

  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter || !mounted) return; // Add mounted check

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus = {'usb': false, 'bluetooth': false};

      // Only do a real check every 5 minutes, otherwise use cached status
      final now = DateTime.now();
      if (_lastPrinterCheck == null ||
          now.difference(_lastPrinterCheck!).inMinutes >= 5) {
        connectionStatus =
            await ThermalPrinterService().checkConnectionStatusOnly();
        _lastPrinterCheck = now;
        _cachedPrinterStatus = connectionStatus;
      } else {
        // Use cached status to avoid frequent printer communication
        connectionStatus =
            _cachedPrinterStatus ?? {'usb': false, 'bluetooth': false};
      }

      bool isConnected =
          connectionStatus['usb'] == true ||
          connectionStatus['bluetooth'] == true;

      if (mounted) {
        setState(() {
          _isPrinterConnected = isConnected;
          _isCheckingPrinter = false;
        });
      }
    } catch (e) {
      print('Error checking printer status: $e');
      if (mounted) {
        setState(() {
          _isPrinterConnected = false;
          _isCheckingPrinter = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _printerStatusTimer?.cancel();
    _colorUpdateTimer?.cancel();
    _reloadDebounceTimer?.cancel();
    _orderStatusSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DynamicOrderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderType != oldWidget.orderType) {
      // Reset filters based on new order type
      if (widget.orderType.toLowerCase() == 'collection') {
        pickcollect = null; // Remove filters for collection
        dineinFilter = null;
      } else if (widget.orderType.toLowerCase() == 'dinein') {
        dineinFilter = null; // Default to null for dine in
        pickcollect = null;
      } else {
        pickcollect = null;
        dineinFilter = null;
      }

      _loadOrdersFromProvider();

      setState(() {
        _selectedBottomNavItem = widget.initialBottomNavItemIndex;
        _selectedOrder = null;
      });
    }
  }

  // Helper method to define status priority for sorting
  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'yellow':
        return 1; // Highest priority (shows first)
      case 'ready':
      case 'green':
        return 2; // Second priority
      default:
        return 3; // Lowest priority for other statuses
    }
  }

  // Helper method to group orders by status for divider placement
  String _getStatusGroup(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'yellow':
        return 'pending';
      case 'ready':
      case 'green':
        return 'ready';
      default:
        return 'other';
    }
  }

  // Updated socket handling sort method
  void _sortActiveOrdersByPriority() {
    activeOrders.sort((a, b) {
      // First priority: status-based sorting
      int statusPriorityA = _getStatusPriority(a.status);
      int statusPriorityB = _getStatusPriority(b.status);

      if (statusPriorityA != statusPriorityB) {
        return statusPriorityA.compareTo(statusPriorityB);
      }

      // If same status priority, sort by creation time (LATEST first - newest orders on top)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _loadOrdersFromProvider() {
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(
      context,
      listen: false,
    );

    // Get filtered orders from provider based on order type
    List<Order> filteredOrders = _getFilteredOrdersFromProvider(
      eposOrdersProvider,
    );
    List<Order> tempActive = [];
    List<Order> tempCompleted = [];

    for (var order in filteredOrders) {
      if (order.status.toLowerCase() == 'blue' ||
          order.status.toLowerCase() == 'completed' ||
          order.status.toLowerCase() == 'delivered' ||
          order.status.toLowerCase() == 'cancelled' ||
          order.status.toLowerCase() == 'red') {
        tempCompleted.add(order.copyWith());
      } else {
        tempActive.add(order.copyWith());
      }
    }

    // Sort active orders: Pending first, then others, then by creation time within each group
    tempActive.sort((a, b) {
      int statusPriorityA = _getStatusPriority(a.status);
      int statusPriorityB = _getStatusPriority(b.status);

      if (statusPriorityA != statusPriorityB) {
        return statusPriorityA.compareTo(statusPriorityB);
      }

      // Sort by creation time (LATEST first - newest orders on top)
      return b.createdAt.compareTo(a.createdAt);
    });

    tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      activeOrders = tempActive;
      completedOrders = tempCompleted;
      // Handle selected order logic
      if (activeOrders.isEmpty && completedOrders.isEmpty) {
        _selectedOrder = null;
      } else if (_selectedOrder == null && activeOrders.isNotEmpty) {
        _selectedOrder = activeOrders.first;
      } else if (_selectedOrder == null && completedOrders.isNotEmpty) {
        _selectedOrder = completedOrders.first;
      } else if (_selectedOrder != null) {
        // Check if the currently selected order still exists in the lists
        bool selectedOrderExists =
            activeOrders.any((o) => o.orderId == _selectedOrder!.orderId) ||
            completedOrders.any((o) => o.orderId == _selectedOrder!.orderId);

        if (!selectedOrderExists) {
          // Selected order no longer exists, select a new one
          if (activeOrders.isNotEmpty) {
            _selectedOrder = activeOrders.first;
          } else if (completedOrders.isNotEmpty) {
            _selectedOrder = completedOrders.first;
          } else {
            _selectedOrder = null;
          }
        } else {
          // Update the selected order with the latest data from the lists
          Order? updatedSelectedOrder = activeOrders.firstWhere(
            (o) => o.orderId == _selectedOrder!.orderId,
            orElse:
                () => completedOrders.firstWhere(
                  (o) => o.orderId == _selectedOrder!.orderId,
                  orElse: () => _selectedOrder!,
                ),
          );
          if (updatedSelectedOrder.orderId == _selectedOrder!.orderId) {
            _selectedOrder = updatedSelectedOrder;
          }
        }
      }
    });
  }

  // FIXED: Get filtered orders from provider based on screen type
  List<Order> _getFilteredOrdersFromProvider(EposOrdersProvider provider) {
    switch (widget.orderType.toLowerCase()) {
      case 'collection':
        // For collection screen, show all collection types without filtering
        return provider.getTakeawayOrders('all_takeaway_types');
      case 'dinein':
        // For dine in screen, filter based on dineinFilter
        if (dineinFilter == null) {
          // Return empty list when no filter is selected
          return [];
        } else if (dineinFilter == 'takeout') {
          // Show only TAKEOUT orders (not takeaway/pickup/collection)
          return provider.allOrders.where((order) {
            final String orderSourceLower = order.orderSource.toLowerCase();
            final String orderTypeLower = order.orderType.toLowerCase();
            // Include both regular EPOS orders and offline EPOS orders
            final isEposOrder =
                orderSourceLower == 'epos' ||
                orderSourceLower == 'epos_offline';
            return isEposOrder && orderTypeLower == 'takeout';
          }).toList();
        } else if (dineinFilter == 'dinein') {
          // Show only DINE IN orders
          return provider.allOrders.where((order) {
            final String orderSourceLower = order.orderSource.toLowerCase();
            final String orderTypeLower = order.orderType.toLowerCase();
            // Include both regular EPOS orders and offline EPOS orders
            final isEposOrder =
                orderSourceLower == 'epos' ||
                orderSourceLower == 'epos_offline';
            return isEposOrder && orderTypeLower == 'dinein';
          }).toList();
        } else {
          // Default case - should not reach here with new logic
          return [];
        }
      case 'delivery':
        return provider.getDeliveryOrders();
      case 'website':
        // For website orders, filter manually since provider focuses on EPOS orders
        return provider.allOrders.where((order) {
          final String orderSourceLower = order.orderSource.toLowerCase();
          final String orderTypeLower = order.orderType.toLowerCase();
          return orderSourceLower == 'website' &&
              (orderTypeLower == 'delivery' || orderTypeLower == 'pickup');
        }).toList();
      default:
        return [];
    }
  }

  String get _screenHeading {
    switch (widget.orderType.toLowerCase()) {
      case 'collection':
        return 'Collections';
      case 'dinein':
        return 'Dine In';
      case 'delivery':
        return 'Deliveries';
      case 'website':
        return 'Website Orders';
      default:
        if (widget.orderType.isNotEmpty) {
          return widget.orderType
              .replaceAll('_', ' ')
              .split(' ')
              .map(
                (word) =>
                    word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1)}'
                        : '',
              )
              .join(' ');
        }
        return 'Orders';
    }
  }

  String get _screenImage {
    switch (widget.orderType.toLowerCase()) {
      case 'collection':
        return 'TakeAwaywhite.png';
      case 'dinein':
        return 'DineInwhite.png';
      case 'delivery':
        return 'Deliverywhite.png';
      case 'website':
        return 'WebsiteOrderswhite.png';
      default:
        return 'home.png';
    }
  }

  String get _emptyStateMessage {
    switch (widget.orderType.toLowerCase()) {
      case 'collection':
        return 'No collection orders found.';
      case 'dinein':
        if (dineinFilter == null) {
          return 'Choose type to see orders';
        }
        return dineinFilter == 'takeout'
            ? 'No take out orders found.'
            : dineinFilter == 'dinein'
            ? 'No dine-in orders found.'
            : 'No orders found.';
      case 'delivery':
        return 'No delivery orders found.';
      case 'website':
        return 'No website orders found.';
      default:
        return 'No orders found.';
    }
  }

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMA':
      case 'SHAWARMAS':
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLICBREAD':
      case 'GARLIC BREADS':
        return 'assets/images/GarlicBreadS.png';
      case 'WRAPS':
        return 'assets/images/WrapsS.png';
      case 'KIDSMEAL':
        return 'assets/images/KidsMealS.png';
      case 'SIDES':
        return 'assets/images/SidesS.png';
      case 'DRINKS':
        return 'assets/images/DrinksS.png';
      case 'MILKSHAKE':
        return 'assets/images/MilkshakeS.png';
      case 'DIPS':
        return 'assets/images/DipsS.png';
      case 'DESSERTS':
        return 'assets/images/Desserts.png';
      case 'CHICKEN':
        return 'assets/images/Chicken.png';
      case 'KEBABS':
        return 'assets/images/Kebabs.png';
      case 'WINGS':
        return 'assets/images/Wings.png';
      case 'DEALS':
        return 'assets/images/DealsS.png';
      default:
        return 'assets/images/default.png';
    }
  }

  // String _mapFromBackendStatus(String backendStatus) {
  //   switch (backendStatus.toLowerCase()) {
  //     case 'yellow':
  //       return 'pending';
  //     case 'green':
  //       return 'ready';
  //     case 'blue':
  //       return 'completed';
  //     default:
  //       return backendStatus; // fallback
  //   }
  // }

  // String _nextStatus(String current) {
  //   debugPrint("nextStatus: Current status is '$current'.");
  //   String newStatus;
  //   switch (current.toLowerCase()) {
  //     case 'pending':
  //       newStatus = 'Ready';
  //       break;
  //     case 'ready':
  //       newStatus =
  //           'Completed'; // This generic transition is only used for non-delivery types now
  //       break;
  //     case 'completed':
  //       newStatus = 'Completed'; // Stays completed
  //       break;
  //     default:
  //       newStatus = 'Pending';
  //   }
  //   debugPrint("nextStatus: Returning '$newStatus'.");
  //   return newStatus;
  // }

  void _updateOrderStatusAndRelist(
    Order orderToUpdate,
    String newStatus,
  ) async {
    // Remove the old optimistic update logic since provider handles it now

    // Set flag to prevent automatic reloads during status update
    _reloadDebounceTimer?.cancel();

    // String backendStatusToSend;
    // switch (newStatus.toLowerCase()) {
    //   case 'pending':
    //     backendStatusToSend = 'yellow';
    //     break;
    //   case 'ready':
    //     backendStatusToSend = 'green';
    //     break;
    //   case 'completed':
    //     backendStatusToSend = 'blue';
    //     break;
    //   default:
    //     backendStatusToSend = newStatus.toLowerCase();
    // }

    final eposOrdersProvider = Provider.of<EposOrdersProvider>(
      context,
      listen: false,
    );

    try {
      // Use the provider's updateOrderStatus method which handles optimistic updates
      final success = await eposOrdersProvider.updateOrderStatus(
        orderToUpdate.orderId,
        newStatus,
      );

      if (success) {
        print(
          "✅ Status for Order ID ${orderToUpdate.orderId} successfully updated to '$newStatus'",
        );

        // Reload orders from provider to get updated state
        _loadOrdersFromProvider();
      } else {
        if (mounted) {
          CustomPopupService.show(
            context,
            'Failed to update order status on server.Please try again',
            type: PopupType.failure,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Error updating status',
          type: PopupType.failure,
        );
      }
    } finally {
      // Reset the updating flag
    }
  }

  String _getNextStepLabel(Order order) {
    // Check if this is an offline order first
    if (order.status.toLowerCase() == 'offline' ||
        order.orderSource == 'epos_offline') {
      return 'Sync Order';
    }

    // Check if this is a delivery order
    final isDeliveryOrder =
        ((order.orderSource.toLowerCase() == 'epos' ||
                order.orderSource.toLowerCase() == 'epos_offline') &&
            order.orderType.toLowerCase() == 'delivery') ||
        (order.orderSource.toLowerCase() == 'website' &&
            order.orderType.toLowerCase() == 'delivery');

    // For cancelled orders, always show "Cancelled"
    if (order.status.toLowerCase() == 'cancelled' ||
        order.status.toLowerCase() == 'red') {
      return 'Cancelled';
    }

    // For completed orders, always show "Completed"
    if (order.status.toLowerCase() == 'blue' ||
        order.status.toLowerCase() == 'completed' ||
        order.status.toLowerCase() == 'delivered') {
      return 'Completed';
    }

    // Handle different order types and their next steps
    if (isDeliveryOrder) {
      switch (order.status.toLowerCase()) {
        case 'pending':
        case 'yellow':
          return 'Ready'; // Show Mark Ready for pending delivery orders
        case 'ready':
        case 'green':
          // ORIGINAL DRIVER RESTRICTION LOGIC (COMMENTED OUT):
          // For delivery orders that are ready
          /*
          if (order.driverId != null && order.driverId! > 0) {
            return 'Complete'; // Driver assigned, can mark complete
          } else {
            return 'On Its Way'; // Waiting for driver assignment, show next visual step
          }
          */

          // NEW LOGIC: Always allow completion regardless of driver assignment
          return 'Complete';
        default:
          return 'Ready';
      }
    } else {
      // For dine-in, takeaway, collection orders
      switch (order.status.toLowerCase()) {
        case 'pending':
        case 'yellow':
          return 'Ready'; // Next step for pending orders
        case 'ready':
        case 'green':
          return 'Complete'; // Next step for ready orders
        default:
          return 'Ready';
      }
    }
  }

  // // Helper to get order count for each nav item
  // String? _getNotificationCount(int index, Map<String, int> currentActiveOrdersCount) {
  //   int count = 0;
  //   switch (index) {
  //     case 0: // Takeaway (includes backend 'takeaway', 'pickup', 'collection' from EPOS source)
  //       count = (currentActiveOrdersCount['takeaway'] ?? 0) +
  //           (currentActiveOrdersCount['pickup'] ?? 0) +
  //           (currentActiveOrdersCount['collection'] ?? 0);
  //       break;
  //     case 1: // Dine In (EPOS source)
  //       count = currentActiveOrdersCount['dinein'] ?? 0;
  //       break;
  //     case 2: // Delivery (EPOS source)
  //       count = currentActiveOrdersCount['delivery'] ?? 0;
  //       break;
  //     case 3: // Website (Website source, all types except completed)
  //       count = currentActiveOrdersCount['website'] ?? 0;
  //       break;
  //     default:
  //       return null; // No notification for home/more
  //   }
  //   return count > 0 ? count.toString() : null;
  // }

  @override
  Widget build(BuildContext context) {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final dominantOrderColors = orderCountsProvider.dominantOrderColors;
    final activeOrdersCount = orderCountsProvider.activeOrdersCount;

    return Consumer<EposOrdersProvider>(
      builder: (context, eposProvider, child) {
        // Get filtered orders directly from provider (live data)
        List<Order> filteredOrders = _getFilteredOrdersFromProvider(
          eposProvider,
        );

        // Separate into active and completed
        List<Order> liveActiveOrders = [];
        List<Order> liveCompletedOrders = [];

        for (var order in filteredOrders) {
          if (order.status.toLowerCase() == 'blue' ||
              order.status.toLowerCase() == 'completed' ||
              order.status.toLowerCase() == 'delivered' ||
              order.status.toLowerCase() == 'cancelled' ||
              order.status.toLowerCase() == 'red') {
            liveCompletedOrders.add(order);
          } else {
            liveActiveOrders.add(order);
          }
        }

        // Sort active orders
        liveActiveOrders.sort((a, b) {
          int statusPriorityA = _getStatusPriority(a.status);
          int statusPriorityB = _getStatusPriority(b.status);
          if (statusPriorityA != statusPriorityB) {
            return statusPriorityA.compareTo(statusPriorityB);
          }
          // Sort by creation time (LATEST first - newest orders on top)
          return b.createdAt.compareTo(a.createdAt);
        });

        liveCompletedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Handle selected order logic
        Order? liveSelectedOrder = _selectedOrder;
        if (liveActiveOrders.isEmpty && liveCompletedOrders.isEmpty) {
          liveSelectedOrder = null;
        } else if (liveSelectedOrder == null && liveActiveOrders.isNotEmpty) {
          liveSelectedOrder = liveActiveOrders.first;
        } else if (liveSelectedOrder == null &&
            liveCompletedOrders.isNotEmpty) {
          liveSelectedOrder = liveCompletedOrders.first;
        } else if (liveSelectedOrder != null) {
          // Check if selected order still exists and update it
          Order? updatedOrder = liveActiveOrders.firstWhere(
            (o) => o.orderId == liveSelectedOrder!.orderId,
            orElse:
                () => liveCompletedOrders.firstWhere(
                  (o) => o.orderId == liveSelectedOrder!.orderId,
                  orElse:
                      () => Order(
                        orderId: -999,
                        paymentType: '',
                        transactionId: '',
                        orderType: '',
                        status: '',
                        createdAt: UKTimeService.now(),
                        changeDue: 0.0,
                        orderSource: '',
                        customerName: '',
                        orderTotalPrice: 0.0,
                        items: [],
                      ),
                ),
          );

          if (updatedOrder.orderId != -999) {
            liveSelectedOrder = updatedOrder;
            // Update the internal _selectedOrder for tap handling
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_selectedOrder?.orderId != liveSelectedOrder?.orderId) {
                setState(() {
                  _selectedOrder = liveSelectedOrder;
                });
              }
            });
          } else {
            // Selected order no longer exists
            liveSelectedOrder =
                liveActiveOrders.isNotEmpty
                    ? liveActiveOrders.first
                    : (liveCompletedOrders.isNotEmpty
                        ? liveCompletedOrders.first
                        : null);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedOrder = liveSelectedOrder;
              });
            });
          }
        }

        // Group active orders by status and add dividers between different statuses
        final allOrdersForDisplay = <Order>[];
        if (liveActiveOrders.isNotEmpty) {
          String? currentStatus;
          for (int i = 0; i < liveActiveOrders.length; i++) {
            final order = liveActiveOrders[i];
            final orderStatus = _getStatusGroup(order.status);

            // Add divider if status changes (except for the first order)
            if (currentStatus != null && currentStatus != orderStatus) {
              allOrdersForDisplay.add(
                Order(
                  orderId: -2, // Different ID for status dividers
                  paymentType: '',
                  transactionId: '',
                  orderType: '',
                  status: 'status_divider',
                  createdAt: UKTimeService.now(),
                  changeDue: 0.0,
                  orderSource: '',
                  customerName: '',
                  orderTotalPrice: 0.0,
                  items: [],
                ),
              );
            }

            currentStatus = orderStatus;
            allOrdersForDisplay.add(order);
          }
        }

        if (liveCompletedOrders.isNotEmpty) {
          // Add divider placeholder for completed orders
          allOrdersForDisplay.add(
            Order(
              orderId: -1,
              paymentType: '',
              transactionId: '',
              orderType: '',
              status: 'completed_divider',
              createdAt: UKTimeService.now(),
              changeDue: 0.0,
              orderSource: '',
              customerName: '',
              orderTotalPrice: 0.0,
              items: [],
            ),
          );
          allOrdersForDisplay.addAll(liveCompletedOrders);
        }

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Row(
                  children: [
                    // LEFT PANEL
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Header with icon and title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(17),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                  child: Image.asset(
                                    'assets/images/${_screenImage}',
                                    width: 60,
                                    height: 60,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                  child: Text(
                                    _screenHeading,
                                    style: const TextStyle(
                                      fontSize: 46,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Dine In sub-filter buttons
                            if (_screenHeading == 'Dine In')
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildDineInSubFilterButton(
                                        title: 'Take Out',
                                        filterValue: 'takeout',
                                        count:
                                            activeOrdersCount['takeout'] ??
                                            0, // Dynamic count
                                        color:
                                            dominantOrderColors['takeout'] ??
                                            const Color(
                                              0xFF8cdd69,
                                            ), // Dynamic color
                                        onTap: () {
                                          setState(() {
                                            dineinFilter = 'takeout';
                                            _loadOrdersFromProvider();
                                          });
                                        },
                                      ),
                                      _buildDineInSubFilterButton(
                                        title: 'Dine In',
                                        filterValue: 'dinein',
                                        count:
                                            activeOrdersCount['dinein'] ??
                                            0, // Dynamic count
                                        color:
                                            dominantOrderColors['dinein'] ??
                                            const Color(
                                              0xFF8cdd69,
                                            ), // Dynamic color
                                        onTap: () {
                                          setState(() {
                                            dineinFilter = 'dinein';
                                            _loadOrdersFromProvider();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                            // Orders list
                            Expanded(
                              child:
                                  allOrdersForDisplay.isEmpty
                                      ? Center(
                                        child:
                                            eposProvider.isLoading
                                                ? const CircularProgressIndicator()
                                                : Text(
                                                  _emptyStateMessage,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                      )
                                      : ListView.builder(
                                        itemCount: allOrdersForDisplay.length,
                                        itemBuilder: (context, index) {
                                          final order =
                                              allOrdersForDisplay[index];

                                          // Handle divider placeholders
                                          if (order.orderId == -1 ||
                                              order.orderId == -2) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10.0,
                                                horizontal: 60,
                                              ),
                                              child: Divider(
                                                color: Color(0xFFB2B2B2),
                                                thickness: 2,
                                              ),
                                            );
                                          }

                                          int? serialNumber;
                                          // Only show serial number for active orders (used for timer logic only)
                                          if (liveActiveOrders.contains(
                                            order,
                                          )) {
                                            serialNumber =
                                                1; // Just set to 1, won't display the number
                                          }

                                          Color finalDisplayColor;

                                          // Helper function for time-based colors - same approach as website orders
                                          Color getTimeBasedColor(
                                            String status,
                                            DateTime orderCreatedAt,
                                          ) {
                                            // Calculate time for THIS specific order - aligned with CircularTimer
                                            final DateTime now =
                                                UKTimeService.now();

                                            // CRITICAL FIX: Use same approach as CircularTimer
                                            // Backend stores UK local time with Z suffix (incorrectly marked as UTC)
                                            // Strip timezone and treat as UK local time
                                            final DateTime orderStart =
                                                DateTime(
                                                  orderCreatedAt.year,
                                                  orderCreatedAt.month,
                                                  orderCreatedAt.day,
                                                  orderCreatedAt.hour,
                                                  orderCreatedAt.minute,
                                                  orderCreatedAt.second,
                                                  orderCreatedAt.millisecond,
                                                  orderCreatedAt.microsecond,
                                                );

                                            final Duration orderAge = now
                                                .difference(orderStart);
                                            final int minutesPassed =
                                                orderAge.inMinutes < 0
                                                    ? 0
                                                    : orderAge.inMinutes;

                                            print(
                                              '🕐 Order ${order.orderId}: ${minutesPassed} minutes elapsed - Color should be ${minutesPassed < 30
                                                  ? "GREEN"
                                                  : minutesPassed < 45
                                                  ? "YELLOW"
                                                  : "RED"}',
                                            );
                                            print(
                                              '   📅 Now: $now | Order Created: $orderStart | Raw Age: ${orderAge.inSeconds}s',
                                            );

                                            // Completed orders are always grey regardless of time
                                            if (status.toLowerCase() ==
                                                    'blue' ||
                                                status.toLowerCase() ==
                                                    'completed' ||
                                                status.toLowerCase() ==
                                                    'delivered') {
                                              print(
                                                '  ↳ Returning GREY (completed/delivered)',
                                              );
                                              return HexColor.fromHex('D6D6D6');
                                            }

                                            // Cancelled orders keep their red color
                                            if (status.toLowerCase() == 'red' ||
                                                status.toLowerCase() ==
                                                    'cancelled') {
                                              print(
                                                '  ↳ Returning RED (cancelled)',
                                              );
                                              return Colors.red[100]!;
                                            }

                                            // Time-based colors for active orders
                                            if (minutesPassed < 30) {
                                              print(
                                                '  ↳ Returning GREEN (0-30 min) - HexColor DEF5D4',
                                              );
                                              return HexColor.fromHex(
                                                'DEF5D4',
                                              ); // Green - 0-30 minutes
                                            } else if (minutesPassed >= 30 &&
                                                minutesPassed < 45) {
                                              print(
                                                '  ↳ Returning YELLOW (30-45 min) - HexColor FFF6D4',
                                              );
                                              return HexColor.fromHex(
                                                'FFF6D4',
                                              ); // Yellow - 30-45 minutes
                                            } else {
                                              print(
                                                '  ↳ Returning RED (45+ min) - HexColor ffcaca',
                                              );
                                              return HexColor.fromHex(
                                                'ffcaca',
                                              ); // Red - 45+ minutes
                                            }
                                          }

                                          finalDisplayColor = getTimeBasedColor(
                                            order.status.toLowerCase(),
                                            order.createdAt,
                                          );

                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedOrder = order;
                                              });
                                            },
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 1,
                                                    horizontal: 60,
                                                  ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                children: [
                                                  // Order Number Box (similar to active orders list)
                                                  Container(
                                                    width: 80,
                                                    height: 70,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            35,
                                                          ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '#${order.orderId}',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        fontFamily: 'Poppins',
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 15),

                                                  Expanded(
                                                    flex: 3,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 30,
                                                            vertical: 20,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            finalDisplayColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              50,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        order.displaySummary,
                                                        style: const TextStyle(
                                                          fontSize: 29,
                                                          color: Colors.black,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),

                                                  // Circular Timer - only show for active orders
                                                  if (serialNumber != null) ...[
                                                    CircularTimer(
                                                      startTime:
                                                          order.createdAt,
                                                      size: 70.0,
                                                      progressColor:
                                                          Colors.black,
                                                      backgroundColor:
                                                          Colors.grey,
                                                      strokeWidth: 5.0,
                                                      maxMinutes: 60,
                                                    ),
                                                    const SizedBox(width: 15),
                                                  ],

                                                  // Status update button
                                                  SizedBox(
                                                    width: 200,
                                                    height: 80,
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        // Check if this is an offline order first
                                                        if (order.status
                                                                    .toLowerCase() ==
                                                                'offline' ||
                                                            order.orderSource ==
                                                                'epos_offline') {
                                                          await _syncSingleOfflineOrder(
                                                            order,
                                                          );
                                                          return;
                                                        }

                                                        final isDeliveryRelevantOrder =
                                                            ((order.orderSource
                                                                            .toLowerCase() ==
                                                                        'epos' ||
                                                                    order.orderSource
                                                                            .toLowerCase() ==
                                                                        'epos_offline') &&
                                                                order.orderType
                                                                        .toLowerCase() ==
                                                                    'delivery') ||
                                                            (order.orderSource
                                                                        .toLowerCase() ==
                                                                    'website' &&
                                                                order.orderType
                                                                        .toLowerCase() ==
                                                                    'delivery');

                                                        // For completed orders, don't allow further changes
                                                        if (order.status
                                                                    .toLowerCase() ==
                                                                'blue' ||
                                                            order.status
                                                                    .toLowerCase() ==
                                                                'completed' ||
                                                            order.status
                                                                    .toLowerCase() ==
                                                                'delivered') {
                                                          return; // Do nothing for completed orders
                                                        }

                                                        if (isDeliveryRelevantOrder) {
                                                          // For delivery orders
                                                          if (order.status
                                                                      .toLowerCase() ==
                                                                  'yellow' ||
                                                              order.status
                                                                      .toLowerCase() ==
                                                                  'pending') {
                                                            _updateOrderStatusAndRelist(
                                                              order,
                                                              'Ready',
                                                            );
                                                          } else if (order
                                                                      .status
                                                                      .toLowerCase() ==
                                                                  'ready' ||
                                                              order.status
                                                                      .toLowerCase() ==
                                                                  'green') {
                                                            // ORIGINAL DRIVER RESTRICTION LOGIC (COMMENTED OUT):
                                                            // For delivery orders that are ready, show message that driver assignment is needed
                                                            /*
                                                            if (order.driverId ==
                                                                    null ||
                                                                order.driverId! <=
                                                                    0) {
                                                              CustomPopupService.show(
                                                                context,
                                                                "Delivery order is ready. Driver assignment needed from dispatch system.",
                                                                type:
                                                                    PopupType
                                                                        .success,
                                                              );
                                                            } else {
                                                              CustomPopupService.show(
                                                                context,
                                                                "Delivery order is on its way. Status managed by dispatch system.",
                                                                type:
                                                                    PopupType
                                                                        .success,
                                                              );
                                                            }
                                                            */

                                                            // NEW LOGIC: Allow status update to completed regardless of driver assignment
                                                            _updateOrderStatusAndRelist(
                                                              order,
                                                              'Completed',
                                                            );
                                                          }
                                                        } else {
                                                          // For non-delivery orders (dine-in, takeaway, collection)
                                                          if (order.status
                                                                      .toLowerCase() ==
                                                                  'yellow' ||
                                                              order.status
                                                                      .toLowerCase() ==
                                                                  'pending') {
                                                            _updateOrderStatusAndRelist(
                                                              order,
                                                              'Ready',
                                                            );
                                                          } else if (order
                                                                      .status
                                                                      .toLowerCase() ==
                                                                  'ready' ||
                                                              order.status
                                                                      .toLowerCase() ==
                                                                  'green') {
                                                            _updateOrderStatusAndRelist(
                                                              order,
                                                              'Completed',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            finalDisplayColor,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 10,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                50,
                                                              ),
                                                        ),
                                                        elevation: 4.0,
                                                      ),
                                                      child: Text(
                                                        _getNextStepLabel(
                                                          order,
                                                        ), // Use the new method here
                                                        style: const TextStyle(
                                                          fontSize: 25,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Vertical divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: const VerticalDivider(
                        width: 3,
                        thickness: 3,
                        color: Color(0xFFB2B2B2),
                      ),
                    ),

                    // RIGHT PANEL (Order Details)
                    Expanded(
                      flex: 1,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(9.0),
                        child:
                            liveSelectedOrder == null
                                ? Center(
                                  child: Text(
                                    'Select an order to see details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                                : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Order header info
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0,
                                        vertical: 5,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                liveSelectedOrder.orderType
                                                                .toLowerCase() ==
                                                            "delivery" &&
                                                        liveSelectedOrder
                                                                .postalCode !=
                                                            null &&
                                                        liveSelectedOrder
                                                            .postalCode!
                                                            .isNotEmpty
                                                    ? '${liveSelectedOrder.postalCode} '
                                                    : '',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                              Text(
                                                'Order no. ${liveSelectedOrder.orderId}',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (liveSelectedOrder.orderType
                                                      .toLowerCase() ==
                                                  "delivery" &&
                                              liveSelectedOrder.streetAddress !=
                                                  null &&
                                              liveSelectedOrder
                                                  .streetAddress!
                                                  .isNotEmpty)
                                            Text(
                                              liveSelectedOrder.streetAddress!,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          if (liveSelectedOrder.orderType
                                                      .toLowerCase() ==
                                                  "delivery" &&
                                              liveSelectedOrder.city != null &&
                                              liveSelectedOrder
                                                  .city!
                                                  .isNotEmpty)
                                            Text(
                                              '${liveSelectedOrder.city}, ${liveSelectedOrder.postalCode ?? ''}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          if (liveSelectedOrder.phoneNumber !=
                                                  null &&
                                              liveSelectedOrder
                                                  .phoneNumber!
                                                  .isNotEmpty)
                                            Text(
                                              liveSelectedOrder.phoneNumber!,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          Text(
                                            liveSelectedOrder.customerName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),

                                          // Display order date and time from created_at
                                          if ((liveSelectedOrder.orderType
                                                          .toLowerCase() ==
                                                      "delivery" ||
                                                  liveSelectedOrder.orderType
                                                          .toLowerCase() ==
                                                      "takeaway") &&
                                              liveSelectedOrder.customerEmail !=
                                                  null &&
                                              liveSelectedOrder
                                                  .customerEmail!
                                                  .isNotEmpty)
                                            Text(
                                              liveSelectedOrder.customerEmail!,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),

                                          Row(
                                            children: [
                                              Text(
                                                DateFormat(
                                                  'dd/MM/yyyy   HH:mm',
                                                ).format(
                                                  liveSelectedOrder.createdAt,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              // Show "Edited" label if order was updated
                                              if (liveSelectedOrder
                                                  .isEdited) ...[
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Edited',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),

                                          // Display order-level extra notes
                                          if (liveSelectedOrder
                                                      .orderExtraNotes !=
                                                  null &&
                                              liveSelectedOrder
                                                  .orderExtraNotes!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12.0,
                                                    horizontal: 16.0,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E8),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF4CAF50,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Order Notes:',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF2E7D2E),
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    liveSelectedOrder
                                                        .orderExtraNotes!,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Color(0xFF2E7D2E),
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Divider
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 55.0,
                                      ),
                                      child: Divider(
                                        height: 0,
                                        thickness: 3,
                                        color: const Color(0xFFB2B2B2),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Items list
                                    Expanded(
                                      child: RawScrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: true,
                                        trackVisibility: false,
                                        thickness: 10.0,
                                        radius: const Radius.circular(30),
                                        interactive: true,
                                        thumbColor: const Color(0xFFF2D9F9),
                                        child: ListView.builder(
                                          controller: _scrollController,
                                          itemCount:
                                              liveSelectedOrder.items.length,
                                          itemBuilder: (context, itemIndex) {
                                            final item =
                                                liveSelectedOrder
                                                    ?.items[itemIndex];

                                            // FIXED: Use direct description approach (same as website orders)
                                            List<String> directOptions = [];

                                            if (item!.description.isNotEmpty &&
                                                item.description !=
                                                    item.itemName) {
                                              // Split description by newlines and use each line directly
                                              List<String> descriptionLines =
                                                  item.description
                                                      .split('\n')
                                                      .map(
                                                        (line) => line.trim(),
                                                      )
                                                      .where(
                                                        (line) =>
                                                            line.isNotEmpty &&
                                                            line !=
                                                                item.itemName &&
                                                            !_shouldExcludeOption(
                                                              line,
                                                            ),
                                                      )
                                                      .toList();

                                              directOptions.addAll(
                                                descriptionLines,
                                              );
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12.0,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 40,
                                                        ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          flex: 6,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                '${item.quantity}',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 34,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        left:
                                                                            30,
                                                                        right:
                                                                            10,
                                                                      ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      // FIXED: Use direct description approach (same as website orders) to show complete information
                                                                      ...directOptions
                                                                          .map(
                                                                            (
                                                                              option,
                                                                            ) => Text(
                                                                              option,
                                                                              style: const TextStyle(
                                                                                fontSize:
                                                                                    15,
                                                                                fontFamily:
                                                                                    'Poppins',
                                                                                color:
                                                                                    Colors.black,
                                                                                fontWeight:
                                                                                    FontWeight.normal,
                                                                              ),
                                                                              maxLines:
                                                                                  option.contains(
                                                                                            'Selected Pizzas',
                                                                                          ) ||
                                                                                          option.contains(
                                                                                            'Selected Shawarmas',
                                                                                          ) ||
                                                                                          option.contains(
                                                                                            'Deal',
                                                                                          )
                                                                                      ? null
                                                                                      : 3,
                                                                              overflow:
                                                                                  option.contains(
                                                                                            'Selected Pizzas',
                                                                                          ) ||
                                                                                          option.contains(
                                                                                            'Selected Shawarmas',
                                                                                          ) ||
                                                                                          option.contains(
                                                                                            'Deal',
                                                                                          )
                                                                                      ? TextOverflow.visible
                                                                                      : TextOverflow.ellipsis,
                                                                            ),
                                                                          )
                                                                          .toList(),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        Container(
                                                          width: 3,
                                                          height: 110,
                                                          margin:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 0,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  30,
                                                                ),
                                                            color: const Color(
                                                              0xFFB2B2B2,
                                                            ),
                                                          ),
                                                        ),

                                                        Expanded(
                                                          flex: 3,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Container(
                                                                width: 90,
                                                                height: 64,
                                                                decoration:
                                                                    BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                    ),
                                                                clipBehavior:
                                                                    Clip.hardEdge,
                                                                child: Image.asset(
                                                                  _getCategoryIcon(
                                                                    item.itemType,
                                                                  ),
                                                                  fit:
                                                                      BoxFit
                                                                          .contain,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              Text(
                                                                item.itemName,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  if (item.comment != null &&
                                                      item.comment!.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8.0,
                                                          ),
                                                      child: Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8.0,
                                                              horizontal: 12.0,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFFDF1C7,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8.0,
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            'Comment: ${item.comment ?? ''}',
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 16,
                                                                  color:
                                                                      Colors
                                                                          .black,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                    // Bottom divider
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 55.0,
                                      ),
                                      child: Divider(
                                        height: 0,
                                        thickness: 3,
                                        color: const Color(0xFFB2B2B2),
                                      ),
                                    ),
                                    const SizedBox(height: 7),

                                    // Total and printer section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.all(15),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 60),
                                                    Text(
                                                      '£${liveSelectedOrder.orderTotalPrice.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'Change Due',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    Text(
                                                      '£${liveSelectedOrder.changeDue.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () async {
                                              // Set the _selectedOrder temporarily for printing
                                              _selectedOrder =
                                                  liveSelectedOrder;
                                              await _handlePrintingOrderReceipt();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Image.asset(
                                                    'assets/images/printer.png',
                                                    width: 50,
                                                    height: 50,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Print',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Cancel button
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () async {
                                              // Set the _selectedOrder temporarily for cancellation
                                              _selectedOrder =
                                                  liveSelectedOrder;
                                              await _handleCancelOrder();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red[700],
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.cancel_outlined,
                                                    size: 50,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // EDIT button - only show for pending orders
                                        if (liveSelectedOrder.status
                                                    .toLowerCase() ==
                                                'pending' ||
                                            liveSelectedOrder.status
                                                    .toLowerCase() ==
                                                'yellow')
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () async {
                                                await _handleEditOrder(
                                                  liveSelectedOrder!,
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[700],
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Image.asset(
                                                      'assets/images/EDIT.png',
                                                      width: 50,
                                                      height: 50,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    const Text(
                                                      'Edit',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
                // Add printer status indicator - positioned at top left
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPrinterConnected ? Colors.green : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: (_isPrinterConnected
                                  ? Colors.green
                                  : Colors.red)
                              .withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            selectedIndex: _selectedBottomNavItem,
            showDivider: true,
            onItemSelected: (index) {
              setState(() {
                _selectedBottomNavItem = index;
              });
            },
          ),
        );
      },
    );
  }

  Future<void> _handlePrintingOrderReceipt() async {
    if (_selectedOrder == null) {
      CustomPopupService.show(
        context,
        "No order selected for printing",
        type: PopupType.failure,
      );
      return;
    }

    try {
      // Convert Order items to CartItem format for the printer service
      List<CartItem> cartItems =
          _selectedOrder!.items.map((orderItem) {
            // Calculate price per unit from total price and quantity
            double pricePerUnit =
                orderItem.quantity > 0
                    ? (orderItem.totalPrice / orderItem.quantity)
                    : 0.0;

            // For dynamic orders, use the description directly without parsing (same as website orders)
            // The order description already contains all necessary information
            List<String> selectedOptions = [];

            if (orderItem.description.isNotEmpty &&
                orderItem.description != orderItem.itemName) {
              // Split description by newlines and use each line directly
              List<String> descriptionLines =
                  orderItem.description
                      .split('\n')
                      .map((line) => line.trim())
                      .where(
                        (line) =>
                            line.isNotEmpty &&
                            line != orderItem.itemName &&
                            !_shouldExcludeOption(
                              line,
                            ), // Filter out default/N/A options
                      )
                      .toList();

              selectedOptions.addAll(descriptionLines);
            }

            return CartItem(
              foodItem:
                  orderItem.foodItem ??
                  FoodItem(
                    id: orderItem.itemId ?? 0,
                    name: orderItem.itemName,
                    category: orderItem.itemType,
                    price: {'default': pricePerUnit},
                    image: orderItem.imageUrl ?? '',
                    availability: true,
                  ),
              quantity: orderItem.quantity,
              selectedOptions:
                  selectedOptions.isNotEmpty ? selectedOptions : null,
              comment: orderItem.comment,
              pricePerUnit: pricePerUnit,
            );
          }).toList();

      // Calculate subtotal
      double subtotal = _selectedOrder!.orderTotalPrice;

      // // Show test dialog with receipt content
      // await _showReceiptDialog(_selectedOrder!, cartItems, subtotal);

      // Use the thermal printer service to print
      // Calculate delivery charge for delivery orders
      double? deliveryChargeAmount;
      if (_shouldApplyDeliveryCharge(
        _selectedOrder!.orderType,
        _selectedOrder!.paymentType,
      )) {
        deliveryChargeAmount = 1.50; // Delivery charge amount
      }

      bool
      success = await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId:
            _selectedOrder!.transactionId.isNotEmpty
                ? _selectedOrder!.transactionId
                : _selectedOrder!.orderId.toString(),
        orderType: _selectedOrder!.orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        totalCharge: _selectedOrder!.orderTotalPrice,
        changeDue: _selectedOrder!.changeDue,
        extraNotes: _selectedOrder!.orderExtraNotes,
        customerName: _selectedOrder!.customerName,
        customerEmail: _selectedOrder!.customerEmail,
        phoneNumber: _selectedOrder!.phoneNumber,
        streetAddress: _selectedOrder!.streetAddress,
        city: _selectedOrder!.city,
        postalCode: _selectedOrder!.postalCode,
        paymentType: _selectedOrder!.paymentType,
        paidStatus:
            _selectedOrder!
                .paidStatus, // Pass the actual paid status from order
        deliveryCharge: deliveryChargeAmount,
        orderDateTime: UKTimeService.now(), // Always use UK time for printing
        isEdited: _selectedOrder!.isEdited, // Pass if order was edited
        onShowMethodSelection: (availableMethods) {
          CustomPopupService.show(
            context,
            "Available printing methods: ${availableMethods.join(', ')}. Please check printer connections.",
            type: PopupType.success,
          );
        },
      );

      if (success) {
        CustomPopupService.show(
          context,
          "Receipt printed successfully.",
          type: PopupType.success,
        );
      } else {
        CustomPopupService.show(
          context,
          "Failed to print receipt. Check printer connection",
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Error printing receipt: $e');
      CustomPopupService.show(
        context,
        "Error printing receipt",
        type: PopupType.failure,
      );
    }
  }

  Future<void> _handleCancelOrder() async {
    if (_selectedOrder == null) {
      CustomPopupService.show(
        context,
        "No order selected for cancellation",
        type: PopupType.failure,
      );
      return;
    }

    final String normalizedStatus = _selectedOrder!.status.toLowerCase();
    String? statusMessage;
    if (normalizedStatus == 'cancelled' || normalizedStatus == 'red') {
      statusMessage = 'Order ${_selectedOrder!.orderId} is already cancelled.';
    } else if (normalizedStatus == 'completed' ||
        normalizedStatus == 'delivered' ||
        normalizedStatus == 'blue') {
      statusMessage =
          'Order ${_selectedOrder!.orderId} has already been completed and cannot be cancelled.';
    }

    if (statusMessage != null) {
      CustomPopupService.show(context, statusMessage, type: PopupType.failure);
      return;
    }

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Text(
            'Are you sure you want to cancel order #${_selectedOrder!.orderId}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel Order'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final success = await OrderApiService.updateOrderStatus(
        _selectedOrder!.orderId,
        'red',
      );

      if (!mounted) return;

      if (success) {
        CustomPopupService.show(
          context,
          'Order ${_selectedOrder!.orderId} has been cancelled',
          type: PopupType.success,
        );

        // Refresh orders to show updated status
        final eposOrdersProvider = Provider.of<EposOrdersProvider>(
          context,
          listen: false,
        );
        await eposOrdersProvider.refresh();
      } else {
        CustomPopupService.show(
          context,
          'Failed to cancel order ${_selectedOrder!.orderId}',
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Error cancelling order: $e');
      if (!mounted) return;
      CustomPopupService.show(
        context,
        'Error cancelling order',
        type: PopupType.failure,
      );
    }
  }

  Widget _buildDineInSubFilterButton({
    required String title,
    required String filterValue,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    bool isSelected = dineinFilter == filterValue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey[100] : Colors.black,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncSingleOfflineOrder(Order order) async {
    try {
      // Check if we have connectivity
      final connectivityService = ConnectivityService();
      if (!connectivityService.isOnline) {
        if (mounted) {
          CustomPopupService.show(
            context,
            'No internet connection. Cannot sync offline order.',
            type: PopupType.failure,
          );
        }
        return;
      }

      // Show loading popup
      if (mounted) {
        CustomPopupService.show(
          context,
          'Syncing offline order...',
          type: PopupType.success,
          duration: const Duration(seconds: 1),
        );
      }
      final success = await connectivityService.syncSingleOfflineOrder(
        order.transactionId,
      );

      if (!mounted) return;

      if (success) {
        // Show success message
        CustomPopupService.show(
          context,
          'Order synced successfully!',
          type: PopupType.success,
        );

        // Refresh the orders list to show updated status
        _loadOrdersFromProvider();
      } else {
        throw Exception('Sync operation returned false');
      }
    } catch (e) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to sync offline order: ${e.toString()}',
          type: PopupType.failure,
        );
      }
    }
  }

  // Helper function to determine if delivery charges should apply
  bool _shouldApplyDeliveryCharge(String? orderType, String? paymentType) {
    if (orderType == null) return false;

    // Check if orderType is delivery
    if (orderType.toLowerCase() == 'delivery') {
      return true;
    }

    // Check if paymentType indicates delivery (COD, Cash on delivery, etc.)
    if (paymentType != null) {
      final paymentTypeLower = paymentType.toLowerCase();
      if (paymentTypeLower.contains('cod') ||
          paymentTypeLower.contains('cash on delivery') ||
          paymentTypeLower.contains('delivery')) {
        return true;
      }
    }

    return false;
  }

  Future<void> _handleEditOrder(Order order) async {
    try {
      // Get food items from provider (cached, instant access)
      final foodItemsProvider = Provider.of<FoodItemsProvider>(
        context,
        listen: false,
      );

      // Get cached food items synchronously (no delay!)
      List<FoodItem> foodItems = foodItemsProvider.getFoodItemsSync();

      // If cache is empty, show loading and fetch
      if (foodItems.isEmpty) {
        // Show loading popup briefly
        CustomPopupService.show(
          context,
          'Loading menu items...',
          type: PopupType.success,
          duration: const Duration(milliseconds: 500),
        );

        // Fetch food items (this should rarely happen as we preload in main.dart)
        await foodItemsProvider.fetchFoodItems();
        foodItems = foodItemsProvider.foodItems;

        if (foodItems.isEmpty) {
          throw Exception('Failed to load menu items');
        }
      }

      if (!mounted) return;

      // Navigate to Page4 with edit parameters - INSTANT!
      final result = await Navigator.pushNamed(
        context,
        '/page4',
        arguments: {
          'selectedOrderType': order.orderType,
          'foodItems': foodItems,
          'editMode': true,
          'orderId': order.orderId,
          'existingOrder': order,
        },
      );

      // Refresh orders after returning from edit
      if (result == true && mounted) {
        final eposOrdersProvider = Provider.of<EposOrdersProvider>(
          context,
          listen: false,
        );
        final activeOrdersProvider = Provider.of<ActiveOrdersProvider>(
          context,
          listen: false,
        );

        // Refresh both providers to update order lists
        await eposOrdersProvider.refresh();
        await activeOrdersProvider.refreshOrders();
        _loadOrdersFromProvider();

        CustomPopupService.show(
          context,
          'Order updated successfully',
          type: PopupType.success,
        );
      }
    } catch (e) {
      print('Error opening edit mode: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to open order for editing',
          type: PopupType.failure,
        );
      }
    }
  }
}
