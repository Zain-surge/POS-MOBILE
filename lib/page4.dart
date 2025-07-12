// lib/page4.dart
import 'package:epos/website_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/food_item_details_model.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:math';

import 'package:epos/dynamic_order_list_screen.dart';

class Page4 extends StatefulWidget {
  final String? initialSelectedServiceImage;
  final List<FoodItem> foodItems;
  final String selectedOrderType; // <--- ADD THIS LINE

  const Page4({
    super.key,
    this.initialSelectedServiceImage,
    required this.foodItems,
    required this.selectedOrderType, // <--- ADD THIS LINE
  });

  @override
  State<Page4> createState() => _Page4State();
}

class _Page4State extends State<Page4> {
  int selectedCategory = 0;
  List<FoodItem> foodItems = [];
  bool isLoading = false;
  List<CartItem> _cartItems = [];

  late String selectedServiceImage;
  late String _actualOrderType; // <--- ADD THIS LINE: To store the order type for submission

  int _selectedBottomNavItem = 4;

  final List<Category> categories = [
    Category(name: 'PIZZA', image: 'assets/images/PizzasS.png'),
    Category(name: 'SHAWARMAS', image: 'assets/images/ShawarmaS.png'),
    Category(name: 'BURGERS', image: 'assets/images/BurgersS.png'),
    Category(name: 'CALZONES', image: 'assets/images/CalzonesS.png'),
    Category(name: 'GARLIC BREAD', image: 'assets/images/GarlicBreadS.png'),
    Category(name: 'WRAPS', image: 'assets/images/WrapsS.png'),
    Category(name: 'KIDS MEAL', image: 'assets/images/KidsMealS.png'),
    Category(name: 'SIDES', image: 'assets/images/SidesS.png'),
    Category(name: 'DRINKS', image: 'assets/images/DrinksS.png'),
  ];

  @override
  void initState() {
    super.initState();

    selectedServiceImage = widget.initialSelectedServiceImage ?? 'TakeAway.png';
    _actualOrderType = widget.selectedOrderType; // <--- INITIALIZE HERE

    // Instead of fetching, use the data passed from parent
    foodItems = widget.foodItems;

    print("📋 Page4 initialized with ${foodItems.length} food items. Selected Order Type: $_actualOrderType");

    final categoriesInData = foodItems.map((e) => e.category).toSet();
    print("📂 Categories in data: $categoriesInData");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No change needed here for initial selectedServiceImage.
    // However, if you want to update _actualOrderType if widget.selectedOrderType
    // changes during the lifetime of this widget (e.g., if you used pushReplacement
    // with different arguments on Page4 itself), you would put that logic here.
    // For now, it's fine as initialized in initState().
  }

  void fetchItems() async {
    try {
      final items = await ApiService.fetchMenuItems();
      print(" Items fetched: ${items.length}");

      final categoriesInData = items.map((e) => e.category).toSet();
      print(" Categories in data: $categoriesInData");

      setState(() {
        foodItems = items;
        isLoading = false;
      });
    } catch (e) {
      print(' Error fetching items: $e');
    }
  }

