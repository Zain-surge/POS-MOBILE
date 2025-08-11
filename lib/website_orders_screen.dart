// lib/website_orders_screen.dart

import 'package:epos/services/thermal_printer_service.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/providers/website_orders_provider.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
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
  String _selectedOrderType = 'all';
  final ScrollController _scrollController = ScrollController();
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;



  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    print("WebsiteOrdersScreen: initState called.");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      _separateOrders(orderProvider.websiteOrders);
      // Initialize counts for website orders after the first load
      _updateWebsiteOrderCountsInProvider();
      if (!orderProvider.isPolling) {
        orderProvider.startPolling();
      }
    });
  }

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      orderProvider.removeListener(_onOrderProviderChange);
    } catch (e) {
      // Listener might not exist yet
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
      print("Error removing listener: $e");
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onOrderProviderChange() {
    print("WebsiteOrdersScreen: OrderProvider data changed, updating UI. Current orders in provider: ${Provider.of<OrderProvider>(context, listen: false).websiteOrders.length}");
    final allWebsiteOrders = Provider.of<OrderProvider>(context, listen: false).websiteOrders;
    _separateOrders(allWebsiteOrders);
    _updateWebsiteOrderCountsInProvider(); // Update counts whenever provider changes
  }

  void _updateWebsiteOrderCountsInProvider() {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);
    int newWebsiteActiveCount = 0;
    for (var order in Provider.of<OrderProvider>(context, listen: false).websiteOrders) {
      if (!(order.status.toLowerCase() == 'completed' ||
          order.status.toLowerCase() == 'delivered' ||
          order.status.toLowerCase() == 'blue' ||
          order.status.toLowerCase() == 'cancelled' ||
          order.status.toLowerCase() == 'red')) {
        newWebsiteActiveCount++;
      }
    }
    orderCountsProvider.setOrderCount('website', newWebsiteActiveCount);
  }

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
        int statusPriorityA = _getStatusPriority(a.status);
        int statusPriorityB = _getStatusPriority(b.status);

        if (statusPriorityA != statusPriorityB) {
          return statusPriorityA.compareTo(statusPriorityB); // Lower number = higher priority
        }
        // If same status priority, sort by creation time (oldest first)
        return a.createdAt.compareTo(b.createdAt);
      });
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

  String _nextStatus(Order order) {
    print("WebsiteOrdersScreen: nextStatus: Current status is '${order.status}'. Order Type: ${order.orderType}, Driver ID: ${order.driverId}");

    final String currentStatusLower = order.status.toLowerCase();
    final String orderTypeLower = order.orderType.toLowerCase();
    final bool hasDriver = order.driverId != null && order.driverId != 0; // Fixed: use != 0 instead of isNotEmpty

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
        // If it's ready but no driver assigned yet, keep it as ready
        // If driver is assigned, it should show "On Its Way" in display but status stays 'green'
          if (hasDriver) {
            return 'Ready'; // Don't change status, just display changes
          }
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
          return 'Completed';
        case 'completed':
        case 'delivered':
        case 'blue':
          return 'Completed';
        case 'cancelled':
        case 'red':
          return 'Completed';
        default:
          return 'Ready';
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

                          // Time calculation for time-based colors
                          DateTime now = DateTime.now();
                          Duration orderAge = now.difference(_selectedOrder!.createdAt);
                          int minutesPassed = orderAge.inMinutes;

                          // Helper function for time-based colors
                          Color getTimeBasedColor(String status) {
                            // Completed orders are always grey regardless of time
                            if (status.toLowerCase() == 'blue' ||
                                status.toLowerCase() == 'completed' ||
                                status.toLowerCase() == 'delivered') {
                              return HexColor.fromHex('D6D6D6');
                            }

                            // Cancelled orders keep their red color
                            if (status.toLowerCase() == 'red' || status.toLowerCase() == 'cancelled') {
                              return Colors.red[100]!;
                            }

                            // Time-based colors for active orders
                            if (minutesPassed < 30) {
                              return HexColor.fromHex('DEF5D4'); // Green - 0-30 minutes
                            } else if (minutesPassed >= 30 && minutesPassed < 45) {
                              return HexColor.fromHex('FFF6D4'); // Yellow - 30-45 minutes
                            } else {
                              return HexColor.fromHex('ffcaca'); // Red - 45+ minutes
                            }
                          }
                          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                          finalDisplayLabel = orderProvider.getDeliveryDisplayStatus(order);
                          finalDisplayColor = getTimeBasedColor(order.status.toLowerCase());

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
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                        decoration: BoxDecoration(
                                          color: finalDisplayColor,
                                          borderRadius: BorderRadius.circular(50),
                                        ),
                                        child: Text(
                                          order.displayAddressSummary,
                                          style: const TextStyle(fontSize: 29,
                                              color: Colors.black),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Circular Timer - only show for active orders
                                  if (serialNumber != null) ...[
                                    CircularTimer(
                                      startTime: order.createdAt,
                                      size: 70.0,
                                      // progressColor:const Color(0xFFCB6CE6),
                                      progressColor: Colors.black,
                                      backgroundColor: Colors.grey,
                                      strokeWidth: 5.0,
                                      maxMinutes: 60, // 30 minutes for full circle
                                    ),
                                  ],
                                  const SizedBox(width: 10),

                                  GestureDetector(
                                    onTap: () async {
                                      // First, check if the order is already in a final state (completed, delivered, cancelled)
                                      final bool isFinalState = order.status.toLowerCase() == 'completed' ||
                                          order.status.toLowerCase() == 'delivered' ||
                                          order.status.toLowerCase() == 'blue' ||
                                          order.status.toLowerCase() == 'cancelled' ||
                                          order.status.toLowerCase() == 'red';

                                      if (isFinalState) {
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


                                      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                      final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);


                                      bool success = await orderProvider.updateAndRefreshOrder(order.orderId, nextIntendedStatus);

                                      if (success) {

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
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: finalDisplayColor, // Use the determined color
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                       child: Text(
                          // Dynamic text for the button - use the same logic as display label
                          (() {
                          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                          final displayStatus = orderProvider.getDeliveryDisplayStatus(order);

                          // For completed orders, always show "Completed"
                          if (order.status.toLowerCase() == 'completed' ||
                          order.status.toLowerCase() == 'blue' ||
                          order.status.toLowerCase() == 'delivered') {
                          return 'Completed';
                          }

                          // For delivery orders that are ready with driver, show "On Its Way"
                          if (order.orderType.toLowerCase() == 'delivery' &&
                          order.status.toLowerCase() == 'green' &&
                          order.driverId != null &&
                          order.driverId != 0) {
                          return 'On Its Way';
                          }

                          return displayStatus;
                          })(),
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
                          Text(
                            _selectedOrder!.customerName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
                          ),
                          if ((_selectedOrder!.orderType.toLowerCase()=="delivery"|| _selectedOrder!.orderType.toLowerCase()=="takeaway" ) && _selectedOrder!.customerEmail != null && _selectedOrder!.customerEmail!.isNotEmpty)
                            Text(
                              _selectedOrder!.customerEmail!,
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
                        itemCount: _selectedOrder!.items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = _selectedOrder!.items[itemIndex];

                          // Enhanced option extraction
                          Map<String, dynamic> itemOptions = _extractAllOptionsFromDescription(
                            item.description,
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
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal:40),
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
                                onTap: () async {
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
}