// lib/page4.dart

import 'package:epos/website_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/food_item_details_model.dart';
import 'package:epos/models/cart_item.dart'; // Corrected import path for cart_item
import 'dart:math';
import 'dart:ui'; // Add this import for BackdropFilter
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:flutter/scheduler.dart'; // Import for SchedulerBinding
import 'package:epos/services/thermal_printer_service.dart';

class Page4 extends StatefulWidget {
  final String? initialSelectedServiceImage;
  final List<FoodItem> foodItems;
  final String selectedOrderType;

  const Page4({
    super.key,
    this.initialSelectedServiceImage,
    required this.foodItems,
    required this.selectedOrderType,
  });

  @override
  State<Page4> createState() => _Page4State();
}

class _Page4State extends State<Page4> {
  int selectedCategory = 0;
  List<FoodItem> foodItems = [];
  bool isLoading = false;
  List<CartItem> _cartItems = [];
  bool _isModalOpen = false; // State variable to track modal visibility
  FoodItem? _modalFoodItem; // Store the food item to be displayed in the modal

  late String selectedServiceImage;
  late String _actualOrderType;

  int _selectedBottomNavItem = 4;

  final GlobalKey _leftPanelKey = GlobalKey(); // GlobalKey for the left panel
  Rect _leftPanelRect = Rect.zero; // Rect to store dimensions

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
    _actualOrderType = widget.selectedOrderType;

    foodItems = widget.foodItems;

    debugPrint("📋 Page4 initialized with ${foodItems.length} food items. Selected Order Type: $_actualOrderType");

    final categoriesInData = foodItems.map((e) => e.category).toSet();
    debugPrint("📂 Categories in data: $categoriesInData");

