import 'package:flutter/material.dart';
import 'package:epos/models/order.dart'; // Ensure Order model is correctly defined AND UPDATED
import 'package:epos/dynamic_order_list_screen.dart'; // Ensure this file exists
import 'package:epos/bottom_nav_item.dart'; // Ensure this file exists (for your bottom nav items)
import 'package:epos/providers/order_provider.dart';
import 'package:provider/provider.dart';

// Extension to darken a color for the status button background
extension ColorBrightness on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
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
  List<Order> _displayedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String _selectedOrderType = 'all'; // 'all', 'pickup', 'delivery'

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    print("WebsiteOrdersScreen: initState called.");
    // Initial fetch to populate UI on first load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDisplayedOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure the listener is added only once.
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // Attempt to remove any existing listener to prevent duplicates.
    try {
      orderProvider.removeListener(_onOrderProviderChange);
    } catch (e) {
      // Listener might not have been added yet, safe to ignore.
    }
    orderProvider.addListener(_onOrderProviderChange);
    _updateDisplayedOrders(orderProvider.websiteOrders);
  }

  @override
  void dispose() {
    Provider.of<OrderProvider>(context, listen: false).removeListener(_onOrderProviderChange);
    super.dispose();
  }

  void _onOrderProviderChange() {
    // Debug print to confirm provider notification
    print("WebsiteOrdersScreen: OrderProvider data changed, updating UI. Current orders in provider: ${Provider.of<OrderProvider>(context, listen: false).websiteOrders.length}");
    _updateDisplayedOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
    print("WebsiteOrdersScreen: _displayedOrders count after update: ${_displayedOrders.length}");
  }

  void _updateDisplayedOrders(List<Order> allOrdersFromProvider) {
    setState(() {
      List<Order> filteredOrders;
      if (_selectedOrderType == 'pickup') {
        filteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'pickup').toList();
      } else if (_selectedOrderType == 'delivery') {
        filteredOrders = allOrdersFromProvider.where((order) => order.orderType.toLowerCase() == 'delivery').toList();
      } else {
        filteredOrders = List.from(allOrdersFromProvider);
      }

      // Sort by creation date, newest first for better visibility of new orders.
      filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _displayedOrders = filteredOrders;

      // Maintain selection or select first if current selection is invalid/empty.
      if (_selectedOrder != null && !_displayedOrders.any((o) => o.orderId == _selectedOrder!.orderId)) {
        _selectedOrder = _displayedOrders.isNotEmpty ? _displayedOrders.first : null;
      } else if (_displayedOrders.isNotEmpty && _selectedOrder == null) {
        _selectedOrder = _displayedOrders.first;
      } else if (_displayedOrders.isEmpty) {
        _selectedOrder = null;
      }
    });
  }

  String get _screenHeading {
    return 'Website';
  }

  String get _screenImage {
    return 'webwhite.png';
  }

  String get _emptyStateMessage {
    return 'No orders found for this type.';
  }

  // Determines text color based on the background status color for readability.
  // With the new colors (FFF6D4, DEF5D4, D6D6D6), black text is suitable for all.
  Color _getTextColor(String status) {
    return Colors.black;
  }

  // Determines the next status in the order workflow for a given current status.
  String _nextStatus(String current) {
    print("nextStatus: Current status is '$current'.");
    String newStatus;
    switch (current.toLowerCase()) {
      case 'pending':
      case 'accepted': // Treat 'accepted' from API like 'pending' for UI transition
        newStatus = 'ready';
        break;
      case 'ready':
      case 'preparing': // Treat 'preparing' from API like 'ready' for UI transition
        newStatus = 'completed';
        break;
      case 'completed':
      case 'delivered': // Once completed/delivered, status remains completed.
        newStatus = 'completed';
        break;
      default:
        newStatus = 'pending'; // Fallback to initial 'pending' status.
    }
    print("nextStatus: Returning '$newStatus'.");
    return newStatus;
  }

  // Maps item category names to their corresponding icon assets.
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

  @override
  Widget build(BuildContext context) {
    print("WebsiteOrdersScreen: build method called. Current number of displayed orders: ${_displayedOrders.length}");

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
                        MouseRegion( // Added MouseRegion
                          cursor: SystemMouseCursors.click, // Hand pointer on hover
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'pickup';
                                _updateDisplayedOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
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
                        MouseRegion( // Added MouseRegion
                          cursor: SystemMouseCursors.click, // Hand pointer on hover
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedOrderType = 'delivery';
                                _updateDisplayedOrders(Provider.of<OrderProvider>(context, listen: false).websiteOrders);
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
                      child: _displayedOrders.isEmpty
                          ? Center(
                        child: Text(
                          _emptyStateMessage,
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _displayedOrders.length,
                        itemBuilder: (context, index) {
                          final order = _displayedOrders[index];
                          bool isSelected = _selectedOrder?.orderId == order.orderId;

                          // Debug print for each order item being built
                          print("Building Order ID: ${order.orderId}, Status: ${order.status}, Color: ${order.statusColor}");

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
                                  // Order number
                                  Text(
                                    '${index + 1}', // Displaying serial number (index + 1) for all items.
                                    style: TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: _getTextColor(order.status), // Text color for readability
                                    ),
                                  ),
                                  const SizedBox(width: 15),

                                  // Order Summary (postcode, street address) - This is the middle part
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedOrder = order;
                                          debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} (inner tap) selected.");
                                        });
                                      },
                                      child: Container( // This container gets the status color background
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: order.statusColor,
                                          borderRadius: BorderRadius.circular(50),
                                        ),
                                        child: Text(
                                          order.displayAddressSummary,
                                          style: TextStyle(fontSize: 32, color: _getTextColor(order.status)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10), // Space between middle and status button

                                  // Status Change Button
                                  GestureDetector(
                                    onTap: () async {
                                      // Only allow status change if not already 'completed'
                                      if (order.status.toLowerCase() != 'completed' && order.status.toLowerCase() != 'delivered') { // Added 'delivered' here
                                        final newStatus = _nextStatus(order.status);
                                        debugPrint("WebsiteOrdersScreen: Attempting to change status for order ID ${order.orderId} from ${order.status} to $newStatus.");

                                        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
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
                                        debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} is already Completed/Delivered. No status change.");
                                      }
                                    },
                                    child: Container(
                                      width: 200, // Fixed width as per reference
                                      height: 80, // Fixed height as per reference
                                      alignment: Alignment.center, // Center text vertically and horizontally
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: order.statusColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        order.statusLabel,
                                        style: TextStyle(fontSize: 32, color: _getTextColor(order.status)),
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
                          _selectedOrder!.paymentType,
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
                    // Add navigation to your "More" screen here if it exists
                    debugPrint("WebsiteOrdersScreen: More button tapped.");
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