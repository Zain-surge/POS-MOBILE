// lib/active_orders_list.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart'; // <--- NEW IMPORT
import 'package:epos/order_counts_provider.dart'; // <--- NEW IMPORT

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class ActiveOrdersList extends StatefulWidget {
  // REMOVE the onOrderCountsChanged callback
  // final Function(Map<String, int>)? onOrderCountsChanged; // <--- REMOVE THIS LINE

  const ActiveOrdersList({
    super.key,
    // this.onOrderCountsChanged, // <--- REMOVE THIS FROM CONSTRUCTOR
  });

  @override
  State<ActiveOrdersList> createState() => _ActiveOrdersListState();
}

class _ActiveOrdersListState extends State<ActiveOrdersList> {
  List<Order> _activeOrders = [];
  bool _isLoadingOrders = true;
  String? _errorLoadingOrders;
  late StreamSubscription _newOrderSocketSubscription;
  late StreamSubscription _acceptedOrderStreamSubscription;
  Order? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
    _listenForNewOrdersFromSocket();
    _listenForAcceptedOrders();
  }

  @override
  void dispose() {
    _newOrderSocketSubscription.cancel();
    _acceptedOrderStreamSubscription.cancel();
    super.dispose();
  }

  // Method to count orders by type AND determine dominant colors
  void _updateOrderCounts() {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);

    // Numeric counts for order types (UNCHANGED from your existing logic)
    Map<String, int> currentTypeCounts = {
      'takeaway': 0,
      'dinein': 0,
      'delivery': 0,
      'website': 0,
    };

    // NEW: Flags to track presence of critical colors for each type
    Map<String, bool> hasRedOrder = {
      'takeaway': false, 'dinein': false, 'delivery': false, 'website': false
    };
    Map<String, bool> hasYellowOrder = {
      'takeaway': false, 'dinein': false, 'delivery': false, 'website': false
    };

    // Loop through all active orders to update both counts and color flags
    for (var order in _activeOrders) {
      String orderTypeKey; // This will hold 'takeaway', 'dinein', 'delivery', or 'website'

      // Determine the correct key for the order type/source
      if (order.orderSource.toLowerCase() == 'website') {
        orderTypeKey = 'website';
      } else { // Assuming 'epos' or other internal sources map to traditional types
        orderTypeKey = order.orderType.toLowerCase();
      }

      // Update numerical counts (your existing logic)
      if (currentTypeCounts.containsKey(orderTypeKey)) {
        currentTypeCounts[orderTypeKey] = currentTypeCounts[orderTypeKey]! + 1;
      }


      // NEW: Update color flags based on order status
      String orderStatus = order.status.toLowerCase();
      if (orderStatus == 'red' || orderStatus == 'declined') {
        hasRedOrder[orderTypeKey] = true;
      } else if (orderStatus == 'yellow') {
        hasYellowOrder[orderTypeKey] = true;
      }
      // If it's 'green' or 'accepted', no need to set a flag,
      // as it's the lowest priority color.
    }

    // NEW: Determine the dominant color for each order type
    Map<String, Color> dominantColorsForTypes = {};
    for (String typeKey in currentTypeCounts.keys) {
      if (hasRedOrder[typeKey] == true) {
        dominantColorsForTypes[typeKey] = Colors.red;
      } else if (hasYellowOrder[typeKey] == true) {
        dominantColorsForTypes[typeKey] = Colors.yellow;
      } else if (currentTypeCounts[typeKey]! > 0) {
        // If there are active orders of this type, and none are red/yellow, they must all be green
        dominantColorsForTypes[typeKey] = Colors.green;
      } else {
        // If there are no active orders for this type, default to grey or a neutral color
        dominantColorsForTypes[typeKey] = Colors.grey; // Or Colors.transparent, or Colors.blue, based on your UI
      }
    }


    print('ActiveOrdersList: Calculated order type counts: $currentTypeCounts');
    print('ActiveOrdersList: Calculated dominant colors: $dominantColorsForTypes');


    // Update the provider with both the numerical counts and the dominant colors
    orderCountsProvider.updateActiveOrdersCount(currentTypeCounts); // Update numerical counts
    orderCountsProvider.updateDominantOrderColors(dominantColorsForTypes); // NEW: Update dominant colors
  }

  // --- Unified Order Processing Logic ---
  void _processIncomingOrder(Order order) {
    final status = order.status.toLowerCase();
    final source = order.orderSource.toLowerCase();

    bool shouldDisplay = false;

    // Logic for Website Orders
    if (source == 'website') {
      shouldDisplay = (status == 'accepted' || status == 'green');
      if (!shouldDisplay) {
        print('ActiveOrdersList: Skipping website order ${order.orderId} (Source: $source, Status: $status) - not accepted.');
      }
    }
    // Logic for EPOS Orders (and any other non-website sources)
    else if (source == 'epos') {
      shouldDisplay = !['completed', 'delivered', 'declined', 'blue'].contains(status);
      if (!shouldDisplay) {
        print('ActiveOrdersList: Skipping EPOS order ${order.orderId} (Source: $source, Status: $status) - non-active EPOS status.');
      }
    }

    setState(() {
      if (shouldDisplay) {
        int existingIndex = _activeOrders.indexWhere((o) => o.orderId == order.orderId);
        if (existingIndex != -1) {
          _activeOrders[existingIndex] = order; // Update existing
          if (_selectedOrder != null && _selectedOrder!.orderId == order.orderId) {
            _selectedOrder = order; // Update selected order if it's the one
          }
          print('ActiveOrdersList: Order ${order.orderId} updated in active list (Source: $source, Status: ${order.status}).');
        } else {
          _activeOrders.add(order); // Add new active order
          print('ActiveOrdersList: Order ${order.orderId} added to active list (Source: $source, Status: ${order.status}).');
        }
        _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        // If not to be displayed, ensure it's removed from the active list if present
        bool wasSelectedOrder = (_selectedOrder != null && _selectedOrder!.orderId == order.orderId);

        _activeOrders.removeWhere((o) => o.orderId == order.orderId); // Perform removal

        if (wasSelectedOrder) {
          _selectedOrder = null; // Deselect if it was the current selected order
        }
        _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        print('ActiveOrdersList: Order ${order.orderId} removed from active list (Source: $source, Status: ${order.status}).');
      }
    });

    // Update order counts after any change
    _updateOrderCounts();
  }

  void _listenForNewOrdersFromSocket() {
    _newOrderSocketSubscription = OrderApiService().newOrderStream.listen((newOrder) {
      print('ActiveOrdersList: Received new order from socket: ${newOrder.orderId} (Source: ${newOrder.orderSource}), Status: ${newOrder.status}');
      _processIncomingOrder(newOrder);
    });
  }

  void _listenForAcceptedOrders() {
    _acceptedOrderStreamSubscription = OrderApiService().acceptedOrderStream.listen((acceptedOrder) {
      print('ActiveOrdersList: Received accepted order via stream: ${acceptedOrder.orderId}');
      _processIncomingOrder(acceptedOrder);
    });
  }

  Future<void> _fetchActiveOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _errorLoadingOrders = null;
    });
    try {
      final allOrders = await OrderApiService.fetchTodayOrders();
      print('ActiveOrdersList: Fetched ${allOrders.length} orders from backend for initial load.');

      final List<Order> initiallyActive = [];

      for (var order in allOrders) {
        final status = order.status.toLowerCase();
        final source = order.orderSource.toLowerCase();

        bool shouldDisplay = false;

        if (source == 'website') {
          shouldDisplay = (status == 'accepted' || status == 'green');
        } else if (source == 'epos') {
          shouldDisplay = !['completed', 'delivered', 'declined', 'blue'].contains(status);
        }

        if (shouldDisplay) {
          initiallyActive.add(order);
          print('ActiveOrdersList: Initially adding order ${order.orderId} to active list (Source: $source, Status: ${order.status}).');
        } else {
          print('ActiveOrdersList: Skipping initial display of order ${order.orderId} (Source: $source, Status: $status).');
        }
      }

      initiallyActive.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _activeOrders = initiallyActive;
        _isLoadingOrders = false;
        if (_selectedOrder != null && !_activeOrders.any((o) => o.orderId == _selectedOrder!.orderId)) {
          _selectedOrder = null;
        }
      });

      print('ActiveOrdersList: Displaying ${_activeOrders.length} active orders after initial fetch.');

      _updateOrderCounts(); // Update order counts after initial fetch
    } catch (e) {
      print('Error fetching active orders: $e');
      setState(() {
        _errorLoadingOrders = 'Failed to load active orders: $e';
        _isLoadingOrders = false;
      });
    }
  }

  void refreshOrders() {
    _fetchActiveOrders();
  }

  Widget _buildOrderSummaryContent(Order order) {
    final textStyle = const TextStyle(fontSize: 17, color: Colors.black, fontFamily: 'Poppins');

    if (order.orderSource.toLowerCase() == 'epos') {
      final itemNames = order.items.map((item) => ' ${item.itemName}').join(', ');
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          itemNames.isNotEmpty ? itemNames : 'No items',
          style: textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
        ),
      );

    } else if (order.orderSource.toLowerCase() == 'website') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          order.displayAddressSummary,
          style: textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
        ),
      );

    }
    return Center(
      child: Text(
        order.displaySummary,
        style: textStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getDisplayOrderType(Order order) {
    String source = order.orderSource.toLowerCase();
    String type = order.orderType.toLowerCase();

    if (source == 'website') {
      return 'Web ${type == 'delivery' ? 'Delivery' : 'Pickup'}';
    } else if (source == 'epos') {
      return 'EPOS ${type == 'delivery' ? 'Delivery' : type == 'dinein' ? 'Dine-In' : 'Take Away'}';
    }
    return '${source.toUpperCase()} ${type.toUpperCase()}';
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
    // ... (rest of the build method, remains unchanged)
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLoadingOrders != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorLoadingOrders!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchActiveOrders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedOrder != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                iconSize: 30,
                onPressed: () {
                  setState(() {
                    _selectedOrder = null;
                  });
                },
              ),
            ),

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

                  // Enhanced option extraction using the same method as desktop
                  Map<String, dynamic> itemOptions = _extractAllOptionsFromDescription(item.description);

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
                              ),
                            ],
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
      );
    } else if (_activeOrders.isEmpty) {
      return const Center(
        child: Text(
          'No active orders found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    } else {
      const double fixedBoxHeight = 50.0;

      return Column(
        children: [
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
            child: Row( // <-- Wrap both containers in a Row
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align to the start of the row
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3D9FF),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Active Orders',
                    textAlign: TextAlign.left, // textAlign usually matters for multi-line text, but good practice
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3D9FF), // You can choose a different color if you like
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Unpaid Orders', // <-- Your new text
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 25, // Consistent font size
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- ADD THE HORIZONTAL DIVIDER  ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(
              height: 0,
              thickness: 2.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: _activeOrders.length,
              itemBuilder: (context, index) {
                final order = _activeOrders[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOrder = order;
                      });
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric( vertical: 6, horizontal: 8),
                      elevation: 0,
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    height: fixedBoxHeight,
                                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
                                    decoration: BoxDecoration(
                                      color: HexColor.fromHex('FFF6D4'),
                                      borderRadius: BorderRadius.circular(35),
                                    ),
                                    child: _buildOrderSummaryContent(order),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: fixedBoxHeight,
                                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 6.0),
                                    decoration: BoxDecoration(
                                      color: HexColor.fromHex('FFF6D4'),
                                      borderRadius: BorderRadius.circular(35),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _getDisplayOrderType(order),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}