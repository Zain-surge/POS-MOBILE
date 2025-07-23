// lib/dynamic_order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:epos/page4.dart'; // Ensure Page4 is correctly imported for navigation
import 'package:epos/settings_screen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:epos/order_counts_provider.dart';


// Extension for HexColor (if you're using it elsewhere, otherwise it could be moved)
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
  List<Order> activeOrders = [];
  List<Order> completedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;

  late StreamSubscription<Map<String, dynamic>> _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    debugPrint("DynamicOrderListScreen: initState called for type: ${widget.orderType}");
    _loadOrders();
    _initializeSocketListener();
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

    // Get access to the OrderCountsProvider
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);


    setState(() {
      int? orderIndexInActive = activeOrders.indexWhere((order) => order.orderId == orderId);
      int? orderIndexInCompleted = completedOrders.indexWhere((order) => order.orderId == orderId);

      Order? targetOrder;
      List<Order>? sourceList;
      int? originalIndex;

      // Determine the new INTERNAL status for the Order model
      String newInternalStatus;
      switch (newStatusBackend) {
        case 'yellow': newInternalStatus = 'pending'; break;
        case 'green': newInternalStatus = 'ready'; break;
        case 'blue': newInternalStatus = 'completed'; break;
        case 'red': newInternalStatus = 'cancelled'; break;
        default: newInternalStatus = newStatusBackend;
      }

      // Find the order and remove it from its current list
      if (orderIndexInActive != -1) {
        targetOrder = activeOrders.removeAt(orderIndexInActive);
        sourceList = activeOrders;
        // Decrement the count for the order's original type if it's moving out of 'active'
        if (newInternalStatus == 'completed' || newInternalStatus == 'blue') {
          orderCountsProvider.decrementOrderCount(targetOrder.orderType);
        }
      } else if (orderIndexInCompleted != -1) {
        targetOrder = completedOrders.removeAt(orderIndexInCompleted);
        sourceList = completedOrders;
        // Increment the count for the order's type if it's moving back to 'active'
        if (newInternalStatus != 'completed' && newInternalStatus != 'blue') {
          orderCountsProvider.incrementOrderCount(targetOrder.orderType);
        }
      } else {
        debugPrint('Socket: Order with ID $orderId not found in current lists. Attempting full reload.');
        _loadOrders(); // Full reload will re-fetch counts as well
        return;
      }

      Order updatedOrder = targetOrder!.copyWith(
        status: newInternalStatus,
        driverId: newDriverId,
      );

      // Re-categorization logic based on newInternalStatus
      bool shouldBeCompleted = (newInternalStatus == 'completed' || newInternalStatus == 'blue' || newInternalStatus == 'delivered');

      if (shouldBeCompleted) {
        completedOrders.add(updatedOrder);
        completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        activeOrders.add(updatedOrder);
        activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      // If the selected order was the one that changed, update _selectedOrder
      if (_selectedOrder?.orderId == orderId) {
        _selectedOrder = updatedOrder;
      }

      // Adjust selected order if current selected disappears
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
    _orderStatusSubscription.cancel();
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
        String initialDisplayStatus = order.statusLabel;

        if (order.status.toLowerCase() == 'green' && order.driverId != null) {
          initialDisplayStatus = 'ON ITS WAY';
        } else if (order.status.toLowerCase() == 'blue' && order.driverId != null) {
          initialDisplayStatus = 'COMPLETED';
        }

        Order orderWithInitialDisplay = order.copyWith(); // Use copyWith to ensure immutability

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
      case 'SHAWARMA': // Note: API might return "Shawarma" singular
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLIC BREAD':
        return 'assets/images/GarlicBreadS.png';
      case 'WRAPS':
        return 'assets/images/WrapsS.png';
      case 'KIDSMEAL': // Note: API might return "KidsMeal"
        return 'assets/images/KidsMealS.png';
      case 'SIDES':
        return 'assets/images/SidesS.png';
      case 'DRINKS':
        return 'assets/images/DrinksS.png';
      case 'MILKSHAKE':
        return 'assets/images/MilkshakeS.png';
      case 'DIPS':
        return 'assets/images/DipsS.png';
      default:
        return 'assets/images/default.png';
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
        newStatus = 'Completed';
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

    // Get access to the OrderCountsProvider
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);

    // Optimistic UI update
    setState(() {
      int originalIndexInActive = activeOrders.indexWhere((o) => o.orderId == orderToUpdate.orderId);
      int originalIndexInCompleted = completedOrders.indexWhere((o) => o.orderId == orderToUpdate.orderId);

      Order updatedOrder = orderToUpdate.copyWith(status: newStatus);

      // Handle count updates based on status change
      if (newStatus.toLowerCase() == 'completed') {
        if (originalIndexInActive != -1) {
          activeOrders.removeAt(originalIndexInActive);
          orderCountsProvider.decrementOrderCount(orderToUpdate.orderType); // Decrement when moving to completed
        }
        completedOrders.add(updatedOrder);
        completedOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        if (originalIndexInCompleted != -1) {
          completedOrders.removeAt(originalIndexInCompleted);
          activeOrders.add(updatedOrder);
          orderCountsProvider.incrementOrderCount(orderToUpdate.orderType); // Increment when moving from completed
          activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else if (originalIndexInActive != -1) {
          activeOrders[originalIndexInActive] = updatedOrder;
          activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else {
          activeOrders.add(updatedOrder);
          orderCountsProvider.incrementOrderCount(orderToUpdate.orderType); // Increment if newly added to active
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
      final success = await OrderApiService.updateOrderStatus(orderToUpdate.orderId, backendStatusToSend);
      if (!success) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update status on server. Re-syncing...")),
          );
        }
        _loadOrders();
      } else {
        debugPrint("Status for Order ID ${orderToUpdate.orderId} successfully updated to '$newStatus' (backend: $backendStatusToSend) on backend.");
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error communicating with server: $e. Re-syncing...")),
        );
      }
      _loadOrders();
    }
  }

  // Helper to get order count for each nav item
  String? _getNotificationCount(int index, Map<String, int> currentActiveOrdersCount) {
    int count = 0;
    switch (index) {
      case 0: // Takeaway
        count = currentActiveOrdersCount['takeaway'] ?? 0;
        break;
      case 1: // Dine In
        count = currentActiveOrdersCount['dinein'] ?? 0;
        break;
      case 2: // Delivery
        count = currentActiveOrdersCount['delivery'] ?? 0;
        break;
      case 3: // Website
        count = currentActiveOrdersCount['website'] ?? 0;
        break;
      default:
        return null; // No notification for home/more
    }
    return count > 0 ? count.toString() : null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("DynamicOrderListScreen: build method called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}");

    // Consume the OrderCountsProvider here to get the latest counts
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final activeOrdersCount = orderCountsProvider.activeOrdersCount;


    final allOrdersForDisplay = [...activeOrders];
    if (completedOrders.isNotEmpty) {
      allOrdersForDisplay.add(Order(
        orderId: -1, // Placeholder for the divider
        paymentType: '', transactionId: '', orderType: '', status: '', createdAt: DateTime.now(),
        changeDue: 0.0, orderSource: '', customerName: '', orderTotalPrice: 0.0, items: [],
      ));
      allOrdersForDisplay.addAll(completedOrders);
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
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
                          if (order.orderType.toLowerCase() != widget.orderType.toLowerCase()) {
                            return const SizedBox.shrink();
                          }

                          String currentDisplayStatus = order.statusLabel;
                          if (order.status.toLowerCase() == 'green' && order.driverId != null) {
                            currentDisplayStatus = 'ON ITS WAY';
                          } else if (order.status.toLowerCase() == 'blue' && order.driverId != null) {
                            currentDisplayStatus = 'DELIVERED';
                          }

                          int? serialNumber;
                          if (activeOrders.contains(order)) {
                            serialNumber = activeOrders.indexOf(order) + 1;
                          }
                          // bool isSelected = _selectedOrder?.orderId == order.orderId; // This variable is not used to control selection color here

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
                                color: Colors.transparent, // No special background for selected state in this list
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: const VerticalDivider(
                width: 2.5,
                thickness: 2.5,
                color: Colors.grey,
              ),
            ),

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
                                        height: 150,
                                        color: Colors.black,
                                        margin: const EdgeInsets.symmetric(horizontal: 0),
                                      ),

                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 90,
                                              height: 90,
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                            const SizedBox(width: 10),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  // no implementation yet
                                  print("No implementation yet");
                                },
                                child: Image.asset(
                                  'assets/images/printer.png',
                                  width: 50,
                                  height: 50,
                                ),
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
      // Pass activeOrdersCount to _buildBottomNavBar
      bottomNavigationBar: _buildBottomNavBar(activeOrdersCount),
    );
  }

  // --- MODIFIED _buildBottomNavBar to use _navItem directly and accept activeOrdersCount ---
  Widget _buildBottomNavBar(Map<String, int> activeOrdersCount) {
    debugPrint("DynamicOrderListScreen: _buildBottomNavBar called with counts.");
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
        color: Colors.white,
      ),
     child: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 45.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(
            'TakeAway.png',
            0,
            notification: _getNotificationCount(0, activeOrdersCount),
            color: Colors.amber, // Yellow notification for take away
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Takeaway.");
              if (_selectedBottomNavItem != 0) { // Only navigate if not already on this screen
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
              }
            },
          ),
          _navItem(
            'DineIn.png',
            1,
            notification: _getNotificationCount(1, activeOrdersCount),
            color: Colors.amber, // Yellow notification for dine in
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Dine In.");
              if (_selectedBottomNavItem != 1) {
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
              }
            },
          ),
          _navItem(
            'Delivery.png',
            2,
            notification: _getNotificationCount(2, activeOrdersCount),
            color: Colors.amber, // Yellow notification for delivery
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to EPOS Delivery.");
              if (_selectedBottomNavItem != 2) {
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
              }
            },
          ),
          _navItem(
            'web.png',
            3,
            notification: _getNotificationCount(3, activeOrdersCount),
            color: Colors.amber, // Yellow notification for website
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to Website Orders.");
              if (_selectedBottomNavItem != 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const WebsiteOrdersScreen(
                      initialBottomNavItemIndex: 3,
                    ),
                  ),
                );
              }
            },
          ),
          _navItem(
            'home.png',
            4,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to Page4 (Home Screen).");
              Navigator.pushReplacementNamed(context, '/service-selection');
            },
          ),
          _navItem(
            'More.png',
            5,
            onTap: () {
              debugPrint("DynamicOrderListScreen: Navigating to Settings Screen.");
              if (_selectedBottomNavItem != 5) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(
                      initialBottomNavItemIndex: 5,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
    );
  }

  // This _navItem is a duplicate from Page4 but is necessary here
  // unless you make a common widget for it. For now, duplicating is simpler.
  Widget _navItem(String image, int index,
      {String? notification, Color? color, required VoidCallback onTap}) {

    bool isSelected = _selectedBottomNavItem == index;

    String displayImage = image;

    if (isSelected) {
      if (image == 'TakeAway.png') {
        displayImage = 'TakeAwaywhite.png';
      } else if (image == 'DineIn.png') {
        displayImage = 'DineInwhite.png';
      } else if (image == 'Delivery.png') {
        displayImage = 'Deliverywhite.png';
      } else if (image.contains('.png')) {
        // For other icons that have a white version when selected
        displayImage = image.replaceAll('.png', 'white.png');
      }
    } else {
      // Logic to switch back to original color version if not selected
      if (image == 'TakeAwaywhite.png') {
        displayImage = 'TakeAway.png';
      } else if (image == 'DineInwhite.png') {
        displayImage = 'DineIn.png';
      } else if (image == 'Deliverywhite.png') {
        displayImage = 'Delivery.png';
      } else if (image.contains('white.png')) {
        displayImage = image.replaceAll('white.png', '.png');
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // No setState here, as navigation handles the selection change
          onTap(); // Execute the specific tap action
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/$displayImage',
                width: index == 2 ? 92 : 60, // Special sizing for Delivery icon
                height: index == 2 ? 92 : 60,
                color: isSelected ? Colors.white : const Color(0xFF616161),
              ),
              if (notification != null && notification.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color ?? Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      notification,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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