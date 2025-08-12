// lib/active_orders_list.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/active_orders_provider.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class ActiveOrdersList extends StatefulWidget {
  const ActiveOrdersList({
    super.key,
  });

  @override
  State<ActiveOrdersList> createState() => _ActiveOrdersListState();
}

class _ActiveOrdersListState extends State<ActiveOrdersList> {
  Order? _selectedOrder;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void refreshOrders() {
    Provider.of<ActiveOrdersProvider>(context, listen: false).refreshOrders();
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
      if (type == 'delivery') {
        return 'EPOS Delivery';
      } else if (type == 'dinein') {
        return 'EPOS Dine-In';
      } else if (type == 'takeout') {
        return 'EPOS Takeout';
      } else {
        return 'EPOS Collection'; // fallback for other cases
      }
    }
    return '${source.toUpperCase()} ${type.toUpperCase()}';
  }

  // UPDATED METHOD WITH DEFAULT VALUE FILTERING (same as website screen)
  Map<String, dynamic> _extractAllOptionsFromDescription(
      String description, {
        List<String>? defaultFoodItemToppings,
        List<String>? defaultFoodItemCheese,
      }) {
    Map<String, dynamic> options = {
      'size': null,
      'crust': null,
      'base': null,
      'drink': null, // NEW: Add drink support
      'isMeal': false, // NEW: Add meal detection
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

      // NEW: Check for meal option
      if (lowerOption.contains('make it a meal') || lowerOption.contains('meal')) {
        options['isMeal'] = true;
        anyNonDefaultOptionFound = true;
      }
      // NEW: Extract drink information
      else if (lowerOption.startsWith('drink:')) {
        String drinkValue = option.substring('drink:'.length).trim();
        if (drinkValue.isNotEmpty) {
          options['drink'] = drinkValue;
          anyNonDefaultOptionFound = true;
        }
      }
      else if (lowerOption.startsWith('size:')) {
        String sizeValue = option.substring('size:'.length).trim();
        // FILTER: Only show if not default
        if (sizeValue.isNotEmpty && sizeValue.toLowerCase() != 'default') {
          options['size'] = sizeValue;
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption.startsWith('crust:')) {
        String crustValue = option.substring('crust:'.length).trim();
        // FILTER: Only show if not normal
        if (crustValue.isNotEmpty && crustValue.toLowerCase() != 'normal') {
          options['crust'] = crustValue;
          anyNonDefaultOptionFound = true;
        }
      } else if (lowerOption.startsWith('base:')) {
        String baseValue = option.substring('base:'.length).trim();
        // FILTER: Only show if not tomato (example default base)
        if (baseValue.isNotEmpty && baseValue.toLowerCase() != 'tomato') {
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

          // --- FILTER: Against FoodItem's default toppings/cheese ---
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
    final activeOrdersProvider = Provider.of<ActiveOrdersProvider>(context);
    final List<Order> activeOrders = activeOrdersProvider.activeOrders;
    final bool isLoadingOrders = activeOrdersProvider.isLoading;
    final String? errorLoadingOrders = activeOrdersProvider.error;

    if (_selectedOrder != null && !activeOrders.any((o) => o.orderId == _selectedOrder!.orderId)) {
      _selectedOrder = null;
    }

    if (isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorLoadingOrders != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorLoadingOrders, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => activeOrdersProvider.refreshOrders(),
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
                icon: Image.asset(
                  'assets/images/bArrow.png',
                  width: 30,
                  height: 30,
                ),
                onPressed: () {
                  setState(() {
                    _selectedOrder = null;
                  });
                },
              ),
            ),

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

                  // UPDATED: Pass default toppings and cheese for filtering
                  Map<String, dynamic> itemOptions = _extractAllOptionsFromDescription(
                    item.description,
                    defaultFoodItemToppings: item.foodItem?.defaultToppings,
                    defaultFoodItemCheese: item.foodItem?.defaultCheese,
                  );

                  String? selectedSize = itemOptions['size'];
                  String? selectedCrust = itemOptions['crust'];
                  String? selectedBase = itemOptions['base'];
                  String? selectedDrink = itemOptions['drink']; // NEW: Add drink extraction
                  bool isMeal = itemOptions['isMeal'] ?? false; // NEW: Add meal detection
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // If no options found, display the description as simple text
                                            if (!hasOptions)
                                              Text(
                                                item.description,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontFamily: 'Poppins',
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.normal,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                            // If options exist, display them individually (ONLY NON-DEFAULT ONES)
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
                                              // Display Toppings (only if not empty after filtering)
                                              if (toppings.isNotEmpty)
                                                Text(
                                                  'Extra Toppings: ${toppings.join(', ')}',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: 'Poppings',
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

                                              // Display meal information - NEW ADDITION
                                              if (isMeal && selectedDrink != null) ...[
                                                const Text(
                                                  'MEAL',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: 'Poppins',
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Drink: $selectedDrink',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: 'Poppins',
                                                    color: Colors.black,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
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

                        // Comment section moved outside the main row
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
                        '£ ${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
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
    } else if (activeOrders.isEmpty) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3D9FF),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Active Orders',
                    textAlign: TextAlign.left,
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
                    color: const Color(0xFFF3D9FF),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Unpaid Orders',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),

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
              itemCount: activeOrders.length,
              itemBuilder: (context, index) {
                final order = activeOrders[index];
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