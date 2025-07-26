// lib/page4.dart
import 'package:epos/website_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/food_item_details_model.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:math';
import 'dart:ui';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:flutter/scheduler.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/customer_details_widget.dart';
import 'package:epos/payment_details_widget.dart';
import 'package:epos/settings_screen.dart';
import 'package:epos/models/order_models.dart';
import 'package:provider/provider.dart';
import 'package:epos/order_counts_provider.dart';

class Page4 extends StatefulWidget {
  final String? initialSelectedServiceImage;
  final List<FoodItem> foodItems;
  final String selectedOrderType;

  const Page4({
    super.key,
    this.initialSelectedServiceImage,
    required this.foodItems,
    required this.selectedOrderType,
    // REMOVED: required this.activeOrdersCount,
  });

  @override
  State<Page4> createState() => _Page4State();
}

class _Page4State extends State<Page4> {
  int selectedCategory = 0;
  List<FoodItem> foodItems = [];
  String _takeawaySubType = 'takeaway';
  bool isLoading = false;
  final List<CartItem> _cartItems = [];
  bool _isModalOpen = false;
  FoodItem? _modalFoodItem;
  String _searchQuery = '';
  bool _hasProcessedFirstStep = false;
  String _selectedPaymentType = 'cash';
  late String selectedServiceImage;
  late String _actualOrderType;

  int _selectedBottomNavItem = 4; // This will determine the highlighted nav item
  bool _showPayment = false;
  CustomerDetails? _customerDetails;

  final GlobalKey _leftPanelKey = GlobalKey(); // GlobalKey for the left panel
  Rect _leftPanelRect = Rect.zero; // Rect to store dimensions

  // --- NEW STATE VARIABLE FOR EDIT MODE ---
  bool _isEditMode = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  final ScrollController _categoryScrollController = ScrollController();

