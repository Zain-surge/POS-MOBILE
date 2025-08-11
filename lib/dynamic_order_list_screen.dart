// lib/dynamic_order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'package:epos/providers/epos_orders_provider.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'package:epos/circular_timer_widget.dart';

import 'models/cart_item.dart';
import 'models/food_item.dart';

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

class _DynamicOrderListScreenState extends State<DynamicOrderListScreen> with WidgetsBindingObserver {
  List<Order> activeOrders = [];
  List<Order> completedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String? pickcollect;
  String? dineinFilter;
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  Timer? _reloadDebounceTimer;
  bool _isUpdatingStatus = false;
  final ScrollController _scrollController = ScrollController();

  late StreamSubscription<Map<String, dynamic>> _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add this line
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;

    // Initialize filters based on order type
    if (widget.orderType.toLowerCase() == 'takeaway') {
      pickcollect = null;
    } else if (widget.orderType.toLowerCase() == 'dinein') {
      dineinFilter = null;
    }

    _loadOrdersFromProvider();
    _initializeSocketListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint("DynamicOrderListScreen: App resumed, resuming polling");
        eposOrdersProvider.resumePolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        debugPrint("DynamicOrderListScreen: App paused/inactive, pausing polling");
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
    _orderStatusSubscription = orderApiService.orderStatusOrDriverChangedStream.listen((payload) {
      _handleOrderStatusOrDriverChange(payload);
    });
    debugPrint("DynamicOrderListScreen: Subscribed to orderStatusOrDriverChangedStream.");
  }

  void _handleOrderStatusOrDriverChange(Map<String, dynamic> payload) {
    final int? orderId = payload['order_id'] as int?;
    final String? newStatusBackend = payload['new_status'] as String?;
    final int? newDriverId = payload['new_driver_id'] as int?;

    if (orderId == null || newStatusBackend == null) {
      debugPrint('Socket payload missing order_id or new_status: $payload');
      return;
    }

    // Update the provider cache first
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(context, listen: false);
    eposOrdersProvider.handleSocketUpdate(payload);

    setState(() {
      int? orderIndexInActive = activeOrders.indexWhere((order) => order.orderId == orderId);
      int? orderIndexInCompleted = completedOrders.indexWhere((order) => order.orderId == orderId);

      Order? targetOrder;

      // Determine the new INTERNAL status for the Order model
      String newInternalStatus;
      switch (newStatusBackend) {
        case 'yellow': newInternalStatus = 'pending'; break;
        case 'green': newInternalStatus = 'ready'; break;
        case 'blue': newInternalStatus = 'completed'; break;
        default: newInternalStatus = newStatusBackend;
      }

      // Find the order and remove it from its current list
      if (orderIndexInActive != -1) {
        targetOrder = activeOrders.removeAt(orderIndexInActive);
      } else if (orderIndexInCompleted != -1) {
        targetOrder = completedOrders.removeAt(orderIndexInCompleted);
      } else {
        debugPrint('Socket: Order with ID $orderId not found in current lists. Attempting full reload.');
        _loadOrdersFromProvider();
        return;
      }

      // ✅ CRITICAL FIX: Create updated order with both status and driver changes
      Order updatedOrder = targetOrder!.copyWith(
        status: newInternalStatus,
        driverId: newDriverId, // This is crucial for "On Its Way" logic
      );

      // ✅ NEW: Check if this is a delivery order and handle special display logic
      final isDeliveryOrder = (updatedOrder.orderSource.toLowerCase() == 'epos' && updatedOrder.orderType.toLowerCase() == 'delivery') ||
          (updatedOrder.orderSource.toLowerCase() == 'website' && updatedOrder.orderType.toLowerCase() == 'delivery');

      // Enhanced re-categorization logic
      bool shouldBeCompleted = false;

      if (isDeliveryOrder) {
        // For delivery orders, completed means status is 'blue' OR status is 'delivered'
        shouldBeCompleted = (newInternalStatus == 'completed' ||
            newInternalStatus == 'blue' ||
            newInternalStatus == 'delivered');

        // ✅ IMPORTANT: Log the delivery status transition
        if (newInternalStatus == 'ready' && newDriverId != null) {
          debugPrint('🚚 Delivery Order ${orderId}: Driver ${newDriverId} assigned - Status should show "On Its Way"');
        } else if (shouldBeCompleted) {
          debugPrint('✅ Delivery Order ${orderId}: Completed - Status should show "Completed"');
        }
      } else {
        // For non-delivery orders, use original logic
        shouldBeCompleted = (newInternalStatus == 'completed' || newInternalStatus == 'blue' || newInternalStatus == 'delivered');
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
        debugPrint('🔄 Selected order updated - forcing display refresh for order ${orderId}');
      }

      // Adjust selected order if current selected disappears
      if (_selectedOrder == null || (!activeOrders.any((o) => o.orderId == _selectedOrder!.orderId) && !completedOrders.any((o) => o.orderId == _selectedOrder!.orderId))) {
        _selectedOrder = activeOrders.isNotEmpty ? activeOrders.first :
        (completedOrders.isNotEmpty ? completedOrders.first : null);
      }

      debugPrint("Socket: Order ${orderId} updated. Internal status: ${updatedOrder.status}, Driver ID: ${updatedOrder.driverId}");
      debugPrint("🎯 Display status will be: ${updatedOrder.getDisplayStatusLabel()}");
    });
  }

  //printer function
  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter) return;

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus = await ThermalPrinterService().testAllConnections();
      bool isConnected = connectionStatus['usb'] == true || connectionStatus['bluetooth'] == true;

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
  void didUpdateWidget(covariant DynamicOrderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderType != oldWidget.orderType) {
      debugPrint("DynamicOrderListScreen: orderType changed from ${oldWidget.orderType} to ${widget.orderType}. Reloading orders.");

      // Reset filters based on new order type
      if (widget.orderType.toLowerCase() == 'takeaway') {
        pickcollect = null; // Remove filters for takeaway
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Add this line
    _orderStatusSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
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

// Updated socket handling sort method
  void _sortActiveOrdersByPriority() {
    activeOrders.sort((a, b) {
      // First priority: status-based sorting
      int statusPriorityA = _getStatusPriority(a.status);
      int statusPriorityB = _getStatusPriority(b.status);

      if (statusPriorityA != statusPriorityB) {
        return statusPriorityA.compareTo(statusPriorityB);
      }

      // If same status priority, sort by creation time (oldest first)
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _loadOrdersFromProvider() {
    debugPrint("DynamicOrderListScreen: _loadOrdersFromProvider called for ${widget.orderType}.");

    final eposOrdersProvider = Provider.of<EposOrdersProvider>(context, listen: false);

    // Get filtered orders from provider based on order type
    List<Order> filteredOrders = _getFilteredOrdersFromProvider(eposOrdersProvider);

    debugPrint("DynamicOrderListScreen: Got ${filteredOrders.length} filtered orders from provider.");

    List<Order> tempActive = [];
    List<Order> tempCompleted = [];

    for (var order in filteredOrders) {
      if (order.status.toLowerCase() == 'blue' ||
          order.status.toLowerCase() == 'completed' ||
          order.status.toLowerCase() == 'delivered') {
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

      return a.createdAt.compareTo(b.createdAt);
    });

    tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    debugPrint("DynamicOrderListScreen: Filtered and separated into ${tempActive.length} active and ${tempCompleted.length} completed orders.");

    setState(() {
      activeOrders = tempActive;
      completedOrders = tempCompleted;

      debugPrint("DynamicOrderListScreen: setState called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}.");

      // Handle selected order logic
      if (activeOrders.isEmpty && completedOrders.isEmpty) {
        _selectedOrder = null;
        debugPrint("DynamicOrderListScreen: No orders available, _selectedOrder set to null.");
      } else if (_selectedOrder == null && activeOrders.isNotEmpty) {
        _selectedOrder = activeOrders.first;
        debugPrint("DynamicOrderListScreen: First active order selected by default: ${_selectedOrder!.orderId}");
      } else if (_selectedOrder == null && completedOrders.isNotEmpty) {
        _selectedOrder = completedOrders.first;
        debugPrint("DynamicOrderListScreen: No active orders, first completed order selected by default: ${_selectedOrder?.orderId}");
      } else if (_selectedOrder != null) {
        // Check if the currently selected order still exists in the lists
        bool selectedOrderExists = activeOrders.any((o) => o.orderId == _selectedOrder!.orderId) ||
            completedOrders.any((o) => o.orderId == _selectedOrder!.orderId);

        if (!selectedOrderExists) {
          // Selected order no longer exists, select a new one
          if (activeOrders.isNotEmpty) {
            _selectedOrder = activeOrders.first;
            debugPrint("DynamicOrderListScreen: Previously selected order no longer exists, selected first active: ${_selectedOrder!.orderId}");
          } else if (completedOrders.isNotEmpty) {
            _selectedOrder = completedOrders.first;
            debugPrint("DynamicOrderListScreen: Previously selected order no longer exists, selected first completed: ${_selectedOrder!.orderId}");
          } else {
            _selectedOrder = null;
            debugPrint("DynamicOrderListScreen: Previously selected order no longer exists, no orders available");
          }
        } else {
          // Update the selected order with the latest data from the lists
          Order? updatedSelectedOrder = activeOrders.firstWhere(
                (o) => o.orderId == _selectedOrder!.orderId,
            orElse: () => completedOrders.firstWhere(
                  (o) => o.orderId == _selectedOrder!.orderId,
              orElse: () => _selectedOrder!,
            ),
          );
          if (updatedSelectedOrder.orderId == _selectedOrder!.orderId) {
            _selectedOrder = updatedSelectedOrder;
            debugPrint("DynamicOrderListScreen: Selected order updated with latest data: ${_selectedOrder!.orderId}");
          }
        }
      }
    });

    debugPrint("DynamicOrderListScreen: _loadOrdersFromProvider finished.");
  }

  // FIXED: Get filtered orders from provider based on screen type
  List<Order> _getFilteredOrdersFromProvider(EposOrdersProvider provider) {
    switch (widget.orderType.toLowerCase()) {
      case 'takeaway':
      // For takeaway screen, show all takeaway types without filtering
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
            return orderSourceLower == 'epos' && orderTypeLower == 'takeout';
          }).toList();
        } else if (dineinFilter == 'dinein') {
          // Show only DINE IN orders
          return provider.allOrders.where((order) {
            final String orderSourceLower = order.orderSource.toLowerCase();
            final String orderTypeLower = order.orderType.toLowerCase();
            return orderSourceLower == 'epos' && orderTypeLower == 'dinein';
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
          return orderSourceLower == 'website' && (orderTypeLower == 'delivery' || orderTypeLower == 'pickup');
        }).toList();
      default:
        return [];
    }
  }

  /// LEGACY: Keep this method for fallback compatibility (not used in optimized version)
  /// Filters a list of orders based on the current screen's order type and source.
  ///
  /// For 'Take Aways' screen, uses the `pickcollect` sub-filter.
  /// For 'Website' screen, filters by source 'website' and type 'delivery'/'pickup'.
  /// For 'Dine In'/'Delivery' (EPOS), filters by source 'epos' and matching type.
  List<Order> _filterOrdersForEpos(List<Order> allOrders, String type) {
    return allOrders.where((order) {
      final String orderSourceLower = order.orderSource.toLowerCase();
      final String orderTypeLower = order.orderType.toLowerCase();
      bool shouldInclude = false;

      // Logic based on the CURRENT screen's orderType (widget.orderType)
      if (widget.orderType.toLowerCase() == 'takeaway') {
        // For takeaway screen, show all takeaway types
        shouldInclude = (orderSourceLower == 'epos' && (orderTypeLower == 'takeaway' || orderTypeLower == 'pickup' || orderTypeLower == 'collection'));
      } else if (widget.orderType.toLowerCase() == 'dinein') {
        // For dine in screen, filter based on dineinFilter
        if (dineinFilter == 'takeout') {
          // Only show TAKEOUT orders (not takeaway/pickup/collection)
          shouldInclude = (orderSourceLower == 'epos' && orderTypeLower == 'takeout');
        } else if (dineinFilter == 'dinein') {
          shouldInclude = (orderSourceLower == 'epos' && orderTypeLower == 'dinein');
        } else {
          // When dineinFilter is null, show no orders
          shouldInclude = false;
        }
      } else if (widget.orderType.toLowerCase() == 'website') {
        // If on the 'Website Orders' screen, filter by source 'website'
        // And backend order types 'delivery' or 'pickup'
        shouldInclude = (orderSourceLower == 'website' && (orderTypeLower == 'delivery' || orderTypeLower == 'pickup'));
      } else {
        // For other main order types (Delivery)
        // Filter by Epos source AND matching orderType (e.g., 'delivery')
        shouldInclude = (orderSourceLower == 'epos' && orderTypeLower == type.toLowerCase());
      }

      return shouldInclude;
    }).toList();
  }

  String get _screenHeading {
    switch (widget.orderType.toLowerCase()) {
      case 'takeaway':
        return 'Take Aways';
      case 'dinein':
        return 'Dine In';
      case 'delivery':
        return 'Deliveries';
      case 'website':
        return 'Website Orders';
      default:
        if (widget.orderType.isNotEmpty) {
          return widget.orderType.replaceAll('_', ' ').split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
        }
        return 'Orders';
    }
  }

  String get _screenImage {
    switch (widget.orderType.toLowerCase()) {
      case 'takeaway':
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
      case 'takeaway':
        return 'No takeaway/collection orders found.';
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
      default:
        return 'assets/images/default.png';
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
        return backendStatus; // fallback
    }
  }

  String _nextStatus(String current) {
    debugPrint("nextStatus: Current status is '$current'.");
    String newStatus;
    switch (current.toLowerCase()) {
      case 'pending':
        newStatus = 'Ready';
        break;
      case 'ready':
        newStatus = 'Completed'; // This generic transition is only used for non-delivery types now
        break;
      case 'completed':
        newStatus = 'Completed'; // Stays completed
        break;
      default:
        newStatus = 'Pending';
    }
    debugPrint("nextStatus: Returning '$newStatus'.");
    return newStatus;
  }

  void _updateOrderStatusAndRelist(Order orderToUpdate, String newStatus) async {
    // Remove the old optimistic update logic since provider handles it now

    // Set flag to prevent automatic reloads during status update
    _isUpdatingStatus = true;
    _reloadDebounceTimer?.cancel();

    String backendStatusToSend;
    switch (newStatus.toLowerCase()) {
      case 'pending':
        backendStatusToSend = 'yellow';
        break;
      case 'ready':
        backendStatusToSend = 'green';
        break;
      case 'completed':
        backendStatusToSend = 'blue';
        break;
      default:
        backendStatusToSend = newStatus.toLowerCase();
    }

    final eposOrdersProvider = Provider.of<EposOrdersProvider>(context, listen: false);

    try {
      // Use the provider's updateOrderStatus method which handles optimistic updates
      final success = await eposOrdersProvider.updateOrderStatus(orderToUpdate.orderId, newStatus);

      if (success) {
        print("✅ Status for Order ID ${orderToUpdate.orderId} successfully updated to '$newStatus'");

        // Reload orders from provider to get updated state
        _loadOrdersFromProvider();

      } else {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update status on server. Please try again.")),
          );
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating status: $e")),
        );
      }
    } finally {
      // Reset the updating flag
      _isUpdatingStatus = false;
    }
  }

  // Helper to get order count for each nav item
  String? _getNotificationCount(int index, Map<String, int> currentActiveOrdersCount) {
    int count = 0;
    switch (index) {
      case 0: // Takeaway (includes backend 'takeaway', 'pickup', 'collection' from EPOS source)
        count = (currentActiveOrdersCount['takeaway'] ?? 0) +
            (currentActiveOrdersCount['pickup'] ?? 0) +
            (currentActiveOrdersCount['collection'] ?? 0);
        break;
      case 1: // Dine In (EPOS source)
        count = currentActiveOrdersCount['dinein'] ?? 0;
        break;
      case 2: // Delivery (EPOS source)
        count = currentActiveOrdersCount['delivery'] ?? 0;
        break;
      case 3: // Website (Website source, all types except completed)
        count = currentActiveOrdersCount['website'] ?? 0;
        break;
      default:
        return null; // No notification for home/more
    }
    return count > 0 ? count.toString() : null;
  }

  Map<String, dynamic> _extractAllOptionsFromDescription(
      String description, {
        List<String>? defaultFoodItemToppings,
        List<String>? defaultFoodItemCheese,
      }) {
    Map<String, dynamic> options = {
      'size': null,
      'crust': null,
      'base': null,
      'toppings': <String>[],
      'sauceDips': <String>[],
      'baseItemName': description,
      'hasOptions': false,
    };

    List<String> optionsList = [];
    String baseItemName = description;
    bool foundOptionsSyntax = false;
    bool anyNonDefaultOptionFound = false;

    // Check if it's parentheses format (EPOS): "Item Name (Size: Large, Crust: Thin)"
    final optionMatch = RegExp(r'\((.*?)\)').firstMatch(description);
    if (optionMatch != null && optionMatch.group(1) != null) {
      // EPOS format with parentheses
      String optionsString = optionMatch.group(1)!;
      baseItemName = description.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      foundOptionsSyntax = true;
      optionsList = _smartSplitOptions(optionsString);
    } else if (description.contains('\n') || description.contains(':')) {
      // Website format with newlines: "Size: 7 inch\nBase: Tomato\nCrust: Normal"
      List<String> lines = description.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // Check if any line contains options (has colons)
      List<String> optionLines = lines.where((line) => line.contains(':')).toList();

      if (optionLines.isNotEmpty) {
        foundOptionsSyntax = true;
        optionsList = optionLines;

        // Find the first line that doesn't contain a colon (likely the item name)
        String foundItemName = '';
        for (var line in lines) {
          if (!line.contains(':')) {
            foundItemName = line;
            break;
          }
        }

        if (foundItemName.isNotEmpty) {
          options['baseItemName'] = foundItemName;
        } else {
          options['baseItemName'] = description; // Fallback to full description
        }
      }
    }

    // If no options syntax found, it's a simple description like "Chocolate Milkshake"
    if (!foundOptionsSyntax) {
      options['baseItemName'] = description;
      options['hasOptions'] = false;
      return options;
    }

    // --- NEW: Combine default toppings and cheese from the FoodItem ---
    final Set<String> defaultToppingsAndCheese = {};
    if (defaultFoodItemToppings != null) {
      defaultToppingsAndCheese.addAll(defaultFoodItemToppings.map((t) => t.trim().toLowerCase()));
    }
    if (defaultFoodItemCheese != null) {
      defaultToppingsAndCheese.addAll(defaultFoodItemCheese.map((c) => c.trim().toLowerCase()));
    }

    // Process the options and apply filtering for default values
    for (var option in optionsList) {
      String lowerOption = option.toLowerCase();

      if (lowerOption.startsWith('size:')) {
        String sizeValue = option.substring('size:'.length).trim();
        if (sizeValue.isNotEmpty && sizeValue.toLowerCase() != 'default') {
          options['size'] = sizeValue;
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption.startsWith('crust:')) {
        String crustValue = option.substring('crust:'.length).trim();
        if (crustValue.isNotEmpty && crustValue.toLowerCase() != 'normal') {
          options['crust'] = crustValue;
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption.startsWith('base:')) {
        String baseValue = option.substring('base:'.length).trim();
        if (baseValue.isNotEmpty && baseValue.toLowerCase() != 'tomato') { // Example default base
          if (baseValue.contains(',')) {
            List<String> baseList = baseValue.split(',').map((b) => b.trim()).toList();
            options['base'] = baseList.join(', ');
          } else {
            options['base'] = baseValue;
          }
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption.startsWith('toppings:') || lowerOption.startsWith('extra toppings:')) {
        String prefix = lowerOption.startsWith('extra toppings:') ? 'extra toppings:' : 'toppings:';
        String toppingsValue = option.substring(prefix.length).trim();

        if (toppingsValue.isNotEmpty) {
          List<String> currentToppingsFromDescription = toppingsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

          // --- NEW: Filter against FoodItem's default toppings/cheese ---
          List<String> filteredToppings = currentToppingsFromDescription.where((topping) {
            String trimmedToppingLower = topping.trim().toLowerCase();
            // Also keep the general "none", "no toppings" filter
            return !defaultToppingsAndCheese.contains(trimmedToppingLower) &&
                !['none', 'no toppings', 'standard', 'default'].contains(trimmedToppingLower);
          }).toList();

          if (filteredToppings.isNotEmpty) {
            List<String> existingToppings = List<String>.from(options['toppings']);
            existingToppings.addAll(filteredToppings);
            options['toppings'] = existingToppings.toSet().toList();
            anyNonDefaultOptionFound = true;
          }
        }
      } else if (lowerOption.startsWith('sauce dips:')) {
        String sauceDipsValue = option.substring('sauce dips:'.length).trim();
        if (sauceDipsValue.isNotEmpty) {
          List<String> sauceDipsList = sauceDipsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
          List<String> currentSauceDips = List<String>.from(options['sauceDips']);
          currentSauceDips.addAll(sauceDipsList);
          options['sauceDips'] = currentSauceDips.toSet().toList();
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption == 'no salad' || lowerOption == 'no sauce' || lowerOption == 'no cream') {
        List<String> currentToppings = List<String>.from(options['toppings']);
        currentToppings.add(option);
        options['toppings'] = currentToppings.toSet().toList();
        anyNonDefaultOptionFound = true;
      }
    }

    options['hasOptions'] = anyNonDefaultOptionFound;
    return options;
  }

// Helper method for EPOS format (parentheses) smart splitting
  List<String> _smartSplitOptions(String optionsString) {
    List<String> result = [];
    String current = '';
    bool inToppings = false;
    bool inSauceDips = false;

    List<String> parts = optionsString.split(', ');

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      String lowerPart = part.toLowerCase();

      if (lowerPart.startsWith('toppings:') || lowerPart.startsWith('extra toppings:')) {
        if (current.isNotEmpty) {
          result.add(current.trim());
          current = '';
        }
        current = part;
        inToppings = true;
        inSauceDips = false;
      } else if (lowerPart.startsWith('sauce dips:')) {
        if (current.isNotEmpty) {
          result.add(current.trim());
          current = '';
        }
        current = part;
        inToppings = false;
        inSauceDips = true;
      } else if (lowerPart.startsWith('size:') || lowerPart.startsWith('base:') || lowerPart.startsWith('crust:')) {
        if (current.isNotEmpty) {
          result.add(current.trim());
          current = '';
        }
        current = part;
        inToppings = false;
        inSauceDips = false;
      } else {
        if (inToppings || inSauceDips) {
          current += ', ' + part;
        } else {
          if (current.isNotEmpty) {
            result.add(current.trim());
          }
          current = part;
        }
      }
    }

    if (current.isNotEmpty) {
      result.add(current.trim());
    }

    return result;
  }


  @override
  Widget build(BuildContext context) {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final dominantOrderColors = orderCountsProvider.dominantOrderColors;
    final activeOrdersCount = orderCountsProvider.activeOrdersCount;

    return Consumer<EposOrdersProvider>(
      builder: (context, eposProvider, child) {
        // Get filtered orders directly from provider (live data)
        List<Order> filteredOrders = _getFilteredOrdersFromProvider(eposProvider);

        // Separate into active and completed
        List<Order> liveActiveOrders = [];
        List<Order> liveCompletedOrders = [];

        for (var order in filteredOrders) {
          if (order.status.toLowerCase() == 'blue' ||
              order.status.toLowerCase() == 'completed' ||
              order.status.toLowerCase() == 'delivered') {
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
          return a.createdAt.compareTo(b.createdAt);
        });

        liveCompletedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Handle selected order logic
        Order? liveSelectedOrder = _selectedOrder;
        if (liveActiveOrders.isEmpty && liveCompletedOrders.isEmpty) {
          liveSelectedOrder = null;
        } else if (liveSelectedOrder == null && liveActiveOrders.isNotEmpty) {
          liveSelectedOrder = liveActiveOrders.first;
        } else if (liveSelectedOrder == null && liveCompletedOrders.isNotEmpty) {
          liveSelectedOrder = liveCompletedOrders.first;
        } else if (liveSelectedOrder != null) {
          // Check if selected order still exists and update it
          Order? updatedOrder = liveActiveOrders.firstWhere(
                (o) => o.orderId == liveSelectedOrder!.orderId,
            orElse: () => liveCompletedOrders.firstWhere(
                  (o) => o.orderId == liveSelectedOrder!.orderId,
              orElse: () => Order(
                orderId: -999, paymentType: '', transactionId: '',
                orderType: '', status: '', createdAt: DateTime.now(),
                changeDue: 0.0, orderSource: '', customerName: '',
                orderTotalPrice: 0.0, items: [],
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
            liveSelectedOrder = liveActiveOrders.isNotEmpty
                ? liveActiveOrders.first
                : (liveCompletedOrders.isNotEmpty ? liveCompletedOrders.first : null);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedOrder = liveSelectedOrder;
              });
            });
          }
        }

        final allOrdersForDisplay = [...liveActiveOrders];
        if (liveCompletedOrders.isNotEmpty) {
          // Add divider placeholder
          allOrdersForDisplay.add(Order(
            orderId: -1, paymentType: '', transactionId: '', orderType: '',
            status: '', createdAt: DateTime.now(), changeDue: 0.0,
            orderSource: '', customerName: '', orderTotalPrice: 0.0, items: [],
          ));
          allOrdersForDisplay.addAll(liveCompletedOrders);
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
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
                                  horizontal: 18, vertical: 14),
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
                                    count: activeOrdersCount['takeout'] ?? 0, // Dynamic count
                                    color: dominantOrderColors['takeout'] ?? const Color(0xFF8cdd69), // Dynamic color
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
                                    count: activeOrdersCount['dinein'] ?? 0, // Dynamic count
                                    color: dominantOrderColors['dinein'] ?? const Color(0xFF8cdd69), // Dynamic color
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
                          child: allOrdersForDisplay.isEmpty
                              ? Center(
                            child: eposProvider.isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                              _emptyStateMessage,
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          )
                              : ListView.builder(
                            itemCount: allOrdersForDisplay.length,
                            itemBuilder: (context, index) {
                              final order = allOrdersForDisplay[index];

                              // Handle the divider placeholder
                              if (order.orderId == -1) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 60),
                                  child: Divider(
                                    color: Color(0xFFB2B2B2),
                                    thickness: 2,
                                  ),
                                );
                              }

                              int? serialNumber;
                              // Only show serial number for active orders
                              if (liveActiveOrders.contains(order)) {
                                serialNumber = liveActiveOrders.indexOf(order) + 1;
                              }

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedOrder = order;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 60),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      if (serialNumber != null)
                                        Text(
                                          '$serialNumber',
                                          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                                        )
                                      else
                                        const SizedBox(width: 0),

                                      SizedBox(width: serialNumber != null ? 15 : 0),

                                      Expanded(
                                        flex: serialNumber != null ? 3 : 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                          decoration: BoxDecoration(
                                            color: order.statusColor,
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          child: Text(
                                            order.displaySummary,
                                            style: const TextStyle(fontSize: 29, color: Colors.black),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Circular Timer - only show for active orders
                                      if (serialNumber != null) ...[
                                        CircularTimer(
                                          startTime: order.createdAt,
                                          size: 70.0,
                                          progressColor: Colors.black,
                                          backgroundColor: Colors.grey,
                                          strokeWidth: 5.0,
                                          maxMinutes: 60,
                                        ),
                                        const SizedBox(width: 15),
                                      ],

                                      // Status update button
                                      GestureDetector(
                                        onTap: () {
                                          final isDeliveryRelevantOrder =
                                              (order.orderSource.toLowerCase() == 'epos' && order.orderType.toLowerCase() == 'delivery') ||
                                                  (order.orderSource.toLowerCase() == 'website' && order.orderType.toLowerCase() == 'delivery');

                                          if (isDeliveryRelevantOrder) {
                                            if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending') {
                                              _updateOrderStatusAndRelist(order, 'Ready');
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Delivery order status can only be set to 'Ready' from EPOS.")),
                                              );
                                            }
                                          } else {
                                            if (order.status.toLowerCase() != 'completed' &&
                                                order.status.toLowerCase() != 'blue' &&
                                                order.status.toLowerCase() != 'delivered') {
                                              final uiFriendlyStatus = _mapFromBackendStatus(order.status);
                                              final newStatus = _nextStatus(uiFriendlyStatus);
                                              _updateOrderStatusAndRelist(order, newStatus);
                                            }
                                          }
                                        },
                                        child: Container(
                                          width: 200,
                                          height: 80,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: order.statusColor,
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          child: Text(
                                            order.getDisplayStatusLabel(),
                                            style: const TextStyle(fontSize: 25, color: Colors.black),
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
                    child: liveSelectedOrder == null
                        ? Center(
                      child: Text(
                        'Select an order to see details',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order header info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    liveSelectedOrder.orderType.toLowerCase() == "delivery" &&
                                        liveSelectedOrder.postalCode != null &&
                                        liveSelectedOrder.postalCode!.isNotEmpty
                                        ? '${liveSelectedOrder.postalCode} '
                                        : '',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                                  ),
                                  Text(
                                    'Order no. ${liveSelectedOrder.orderId}',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                              if (liveSelectedOrder.orderType.toLowerCase() == "delivery" &&
                                  liveSelectedOrder.streetAddress != null &&
                                  liveSelectedOrder.streetAddress!.isNotEmpty)
                                Text(
                                  liveSelectedOrder.streetAddress!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              if (liveSelectedOrder.orderType.toLowerCase() == "delivery" &&
                                  liveSelectedOrder.city != null &&
                                  liveSelectedOrder.city!.isNotEmpty)
                                Text(
                                  '${liveSelectedOrder.city}, ${liveSelectedOrder.postalCode ?? ''}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              if (liveSelectedOrder.phoneNumber != null &&
                                  liveSelectedOrder.phoneNumber!.isNotEmpty)
                                Text(
                                  liveSelectedOrder.phoneNumber!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              Text(
                                liveSelectedOrder.customerName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                              ),
                              if ((liveSelectedOrder.orderType.toLowerCase() == "delivery" ||
                                  liveSelectedOrder.orderType.toLowerCase() == "takeaway") &&
                                  liveSelectedOrder.customerEmail != null &&
                                  liveSelectedOrder.customerEmail!.isNotEmpty)
                                Text(
                                  liveSelectedOrder.customerEmail!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 55.0),
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
                              itemCount: liveSelectedOrder.items.length,
                              itemBuilder: (context, itemIndex) {
                                final item = liveSelectedOrder?.items[itemIndex];

                                // Extract options from description
                                Map<String, dynamic> itemOptions = _extractAllOptionsFromDescription(
                                  item!.description,
                                  defaultFoodItemToppings: item.foodItem?.defaultToppings,
                                  defaultFoodItemCheese: item.foodItem?.defaultCheese,
                                );

                                String? selectedSize = itemOptions['size'];
                                String? selectedCrust = itemOptions['crust'];
                                String? selectedBase = itemOptions['base'];
                                List<String> toppings = itemOptions['toppings'] ?? [];
                                List<String> sauceDips = itemOptions['sauceDips'] ?? [];
                                String baseItemName = item.itemName;
                                bool hasOptions = itemOptions['hasOptions'] ?? false;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 6,
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${item.quantity}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 34,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(left: 30, right: 10),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          // Display item options or simple description
                                                          if (!hasOptions)
                                                            Text(
                                                              item.description,
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                                fontFamily: 'Poppins',
                                                                color: Colors.black,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          if (hasOptions) ...[
                                                            if (selectedSize != null)
                                                              Text(
                                                                'Size: $selectedSize',
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontFamily: 'Poppins',
                                                                  color: Colors.black,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            if (selectedCrust != null)
                                                              Text(
                                                                'Crust: $selectedCrust',
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontFamily: 'Poppins',
                                                                  color: Colors.black,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            if (selectedBase != null)
                                                              Text(
                                                                'Base: $selectedBase',
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontFamily: 'Poppins',
                                                                  color: Colors.black,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            if (toppings.isNotEmpty)
                                                              Text(
                                                                'Toppings: ${toppings.join(', ')}',
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontFamily: 'Poppins',
                                                                  color: Colors.black,
                                                                ),
                                                                maxLines: 3,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            if (sauceDips.isNotEmpty)
                                                              Text(
                                                                'Sauce Dips: ${sauceDips.join(', ')}',
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontFamily: 'Poppins',
                                                                  color: Colors.black,
                                                                ),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),

                                            Container(
                                              width: 3,
                                              height: 110,
                                              margin: const EdgeInsets.symmetric(horizontal: 0),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(30),
                                                color: const Color(0xFFB2B2B2),
                                              ),
                                            ),

                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 90,
                                                    height: 64,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    clipBehavior: Clip.hardEdge,
                                                    child: Image.asset(
                                                      _getCategoryIcon(item.itemType),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    baseItemName,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.normal,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (item.comment != null && item.comment!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDF1C7),
                                              borderRadius: BorderRadius.circular(8.0),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Comment: ${item.comment!}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontFamily: 'Poppins',
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
                          padding: const EdgeInsets.symmetric(horizontal: 55.0),
                          child: Divider(
                            height: 0,
                            thickness: 3,
                            color: const Color(0xFFB2B2B2),
                          ),
                        ),
                        const SizedBox(height: 7),

                        // Total and printer section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 110),
                                      Text(
                                        '${liveSelectedOrder.orderTotalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Change Due',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 40),
                                      Text(
                                        '${liveSelectedOrder.changeDue?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () async {
                                  // Set the _selectedOrder temporarily for printing
                                  _selectedOrder = liveSelectedOrder;
                                  await _handlePrintingOrderReceipt();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          _isPrinterConnected ? Colors.green : Colors.red,
                                          BlendMode.srcIn,
                                        ),
                                        child: Image.asset(
                                          'assets/images/printer.png',
                                          width: 58,
                                          height: 58,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Print Receipt',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No order selected for printing")),
      );
      return;
    }

    try {
      // Convert Order items to CartItem format for the printer service
      List<CartItem> cartItems = _selectedOrder!.items.map((orderItem) {
        // Calculate price per unit from total price and quantity
        double pricePerUnit = orderItem.quantity > 0 ? (orderItem.totalPrice / orderItem.quantity) : 0.0;

        return CartItem(
          foodItem: orderItem.foodItem ?? FoodItem(
            id: orderItem.itemId ?? 0,
            name: orderItem.itemName,
            category: orderItem.itemType,
            price: {'default': pricePerUnit},
            image: orderItem.imageUrl ?? '',
            availability: true,
          ),
          quantity: orderItem.quantity,
          selectedOptions: null, // OrderItem doesn't have selectedOptions, will use description parsing
          comment: orderItem.comment,
          pricePerUnit: pricePerUnit,
        );
      }).toList();

      // Calculate subtotal (assuming no VAT separation needed based on printer service)
      double subtotal = _selectedOrder!.orderTotalPrice;

      // Use the thermal printer service to print
      bool success = await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId: _selectedOrder!.transactionId.isNotEmpty
            ? _selectedOrder!.transactionId
            : _selectedOrder!.orderId.toString(),
        orderType: _selectedOrder!.orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        totalCharge: _selectedOrder!.orderTotalPrice,
        changeDue: _selectedOrder!.changeDue ?? 0.0,
        extraNotes: null, // Add any extra notes if available in your Order model
        onShowMethodSelection: (availableMethods) {
          // Handle case when no printer is connected
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Available printing methods: ${availableMethods.join(', ')}. Please check printer connections."),
              duration: const Duration(seconds: 4),
            ),
          );
        },
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Receipt printed successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to print receipt. Please check printer connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error printing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error printing receipt: $e"),
          backgroundColor: Colors.red,
        ),
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
}