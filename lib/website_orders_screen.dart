// lib/website_orders_screen.dart

import 'package:epos/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart'; // Make sure this path is correct for your Order model
import 'package:epos/dynamic_order_list_screen.dart'; // Ensure this is correct if navigating to it
import 'package:epos/providers/order_provider.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import 'package:epos/order_counts_provider.dart'; // Import for OrderCountsProvider

// Assuming HexColor extension is in order.dart or a common utility.
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class WebsiteOrdersScreen extends StatefulWidget {
  final int initialBottomNavItemIndex;

  const WebsiteOrdersScreen({
    Key? key,
    required this.initialBottomNavItemIndex,
  }) : super(key: key);

  @override
  State<WebsiteOrdersScreen> createState() => _WebsiteOrdersScreenState();
}

class _WebsiteOrdersScreenState extends State<WebsiteOrdersScreen> {
  List<Order> activeOrders = [];
  List<Order> completedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String _selectedOrderType = 'all'; // Filter: 'all', 'pickup', 'delivery'

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    print("WebsiteOrdersScreen: initState called.");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
      // Initialize counts for website orders after the first load
      _updateWebsiteOrderCountsInProvider();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      orderProvider.removeListener(_onOrderProviderChange);
    } catch (e) {
      // Listener might not have been added yet, safe to ignore.
    }
    orderProvider.addListener(_onOrderProviderChange);
    // Re-separate orders whenever dependencies change or provider updates
    _separateOrders(orderProvider.websiteOrders);
  }

  @override
  void dispose() {
    try {
      Provider.of<OrderProvider>(context, listen: false).removeListener(_onOrderProviderChange);
    } catch (e) {
      // Widget might be disposed in an unusual state
    }
    super.dispose();
  }

  void _onOrderProviderChange() {
    print("WebsiteOrdersScreen: OrderProvider data changed, updating UI. Current orders in provider: ${Provider.of<OrderProvider>(context, listen: false).websiteOrders.length}");
    final allWebsiteOrders = Provider.of<OrderProvider>(context, listen: false).websiteOrders;
    _separateOrders(allWebsiteOrders);
    _updateWebsiteOrderCountsInProvider(); // Update counts whenever provider changes
  }

  // Refactored: This method will specifically manage the 'website' order count in OrderCountsProvider.
  // Now uses the new setOrderCount method.
  void _updateWebsiteOrderCountsInProvider() {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);
    int newWebsiteActiveCount = 0;
    for (var order in Provider.of<OrderProvider>(context, listen: false).websiteOrders) {
      // Logic for what constitutes an "active" website order
      if (!(order.status.toLowerCase() == 'completed' ||
          order.status.toLowerCase() == 'delivered' ||
          order.status.toLowerCase() == 'blue' ||
          order.status.toLowerCase() == 'cancelled' ||
          order.status.toLowerCase() == 'red')) {
        newWebsiteActiveCount++;
      }
    }
    // Use the new setOrderCount method to directly set the count
    orderCountsProvider.setOrderCount('website', newWebsiteActiveCount);
  }


  void _separateOrders(List<Order> allOrdersFromProvider) {
    setState(() {
      int? selectedOrderId = _selectedOrder?.orderId;

      List<Order> typeFilteredOrders;
      if (_selectedOrderType == 'pickup') {
        typeFilteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'pickup').toList();
      } else if (_selectedOrderType == 'delivery') {
        typeFilteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'delivery').toList();
      } else {
        typeFilteredOrders = List.from(allOrdersFromProvider);
      }

      List<Order> tempActive = [];
      List<Order> tempCompleted = [];

      for (var order in typeFilteredOrders) {
        if (order.status.toLowerCase() == 'completed' ||
            order.status.toLowerCase() == 'delivered' ||
            order.status.toLowerCase() == 'blue' ||
            order.status.toLowerCase() == 'cancelled' ||
            order.status.toLowerCase() == 'red') {
          tempCompleted.add(order);
        } else {
          tempActive.add(order);
        }
      }

      tempActive.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      activeOrders = tempActive;
      completedOrders = tempCompleted;

      print("WebsiteOrdersScreen: Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length} for type '$_selectedOrderType'");

      if (selectedOrderId != null) {
        Order? foundOrder;
        try {
          foundOrder = activeOrders.firstWhere((o) => o.orderId == selectedOrderId);
          print("WebsiteOrdersScreen: Found selected order ${selectedOrderId} in active orders");
        } catch (e) {
          try {
            foundOrder = completedOrders.firstWhere((o) => o.orderId == selectedOrderId);
            print("WebsiteOrdersScreen: Found selected order ${selectedOrderId} in completed orders");
          } catch (e) {
            foundOrder = null;
            print("WebsiteOrdersScreen: Selected order ${selectedOrderId} not found in any list");
          }
        }

        if (foundOrder != null) {
          _selectedOrder = foundOrder;
          print("WebsiteOrdersScreen: Maintained selection for order: ${_selectedOrder?.orderId}");
        } else {
          _selectedOrder = activeOrders.isNotEmpty ? activeOrders.first :
          completedOrders.isNotEmpty ? completedOrders.first : null;
          print("WebsiteOrdersScreen: Selected order disappeared, new selected: ${_selectedOrder?.orderId}");
        }
      } else {
        _selectedOrder = activeOrders.isNotEmpty ? activeOrders.first :
        completedOrders.isNotEmpty ? completedOrders.first : null;
        if (_selectedOrder != null) {
          print("WebsiteOrdersScreen: No order selected, setting default: ${_selectedOrder?.orderId}");
        }
      }
    });
  }

  String get _screenHeading {
    return 'Website';
  }

  String get _screenImage {
    return 'webwhite.png';
  }

  String _getEmptyStateMessage() {
    if (_selectedOrderType == 'pickup') {
      return 'No pickup orders found.';
    } else if (_selectedOrderType == 'delivery') {
      return 'No delivery orders found.';
    }
    return 'No website orders found.';
  }

  String _nextStatus(String current) {
    print("WebsiteOrdersScreen: nextStatus: Current status is '$current'.");
    String newStatus;
    switch (current.toLowerCase()) {
      case 'pending':
      case 'accepted':
      case 'yellow':
        newStatus = 'ready';
        break;
      case 'ready':
      case 'preparing':
      case 'green':
        newStatus = 'completed';
        break;
      case 'completed':
      case 'delivered':
      case 'blue':
        newStatus = 'completed';
        break;
      case 'cancelled':
      case 'red':
        newStatus = 'cancelled';
        break;
      default:
        newStatus = 'ready';
    }
    print("WebsiteOrdersScreen: nextStatus: Returning '$newStatus'.");
    return newStatus;
  }

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMA':
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLIC BREAD':
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
      default:
        return 'assets/images/default.png';
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
    print("WebsiteOrdersScreen: build method called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}");

    // Consume the OrderCountsProvider here to get the latest counts
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final activeOrdersCount = orderCountsProvider.activeOrdersCount;


    final allOrdersForDisplay = <Order>[];
    allOrdersForDisplay.addAll(activeOrders);

    if (activeOrders.isNotEmpty && completedOrders.isNotEmpty) {
      allOrdersForDisplay.add(Order(
        orderId: -1,
        customerName: '',
        items: [],
        orderTotalPrice: 0.0,
        createdAt: DateTime.now(),
        status: 'divider',
        orderType: 'divider',
        changeDue: 0.0,
        orderSource: 'internal',
        paymentType: '',
        transactionId: '',
      ));
    }

    allOrdersForDisplay.addAll(completedOrders);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // --- Left Panel (Order List) ---
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    // Pickup/Delivery Filter Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'pickup';
                                _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
                                // The _onOrderProviderChange will correctly update the counts.
                                // No explicit _updateWebsiteOrderCountsInProvider call needed here,
                                // as it's handled by the listener if the underlying order data changes.
                              });
                            },
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedOrderType == 'pickup' ? Colors.grey[800] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: const Center(
                                child: Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'delivery';
                                _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
                                // The _onOrderProviderChange will correctly update the counts.
                              });
                            },
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedOrderType == 'delivery' ? Colors.grey[800] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: const Center(
                                child: Text(
                                  'Delivery',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
                          _getEmptyStateMessage(),
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                          : ListView.builder(
                        itemCount: allOrdersForDisplay.length,
                        itemBuilder: (context, index) {
                          final order = allOrdersForDisplay[index];

                          if (order.orderId == -1 && order.status == 'divider' && order.orderType == 'divider') {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 60),
                              child: Divider(
                                color: Colors.black,
                                thickness: 2,
                              ),
                            );
                          }

                          bool isActiveOrder = activeOrders.contains(order);
                          int? serialNumber;
                          if (isActiveOrder) {
                            serialNumber = activeOrders.indexOf(order) + 1;
                          }

                          String finalDisplayLabel;
                          Color finalDisplayColor;

                          if (order.orderType.toLowerCase() == 'delivery') {
                            if (order.status.toLowerCase() == 'green' && order.driverId != null) {
                              finalDisplayLabel = 'ON ITS WAY';
                              finalDisplayColor = HexColor.fromHex('FFF6D4');
                            } else if (order.status.toLowerCase() == 'blue' || order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'delivered') {
                              finalDisplayLabel = 'DELIVERED';
                              finalDisplayColor = HexColor.fromHex('D6D6D6');
                            } else if (order.status.toLowerCase() == 'green' || order.status.toLowerCase() == 'ready') {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4');
                            } else if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'accepted') {
                              finalDisplayLabel = 'Pending';
                              finalDisplayColor = HexColor.fromHex('FFF6D4');
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Cancelled';
                              finalDisplayColor = Colors.red[100]!;
                            } else {
                              finalDisplayLabel = order.statusLabel;
                              finalDisplayColor = order.statusColor;
                            }
                          } else {
                            if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'accepted') {
                              finalDisplayLabel = 'Pending';
                              finalDisplayColor = HexColor.fromHex('FFF6D4');
                            } else if (order.status.toLowerCase() == 'green' || order.status.toLowerCase() == 'ready' || order.status.toLowerCase() == 'preparing') {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4');
                            } else if (order.status.toLowerCase() == 'blue' || order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'delivered') {
                              finalDisplayLabel = 'COLLECTED';
                              finalDisplayColor = HexColor.fromHex('D6D6D6');
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Cancelled';
                              finalDisplayColor = Colors.red[100]!;
                            } else {
                              finalDisplayLabel = order.statusLabel;
                              finalDisplayColor = order.statusColor;
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrder = order;
                                debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} selected.");
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 60),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.transparent, width: 3),
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
                                          debugPrint("WebSiteOrdersScreen: Order ID ${order.orderId} (inner tap) selected.");
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: finalDisplayColor,
                                          borderRadius: BorderRadius.circular(50),
                                        ),
                                        child: Text(
                                          order.displayAddressSummary,
                                          style: const TextStyle(fontSize: 32,
                                              color: Colors.black),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  GestureDetector(
                                    onTap: () async {
                                      bool wasActive = !(order.status.toLowerCase() == 'completed' ||
                                          order.status.toLowerCase() == 'delivered' ||
                                          order.status.toLowerCase() == 'blue' ||
                                          order.status.toLowerCase() == 'cancelled' ||
                                          order.status.toLowerCase() == 'red');

                                      if (wasActive) {
                                        final newStatus = _nextStatus(order.status);
                                        debugPrint("WebsiteOrdersScreen: Attempting to change status for order ID ${order.orderId} from ${order.status} to $newStatus.");

                                        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                        final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);


                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Updating order ${order.orderId}...'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );

                                        bool success = await orderProvider.updateAndRefreshOrder(order.orderId, newStatus);

                                        if (success) {
                                          bool willBeActive = !(newStatus.toLowerCase() == 'completed' ||
                                              newStatus.toLowerCase() == 'delivered' ||
                                              newStatus.toLowerCase() == 'blue' ||
                                              newStatus.toLowerCase() == 'cancelled' ||
                                              newStatus.toLowerCase() == 'red');

                                          if (wasActive && !willBeActive) {
                                            orderCountsProvider.decrementOrderCount('website');
                                            print("WebsiteOrdersScreen: Decremented 'website' count for order ${order.orderId}");
                                          } else if (!wasActive && willBeActive) {
                                            orderCountsProvider.incrementOrderCount('website');
                                            print("WebsiteOrdersScreen: Incremented 'website' count for order ${order.orderId}");
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Order ${order.orderId} status updated to ${newStatus.toUpperCase()}.')),
                                            );
                                          }
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to update status for order ${order.orderId}. Please try again.')),
                                            );
                                          }
                                        }
                                      } else {
                                        debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} is already in a final state. No status change.");
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Order ${order.orderId} is already completed.')),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 200,
                                      height: 80,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: finalDisplayColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        finalDisplayLabel,
                                        style: const TextStyle(fontSize: 32, color: Colors.black),
                                      ),
                                    ),
                                  )
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

            // --- Right Panel (Order Details) ---
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
                    // Order Number and Header
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

                    // Customer Details
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

                    // Order Items List
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
                                    padding: const EdgeInsets.only(top: 8.0, left: 20.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Comment: ${item.comment}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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

                    Column(
                      children: [
                        // Payment Type Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payment Type:',
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              _selectedOrder!.paymentType ?? 'N/A',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Total and Change Due Box with Printer Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total:',
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '£${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (_selectedOrder!.changeDue != null && _selectedOrder!.changeDue! > 0) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Change Due:',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '£${_selectedOrder!.changeDue!.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  print("No implementation yet");
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Image.asset(
                                    'assets/images/printer.png',
                                    width: 50,
                                    height: 50,
                                  ),
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
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    print("WebsiteOrdersScreen: _buildBottomNavBar called.");
    return Consumer<OrderCountsProvider>(
      builder: (context, orderCountsProvider, child) {
        final activeOrdersCount = orderCountsProvider.activeOrdersCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey,
            ),
            Container(
              height: 90,
              color: Colors.white,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 45.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navItem(
                    'TakeAway.png',
                    0,
                    notification: _getNotificationCount(0, activeOrdersCount),
                    color: const Color(0xFFFFE26B),
                    onTap: () {
                      debugPrint("WebsiteOrdersScreen: Navigating to EPOS Takeaway.");
                      if (_selectedBottomNavItem != 0) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicOrderListScreen(
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
                    color: const Color(0xFFFFE26B),
                    onTap: () {
                      debugPrint("WebsiteOrdersScreen: Navigating to EPOS Dine In.");
                      if (_selectedBottomNavItem != 1) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicOrderListScreen(
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
                    color: const Color(0xFFFFE26B),
                    onTap: () {
                      debugPrint("WebsiteOrdersScreen: Navigating to EPOS Delivery.");
                      if (_selectedBottomNavItem != 2) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicOrderListScreen(
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
                    color: const Color(0xFFFFE26B),
                    onTap: () {
                      debugPrint("WebsiteOrdersScreen: Navigating to Website Orders.");
                      if (_selectedBottomNavItem != 3) {
                        setState(() {
                          _selectedBottomNavItem = 3;
                        });
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
                      debugPrint("WebsiteOrdersScreen: Navigating to Settings Screen.");
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
            ),
          ],
        );
      },
    );
  }

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
        displayImage = image.replaceAll('.png', 'white.png');
      }
    } else {
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
        onTap: onTap,
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
                width: index == 2 ? 92 : 60,
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