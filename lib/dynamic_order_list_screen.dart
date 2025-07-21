// lib/dynamic_order_list_screen.dart (MODIFIED)

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart'; // Your existing OrderApiService
import 'package:epos/bottom_nav_item.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:epos/page4.dart';
import 'package:epos/settings_screen.dart';
import 'dart:async'; // Import for StreamSubscription

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

class _DynamicOrderListScreenState extends State<DynamicOrderListScreen> {
  List<Order> activeOrders = []; // List for pending/ready orders
  List<Order> completedOrders = []; // List for completed orders
  Order? _selectedOrder;
  late int _selectedBottomNavItem;

  // --- NEW: StreamSubscription for socket updates ---
  late StreamSubscription<Map<String, dynamic>> _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    debugPrint("DynamicOrderListScreen: initState called for type: ${widget.orderType}");
    _loadOrders();
    // --- NEW: Initialize and listen to socket updates ---
    _initializeSocketListener();
  }

  // --- NEW METHOD: Initialize Socket Listener ---
  void _initializeSocketListener() {
    // Get the singleton instance of OrderApiService
    final orderApiService = OrderApiService();

    // Subscribe to the stream for order status/driver changes
    _orderStatusSubscription = orderApiService.orderStatusOrDriverChangedStream.listen((payload) {
      _handleOrderStatusOrDriverChange(payload);
    });

    debugPrint("DynamicOrderListScreen: Subscribed to orderStatusOrDriverChangedStream.");
  }

  // --- MODIFIED METHOD: Handle Order Status/Driver Change from Socket ---
  void _handleOrderStatusOrDriverChange(Map<String, dynamic> payload) {
    final int? orderId = payload['order_id'] as int?;
    final String? newStatusBackend = payload['new_status'] as String?; // Backend status (green, blue, yellow)
    final int? newDriverId = payload['new_driver_id'] as int?; // Only new_driver_id is relevant here

    if (orderId == null || newStatusBackend == null) {
      debugPrint('Socket payload missing order_id or new_status: $payload');
      return;
    }

    setState(() {
      int? orderIndexInActive = activeOrders.indexWhere((order) => order.orderId == orderId);
      int? orderIndexInCompleted = completedOrders.indexWhere((order) => order.orderId == orderId);

      Order? targetOrder;
      List<Order> sourceList; // To keep track if it came from active or completed
      int originalIndex;

      if (orderIndexInActive != -1) {
        targetOrder = activeOrders[orderIndexInActive];
        sourceList = activeOrders;
        originalIndex = orderIndexInActive;
      } else if (orderIndexInCompleted != -1) {
        targetOrder = completedOrders[orderIndexInCompleted];
        sourceList = completedOrders;
        originalIndex = orderIndexInCompleted;
      } else {
        // Order not found, might be a new order that now matches filter or a very old one.
        debugPrint('Socket: Order with ID $orderId not found in current lists. Attempting full reload.');
        _loadOrders();
        return; // Exit as full reload will handle the state
      }

      // Determine the new INTERNAL status for the Order model
      String newInternalStatus;
      switch (newStatusBackend) {
        case 'yellow': newInternalStatus = 'pending'; break;
        case 'green': newInternalStatus = 'ready'; break;
        case 'blue': newInternalStatus = 'completed'; break;
        case 'red': newInternalStatus = 'cancelled'; break;
        default: newInternalStatus = newStatusBackend; // Fallback to raw if unknown
      }

      Order updatedOrder = targetOrder.copyWith(
        status: newInternalStatus, // Update the internal status
        driverId: newDriverId, // Update driver ID
      );

      // --- Re-categorization logic based on newInternalStatus ---
      // Decide if the order should be in 'completed' or 'active' list
      bool shouldBeCompleted = (newInternalStatus == 'completed' || newInternalStatus == 'blue' || newInternalStatus == 'delivered');

      if (shouldBeCompleted) {
        if (sourceList == activeOrders) {
          activeOrders.removeAt(originalIndex);
          completedOrders.add(updatedOrder);
        } else { // Already in completed list, just update
          completedOrders[originalIndex] = updatedOrder;
        }
        completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
      } else { // It's an active status (pending, ready, cancelled etc.)
        if (sourceList == completedOrders) { // If it moved from completed to active
          completedOrders.removeAt(originalIndex);
          activeOrders.add(updatedOrder);
        } else { // Already in active list, just update
          activeOrders[originalIndex] = updatedOrder;
        }
        activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
      }

      // If the selected order was the one that changed, update _selectedOrder
      if (_selectedOrder?.orderId == orderId) {
        _selectedOrder = updatedOrder;
      }

      // Adjust selected order if current selected disappears (e.g., moves to completed and list becomes empty)
      if (_selectedOrder == null || (!activeOrders.any((o) => o.orderId == _selectedOrder!.orderId) && !completedOrders.any((o) => o.orderId == _selectedOrder!.orderId))) {
        _selectedOrder = activeOrders.isNotEmpty ? activeOrders.first :
        (completedOrders.isNotEmpty ? completedOrders.first : null);
      }

      debugPrint("Socket: Order ${orderId} updated. Internal status: ${updatedOrder.status}, Driver ID: ${updatedOrder.driverId}");
    });
  }






  @override
  void didUpdateWidget(covariant DynamicOrderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderType != oldWidget.orderType) {
      debugPrint("DynamicOrderListScreen: orderType changed from ${oldWidget.orderType} to ${widget.orderType}. Reloading orders.");
      _loadOrders();

      setState(() {
        _selectedBottomNavItem = widget.initialBottomNavItemIndex;
        _selectedOrder = null;
      });
    }
  }

  @override
  void dispose() {
    _orderStatusSubscription.cancel(); // --- NEW: Cancel the stream subscription ---
    super.dispose();
  }

  void _loadOrders() async {
    debugPrint("DynamicOrderListScreen: _loadOrders called for ${widget.orderType}. Attempting to fetch orders...");
    try {
      List<Order> fetchedOrders = await OrderApiService.fetchTodayOrders();
      debugPrint("DynamicOrderListScreen: Successfully fetched ${fetchedOrders.length} orders from API.");
      List<Order> filteredOrders = _filterOrdersForEpos(fetchedOrders, widget.orderType);

      List<Order> tempActive = [];
      List<Order> tempCompleted = [];

      for (var order in filteredOrders) {
        // IMPORTANT: Ensure your Order model's `status` and `driverId` are parsed correctly from API
        // And that your Order model has `statusLabel` and `statusColor` getters that map
        // your internal `status` (e.g., "Ready", "Completed", "Pending") to the desired display.

        // When loading, we also need to apply the "ON ITS WAY" logic for initial display
        String initialDisplayStatus = order.statusLabel; // Get default from Order model's getter

        if (order.status.toLowerCase() == 'green' && order.driverId != null) {
          initialDisplayStatus = 'ON ITS WAY';
        } else if (order.status.toLowerCase() == 'blue' && order.driverId != null) {
          initialDisplayStatus = 'COMPLETED';
        }

        Order orderWithInitialDisplay = order.copyWith(
          // Ensure `currentDisplayStatus` field is in your Order model if you want to store it directly
          // For now, relying on `statusLabel` getter from Order model and potentially updating it here.
          // If you add `currentDisplayStatus` to Order model, pass it here.
        );


        if (orderWithInitialDisplay.status.toLowerCase() == 'blue') {
          tempCompleted.add(orderWithInitialDisplay);
        } else {
          tempActive.add(orderWithInitialDisplay);
        }
      }

      tempActive.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      tempCompleted.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      debugPrint("DynamicOrderListScreen: Filtered and separated into ${tempActive.length} active and ${tempCompleted.length} completed orders.");

      setState(() {
        activeOrders = tempActive;
        completedOrders = tempCompleted;

        debugPrint("DynamicOrderListScreen: setState called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}.");

        if (activeOrders.isEmpty && completedOrders.isEmpty) {
          _selectedOrder = null;
          debugPrint("DynamicOrderListScreen: No orders available, _selectedOrder set to null.");
        } else if (activeOrders.isNotEmpty) {
          _selectedOrder = activeOrders.first;
          debugPrint("DynamicOrderListScreen: First active order selected by default: ${_selectedOrder?.orderId}");
        } else if (completedOrders.isNotEmpty) {
          _selectedOrder = completedOrders.first;
          debugPrint("DynamicOrderListScreen: No active orders, first completed order selected by default: ${_selectedOrder?.orderId}");
        }
      });
    } catch (e) {
      debugPrint("DynamicOrderListScreen: ERROR - Failed to fetch orders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load orders. Error: $e")),
      );
    }
    debugPrint("DynamicOrderListScreen: _loadOrders finished.");
  }

  List<Order> _filterOrdersForEpos(List<Order> allOrders, String type) {
    return allOrders.where((order) {
      final isMatchingType = order.orderType.toLowerCase() == type.toLowerCase();
      final isEposSource = order.orderSource.toLowerCase() == 'epos';
      return isMatchingType && isEposSource;
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
      default:
        return 'home.png';
    }
  }

  String get _emptyStateMessage {
    switch (widget.orderType.toLowerCase()) {
      case 'takeaway':
        return 'No takeaway orders found.';
      case 'dinein':
        return 'No dine-in orders found.';
      case 'delivery':
        return 'No delivery orders found.';
      default:
        return 'No orders found.';
    }
  }

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMAS':
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLIC BREAD':
        return 'assets/images/GarlicBreadS.png';
      case 'WRAPS':
        return 'assets/images/WrapsS.png';
      case 'KIDS MEAL':
        return 'assets/images/KidsMealS.png';
      case 'SIDES':
        return 'assets/images/SidesS.png';
      case 'DRINKS':
        return 'assets/images/DrinksS.png';
      default:
        return 'assets/images/default.png';
    }
  }

  String _nextStatus(String current) {
    debugPrint("nextStatus: Current status is '$current'.");
    String newStatus;
    switch (current.toLowerCase()) {
      case 'pending':
        newStatus = 'Ready'; // EPOS internal status for 'preparing' / 'on its way'
        break;
      case 'ready':
        newStatus = 'Completed';
        break;
      case 'completed':
        newStatus = 'Completed'; // Stays completed
        break;
      default:
        newStatus = 'Pending'; // Fallback
    }
    debugPrint("nextStatus: Returning '$newStatus'.");
    return newStatus;
  }

  void _updateOrderStatusAndRelist(Order orderToUpdate, String newStatus) async {
    // Determine the backend status string
    String backendStatusToSend;
    switch (newStatus.toLowerCase()) {
      case 'pending':
        backendStatusToSend = 'yellow';
        break;
      case 'ready': // This corresponds to 'preparing' or 'on its way' from EPOS
        backendStatusToSend = 'green';
        break;
      case 'completed':
        backendStatusToSend = 'blue';
        break;
      default:
        backendStatusToSend = newStatus.toLowerCase();
    }

    // Optimistic UI update
    setState(() {
      int originalIndexInActive = activeOrders.indexWhere((o) => o.orderId == orderToUpdate.orderId);
      int originalIndexInCompleted = completedOrders.indexWhere((o) => o.orderId == orderToUpdate.orderId);

      Order updatedOrder = orderToUpdate.copyWith(status: newStatus);

      // Re-categorize the order in UI based on the new EPOS status
      if (newStatus.toLowerCase() == 'completed') {
        if (originalIndexInActive != -1) {
          activeOrders.removeAt(originalIndexInActive);
        }
        completedOrders.add(updatedOrder);
        completedOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else { // If moving to Pending or Ready
        if (originalIndexInCompleted != -1) { // If it was completed but now active again
          completedOrders.removeAt(originalIndexInCompleted);
          activeOrders.add(updatedOrder);
          activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else if (originalIndexInActive != -1) {
          activeOrders[originalIndexInActive] = updatedOrder;
          activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else { // Should not typically happen unless order was missing from both lists
          activeOrders.add(updatedOrder);
          activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
      }

      if (_selectedOrder?.orderId == orderToUpdate.orderId) {
        _selectedOrder = updatedOrder;
      }
      if (activeOrders.isEmpty && _selectedOrder == null && completedOrders.isNotEmpty) {
        _selectedOrder = completedOrders.first;
      } else if (activeOrders.isNotEmpty && _selectedOrder == null) {
        _selectedOrder = activeOrders.first;
      }
    });

    try {
      // Send the backend status (green, blue, yellow) to the API
      final success = await OrderApiService.updateOrderStatus(orderToUpdate.orderId, backendStatusToSend);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status on server. Re-syncing...")),
        );
        _loadOrders(); // Revert or re-sync if API call fails
      } else {
        debugPrint("Status for Order ID ${orderToUpdate.orderId} successfully updated to '$newStatus' (backend: $backendStatusToSend) on backend.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error communicating with server: $e. Re-syncing...")),
      );
      _loadOrders(); // Revert or re-sync if error
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("DynamicOrderListScreen: build method called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}");

    final allOrdersForDisplay = [...activeOrders];
    if (completedOrders.isNotEmpty) {
      allOrdersForDisplay.add(Order(
        orderId: -1,
        paymentType: '', transactionId: '', orderType: '', status: '', createdAt: DateTime.now(),
        changeDue: 0.0, orderSource: '', customerName: '', orderTotalPrice: 0.0, items: [],
      ));
      allOrdersForDisplay.addAll(completedOrders);
    }


    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(     //left panel
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                    Expanded(
                      child: allOrdersForDisplay.isEmpty
                          ? Center(
                        child: Text(
                          _emptyStateMessage,
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                          : ListView.builder(
                        itemCount: allOrdersForDisplay.length,
                        itemBuilder: (context, index) {
                          final order = allOrdersForDisplay[index];

                          if (order.orderId == -1) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 60),
                              child: Divider(
                                color: Colors.black,
                                thickness: 2,
                              ),
                            );
                          }
                          // Only display orders that match the screen's orderType
                          if (order.orderType.toLowerCase() != widget.orderType.toLowerCase()) {
                            return const SizedBox.shrink(); // Hide orders of different types
                          }

                          // Determine the display label for the order's status
                          String currentDisplayStatus = order.statusLabel; // Default from Order model
                          if (order.status.toLowerCase() == 'green' && order.driverId != null) {
                            currentDisplayStatus = 'ON ITS WAY';
                          } else if (order.status.toLowerCase() == 'blue' && order.driverId != null) {
                            currentDisplayStatus = 'DELIVERED';
                          }

                          int? serialNumber;
                          if (activeOrders.contains(order)) {
                            serialNumber = activeOrders.indexOf(order) + 1;
                          }
                          bool isSelected = _selectedOrder?.orderId == order.orderId;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrder = order;
                                debugPrint("DynamicOrderListScreen: Order ID ${order.orderId} selected.");
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 60),
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
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedOrder = order;
                                          debugPrint("DynamicOrderListScreen: Order ID ${order.orderId} (inner tap) selected.");
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: order.statusColor,
                                          borderRadius: BorderRadius.circular(50),
                                        ),
                                        child: Text(
                                          order.displaySummary,
                                          style: const TextStyle(fontSize: 32,
                                              color: Colors.black),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  GestureDetector(
                                    onTap: () {
                                      // Only allow status change if not already completed
                                      if (order.status.toLowerCase() != 'completed' && order.status.toLowerCase() != 'delivered') {
                                        final newStatus = _nextStatus(order.status);
                                        debugPrint("DynamicOrderListScreen: Changing status for order ID ${order.orderId} from ${order.status} to $newStatus.");
                                        _updateOrderStatusAndRelist(order, newStatus);
                                      } else {
                                        debugPrint("DynamicOrderListScreen: Order ID ${order.orderId} is already Completed. No status change.");
                                      }
                                    },
                                    child: Container(
                                      width: 200,
                                      height: 80,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: order.statusColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        // Use the dynamic `currentDisplayStatus` here
                                        currentDisplayStatus,
                                        style: const TextStyle(fontSize: 32,
                                            color: Colors.black),
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
            const VerticalDivider(
                width: 1, thickness: 0.5, color: Colors.black),

            //Right Panel
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: _selectedOrder == null
                    ? Center(
                  child: Text(
                    'Select an order to see details',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order no. ${_selectedOrder!.orderId}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _selectedOrder!.customerName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_selectedOrder!.phoneNumber != null && _selectedOrder!.phoneNumber!.isNotEmpty)
                      Text(
                        _selectedOrder!.phoneNumber!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    if (_selectedOrder!.streetAddress != null && _selectedOrder!.streetAddress!.isNotEmpty)
                      Text(
                        _selectedOrder!.streetAddress!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    if (_selectedOrder!.city != null && _selectedOrder!.city!.isNotEmpty)
                      Text(
                        '${_selectedOrder!.city}, ${_selectedOrder!.postalCode ?? ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedOrder!.items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = _selectedOrder!.items[itemIndex];

                          String? selectedSize;
                          String? selectedCrust;
                          String baseItemName = item.itemName;

                          final optionMatch = RegExp(r'\((.*?)\)').firstMatch(item.description);
                          if (optionMatch != null && optionMatch.group(1) != null) {
                            String optionsString = optionMatch.group(1)!;
                            List<String> optionsList = optionsString.split(', ').map((s) => s.trim()).toList();

                            for (var option in optionsList) {
                              if (option.toLowerCase().startsWith('size:')) {
                                selectedSize = option.substring('size:'.length).trim();
                              } else if (option.toLowerCase().startsWith('crust:')) {
                                selectedCrust = option.substring('crust:'.length).trim();
                              }
                            }
                            baseItemName = item.description.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
                          }

                          String sizeDisplay = selectedSize != null ? 'Size: $selectedSize' : 'Size: Default';
                          String? crustDisplay = selectedCrust != null ? 'Crust: $selectedCrust' : null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 30,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(left: 30),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sizeDisplay,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontFamily: 'Poppins',
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  if (crustDisplay != null)
                                                    Text(
                                                      crustDisplay,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontFamily: 'Poppins',
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),

                                      Container(
                                        width: 1.2,
                                        height: 180,
                                        color: Colors.black,
                                        margin: const EdgeInsets.symmetric(horizontal: 0),
                                      ),

                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 110,
                                              height: 110,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              clipBehavior: Clip.hardEdge,

                                              child: Image.asset(
                                                _getCategoryIcon(item.itemType),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              baseItemName,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 20,
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
                    const Divider(),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Total amount:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                '€ ${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    debugPrint("DynamicOrderListScreen: _buildBottomNavBar called.");
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BottomNavItem(
            image: 'TakeAway.png',
            index: 0,
            selectedIndex: _selectedBottomNavItem,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Takeaway.");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const DynamicOrderListScreen(
                    orderType: 'takeaway',
                    initialBottomNavItemIndex: 0,
                  ),
                ),
              );
            },
          ),
          BottomNavItem(
            image: 'DineIn.png',
            index: 1,
            selectedIndex: _selectedBottomNavItem,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Dine In.");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const DynamicOrderListScreen(
                    orderType: 'dinein',
                    initialBottomNavItemIndex: 1,
                  ),
                ),
              );
            },
          ),
          BottomNavItem(
            image: 'Delivery.png',
            index: 2,
            selectedIndex: _selectedBottomNavItem,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Delivery.");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const DynamicOrderListScreen(
                    orderType: 'delivery',
                    initialBottomNavItemIndex: 2,
                  ),
                ),
              );
            },
          ),
          BottomNavItem(
            image: 'web.png',
            index: 3,
            selectedIndex: _selectedBottomNavItem,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to Website Orders.");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const WebsiteOrdersScreen(
                    initialBottomNavItemIndex: 3,
                  ),
                ),
              );
            },
          ),
          BottomNavItem(
            image: 'home.png', // Make sure you have 'assets/images/home.png'
            index: 4,
            selectedIndex: _selectedBottomNavItem,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to Page4 (Home Screen).");
              Navigator.pushReplacementNamed(context, '/service-selection');
            },
          ),
          BottomNavItem(
            image: 'More.png', // Make sure you have 'assets/images/home.png'
            index: 5,
            selectedIndex: _selectedBottomNavItem,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(
                      initialBottomNavItemIndex: 5,
                    ),
                  ),
                );
              }
          ),
        ],
      ),
    );
  }
}