  // Function to scroll the category list left
  void _scrollCategoriesLeft() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset - 200, // Scroll by 200 pixels (adjust as needed)
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Function to scroll the category list right
  void _scrollCategoriesRight() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset + 200, // Scroll by 200 pixels (adjust as needed)
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }



  final List<Category> categories = [
    Category(name: 'PIZZA', image: 'assets/images/PizzasS.png'),
    //Category(name: 'SHAWARMAS', image: 'assets/images/ShawarmaS.png'),
    Category(name: 'BURGERS', image: 'assets/images/BurgersS.png'),
    // Category(name: 'CALZONES', image: 'assets/images/CalzonesS.png'),
    Category(name: 'GARLIC BREAD', image: 'assets/images/GarlicBreadS.png'),
    Category(name: 'WRAPS', image: 'assets/images/WrapsS.png'),
    Category(name: 'KIDS MEAL', image: 'assets/images/KidsMealS.png'),
    Category(name: 'SIDES', image: 'assets/images/SidesS.png'),
    Category(name: 'MILKSHAKE', image: 'assets/images/MilkshakeS.png'),
    Category(name: 'DRINKS', image: 'assets/images/DrinksS.png'),
    Category(name: 'DIPS', image: 'assets/images/DipsS.png'),
    Category(name: 'CHICKEN', image: 'assets/images/Chicken.png'),
    Category(name: 'DESSERTS', image: 'assets/images/Desserts.png'),
    Category(name: 'KEBABS', image: 'assets/images/Kebabs.png'),
    Category(name: 'WINGS', image: 'assets/images/Wings.png'),
  ];

  int _getBottomNavItemIndexForOrderType(String orderType) {
    switch(orderType.toLowerCase()) {
      case 'takeaway':
      case 'collection': // Both takeaway and collection map to index 0
        return 0;
      case 'dinein':
        return 1;
      case 'delivery':
        return 2;
      case 'website':
        return 3;
      default:
        return 4; // Default to 'home' or a neutral state
    }
  }

  // Method to get order count for each nav item (NOW uses provider's activeOrdersCount)
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
  void initState() {
    super.initState();

    selectedServiceImage = widget.initialSelectedServiceImage ?? 'TakeAway.png';
    _actualOrderType = widget.selectedOrderType;

    // Initialize takeaway sub-type based on the selected order type
    if (_actualOrderType.toLowerCase() == 'collection') {
      _takeawaySubType = 'collection';
    } else if (_actualOrderType.toLowerCase() == 'takeaway') {
      _takeawaySubType = 'takeaway';
    }

    _selectedBottomNavItem = _getBottomNavItemIndexForOrderType(_actualOrderType);

    foodItems = widget.foodItems;

    debugPrint("📋 Page4 initialized with ${foodItems.length} food items. Selected Order Type: $_actualOrderType");

    final categoriesInData = foodItems.map((e) => e.category).toSet();
    debugPrint("📂 Categories in data: $categoriesInData");

    // Schedule a post-frame callback to get the left panel's dimensions
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });

    _categoryScrollController.addListener(_updateScrollButtonVisibility);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtonVisibility();
    });
  }


  void _showErrorSnackBar(String message) {
    if (!mounted) return; // Important: Check if the widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, // Often used for error messages
        duration: const Duration(seconds: 3), // Optional: how long it shows
      ),
    );
  }

  // Method to get the dimensions and position of the left panel
  void _getLeftPanelDimensions() {
    final RenderBox? renderBox = _leftPanelKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final Offset offset = renderBox.localToGlobal(Offset.zero);
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

  @override
  void dispose() {
    _categoryScrollController.removeListener(_updateScrollButtonVisibility);
    _categoryScrollController.dispose(); // Don't forget to dispose controllers
    super.dispose();
  }

  void _updateScrollButtonVisibility() {
    setState(() {
      _canScrollLeft = _categoryScrollController.offset > _categoryScrollController.position.minScrollExtent;
      _canScrollRight = _categoryScrollController.offset < _categoryScrollController.position.maxScrollExtent;
    });
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
      if(mounted) {
        _showErrorSnackBar('Failed to load menu items: $e');
      }
    }
  }

  void _addToCart(CartItem newItem) {
    // Check if customer details are required but not provided
    bool requiresCustomerDetails = (_actualOrderType.toLowerCase() == 'delivery' ||
        _actualOrderType.toLowerCase() == 'takeaway' ||
        _actualOrderType.toLowerCase() == 'collection');

    if (requiresCustomerDetails && _customerDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter customer details first before adding items to cart.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return; // Exit without adding to cart
    }

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
      total += item.pricePerUnit * item.quantity;
    }
    return total;
  }

  String generateTransactionId() {
    const uuid = Uuid();
    return uuid.v4(); // Generate a UUID v4 string
  }