    // Schedule a post-frame callback to get the left panel's dimensions
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });
  }

  // Method to get the dimensions and position of the left panel
  void _getLeftPanelDimensions() {
    final RenderBox? renderBox = _leftPanelKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final Offset offset = renderBox.localToGlobal(Offset.zero); // Get global position
      setState(() {
        _leftPanelRect = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      });
      debugPrint('Left Panel Rect for Modal Positioning: $_leftPanelRect'); // For debugging
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void fetchItems() async {
    try {
      final items = await ApiService.fetchMenuItems();
      debugPrint(" Items fetched: ${items.length}");

      final categoriesInData = items.map((e) => e.category).toSet();
      debugPrint(" 📂 Categories in data: $categoriesInData");

      setState(() {
        foodItems = items;
        isLoading = false;
      });
    } catch (e) {
      debugPrint(' Error fetching items: $e');
    }
  }

  void _addToCart(CartItem newItem) {
    setState(() {
      int existingIndex = _cartItems.indexWhere((item) {
        bool sameFoodItem = item.foodItem.id == newItem.foodItem.id;
        bool sameOptions = (item.selectedOptions ?? []).join() ==
            (newItem.selectedOptions ?? []).join();
        bool sameComment = (item.comment ?? '') == (newItem.comment ?? '');

        return sameFoodItem && sameOptions && sameComment;
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
      // Use the calculated pricePerUnit from the CartItem itself
      total += item.pricePerUnit * item.quantity;
    }
    return total;
  }

  String generateTransactionId() {
    const uuid = Uuid(); // Use Uuid for better uniqueness
    return uuid.v4(); // Generate a UUID v4 string
  }

  Future<void> _submitOrder() async {
    // Check if cart is empty first
    if (_cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cart is empty. Please add items to place an order."),
          ),
        );
      }
      return;
    }

    String id1 = generateTransactionId();
    print("Generated Transaction ID: $id1");

    final double subtotal = double.parse(
      _calculateTotalPrice().toStringAsFixed(2),
    );
    const double vatRate = 0.05; // 5% VAT
    final double vatAmount = double.parse(
      (subtotal * vatRate).toStringAsFixed(2),
    );
    final double totalCharge = double.parse(
      (subtotal + vatAmount).toStringAsFixed(2),
    );

    final orderData = {
      "guest": {
        "name": "POS Customer - ${_actualOrderType.toUpperCase()}",
        "email": "pos_customer@example.com",
        "phone_number": "03001234567",
        "street_address": "POS ORDER",
        "city": "POS ORDER",
        "county": "POS ORDER",
        "postal_code": "POS ORDER",
      },
      "transaction_id": id1,
      "payment_type": "POS ORDER",
      "order_type": _actualOrderType,
      "total_price": totalCharge,
      "extra_notes":
      _cartItems.map((item) => item.comment ?? '').join(', ').trim(),
      "status": "pending",
      "order_source": "epos",
      "items":
      _cartItems.map((cartItem) {
        String description = cartItem.foodItem.name;
        if (cartItem.selectedOptions != null &&
            cartItem.selectedOptions!.isNotEmpty) {
          description += ' (${cartItem.selectedOptions!.join(', ')})';
        }

        double itemPricePerUnit =
        cartItem.foodItem.price.isNotEmpty
            ? (cartItem.foodItem.price[cartItem
            .foodItem
            .price
            .keys
            .first] ??
            0.0)
            : 0.0;

        double itemTotalPrice = double.parse(
          (itemPricePerUnit * cartItem.quantity).toStringAsFixed(2),
        );

        return {
          "item_id": cartItem.foodItem.id,
          "quantity": cartItem.quantity,
          "description": description,
          "total_price": itemTotalPrice,
          "comment": cartItem.comment,
        };
      }).toList(),
    };

    print("Attempting to submit order with order_type: $_actualOrderType");

    // Show receipt preview dialog
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Receipt Preview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                // Order details preview
                Container(
                  height: 300,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transaction ID: $id1', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Order Type: ${_actualOrderType.toUpperCase()}'),
                        Text('Payment: POS ORDER'),
                        const Divider(),

                        const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ..._cartItems.map((item) {
                          double itemPricePerUnit = item.foodItem.price.isNotEmpty
                              ? (item.foodItem.price[item.foodItem.price.keys.first] ?? 0.0)
                              : 0.0;
                          double itemTotalPrice = itemPricePerUnit * item.quantity;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.quantity}x ${item.foodItem.name} (£${itemTotalPrice.toStringAsFixed(2)})'),
                                if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty)
                                  Text('  Options: ${item.selectedOptions!.join(', ')}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                if (item.comment != null && item.comment!.isNotEmpty)
                                  Text('  Comment: ${item.comment}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          );
                        }),

                        const Divider(),
                        Text('Subtotal: £${subtotal.toStringAsFixed(2)}'),
                        Text('VAT (5%): £${vatAmount.toStringAsFixed(2)}'),
                        Text('Total: £${totalCharge.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        try {
                          Navigator.of(dialogContext).pop();
                        } catch (e) {
                          print('Error closing dialog: $e');
                        }
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Close preview dialog first
                        try {
                          Navigator.of(dialogContext).pop();
                        } catch (e) {
                          print('Error closing preview dialog: $e');
                        }

                        // Check if widget is still mounted before proceeding
                        if (!mounted) return;

                        // Show loading indicator
                        try {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(child: CircularProgressIndicator());
                            },
                          );
                        } catch (e) {
                          print('Error showing loading dialog: $e');
                          if (!mounted) return;
                        }

                        try {
                          // First test printer connections
                          final printerService = ThermalPrinterService();
                          final connectionResults = await printerService.testAllConnections();

                          // If no printers available, show selection dialog
                          if (!connectionResults['usb']! &&
                              !connectionResults['bluetooth']! &&
                              !connectionResults['thermal']!) {
                            if (!mounted) return;
                            Navigator.of(context).pop(); // Close loading dialog

                            // Show printer selection dialog
                            final printerType = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Select Printer Type'),
                                content: Text('No printers are currently connected. Please select a printer type to connect to:'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, 'bluetooth'),
                                    child: Text('Bluetooth Printer'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, 'usb'),
                                    child: Text('USB Printer'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, 'cancel'),
                                    child: Text('Cancel'),
                                  ),
                                ],
                              ),
                            );

                            if (printerType == null || printerType == 'cancel') {
                              return;
                            }

                            // Show loading again while connecting
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return const Center(child: CircularProgressIndicator());
                              },
                            );
                          }

                          // Submit the order regardless of printer status
                          final orderId = await ApiService.createOrderFromMap(orderData);

                          // Check if widget is still mounted before using context
                          if (!mounted) return;

                          // Hide loading indicator
                          try {
                            Navigator.of(context).pop();
                          } catch (e) {
                            print('Error hiding loading dialog: $e');
                          }

                          print('Order placed successfully: $orderId for type: $_actualOrderType');

                          // Show success message
                          if (mounted) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Order Placed Successfully! Printing receipt..."),
                                ),
                              );
                            } catch (e) {
                              print('Error showing success message: $e');
                            }
                          }

                          // Print receipt
                          bool printSuccess = await ThermalPrinterService().printReceipt(
                            transactionId: id1,
                            orderType: _actualOrderType,
                            cartItems: _cartItems,
                            subtotal: subtotal,
                            vatAmount: vatAmount,
                            totalCharge: totalCharge,
                            extraNotes:
                            _cartItems.map((item) => item.comment ?? '').join(', ').trim(),
                          );

                          if (mounted) {
                            try {
                              if (printSuccess) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Receipt printed successfully!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Order placed but printing failed. Please check printer connection.",
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            } catch (e) {
                              print('Error showing print status message: $e');
                            }
                          }

                          // Clear cart on successful order
                          if (mounted) {
                            setState(() {
                              _cartItems.clear();
                            });
                          }
                        } catch (e) {
                          // Check if widget is still mounted before using context
                          if (!mounted) return;

                          // Hide loading indicator
                          try {
                            Navigator.of(context).pop();
                          } catch (navError) {
                            print('Error hiding loading dialog after error: $navError');
                          }

                          print('Order submission failed: $e');
                          if (mounted) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error placing order: $e"))
                              );
                            } catch (snackbarError) {
                              print('Error showing error message: $snackbarError');
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm & Print'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

//final double subtotal = double.parse(_calculateTotalPrice().toStringAsFixed(2));
 //double itemTotalPrice = double.parse((cartItem.pricePerUnit * cartItem.quantity).toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    // These calculations are for the MODAL's positioning.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Define the height of your bottom navigation bar. Adjust if yours is different.
    const double bottomNavBarHeight = 80.0; // Assuming a fixed height of 80 for the nav bar

    // Calculate available vertical space for the modal (screen height minus nav bar height)
    final double availableModalHeight = screenHeight - bottomNavBarHeight;

    // Calculate modal dimensions
    final double modalDesiredWidth = min(screenWidth * 0.5, 800.0);
    final double modalActualWidth = min(modalDesiredWidth, screenWidth * 0.9); // Max 90% of screen width

    // IMPORTANT CHANGE HERE: Constrain modal height to available space above navbar
    final double modalDesiredHeight = min(availableModalHeight * 0.9, 900.0); // Max 90% of AVAILABLE height
    double modalActualHeight = min(modalDesiredHeight, availableModalHeight * 0.9);


    // Calculate modal offsets relative to the left panel's global position.
    // The modal will be centered within the left panel's bounds.
    final double modalLeftOffset = _leftPanelRect.left + (_leftPanelRect.width - modalActualWidth) / 2;

    // Use a temporary variable for mutable top offset
    double modalTopOffset = _leftPanelRect.top + (_leftPanelRect.height - modalActualHeight) / 2;

    // Add a check to prevent negative top offset or pushing it too far down
    // Ensure modal doesn't go below the calculated available height.
    final double calculatedBottomEdge = modalTopOffset + modalActualHeight;
    if (calculatedBottomEdge > availableModalHeight) {
      // If it would go off-screen, adjust top to fit
      modalTopOffset = availableModalHeight - modalActualHeight;
      // Also ensure it doesn't go above the top of the left panel if this adjustment happens
      if (modalTopOffset < _leftPanelRect.top) {
        modalTopOffset = _leftPanelRect.top;
      }
    }
    // Also ensure it doesn't go off the top of the screen (or left panel's start)
    if (modalTopOffset < 0) {
      modalTopOffset = 0; // Set to 0 to prevent it from going off top of screen
    }


    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack( // Main Stack for both panels and the modal overlay
              children: [
                SafeArea( // Apply SafeArea to the main content Row
                  child: Row(
                    children: [
                      Expanded( // Left Panel
                        key: _leftPanelKey, // GlobalKey here
                        flex: 2,
                        child: Stack( // Internal Stack for Left Panel's content and its blur
                          children: [
                            // Left Panel Content (Column for search, categories, grid)
                            Column(
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
                            // Blur overlay for LEFT PANEL ONLY
                            if (_isModalOpen)
                              Positioned.fill( // Fills the entire parent Stack (i.e., the left panel)
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: Colors.black,
                      ),
                      Expanded( // Right Panel (will not be blurred)
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
                // FoodItemDetailsModal (NOW HERE in the main Stack, positioned globally)
                if (_isModalOpen && _modalFoodItem != null && _leftPanelRect != Rect.zero)
                  Positioned(
                    left: modalLeftOffset, // Position calculated to be over left panel
                    top: modalTopOffset,   // Position calculated to be over left panel
                    width: modalActualWidth,
                    height: modalActualHeight,
                    child: FoodItemDetailsModal(
                      foodItem: _modalFoodItem!,
                      onAddToCart: (item) {
                        _addToCart(item);
                        setState(() {
                          _isModalOpen = false; // Close modal after adding to cart
                          _modalFoodItem = null;
                        });
                      },
                      onClose: () { // Callback from modal to close itself
                        setState(() {
                          _isModalOpen = false;
                          _modalFoodItem = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          _buildBottomNavBar(), // Bottom Navigation Bar is outside the main Stack
        ],
      ),
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
    // const double vatRate = 0.05;
    // double vatAmount = subtotal * vatRate;
    // double totalCharge = subtotal + vatAmount;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildServiceHighlight('takeaway', 'TakeAway.png'),
            _buildServiceHighlight('dinein', 'DineIn.png'),
            _buildServiceHighlight('delivery', 'Delivery.png'),
          ],
        ),
        const SizedBox(height: 20),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: Divider(
            thickness: 1,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

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

              String? selectedSize;
              String? selectedCrust;

              // Null-safe access to selectedOptions
              if (item.selectedOptions?.isNotEmpty ?? false) {
                for (var option in item.selectedOptions!) {
                  if (option.toLowerCase().contains('size')) {
                    selectedSize = option.split(':').last.trim();
                  } else if (option.toLowerCase().contains('crust')) {
                    selectedCrust = option.split(':').last.trim();
                  }
                }
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
          // children: [
          //   const Text('VAT (5%)',
          //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          //   Text('£${vatAmount.toStringAsFixed(2)}',
          //       style: const TextStyle(fontSize: 16)),
          // ],
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
                      'Charge £${ subtotal.toStringAsFixed(2)}',
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

  Widget _buildServiceHighlight(String type, String imageName) {
    bool isSelected = _actualOrderType.toLowerCase() == type.toLowerCase();

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
            setState(() {
              _isModalOpen = true; // Open the modal
              _modalFoodItem = item; // Set the item to display in the modal
            });
            // Re-calculate the left panel dimensions just before opening modal
            // to ensure they are up-to-date, especially if layout changes.
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _getLeftPanelDimensions();
            });
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
      height: 80, // Explicitly set height here (matches constant)
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
            debugPrint("More button tapped, implement its navigation.");
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
        // Fallback for other icons if they have a 'white' version
        displayImage = image.replaceAll('.png', 'white.png');
      }
    } else {
      // Logic for unselected state - revert to original if it was 'white'
      // Ensure we only try to replace 'white.png' if it's actually in the string
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