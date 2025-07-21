import 'package:epos/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart'; // Make sure this path is correct for your Order model
import 'package:epos/dynamic_order_list_screen.dart'; // Only if you link to it, otherwise remove
import 'package:epos/bottom_nav_item.dart'; // Only if you use it, otherwise remove
import 'package:epos/providers/order_provider.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';

// HexColor extension: Ensure this is available.
// It's in order.dart now, so you might not need it duplicated here unless directly used for other colors.
// Keeping it here for full code example to avoid compilation issues.
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
  List<Order> activeOrders = []; // List of active orders for the current filter
  List<Order> completedOrders = []; // List of completed orders for the current filter
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String _selectedOrderType = 'all'; // Filter: 'all', 'pickup', 'delivery'

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    print("WebsiteOrdersScreen: initState called.");
    // Ensure _separateOrders is called after the first frame to use context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // Remove listener before adding to prevent multiple subscriptions
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
    // Make sure to remove the listener when the widget is disposed
    Provider.of<OrderProvider>(context, listen: false).removeListener(_onOrderProviderChange);
    super.dispose();
  }

  // This method is called whenever OrderProvider's data changes
  void _onOrderProviderChange() {
    print("WebsiteOrdersScreen: OrderProvider data changed, updating UI. Current orders in provider: ${Provider.of<OrderProvider>(context, listen: false).websiteOrders.length}");
    _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
  }

  // This method filters and separates orders into active/completed lists
  void _separateOrders(List<Order> allOrdersFromProvider) {
    setState(() {
      // Step 1: Filter by order type (pickup/delivery) first
      List<Order> typeFilteredOrders;
      if (_selectedOrderType == 'pickup') {
        typeFilteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'pickup').toList();
      } else if (_selectedOrderType == 'delivery') {
        typeFilteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'delivery').toList();
      } else { // _selectedOrderType == 'all'
        typeFilteredOrders = List.from(allOrdersFromProvider);
      }

      // Step 2: Separate active and completed orders from the type-filtered list
      List<Order> tempActive = [];
      List<Order> tempCompleted = [];

      for (var order in typeFilteredOrders) {
        // Define what constitutes a "completed" order for website orders.
        // This should match your backend's final status for these orders.
        if (order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'delivered' || order.status.toLowerCase() == 'blue') {
          tempCompleted.add(order);
        } else {
          tempActive.add(order);
        }
      }

      // Sort each group separately by creation date, newest first
      tempActive.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      activeOrders = tempActive;
      completedOrders = tempCompleted;

      print("WebsiteOrdersScreen: Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length} for type '$_selectedOrderType'");

      // Maintain selection or select first available order
      if (_selectedOrder != null) {
        // Check if the previously selected order is still in the active or completed list
        bool foundInActive = activeOrders.any((o) => o.orderId == _selectedOrder!.orderId);
        bool foundInCompleted = completedOrders.any((o) => o.orderId == _selectedOrder!.orderId);
        if (!foundInActive && !foundInCompleted) {
          // If not found, select the first available order
          _selectedOrder = activeOrders.isNotEmpty ? activeOrders.first :
          completedOrders.isNotEmpty ? completedOrders.first : null;
          print("WebsiteOrdersScreen: Selected order disappeared, new selected: ${_selectedOrder?.orderId}");
        } else if (foundInActive) {
          // If found in active, ensure _selectedOrder points to the updated object
          _selectedOrder = activeOrders.firstWhere((o) => o.orderId == _selectedOrder!.orderId);
        } else if (foundInCompleted) {
          // If found in completed, ensure _selectedOrder points to the updated object
          _selectedOrder = completedOrders.firstWhere((o) => o.orderId == _selectedOrder!.orderId);
        }
      } else {
        // If no order was selected, select the first active, then first completed
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

  // This `_nextStatus` is for Website orders.
  // It defines the progression of internal statuses for website orders.
  String _nextStatus(String current) {
    print("WebsiteOrdersScreen: nextStatus: Current status is '$current'.");
    String newStatus;
    switch (current.toLowerCase()) {
      case 'pending': // Initial state from website (yellow)
      case 'accepted':
        newStatus = 'ready'; // Move to 'Ready' (green)
        break;
      case 'ready': // Ready for pickup/delivery (green)
      case 'preparing':
        newStatus = 'completed'; // Move to 'Completed' (blue)
        break;
      case 'completed': // Final states (blue)
      case 'delivered':
      case 'blue':
        newStatus = 'completed'; // Stays completed
        break;
      case 'cancelled': // Final state (red)
      case 'red':
        newStatus = 'cancelled'; // Stays cancelled
        break;
      default:
        newStatus = 'pending'; // Fallback
    }
    print("WebsiteOrdersScreen: nextStatus: Returning '$newStatus'.");
    return newStatus;
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
      case 'MILKSHAKE':
        return 'assets/images/MilkshakeS.png';
      case 'DIPS':
        return 'assets/images/DipsS.png';
      default:
        return 'assets/images/default.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    print("WebsiteOrdersScreen: build method called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}");

    // Create the combined list for display, including the divider
    final allOrdersForDisplay = <Order>[];

    // Add active orders first
    allOrdersForDisplay.addAll(activeOrders);

    // Add the divider ONLY if there are active orders AND completed orders.
    // This ensures the divider acts as a clear separator between the two groups.
    if (activeOrders.isNotEmpty && completedOrders.isNotEmpty) {
      allOrdersForDisplay.add(Order(
        orderId: -1, // Unique ID for the divider
        customerName: '',
        items: [],
        orderTotalPrice: 0.0,
        createdAt: DateTime.now(),
        status: 'divider', // A unique status for the divider
        orderType: 'divider', // A unique orderType for the divider
        changeDue: 0.0,
        orderSource: 'internal', // Can be anything, just needs to be consistent
        paymentType: '',
        transactionId: '',
      ));
    }

    // Add completed orders after the divider
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
                        // --- Pickup Button ---
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'pickup';
                                // Re-separate orders after changing filter type
                                _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
                              });
                            },
                            child: Container(
                              width: 250,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _selectedOrderType == 'pickup' ? Colors.grey[800] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: const Center(
                                child: Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // --- Deliveries Button ---
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'delivery';
                                // Re-separate orders after changing filter type
                                _separateOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
                              });
                            },
                            child: Container(
                              width: 250,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _selectedOrderType == 'delivery' ? Colors.grey[800] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: const Center(
                                child: Text(
                                  'Deliveries',
                                  style: TextStyle(
                                    fontSize: 32,
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
                          _getEmptyStateMessage(), // Use new helper function
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                          : ListView.builder(
                        itemCount: allOrdersForDisplay.length,
                        itemBuilder: (context, index) {
                          final order = allOrdersForDisplay[index];

                          // --- CHECK FOR DIVIDER FIRST ---
                          if (order.orderId == -1 && order.status == 'divider' && order.orderType == 'divider') {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 60),
                              child: Divider(
                                color: Colors.black,
                                thickness: 2,
                              ),
                            );
                          }

                          // Check if this order is in active orders to show serial number
                          bool isActiveOrder = activeOrders.contains(order); // Check against the filtered activeOrders list
                          int? serialNumber;
                          if (isActiveOrder) {
                            serialNumber = activeOrders.indexOf(order) + 1;
                          }

                          // Determine FINAL display label and color for the UI
                          String finalDisplayLabel;
                          Color finalDisplayColor;

                          // Website orders have different status labels and colors depending on type
                          if (order.orderType.toLowerCase() == 'delivery') {
                            // Delivery website orders: Ready(green)- On Its Way(yellow)- Delivered(blue)
                            if (order.status.toLowerCase() == 'green' && order.driverId != null) {
                              finalDisplayLabel = 'ON ITS WAY';
                              finalDisplayColor = HexColor.fromHex('FFF6D4'); // Yellow
                            } else if (order.status.toLowerCase() == 'blue' || order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'delivered') {
                              finalDisplayLabel = 'DELIVERED';
                              finalDisplayColor = HexColor.fromHex('D4E8FF'); // Light blue for delivered
                            } else if (order.status.toLowerCase() == 'green') {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4'); // Green
                            } else if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'accepted') {
                              finalDisplayLabel = 'Pending';
                              finalDisplayColor = HexColor.fromHex('FFF6D4'); // Yellow
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Cancelled';
                              finalDisplayColor = Colors.red[100]!; // Light red
                            } else {
                              finalDisplayLabel = order.statusLabel; // Fallback to generic model label
                              finalDisplayColor = order.statusColor; // Fallback to generic model color
                            }
                          } else { // All other website order types (e.g., 'pickup')
                            // Other website orders: Pending(yellow)- Ready(green)- Collected(grey)
                            if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'accepted') {
                              finalDisplayLabel = 'Pending';
                              finalDisplayColor = HexColor.fromHex('FFF6D4'); // Yellow
                            } else if (order.status.toLowerCase() == 'green' || order.status.toLowerCase() == 'ready' || order.status.toLowerCase() == 'preparing') {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4'); // Green
                            } else if (order.status.toLowerCase() == 'blue' || order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'delivered') {
                              finalDisplayLabel = 'COLLECTED';
                              finalDisplayColor = HexColor.fromHex('D6D6D6'); // Grey for Collected
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Cancelled';
                              finalDisplayColor = Colors.red[100]!; // Light red
                            } else {
                              finalDisplayLabel = order.statusLabel; // Fallback to generic model label
                              finalDisplayColor = order.statusColor; // Fallback to generic model color
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
                                          color: finalDisplayColor, // Use the determined color
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
                                      // Only allow status change if not already in a final state
                                      if (order.status.toLowerCase() != 'completed' &&
                                          order.status.toLowerCase() != 'delivered' &&
                                          order.status.toLowerCase() != 'blue' &&
                                          order.status.toLowerCase() != 'cancelled' &&
                                          order.status.toLowerCase() != 'red') {
                                        final newStatus = _nextStatus(order.status); // Get next INTERNAL status
                                        debugPrint("WebsiteOrdersScreen: Attempting to change status for order ID ${order.orderId} from ${order.status} to $newStatus.");

                                        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                        // `updateAndRefreshOrder` should handle sending status to backend and refreshing
                                        bool success = await orderProvider.updateAndRefreshOrder(order.orderId, newStatus);
                                        if (success) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Order ${order.orderId} status updated to ${newStatus.toUpperCase()}.')),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to update status for order ${order.orderId}. Please try again.')),
                                          );
                                        }
                                      } else {
                                        debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} is already in a final state. No status change.");
                                      }
                                    },

                                    child: Container(
                                      width: 200,
                                      height: 80,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: finalDisplayColor, // Use the determined color
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        finalDisplayLabel, // Use the determined label
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


            const VerticalDivider(width: 1, thickness: 0.5, color: Colors.black),


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

                    // Total Price and Payment Type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '£${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
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
                    if (_selectedOrder!.changeDue != null && _selectedOrder!.changeDue! > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Change Due:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            '£${_selectedOrder!.changeDue!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      // --- Bottom Navigation Bar ---
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    print("WebsiteOrdersScreen: _buildBottomNavBar called.");
    return Column( // Use a Column to place Divider above the Row
      mainAxisSize: MainAxisSize.min, // Make column take minimum height
      children: [
        const Divider(
          height: 1, // Visual height of the divider
          thickness: 1, // Thickness of the line
          color: Colors.grey, // Grey color for the boundary
        ),
        Container(
          height: 90,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Nav Item 0: Takeaway Orders
              BottomNavItem(
                image: 'TakeAway.png',
                index: 0,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 0;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'takeaway',
                          initialBottomNavItemIndex: 0,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 1: Dine-In Orders
              BottomNavItem(
                image: 'DineIn.png',
                index: 1,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 1;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'dinein',
                          initialBottomNavItemIndex: 1,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 2: Delivery Orders
              BottomNavItem(
                image: 'Delivery.png',
                index: 2,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 2;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DynamicOrderListScreen(
                          orderType: 'delivery',
                          initialBottomNavItemIndex: 2,
                        ),
                      ),
                    );
                  });
                },
              ),
              // Nav Item 3: Website Orders (Current Screen)
              BottomNavItem(
                image: 'web.png',
                index: 3,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 3;
                    // Already on WebsiteOrdersScreen, no navigation needed here.
                  });
                },
              ),
              // Nav Item 4: Home
              BottomNavItem(
                image: 'home.png',
                index: 4,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 4;
                    Navigator.pushReplacementNamed(context, '/service-selection');
                  });
                },
              ),
              // Nav Item 5: More
              BottomNavItem(
                image: 'More.png',
                index: 5,
                selectedIndex: _selectedBottomNavItem,
                onTap: () {
                  setState(() {
                    _selectedBottomNavItem = 5;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(
                          initialBottomNavItemIndex: 5,
                        ),
                      ),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}