// --- MODIFIED _toggleItemAvailability (FINAL CLARIFICATION WITH CONSISTENCY) ---
  Future<void> _toggleItemAvailability(FoodItem item) async {

    final currentAvailability = item.availability;
    final optimisticAvailability = !currentAvailability;

    final originalItemState = item;

    setState(() {
      final itemIndex = foodItems.indexWhere((i) => i.id == item.id);
      if (itemIndex != -1) {
        foodItems[itemIndex] = item.copyWith(availability: optimisticAvailability);
      }
    });

    try {
      final updatedItemFromApi = await ApiService.setItemAvailability(
        item.id,
        optimisticAvailability, // Send the new availability state
      );

      setState(() {
        final itemIndex = foodItems.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          foodItems[itemIndex] = originalItemState.copyWith(
            availability: updatedItemFromApi.availability, // Use the confirmed availability from backend
          );
        }
      });

      //_showErrorSnackBar('${item.name} availability successfully set to ${updatedItemFromApi.availability ? "Available" : "Unavailable"}.');

    } catch (e) {
      setState(() {
        final itemIndex = foodItems.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          foodItems[itemIndex] = originalItemState; // Revert to original state
        }
      });
      //_showErrorSnackBar('Failed to update ${item.name} availability: $e');
      debugPrint('Error toggling item availability for ${item.name}: $e');
      if(mounted) {
        _showErrorSnackBar('Failed to update ${item.name} availability.');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Consume the OrderCountsProvider here
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final activeOrdersCount = orderCountsProvider.activeOrdersCount; // Get the live counts from the provider

    // These calculations are for the MODAL's positioning.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Define the height of your bottom navigation bar. Adjust if yours is different.
    const double bottomNavBarHeight = 80.0; // Assuming a fixed height of 80 for the nav bar

    // Calculate available vertical space for the modal (screen height minus nav bar height)
    final double availableModalHeight = screenHeight - bottomNavBarHeight;

    // Calculate modal dimensions
    final double modalDesiredWidth = min(screenWidth * 0.6, 1200.0);
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
                                _buildSearchBar(),
                                _buildCategoryTabs(),

                                const SizedBox(height: 20),

                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 40),
                                  height: 7,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF2D9F9),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: const VerticalDivider(
                          width: 2.5,
                          thickness: 2.5,
                          color: Color(0xFFB2B2B2),
                        ),
                      ),

                      Expanded( // Right Panel (will not be blurred)
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Expanded(child:  _buildRightPanelContent()),
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

          _buildBottomNavBar(activeOrdersCount),
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



  // Updated _buildCartSummary method with MouseRegion for hand cursor

  Widget _buildCartSummary() {
    double subtotal = _calculateTotalPrice();

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
        // --- ADD THE HORIZONTAL DIVIDER  ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60.0),
          child: Divider(
            height: 0,
            thickness: 3,
            color: const Color(0xFFB2B2B2),
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: _cartItems.isEmpty
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_customerDetails != null && (_actualOrderType.toLowerCase() == 'delivery' || _actualOrderType.toLowerCase() == 'takeaway'))
                const SizedBox(height: 16),
              const Text(
                'Cart is empty. Add items to see summary.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Color(0xFFB2B2B2),
                ),
              ),
            ],
          )
              : ListView.builder(
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];

              // UPDATED: Extract all options using the same logic
              String? selectedSize;
              String? selectedCrust;
              String? selectedBase;
              List<String> toppings = [];
              List<String> sauceDips = [];
              bool hasOptions = false;

              // Enhanced option extraction from selectedOptions
              if (item.selectedOptions?.isNotEmpty ?? false) {
                hasOptions = true;
                for (var option in item.selectedOptions!) {
                  String lowerOption = option.toLowerCase();

                  if (lowerOption.contains('size:')) {
                    selectedSize = option.split(':').last.trim();
                  } else if (lowerOption.contains('crust:')) {
                    selectedCrust = option.split(':').last.trim();
                  } else if (lowerOption.contains('base:')) {
                    selectedBase = option.split(':').last.trim();
                  } else if (lowerOption.contains('toppings:') || lowerOption.contains('extra toppings:')) {
                    String toppingsValue = option.split(':').last.trim();
                    if (toppingsValue.isNotEmpty) {
                      List<String> toppingsList = toppingsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                      toppings.addAll(toppingsList);
                    }
                  } else if (lowerOption.contains('sauce dips:')) {
                    String dipsValue = option.split(':').last.trim();
                    if (dipsValue.isNotEmpty) {
                      List<String> dipsList = dipsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                      sauceDips.addAll(dipsList);
                    }
                  }
                }
              }

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quantity and Options section
                                Row(
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
                                            // If no options, show simple text or item name
                                            if (!hasOptions)
                                              Text(
                                                item.foodItem.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontFamily: 'Poppins',
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                            // If options exist, display them individually
                                            if (hasOptions) ...[
                                              // Display Size
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
                                              // Display Crust
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
                                              // Display Base
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
                                              // Display Toppings
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
                                              // Display Sauce Dips
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

                                const SizedBox(height: 40),

                                // Quantity controls row (below options) with MouseRegion
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 50),

                                    // Delete button with hand cursor
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _cartItems.removeAt(index);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${item.foodItem.name} removed from cart!'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: SizedBox(
                                          width: 35,
                                          height: 35,
                                          child: Image.asset(
                                            'assets/images/Bin.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Decrement button with hand cursor
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (item.quantity > 1) {
                                              item.decrementQuantity();
                                            }
                                          });
                                        },
                                        child: SizedBox(
                                          width: 35,
                                          height: 35,
                                          child: const Icon(
                                            Icons.remove,
                                            color: Colors.black,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Increment button with hand cursor
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            item.incrementQuantity();
                                          });
                                        },
                                        child: SizedBox(
                                          width: 35,
                                          height: 35,
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.black,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1.2,
                            height: 130,
                            color: const Color(0xFFB2B2B2),
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                          ),

                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 110,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.asset(
                                    _getCategoryIcon(item.foodItem.category),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.foodItem.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Price display
                                Text(
                                  '£${(item.pricePerUnit * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFCB6CE6),
                                  ),
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

        // --- ADD THE HORIZONTAL DIVIDER  ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60.0),
          child: Divider(
            height: 0,
            color: const Color(0xFFB2B2B2),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('£${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Cash Button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPaymentType = 'cash';
                  });
                  _proceedToNextStep();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedPaymentType == 'cash' ? Colors.black : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: _selectedPaymentType == 'cash' ? null : Border.all(color: Colors.grey),
                  ),
                  child: Center(
                    child: Text(
                      'Cash',
                      style: TextStyle(
                        color: _selectedPaymentType == 'cash' ? Colors.white : Colors.black,
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

            // Card Button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPaymentType = 'card';
                  });
                  _proceedToNextStep();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedPaymentType == 'card' ? Colors.black : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: _selectedPaymentType == 'card' ? null : Border.all(color: Colors.grey),
                  ),
                  child: Center(
                    child: Text(
                      'Card',
                      style: TextStyle(
                        color: _selectedPaymentType == 'card' ? Colors.white : Colors.black,
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

  Future<void> _handleOrderCompletion({
    required CustomerDetails customerDetails,
    required PaymentDetails paymentDetails,
  }) async {
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

    final double finalTotalCharge = paymentDetails.totalCharge;
    final double finalChangeDue = paymentDetails.changeDue;
    final double finalDiscountPercentage = paymentDetails.discountPercentage;
    final double finalAmountReceived = paymentDetails.amountReceived ?? 0.0;

    final orderData = {
      "guest": {
        "name": customerDetails.name,
        "email": customerDetails.email ?? "N/A",
        "phone_number": customerDetails.phoneNumber,
        "street_address": customerDetails.streetAddress ?? "N/A",
        "city": customerDetails.city ?? "N/A",
        "county": customerDetails.city ?? "N/A",
        "postal_code": customerDetails.postalCode ?? "N/A",
      },
      "transaction_id": id1,
      "payment_type": _selectedPaymentType,
      "amount_received": finalAmountReceived,
      "discount_percentage": finalDiscountPercentage,
      "order_type": _actualOrderType.toLowerCase() == 'collection' ? 'takeaway' : _actualOrderType,
      "total_price": finalTotalCharge, // Use totalCharge from paymentDetails
      "order_extra_notes": _cartItems.map((item) => item.comment ?? '').join(', ').trim(),
      "status": "yellow",
      "change_due": finalChangeDue, // Use changeDue from paymentDetails
      //'driver_id': null, // ADDED: driver_id with null value
      "order_source": "EPOS",
      "items": _cartItems.map((cartItem) {
        String description = cartItem.foodItem.name;
        if (cartItem.selectedOptions != null && cartItem.selectedOptions!.isNotEmpty) {
          description += ' (${cartItem.selectedOptions!.join(', ')})';
        }


        double itemTotalPrice = double.parse((cartItem.pricePerUnit * cartItem.quantity).toStringAsFixed(2));
        return {
          "item_id": cartItem.foodItem.id,
          "quantity": cartItem.quantity,
          "description": description,
          "price_per_unit": double.parse(cartItem.pricePerUnit.toStringAsFixed(2)),
          "total_price": itemTotalPrice,
          "comment": cartItem.comment,
        };
      }).toList(),
    };

    print("Attempting to submit order with order_type: $_actualOrderType");
    print("Order Data being sent: $orderData");

    String extraNotes = _cartItems.map((item) => item.comment ?? '').join(', ').trim();

    // Proceed directly to printing and order process without dialog
    await _handlePrintingAndOrderDirect(
      orderData: orderData,
      id1: id1,
      subtotal: finalTotalCharge,
      totalCharge: finalTotalCharge,
      extraNotes: extraNotes,
      changeDue: finalChangeDue,
    );
  }

// New method that handles printing without showing dialog
  Future<void> _handlePrintingAndOrderDirect({
    required Map<String, dynamic> orderData,
    required String id1,
    required double subtotal,
    required double totalCharge,
    required String extraNotes,
    required double changeDue,
  }) async {
    if (!mounted) return;

    // Try to print silently in the background
    try {
      await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId: id1,
        orderType: _actualOrderType,
        cartItems: _cartItems,
        subtotal: subtotal,
        totalCharge: totalCharge,
        extraNotes: extraNotes.isNotEmpty ? extraNotes : null,
        changeDue: changeDue,
      );
    } catch (e) {
      print('Background printing failed: $e');
      // Continue with order placement even if printing fails
      if(mounted) {
        _showErrorSnackBar('Printing failed: $e');
      }
    }

    // Place order regardless of printing success
    await _placeOrderDirectly(orderData);
  }

  Future<void> _placeOrderDirectly(Map<String, dynamic> orderData) async {
    if (!mounted) return;

    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);

    try {
      // Place the order in background
      final orderId = await ApiService.createOrderFromMap(orderData);

      print('Order placed successfully: $orderId for type: $_actualOrderType');

      // Update provider after successful order
      orderCountsProvider.incrementOrderCount(_actualOrderType);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order placed successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Reset UI state to go back to cart widget
        setState(() {
          _cartItems.clear();
          _showPayment = false;
          _customerDetails = null;
          _hasProcessedFirstStep = false; // Reset the flag after successful order
        });
      }
    } catch (e) {
      print('Order placement failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to place order: $e"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

// Update the _proceedToNextStep method
  void _proceedToNextStep() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to cart first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the flag when proceeding to next step
    setState(() {
      _hasProcessedFirstStep = true;
    });

    // For dine-in orders, skip customer details and go directly to payment
    if (_actualOrderType.toLowerCase() == 'dinein') {
      setState(() {
        // Create default customer details for dine-in
        _customerDetails = CustomerDetails(
          name: 'Dine-in Customer',
          phoneNumber: 'N/A',
          email: null,
          streetAddress: null,
          city: null,
          postalCode: null,
        );
        _showPayment = true;
      });
      return;
    }

    // For delivery and takeaway, check if customer details are already saved
    if (_customerDetails != null) {
      // Customer details already exist, go directly to payment
      setState(() {
        _showPayment = true;
      });
    } else {
      // No customer details yet, go to customer details first
      setState(() {
      });
    }
  }

// Update the _buildRightPanelContent method
  Widget _buildRightPanelContent() {
    // If showing customer details
    // If showing payment
    if (_showPayment) {
      return PaymentWidget(
        subtotal: _calculateTotalPrice(),
        customerDetails: _customerDetails!,
        paymentType: _selectedPaymentType,
        onPaymentConfirmed: (PaymentDetails paymentDetails) {
          _handleOrderCompletion(
            customerDetails: _customerDetails!,
            paymentDetails: paymentDetails,
          );
        },
        onBack: () {
          // This allows service switching again
          setState(() {
            _showPayment = false;
            _hasProcessedFirstStep = false;
            // Keep _customerDetails for future use
          });
        },
      );
    }

    // If showing payment
    if (_showPayment) {
      return PaymentWidget(
        subtotal: _calculateTotalPrice(),
        customerDetails: _customerDetails!,
        paymentType: _selectedPaymentType,
        onPaymentConfirmed: (PaymentDetails paymentDetails) {
          _handleOrderCompletion(
            customerDetails: _customerDetails!,
            paymentDetails: paymentDetails,
          );
        },
        onBack: () {
          // FIXED: Don't reset everything, just go back to cart view
          // Keep customer details and processed state
          setState(() {
            _showPayment = false;
            // Don't reset _hasProcessedFirstStep or _customerDetails
          });
        },
      );
    }

    // Only show Customer Details Widget for empty cart when:
    // 1. Cart is empty AND
    // 2. Order type is delivery/takeaway (NOT dine-in) AND
    // 3. Customer details haven't been entered yet AND
    // 4. We haven't processed the first step (meaning we're in initial state)
    if (_cartItems.isEmpty &&
        (_actualOrderType.toLowerCase() == 'delivery' ||
            _actualOrderType.toLowerCase() == 'takeaway' ||
            _actualOrderType.toLowerCase() == 'collection') &&
        _customerDetails == null &&
        !_hasProcessedFirstStep) {
      return Column(
        children: [
          // Keep the service selection at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              _buildServiceHighlight('dinein', 'DineIn.png'),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(
              height: 0,
              thickness: 2.5,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          // Customer Details Widget
          Expanded(
            child: CustomerDetailsWidget(
              subtotal: 0.0,
              orderType: _actualOrderType,
              onCustomerDetailsSubmitted: (CustomerDetails details) {
                setState(() {
                  _customerDetails = details;
                  _hasProcessedFirstStep = true; // Set flag here too
                });
              },
              onBack: () {
                // For empty cart, there's nowhere to go back to, so maybe do nothing
                // or you could implement some other logic here
              },
            ),
          ),
        ],
      );
    }
    return _buildCartSummary();
  }

  Widget _buildServiceHighlight(String type, String imageName) {
    bool isSelected = _actualOrderType.toLowerCase() == type.toLowerCase() ||
        (type.toLowerCase() == 'takeaway' && _actualOrderType.toLowerCase() == 'collection');

    String displayImage = isSelected && !imageName.contains('white.png')
        ? imageName.replaceAll('.png', 'white.png')
        : imageName;

    String baseImageNameForSizing = imageName.replaceAll('white.png', '.png');

    return Column(
      children: [
        InkWell(
          onTap: _hasProcessedFirstStep
              ? null
              : () {
            // Check if switching from dine-in to delivery/takeaway
            bool switchingFromDineInToOthers = (_actualOrderType.toLowerCase() == 'dinein' &&
                (type.toLowerCase() == 'delivery' || type.toLowerCase() == 'takeaway'));

            // Check if switching from delivery/takeaway to dine-in
            bool switchingToDineIn = ((_actualOrderType.toLowerCase() == 'delivery' ||
                _actualOrderType.toLowerCase() == 'takeaway' ||
                _actualOrderType.toLowerCase() == 'collection') &&
                type.toLowerCase() == 'dinein');

            setState(() {
              if (type.toLowerCase() == 'takeaway') {
                _actualOrderType = 'takeaway'; // Default to takeaway when clicking the takeaway icon
                _takeawaySubType = 'takeaway';
              } else {
                _actualOrderType = type;
                _takeawaySubType = type.toLowerCase() == 'collection' ? 'collection' : 'takeaway';
              }
              _selectedBottomNavItem = _getBottomNavItemIndexForOrderType(type);

              // Reset cart and customer details when switching between different service types
              if (switchingFromDineInToOthers || switchingToDineIn) {
                _cartItems.clear(); // Clear the cart
                _customerDetails = null; // Reset customer details
                _hasProcessedFirstStep = false; // Reset the processed flag
                _showPayment = false; // Hide payment if showing
              }
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              // Add visual indication that switching is disabled
              border: _hasProcessedFirstStep && !isSelected
                  ? Border.all(color: Colors.grey.withOpacity(0.5), width: 1)
                  : null,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/$displayImage',
                width: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
                height: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
                fit: BoxFit.contain,
                color: _hasProcessedFirstStep && !isSelected
                    ? Colors.grey.withOpacity(0.5) // Grey out disabled options
                    : (isSelected ? Colors.white : const Color(0xFF616161)),
              ),
            ),
          ),
        ),

        // Show radio buttons when takeaway or collection is selected
        if (type.toLowerCase() == 'takeaway' &&
            (isSelected || _actualOrderType.toLowerCase() == 'collection') &&
            !_hasProcessedFirstStep)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: [
                _buildRadioOption('takeaway', 'Takeaway'),
                const SizedBox(height: 4),
                _buildRadioOption('collection', 'Collection'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRadioOption(String value, String label) {
    bool isSelected = _takeawaySubType == value;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _takeawaySubType = value;
            // Update the actual order type to reflect the selection
            _actualOrderType = value;
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFCB6CE6) : Colors.grey,
                  width: 2,
                ),
                color: Colors.white,
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFCB6CE6),
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                color: isSelected ? const Color(0xFFCB6CE6) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row with Edit Icon on the Right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditMode = !_isEditMode;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isEditMode ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Image.asset(
                      'assets/images/EDIT.png',
                      color: _isEditMode ? Colors.white : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar Row with Arrow Icon
        Padding(
          padding: const EdgeInsets.only(left: 50, right: 120),
          child: Row(
            children: [
              // Rounded Back Arrow Icon
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: SizedBox(
                  width: 45,
                  height: 45,
                  child: Image.asset(
                    'assets/images/bArrow.png',
                    fit: BoxFit.contain,
                  ),

                ),
              ),

              const SizedBox(width: 40),

              // Search TextField
              Expanded(
                child: TextField(
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "Search",
                    hintStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 15),
                    filled: true,
                    fillColor: Color(0xFFc9c9c9),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 20.0, right: 8.0),
                      child: Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }


// Modified _buildCategoryTabs method
  Widget _buildCategoryTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        // This baseUnit is for general responsiveness
        double baseUnit = screenWidth / 35;

        // Calculate item width
        double itemWidth = screenWidth / 10; // This is the horizontal space each category card takes
        double itemHeight = itemWidth * 0.7; // Maintain an aspect ratio for images

        // Text sizing, adjusted to be proportional to itemWidth
        double textFontSize = itemWidth * 0.12;
        double textContainerPaddingVertical = textFontSize * 0.1;
        double minTextContainerHeight = textFontSize * 1.5 + (2 * textContainerPaddingVertical);

        // Total height calculation for the Row, including image, text, and internal spacing
        double totalHeight = itemHeight + (baseUnit * 0.05) + minTextContainerHeight;

        return SizedBox(
          height: totalHeight,
          child: Row(
            children: [

              if (_canScrollLeft)
                IconButton(
                  onPressed: _scrollCategoriesLeft,
                  icon: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/images/lArrow.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 30,
                ),

              Expanded(
                child: ListView.separated(
                  controller: _categoryScrollController, // Assign the scroll controller
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: baseUnit * 0), // Padding for the ListView content
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => SizedBox(width: baseUnit * 0), // Spacing between category items
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = index;
                          _searchQuery = '';
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container( // Directly size the container for the image
                            width: itemWidth,
                            height: itemHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(baseUnit * 0.6),
                            ),
                            child: Image.asset(
                              category.image,
                              fit: BoxFit.contain,
                              color: const Color(0xFFCB6CE6),
                            ),
                          ),
                          SizedBox(height: baseUnit * 0.05), // Small gap between image and text
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              height: minTextContainerHeight,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: baseUnit * 0.7,
                                vertical: textContainerPaddingVertical,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3D9FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(baseUnit * 1.0),
                              ),
                              child: Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: textFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
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
              if (_canScrollRight) // Only show if we can scroll right
                IconButton(
                  onPressed: _scrollCategoriesRight,
                  icon: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/images/rArrow.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 30,
                ),
            ],
          ),
        );
      },
    );
  }
// --- End of _buildCategoryTabs ---

// --- Start of _buildItemGrid
  Widget _buildItemGrid() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty || selectedCategory < 0 || selectedCategory >= categories.length) {
      return const Center(child: Text('No categories available or selected category is invalid.'));
    }

    final selectedCategoryName = categories[selectedCategory].name;

    // Map category name to correct backend key
    String mappedCategoryKey;
    if (selectedCategoryName.toLowerCase() == 'shawarmas') {
      mappedCategoryKey = 'Shawarma';
    } else if (selectedCategoryName.toLowerCase() == 'kids meal') {
      mappedCategoryKey = 'KidsMeal';
    }  else if (selectedCategoryName.toLowerCase() == 'garlic bread') {
      mappedCategoryKey = 'GarlicBread';
    } else {
      mappedCategoryKey = selectedCategoryName.toLowerCase();
    }

    // Start with items filtered by mapped category
    Iterable<FoodItem> currentItems = foodItems.where(
          (item) => item.category.toLowerCase() == mappedCategoryKey.toLowerCase(),
    );

    // Apply search filtering if a query exists
    if (_searchQuery.isNotEmpty) {
      final lowerCaseQuery = _searchQuery.toLowerCase();
      currentItems = currentItems.where((item) {
        return item.name.toLowerCase().contains(lowerCaseQuery) ||
            (item.description?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
            (item.subType?.toLowerCase().contains(lowerCaseQuery) ?? false);
      });
    }

    final filteredItems = currentItems.toList();

    if (filteredItems.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(child: Text('No items found matching "$_searchQuery" in this category.'));
      } else {
        return const Center(child: Text('No items found in this category.'));
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 30,
        crossAxisSpacing: 30,
        childAspectRatio: 2,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return GestureDetector(
          onTap: () {
            if (!_isEditMode) {
              // Check if customer details are required but not provided
              bool requiresCustomerDetails = (_actualOrderType.toLowerCase() == 'delivery' ||
                  _actualOrderType.toLowerCase() == 'takeaway' ||
                  _actualOrderType.toLowerCase() == 'collection');

              if (requiresCustomerDetails && _customerDetails == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter customer details first before selecting items.'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                return; // Exit without opening modal
              }

              setState(() {
                _isModalOpen = true;
                _modalFoodItem = item;
              });
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _getLeftPanelDimensions();
              });
            }
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
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 19,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            if (_isEditMode)
                              Text(
                                item.availability ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  color: item.availability ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!_isEditMode)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 40,
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD887EF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 42,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isEditMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _toggleItemAvailability(item);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.availability ? Icons.remove : Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  // --- MODIFIED _buildBottomNavBar to take activeOrdersCount ---
  Widget _buildBottomNavBar(Map<String, int> activeOrdersCount) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFB2B2B2),
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 45.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(
              'TakeAway.png',
              0,
              notification: _getNotificationCount(0, activeOrdersCount), // Use provider data
              color: const Color(0xFFFFE26B), // Yellow notification for take away
              onTap: () {
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
              },
            ),

            _navItem(
              'DineIn.png',
              1,
              notification: _getNotificationCount(1, activeOrdersCount), // Use provider data
              color: const Color(0xFFFFE26B), // Yellow notification for dine in
              onTap: () {
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
              },
            ),

            _navItem(
              'Delivery.png',
              2,
              notification: _getNotificationCount(2, activeOrdersCount), // Use provider data
              color: const Color(0xFFFFE26B), // Yellow notification for delivery
              onTap: () {
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
              },
            ),

            _navItem(
              'web.png',
              3,
              notification: _getNotificationCount(3, activeOrdersCount), // Use provider data
              color: const Color(0xFFFFE26B), // Yellow notification for website
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WebsiteOrdersScreen(initialBottomNavItemIndex: 3)));
              },
            ),
            _navItem('home.png', 4, onTap: () {
              Navigator.pop(context);
            }),

            _navItem('More.png', 5, onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(
                    initialBottomNavItemIndex: 5,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED _navItem to accept notification and color ---
  Widget _navItem(String image, int index,
      {String? notification, Color? color, required VoidCallback onTap}) {

    bool isSelected = _selectedBottomNavItem == index;

    String displayImage = image;

    if (isSelected) {
      // Logic to switch to white version of image if selected
      if (image == 'TakeAway.png') {
        displayImage = 'TakeAwaywhite.png';
      } else if (image == 'DineIn.png') {
        displayImage = 'DineInwhite.png';
      } else if (image == 'Delivery.png') {
        displayImage = 'Deliverywhite.png';
      } else if (image == 'home.png' || image == 'More.png') {
        // These might not have a 'white' version or you explicitly don't want them to change color
        // For 'home.png' and 'More.png', the `color` property below will handle it
      } else if (image.contains('.png')) {
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
              if (notification != null && notification.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color ?? Colors.red, // Use passed color or default to red
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

class Category {
  final String name;
  final String image;

  Category({required this.name, required this.image});
}