  void _addToCart(CartItem newItem) {
    setState(() {
      int existingIndex = _cartItems.indexWhere((item) {
        bool sameFoodItem = item.foodItem.id == newItem.foodItem.id;

        // Ensure selectedOptions comparison is robust, order-independent might be needed for complex cases
        bool sameOptions = (item.selectedOptions ?? []).join() ==
            (newItem.selectedOptions ?? []).join();
        bool sameComment = (item.comment ?? '') == (newItem.comment ?? '');

        return sameFoodItem && sameOptions && sameComment; // Include comment in comparison
      });

      if (existingIndex != -1) {
        _cartItems[existingIndex].incrementQuantity(newItem.quantity);
      } else {
        _cartItems.add(newItem);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newItem.foodItem.name} added to cart!')),
    );
  }

  double _calculateTotalPrice() {
    double total = 0.0;
    for (var item in _cartItems) {
      double itemPricePerUnit = item.foodItem.price.isNotEmpty
          ? (item.foodItem.price[item.foodItem.price.keys.first] ?? 0.0)
          : 0.0;
      total += itemPricePerUnit * item.quantity;
    }
    return total;
  }

  String generateTransactionId() {
    final random = Random();
    final int transactionNumber = 10000000 + random.nextInt(900000000);
    return transactionNumber.toString();
  }

  Future<void> _submitOrder() async {
    String id1 = generateTransactionId();
    print("Generated Transaction ID: $id1");

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            "Cart is empty. Please add items to place an order.")),
      );
      return;
    }

    final double subtotal = double.parse(_calculateTotalPrice().toStringAsFixed(2));
    const double vatRate = 0.05; // 5% VAT
    final double vatAmount = double.parse((subtotal * vatRate).toStringAsFixed(2));

    final double totalCharge = double.parse((subtotal + vatAmount).toStringAsFixed(2));

    final orderData = {
      "guest": {
        "name": "POS Customer - ${_actualOrderType.toUpperCase()}", // More descriptive
        "email": "pos_customer@example.com",
        "phone_number": "03001234567",
        "street_address": "POS ORDER",
        "city": "POS ORDER",
        "county": "POS ORDER",
        "postal_code": "POS ORDER"
      },
      "transaction_id": id1,
      "payment_type": "POS ORDER",
      "order_type": _actualOrderType, // <--- IMPORTANT: Use the dynamic order type here
      "total_price": totalCharge,
      "extra_notes": _cartItems.map((item) => item.comment ?? '').join(', ').trim(),
      "status": "pending", // Set initial status as 'pending' for EPOS orders
      "order_source": "epos", // Ensure this is 'epos' for correct filtering
      "items": _cartItems.map((cartItem) {
        String description = cartItem.foodItem.name;
        if (cartItem.selectedOptions != null && cartItem.selectedOptions!.isNotEmpty) {
          description += ' (${cartItem.selectedOptions!.join(', ')})';
        }

        // The API service or backend should correctly handle "comment" field
        // as a separate field, not necessarily merged into description for display.
        // If your API expects it merged into description for this specific endpoint,
        // then the current approach is fine, but generally, comments are separate.
        // For now, removing "Note" from description here if it's already a separate comment field.
        // If your backend specifically needs it in description, put it back.

        double itemPricePerUnit = cartItem.foodItem.price.isNotEmpty
            ? (cartItem.foodItem.price[cartItem.foodItem.price.keys.first] ?? 0.0)
            : 0.0;

        double itemTotalPrice = double.parse((itemPricePerUnit * cartItem.quantity).toStringAsFixed(2));

        return {
          "item_id": cartItem.foodItem.id,
          "quantity": cartItem.quantity,
          "description": description,
          "total_price": itemTotalPrice,
          "comment": cartItem.comment, // Send comment as a separate field
        };
      }).toList(),
    };

    print("Attempting to submit order with order_type: $_actualOrderType");
    try {
      final orderId = await ApiService.createOrderFromMap(orderData);
      if (orderId != null) {
        print('Order placed successfully: $orderId for type: $_actualOrderType');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order Placed Successfully")),
        );
        setState(() {
          _cartItems.clear(); // Clear cart on successful order
        });
        // Optionally, navigate back to Page3 or to the relevant order list screen
        // based on the _actualOrderType.
        // For example:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => DynamicOrderListScreen(
        //       orderType: _actualOrderType,
        //       initialBottomNavItemIndex: _getNavIndexForOrderType(_actualOrderType),
        //     ),
        //   ),
        // );

      } else {
        print('Order placement failed: orderId is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to place order.")),
        );
      }
    } catch (e) {
      print('Order submission failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error placing order: $e")),
      );
    }
  }

  // Helper to get bottom nav index for a given order type
  int _getNavIndexForOrderType(String type) {
    switch (type.toLowerCase()) {
      case 'takeaway': return 0;
      case 'dinein': return 1;
      case 'delivery': return 2;
      default: return 4; // Home or default if type is unknown
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  _buildCategoryTabs(),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    height: 5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB6CE6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(child: _buildItemGrid()),
                ],
              ),
            ),

            const VerticalDivider(
              width: 1,
              thickness: 0.5,
              color: Colors.black,
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(child: _buildCartSummary()),
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

  Widget _buildCartSummary() {
    double subtotal = _calculateTotalPrice();
    const double vatRate = 0.05;
    double vatAmount = subtotal * vatRate;
    double totalCharge = subtotal + vatAmount;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Pass the actual order type to _buildServiceHighlight
            _buildServiceHighlight('takeaway', 'TakeAway.png'),
            _buildServiceHighlight('dinein', 'DineIn.png'),
            _buildServiceHighlight('delivery', 'Delivery.png'),
          ],
        ),
        const SizedBox(height: 20),

        const Padding( // Removed unnecessary const from Divider
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: Divider(
            thickness: 1,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

        // SCROLLABLE CART ITEMS
        Expanded(
          child: _cartItems.isEmpty
              ? const Center(
            child: Text(
              'Cart is empty. Add items to see summary.',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 16, color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];

              // Extract size and crust from selectedOptions
              String? selectedSize;
              String? selectedCrust;

              if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
                for (var option in item.selectedOptions!) {
                  if (option.toLowerCase().contains('size')) {
                    selectedSize = option.split(':').last.trim();
                  } else if (option.toLowerCase().contains('crust')) {
                    selectedCrust = option.split(':').last.trim();
                  }
                }
              }

              // Determine the display string for size and crust
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

                          // LEFT: Qty + Size/Crust information
                          Expanded(
                            flex: 5,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity}', // Quantity
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
                                          crustDisplay, // Crust information
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

                          // Divider
                          Container(
                            width: 1.2,
                            height: 180,
                            color: Colors.black,
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                          ),

                          // RIGHT: Category Image + Item Name
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
                                    _getCategoryIcon(item.foodItem.category),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.foodItem.name,
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


                    // --- ADD THIS SECTION FOR THE COMMENT ---
                    if (item.comment != null && item.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF1C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Comment: ${item.comment!}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.normal,
                                color: Colors.black,
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    // --- END ADDED SECTION ---
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(thickness: 2, color: Color(0xFFCB6CE6)),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('£${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('VAT (5%)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('£${vatAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _submitOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Charge £${totalCharge.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Image.asset('assets/images/men.png', width: 45, height: 45),
          ],
        ),
      ],
    );
  }

  // Modified _buildServiceHighlight to take actual order type as argument
  Widget _buildServiceHighlight(String type, String imageName) {
    bool isSelected = _actualOrderType.toLowerCase() == type.toLowerCase();

    // Determine the display image (white or colored)
    String displayImage = isSelected && !imageName.contains('white.png')
        ? imageName.replaceAll('.png', 'white.png')
        : imageName;

    String baseImageNameForSizing = imageName.replaceAll('white.png', '.png');

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isSelected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/$displayImage',
          width: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
          height: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
          fit: BoxFit.contain,
          color: isSelected ? Colors.white : const Color(0xFF616161),
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 120),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search in items",
                hintStyle: const TextStyle(color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: 15),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(
                      color: Color(0xFFF2D9F9), width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double itemWidth = (constraints.maxWidth - 45) / 5;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = index;
                  });
                },
                child: Column(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: itemWidth,
                        height: itemWidth * 0.65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          category.image,
                          fit: BoxFit.contain,
                          color: const Color(0xFFCB6CE6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20,
                            vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF3D9FF) : Colors
                              .transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildItemGrid() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedCategoryName = categories[selectedCategory].name
        .toLowerCase();
    final filteredItems = foodItems
        .where((item) => item.category.toLowerCase() == selectedCategoryName)
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 50,
        crossAxisSpacing: 50,
        childAspectRatio: 1.7,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return FoodItemDetailsModal(
                  foodItem: item,
                  onAddToCart: _addToCart,
                );
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2D9F9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 40,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB6CE6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [

          _navItem('TakeAway.png', 0, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                const DynamicOrderListScreen(
                  orderType: 'takeaway',
                  initialBottomNavItemIndex: 0,
                ),
              ),
            );
          }),

          _navItem('DineIn.png', 1, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                const DynamicOrderListScreen(
                  orderType: 'dinein',
                  initialBottomNavItemIndex: 1,
                ),
              ),
            );
          }),

          _navItem('Delivery.png', 2, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                const DynamicOrderListScreen(
                  orderType: 'delivery',
                  initialBottomNavItemIndex: 2,
                ),
              ),
            );
          }),

          _navItem('web.png', 3, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WebsiteOrdersScreen(initialBottomNavItemIndex: 3)));
          }),

          _navItem('home.png', 4, onTap: () {
            Navigator.pop(context);
          }),

          _navItem('More.png', 5, onTap: () {
            print("More button tapped, implement its navigation.");
            // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => const MoreOptionsScreen()));
          }),
        ],
      ),
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
      } else if (image == 'home.png') {
        displayImage =
        'home.png'; // home.png doesn't have a white version in your assets based on the previous context
      } else if (image.contains('.png')) {
        // Fallback for other icons if they have a 'white' version
        displayImage = image.replaceAll('.png', 'white.png');
      }
    } else {
      // Logic for unselected state - revert to original if it was 'white'
      if (image == 'TakeAwaywhite.png') {
        displayImage = 'TakeAway.png';
      } else if (image == 'DineInwhite.png') {
        displayImage = 'DineIn.png';
      } else if (image == 'Deliverywhite.png') {
        displayImage = 'Delivery.png';
      } else if (image.contains('white.png')) { // General case for other icons
        displayImage = image.replaceAll('white.png', '.png');
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          print("Nav item at index $index tapped from Page4.");
          setState(() {
            _selectedBottomNavItem = index;
          });
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
              if (notification != null && notification!.isNotEmpty)
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
                      notification!,
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


class Category {
  final String name;
  final String image;

  Category({required this.name, required this.image});
}