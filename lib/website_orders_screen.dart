// lib/website_orders_screen.dart

import 'package:epos/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:epos/providers/order_provider.dart';
import 'package:provider/provider.dart';
import 'package:epos/order_counts_provider.dart';
import 'package:epos/custom_bottom_nav_bar.dart';

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


  // Add these helper methods after the dispose() method and before _onOrderProviderChange()

// Helper method to define status priority for sorting
  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'yellow':
      case 'accepted':
        return 1; // Highest priority (shows first)
      case 'ready':
      case 'green':
      case 'preparing':
        return 2; // Second priority
      default:
        return 3; // Lowest priority for other statuses
    }
  }

// Updated socket handling sort method for website orders
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

// Updated _separateOrders method with proper sorting
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

      // Sort active orders: Pending first, then others, then by creation time within each group
      tempActive.sort((a, b) {
        // First priority: status-based sorting
        int statusPriorityA = _getStatusPriority(a.status);
        int statusPriorityB = _getStatusPriority(b.status);

        if (statusPriorityA != statusPriorityB) {
          return statusPriorityA.compareTo(statusPriorityB); // Lower number = higher priority
        }

        // If same status priority, sort by creation time (oldest first)
        return a.createdAt.compareTo(b.createdAt);
      });

      tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort completed by newest first

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
// In _WebsiteOrdersScreenState class

  String _nextStatus(Order order) {
    print("WebsiteOrdersScreen: nextStatus: Current status is '${order.status}'. Order Type: ${order.orderType}");

    final String currentStatusLower = order.status.toLowerCase();
    final String orderTypeLower = order.orderType.toLowerCase();

    // Determine if it's a Website Delivery order
    final bool isWebsiteDeliveryOrder = orderTypeLower == 'delivery';

    if (isWebsiteDeliveryOrder) {
      switch (currentStatusLower) {
        case 'pending':
        case 'accepted':
        case 'yellow':
          return 'Ready'; // Allow PENDING delivery to go to READY
        case 'ready':
        case 'preparing':
        case 'green':
        // For website delivery, if it's already 'ready', it cannot proceed further
        // from this app's logic, based on the backend's implicit rule (you mentioned "from epos order can't be updated beyond ready").
        // We'll treat website delivery similarly if it has the same limitation.
          return 'Ready'; // Stays 'ready' (frontend enforcement)
        case 'completed':
        case 'delivered':
        case 'blue':
          return 'Completed'; // Stays completed
        case 'cancelled':
        case 'red':
          return 'Completed'; // Stays cancelled
        default:
          return 'Ready'; // Fallback
      }
    } else {
      // For all other website order types (e.g., 'pickup')
      switch (currentStatusLower) {
        case 'pending':
        case 'accepted':
        case 'yellow':
          return 'Ready';
        case 'ready':
        case 'preparing':
        case 'green':
          return 'Completed'; // Pickup can go directly to 'completed' after 'ready'
        case 'completed':
        case 'delivered':
        case 'blue':
          return 'Completed'; // Stays completed
        case 'cancelled':
        case 'red':
          return 'Completed'; // Stays cancelled
        default:
          return 'Ready'; // Fallback
      }
    }
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
      case 'GARLICBREAD':
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
// Updated method - Shows ALL options including "default" and "normal"
  Map<String, dynamic> _extractAllOptionsFromDescription(String description) {
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
    bool foundOptions = false;

    // Check if it's parentheses format (EPOS): "Item Name (Size: Large, Crust: Thin)"
    final optionMatch = RegExp(r'\((.*?)\)').firstMatch(description);
    if (optionMatch != null && optionMatch.group(1) != null) {
      // EPOS format with parentheses
      String optionsString = optionMatch.group(1)!;
      baseItemName = description.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      foundOptions = true;
      optionsList = _smartSplitOptions(optionsString);

    } else if (description.contains('\n') || description.contains(':')) {
      // Website format with newlines: "Size: 7 inch\nBase: Tomato\nCrust: Normal"
      List<String> lines = description.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // Check if any line contains options (has colons)
      List<String> optionLines = lines.where((line) => line.contains(':')).toList();

      if (optionLines.isNotEmpty) {
        foundOptions = true;
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
          baseItemName = foundItemName;
        } else {
          baseItemName = description;
        }
      }
    }

    // If no options found, it's a simple description like "Chocolate Milkshake"
    if (!foundOptions) {
      options['baseItemName'] = description;
      options['hasOptions'] = false;
      return options;
    }

    // Process the options - REMOVED all "default" and "normal" checks
    options['hasOptions'] = true;
    for (var option in optionsList) {
      String lowerOption = option.toLowerCase();

      if (lowerOption.startsWith('size:')) {
        String sizeValue = option.substring('size:'.length).trim();
        // REMOVED: if (sizeValue.toLowerCase() != 'default' && sizeValue.toLowerCase() != 'normal')
        if (sizeValue.isNotEmpty) { // Only check if not empty
          options['size'] = sizeValue;
        }
      } else if (lowerOption.startsWith('crust:')) {
        String crustValue = option.substring('crust:'.length).trim();
        // REMOVED: if (crustValue.toLowerCase() != 'default' && crustValue.toLowerCase() != 'normal')
        if (crustValue.isNotEmpty) { // Only check if not empty
          options['crust'] = crustValue;
        }
      } else if (lowerOption.startsWith('base:')) {
        String baseValue = option.substring('base:'.length).trim();
        // REMOVED: if (baseValue.toLowerCase() != 'default' && baseValue.toLowerCase() != 'normal')
        if (baseValue.isNotEmpty) { // Only check if not empty
          // Handle multiple bases separated by comma: "Tomato,Garlic"
          if (baseValue.contains(',')) {
            List<String> baseList = baseValue.split(',').map((b) => b.trim()).toList();
            options['base'] = baseList.join(', '); // Join with proper spacing
          } else {
            options['base'] = baseValue;
          }
        }
      } else if (lowerOption.startsWith('toppings:') || lowerOption.startsWith('extra toppings:')) {
        // Handle both "Toppings:" and "Extra Toppings:"
        String prefix = lowerOption.startsWith('extra toppings:') ? 'extra toppings:' : 'toppings:';
        String toppingsValue = option.substring(prefix.length).trim();

        // REMOVED: if (toppingsValue.toLowerCase() != 'default')
        if (toppingsValue.isNotEmpty) { // Only check if not empty
          // Split toppings by comma and clean them
          List<String> toppingsList = toppingsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
          options['toppings'] = toppingsList;
        }
      } else if (lowerOption.startsWith('sauce dips:')) {
        String sauceDipsValue = option.substring('sauce dips:'.length).trim();
        // REMOVED: if (sauceDipsValue.toLowerCase() != 'default')
        if (sauceDipsValue.isNotEmpty) { // Only check if not empty
          // Split sauce dips by comma and clean them
          List<String> sauceDipsList = sauceDipsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
          options['sauceDips'] = sauceDipsList;
        }
      }
    }

    options['baseItemName'] = baseItemName;
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

                              });
                            },
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedOrderType == 'pickup' ? Colors.grey[100] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child:  Center(
                                child: Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedOrderType == 'pickup' ?  Colors.black : Colors.white,
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
                                color: _selectedOrderType == 'delivery' ? Colors.grey[100] : Colors.black,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: Center(
                                child: Text(
                                  'Delivery',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedOrderType == 'delivery' ?  Colors.black : Colors.white,
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
                                color: const Color(0xFFB2B2B2),
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
                              finalDisplayLabel = 'On Its Way';
                              finalDisplayColor = HexColor.fromHex('DEF5D4');
                            } else if (order.status.toLowerCase() == 'blue' && order.driverId != null) {
                              finalDisplayLabel = 'Completed';
                              finalDisplayColor = HexColor.fromHex('D6D6D6');
                            } else if (order.status.toLowerCase() == 'green' && order.driverId == null) {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4');
                            }
                            else if (order.status.toLowerCase() == 'green' || order.status.toLowerCase() == 'ready') {
                              finalDisplayLabel = 'Ready';
                              finalDisplayColor = HexColor.fromHex('DEF5D4');
                            } else if (order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'accepted') {
                              finalDisplayLabel = 'Pending';
                              finalDisplayColor = HexColor.fromHex('FFF6D4');
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Completed';
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
                              finalDisplayLabel = 'Completed';
                              finalDisplayColor = HexColor.fromHex('D6D6D6');
                            } else if (order.status.toLowerCase() == 'red' || order.status.toLowerCase() == 'cancelled') {
                              finalDisplayLabel = 'Completed';
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
                                  const SizedBox(width: 10), // This was the line 574 mentioned in error. The comma is correct if another child follows.
                                  GestureDetector( // This is the start of the next child, so the comma above it is fine.
                                    onTap: () async {
                                      // First, check if the order is already in a final state (completed, delivered, cancelled)
                                      final bool isFinalState = order.status.toLowerCase() == 'completed' ||
                                          order.status.toLowerCase() == 'delivered' ||
                                          order.status.toLowerCase() == 'blue' ||
                                          order.status.toLowerCase() == 'cancelled' ||
                                          order.status.toLowerCase() == 'red';

                                      if (isFinalState) {
                                        debugPrint("WebsiteOrdersScreen: Order ID ${order.orderId} is already in a final state. No status change.");
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Order ${order.orderId} is already ${order.statusLabel}.')),
                                          );
                                        }
                                        return; // Do nothing if it's already in a final state
                                      }

                                      // Determine the next intended status using the intelligent function
                                      final String nextIntendedStatus = _nextStatus(order); // Pass the full order object

                                      // Specific rule for Website Delivery Orders:
                                      // If it's a delivery order and currently 'ready', AND the _nextStatus function also says 'ready'
                                      // (meaning it cannot progress further from this app), then show a message and stop.
                                      final bool isWebsiteDeliveryOrder = order.orderType.toLowerCase() == 'delivery';

                                      if (isWebsiteDeliveryOrder && order.status.toLowerCase() == 'ready' && nextIntendedStatus.toLowerCase() == 'ready') {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text("Website Delivery orders cannot be updated beyond 'Ready' from this screen.")),
                                          );
                                        }
                                        return; // Prevent update
                                      }

                                      debugPrint("WebsiteOrdersScreen: Attempting to change status for order ID ${order.orderId} from ${order.status} to $nextIntendedStatus.");

                                      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                      final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);

                                      // ScaffoldMessenger.of(context).showSnackBar(
                                      //   SnackBar(
                                      //     content: Text('Updating order ${order.orderId} to ${nextIntendedStatus.toUpperCase()}...'),
                                      //     duration: const Duration(seconds: 1),
                                      //   ),
                                      // );

                                      // Attempt to update the status via the provider
                                      bool success = await orderProvider.updateAndRefreshOrder(order.orderId, nextIntendedStatus);

                                      if (success) {
                                        // The _onOrderProviderChange handler already calls _updateWebsiteOrderCountsInProvider(),
                                        // so explicit decrement/increment here might be redundant or could lead to double-counting.
                                        // It's safer to let the centralized _updateWebsiteOrderCountsInProvider handle counts
                                        // after the orderProvider.updateAndRefreshOrder() fetches the latest data.
                                        // Removed explicit increment/decrement here:
                                        // if (wasActive && !willBeActive) {
                                        //   orderCountsProvider.decrementOrderCount('website');
                                        //   print("WebsiteOrdersScreen: Decremented 'website' count for order ${order.orderId}");
                                        // } else if (!wasActive && willBeActive) {
                                        //   orderCountsProvider.incrementOrderCount('website');
                                        //   print("WebsiteOrdersScreen: Incremented 'website' count for order ${order.orderId}");
                                        // }

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Order ${order.orderId} status updated to ${nextIntendedStatus.toUpperCase()}.')),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to update status for order ${order.orderId}. Please try again.')),
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
                                        color: finalDisplayColor, // Use the determined color
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        // Dynamic text for the button
                                        order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'blue' || order.status.toLowerCase() == 'delivered'
                                            ? 'Completed' // If it's already completed
                                            : (order.orderType.toLowerCase() == 'delivery' && order.status.toLowerCase() == 'ready')
                                            ? 'Ready' // Specific text for 'Ready' delivery orders
                                            : (order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'yellow' || order.status.toLowerCase() == 'accepted')
                                            ? 'Pending'
                                            : _nextStatus(order),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: const VerticalDivider(
                width: 3,
                thickness: 3,
                color: Colors.grey,
              ),
            ),

            //RIGHT PANEL
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(9.0),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical:5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedOrder!.orderType.toLowerCase()=="delivery" && _selectedOrder!.postalCode != null && _selectedOrder!.postalCode!.isNotEmpty
                                    ? '${_selectedOrder!.postalCode} '
                                    : '',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                              ),
                              // Display Order Number
                              Text(
                                'Order no. ${_selectedOrder!.orderId}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                          Text(
                            _selectedOrder!.customerName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                          ),
                          if (_selectedOrder!.orderType.toLowerCase()=="delivery" && _selectedOrder!.streetAddress != null && _selectedOrder!.streetAddress!.isNotEmpty)
                            Text(
                              _selectedOrder!.streetAddress!,
                              style: const TextStyle(fontSize: 18),
                            ),
                          if (_selectedOrder!.orderType.toLowerCase()=="delivery" && _selectedOrder!.city != null && _selectedOrder!.city!.isNotEmpty)
                            Text(
                              '${_selectedOrder!.city}, ${_selectedOrder!.postalCode ?? ''}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          if (_selectedOrder!.phoneNumber != null && _selectedOrder!.phoneNumber!.isNotEmpty)
                            Text(
                              _selectedOrder!.phoneNumber!,
                              style: const TextStyle(fontSize: 18),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // --- ADD THE HORIZONTAL DIVIDER  ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 55.0),
                      child: Divider(
                        height: 0,
                        thickness: 3,
                        color: const Color(0xFFB2B2B2),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedOrder!.items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = _selectedOrder!.items[itemIndex];

                          // Enhanced option extraction
                          Map<String, dynamic> itemOptions = _extractAllOptionsFromDescription(item.description);

                          String? selectedSize = itemOptions['size'];
                          String? selectedCrust = itemOptions['crust'];
                          String? selectedBase = itemOptions['base'];
                          List<String> toppings = itemOptions['toppings'] ?? [];
                          List<String> sauceDips = itemOptions['sauceDips'] ?? [];
                          String baseItemName = item.itemName;
                          bool hasOptions = itemOptions['hasOptions'] ?? false;

                          // print('=== Debug Item from WEBSITE ${itemIndex} ===');
                          // print('Original description: ${item.description}');
                          // print('Extracted options: $itemOptions');
                          // print('Size: $selectedSize');
                          // print('Crust: $selectedCrust');
                          // print('Base: $selectedBase');
                          // print('Toppings: $toppings');
                          // print('Base item name: $baseItemName');
                          // print('========================');
                          // print('Item type: ${item.itemType}');
                          // print('Category icon: ${_getCategoryIcon(item.itemType)}');

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
                                        flex: 6,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 28,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 30, right: 10),
                                                // In your Column for displaying options:
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // If no options found, display the description as a simple text
                                                    if (!hasOptions)
                                                      Text(
                                                        item.description, // Show "Chocolate Milkshake"
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),

                                                    // If options exist, display them individually
                                                    if (hasOptions) ...[
                                                      // Display Size (only if not default)
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
                                                      // Display Crust (only if not default)
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
                                                      // Display Base (only if not default)
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
                                                      // Display Toppings (only if not empty)
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
                                                      // Display Sauce Dips (only if not empty)
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
                                        width: 1.2,
                                        height: 110,
                                        color: const Color(0xFFB2B2B2),
                                        margin: const EdgeInsets.symmetric(horizontal: 0),
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

                    // --- ADD THE HORIZONTAL DIVIDER  ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 55.0),
                      child: Divider(
                        height: 0,
                        thickness: 3,
                        color: const Color(0xFFB2B2B2),
                      ),
                    ),

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
                        const SizedBox(height: 13),

                        // Total and Change Due Box with Printer Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(35),
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
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 110),
                                      Text(
                                        '${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,),
                                      ),
                                    ],
                                  ),
                                  if (_selectedOrder!.changeDue != null && _selectedOrder!.changeDue! > 0) ...[
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
                                          '${_selectedOrder!.changeDue!.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,  color: Colors.white),
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
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/printer.png',
                                        width: 58,
                                        height: 58,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      //bottomNavigationBar: _buildBottomNavBar(),

      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedBottomNavItem,
        showDivider: true,
        onItemSelected: (index) {
          if (index == 3) {
            setState(() {
              _selectedBottomNavItem = index;
            });
          }
        },
      ),
    );
  }













  // Widget _buildBottomNavBar() {
  //   print("WebsiteOrdersScreen: _buildBottomNavBar called.");
  //   return Consumer<OrderCountsProvider>(
  //     builder: (context, orderCountsProvider, child) {
  //       final activeOrdersCount = orderCountsProvider.activeOrdersCount;
  //       return Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           const Divider(
  //             height: 1,
  //             thickness: 1,
  //             color: Colors.grey,
  //           ),
  //           Container(
  //             height: 90,
  //             color: Colors.white,
  //       child: Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 45.0),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 _navItem(
  //                   'TakeAway.png',
  //                   0,
  //                   notification: _getNotificationCount(0, activeOrdersCount),
  //                   color: const Color(0xFFFFE26B),
  //                   onTap: () {
  //                     debugPrint("WebsiteOrdersScreen: Navigating to EPOS Takeaway.");
  //                     if (_selectedBottomNavItem != 0) {
  //                       Navigator.pushReplacement(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (context) => const DynamicOrderListScreen(
  //                             orderType: 'takeaway',
  //                             initialBottomNavItemIndex: 0,
  //                           ),
  //                         ),
  //                       );
  //                     }
  //                   },
  //                 ),
  //                 _navItem(
  //                   'DineIn.png',
  //                   1,
  //                   notification: _getNotificationCount(1, activeOrdersCount),
  //                   color: const Color(0xFFFFE26B),
  //                   onTap: () {
  //                     debugPrint("WebsiteOrdersScreen: Navigating to EPOS Dine In.");
  //                     if (_selectedBottomNavItem != 1) {
  //                       Navigator.pushReplacement(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (context) => const DynamicOrderListScreen(
  //                             orderType: 'dinein',
  //                             initialBottomNavItemIndex: 1,
  //                           ),
  //                         ),
  //                       );
  //                     }
  //                   },
  //                 ),
  //                 _navItem(
  //                   'Delivery.png',
  //                   2,
  //                   notification: _getNotificationCount(2, activeOrdersCount),
  //                   color: const Color(0xFFFFE26B),
  //                   onTap: () {
  //                     debugPrint("WebsiteOrdersScreen: Navigating to EPOS Delivery.");
  //                     if (_selectedBottomNavItem != 2) {
  //                       Navigator.pushReplacement(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (context) => const DynamicOrderListScreen(
  //                             orderType: 'delivery',
  //                             initialBottomNavItemIndex: 2,
  //                           ),
  //                         ),
  //                       );
  //                     }
  //                   },
  //                 ),
  //                 _navItem(
  //                   'web.png',
  //                   3,
  //                   notification: _getNotificationCount(3, activeOrdersCount),
  //                   color: const Color(0xFFFFE26B),
  //                   onTap: () {
  //                     debugPrint("WebsiteOrdersScreen: Navigating to Website Orders.");
  //                     if (_selectedBottomNavItem != 3) {
  //                       setState(() {
  //                         _selectedBottomNavItem = 3;
  //                       });
  //                     }
  //                   },
  //                 ),
  //                 _navItem(
  //                   'home.png',
  //                   4,
  //                   onTap: () {
  //                     debugPrint("DynamicOrderListScreen: Navigating to Page4 (Home Screen).");
  //                     Navigator.pushReplacementNamed(context, '/service-selection');
  //                   },
  //                 ),
  //                 _navItem(
  //                   'More.png',
  //                   5,
  //                   onTap: () {
  //                     debugPrint("WebsiteOrdersScreen: Navigating to Settings Screen.");
  //                     if (_selectedBottomNavItem != 5) {
  //                       Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (context) => const SettingsScreen(
  //                             initialBottomNavItemIndex: 5,
  //                           ),
  //                         ),
  //                       );
  //                     }
  //                   },
  //                 ),
  //               ],
  //             ),
  //       ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Widget _navItem(String image, int index,
  //     {String? notification, Color? color, required VoidCallback onTap}) {
  //
  //   bool isSelected = _selectedBottomNavItem == index;
  //
  //   String displayImage = image;
  //
  //   if (isSelected) {
  //     if (image == 'TakeAway.png') {
  //       displayImage = 'TakeAwaywhite.png';
  //     } else if (image == 'DineIn.png') {
  //       displayImage = 'DineInwhite.png';
  //     } else if (image == 'Delivery.png') {
  //       displayImage = 'Deliverywhite.png';
  //     } else if (image.contains('.png')) {
  //       displayImage = image.replaceAll('.png', 'white.png');
  //     }
  //   } else {
  //     if (image == 'TakeAwaywhite.png') {
  //       displayImage = 'TakeAway.png';
  //     } else if (image == 'DineInwhite.png') {
  //       displayImage = 'DineIn.png';
  //     } else if (image == 'Deliverywhite.png') {
  //       displayImage = 'Delivery.png';
  //     } else if (image.contains('white.png')) {
  //       displayImage = image.replaceAll('white.png', '.png');
  //     }
  //   }
  //
  //   return MouseRegion(
  //     cursor: SystemMouseCursors.click,
  //     child: GestureDetector(
  //       onTap: onTap,
  //       child: Container(
  //         padding: const EdgeInsets.all(5),
  //         decoration: BoxDecoration(
  //           color: isSelected ? Colors.black : Colors.transparent,
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Stack(
  //           alignment: Alignment.center,
  //           children: [
  //             Image.asset(
  //               'assets/images/$displayImage',
  //               width: index == 2 ? 92 : 60,
  //               height: index == 2 ? 92 : 60,
  //               color: isSelected ? Colors.white : const Color(0xFF616161),
  //             ),
  //             if (notification != null && notification.isNotEmpty)
  //               Positioned(
  //                 top: 0,
  //                 right: 0,
  //                 child: Container(
  //                   padding: const EdgeInsets.all(4),
  //                   decoration: BoxDecoration(
  //                     color: color ?? Colors.red,
  //                     shape: BoxShape.circle,
  //                   ),
  //                   constraints: const BoxConstraints(
  //                     minWidth: 20,
  //                     minHeight: 20,
  //                   ),
  //                   child: Text(
  //                     notification,
  //                     style: const TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}