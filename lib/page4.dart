// lib/page4.dart
import 'package:epos/website_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/food_item_details_model.dart'; // Make sure this import is correct
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
import 'package:epos/custom_bottom_nav_bar.dart';

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
  int _selectedBottomNavItem = -1;
  bool _showPayment = false;
  CustomerDetails? _customerDetails;
  bool _isEditMode = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int? _editingCartIndex; // To store the index of the cart item being edited

  // NEW: State for in-place comment editing
  int? _editingCommentIndex;
  final TextEditingController _commentEditingController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();


  final GlobalKey _leftPanelKey = GlobalKey();
  Rect _leftPanelRect = Rect.zero;

  void _scrollCategoriesLeft() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset - 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollCategoriesRight() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onBottomNavItemSelected(int index) {
    setState(() {
      _selectedBottomNavItem = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DynamicOrderListScreen(initialBottomNavItemIndex: 0, orderType: 'takeaway',)));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DynamicOrderListScreen(initialBottomNavItemIndex: 1, orderType: 'dinein',)));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DynamicOrderListScreen(initialBottomNavItemIndex: 2, orderType: 'delivery',)));
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WebsiteOrdersScreen(initialBottomNavItemIndex: 3)));
    } else if (index == 4) {
      setState(() {
        _selectedBottomNavItem = -1;
      });
    } else if (index == 5) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SettingsScreen(initialBottomNavItemIndex: 5)));
    }
  }

  final List<Category> categories = [
    Category(name: 'PIZZA', image: 'assets/images/PizzasS.png'),
    Category(name: 'BURGERS', image: 'assets/images/BurgersS.png'),
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
      case 'collection':
        return 0;
      case 'dinein':
        return 1;
      case 'delivery':
        return 2;
      case 'website':
        return 3;
      default:
        return 4;
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text.split(' ').map((word) {
      if (word.isEmpty) {
        return '';
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  @override
  void initState() {
    super.initState();
    selectedServiceImage = widget.initialSelectedServiceImage ?? 'TakeAway.png';
    _actualOrderType = widget.selectedOrderType;
    if (_actualOrderType.toLowerCase() == 'collection') {
      _takeawaySubType = 'collection';
    } else if (_actualOrderType.toLowerCase() == 'takeaway') {
      _takeawaySubType = 'takeaway';
    }

    _selectedBottomNavItem = -1;

    foodItems = widget.foodItems;

    debugPrint("📋 Page4 initialized with ${foodItems.length} food items. Selected Order Type: $_actualOrderType");

    final categoriesInData = foodItems.map((e) => e.category).toSet();
    debugPrint("📂 Categories in data: $categoriesInData");

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });

    _categoryScrollController.addListener(_updateScrollButtonVisibility);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtonVisibility();
    });

    _searchController.addListener(() => setState(() {}));
    _searchFocusNode.addListener(() => setState(() {}));

    // NEW: Add listener to focus node for comment editing
    _commentFocusNode.addListener(() {
      if (!_commentFocusNode.hasFocus) {
        // If focus is lost, stop editing
        _stopEditingComment();
      }
    });
  }


  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
      debugPrint('Left Panel Rect for Modal Positioning: $_leftPanelRect');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _categoryScrollController.removeListener(_updateScrollButtonVisibility);
    _categoryScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // NEW: Dispose comment editing controllers and focus node
    _commentEditingController.dispose();
    _commentFocusNode.dispose();
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

  // MODIFIED: This method now handles both adding new items and updating existing ones
  void _handleItemAdditionOrUpdate(CartItem newItem) {
    bool requiresCustomerDetails = (_actualOrderType.toLowerCase() == 'delivery' ||
        _actualOrderType.toLowerCase() == 'takeaway' ||
        _actualOrderType.toLowerCase() == 'collection');

    if (requiresCustomerDetails && _customerDetails == null && _editingCartIndex == null) { // Only check if adding new and requires details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter customer details first before adding items to cart.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      if (_editingCartIndex != null) {
        // If editing, replace the item at the stored index
        _cartItems[_editingCartIndex!] = newItem;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newItem.foodItem.name} updated in cart!')),
        );
      } else {
        // If not editing, add or increment as before
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newItem.foodItem.name} added to cart!')),
        );
      }
      _isModalOpen = false; // Close modal after action
      _modalFoodItem = null;
      _editingCartIndex = null; // Reset editing index
    });
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
    return uuid.v4();
  }

  // NEW: Method to start editing a comment
  void _startEditingComment(int index, String? currentComment) {
    setState(() {
      _editingCommentIndex = index;
      _commentEditingController.text = currentComment ?? '';
    });
    // Request focus for the text field
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  // NEW: Method to stop editing a comment and update backend
  void _stopEditingComment() async {
    if (_editingCommentIndex != null) {
      final String newComment = _commentEditingController.text.trim();
      final CartItem itemToUpdate = _cartItems[_editingCommentIndex!];

      // Only update if the comment has actually changed
      if ((itemToUpdate.comment ?? '') != newComment) {
        // IMPORTANT: Create a new CartItem instance because 'comment' is final.
        final updatedCartItem = CartItem(
          foodItem: itemToUpdate.foodItem,
          quantity: itemToUpdate.quantity,
          pricePerUnit: itemToUpdate.pricePerUnit,
          selectedOptions: itemToUpdate.selectedOptions,
          comment: newComment.isEmpty ? null : newComment, // Set to null if empty
        );

        setState(() {
          _cartItems[_editingCommentIndex!] = updatedCartItem;
        });

        // Now, prepare to "update" this in the backend.
        // As discussed, since there's no specific "update item comment" endpoint,
        // the practical approach is to ensure the complete order payload
        // sent later (when placing the order) contains this updated comment.
        // For demonstration, we'll log a simulated update.
        print('Simulating backend update for item comment: ${itemToUpdate.foodItem.name} new comment: "$newComment"');
        print('The updated CartItem is now: ${updatedCartItem.foodItem.name}, Comment: ${updatedCartItem.comment}');


        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment updated locally! (Backend update will occur on order placement)'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      setState(() {
        _editingCommentIndex = null;
        _commentEditingController.clear();
      });
    }
  }


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
        optimisticAvailability,
      );

      setState(() {
        final itemIndex = foodItems.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          foodItems[itemIndex] = originalItemState.copyWith(
            availability: updatedItemFromApi.availability,
          );
        }
      });

    } catch (e) {
      setState(() {
        final itemIndex = foodItems.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          foodItems[itemIndex] = originalItemState;
        }
      });
      debugPrint('Error toggling item availability for ${item.name}: $e');
      if(mounted) {
        _showErrorSnackBar('Failed to update ${item.name} availability.');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final orderCountsProvider = Provider.of<OrderCountsProvider>(context);
    final activeOrdersCount = orderCountsProvider.activeOrdersCount;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    const double bottomNavBarHeight = 80.0;

    final double availableModalHeight = screenHeight - bottomNavBarHeight;

    final double modalDesiredWidth = min(screenWidth * 0.6, 1200.0);
    final double modalActualWidth = min(modalDesiredWidth, screenWidth * 0.9);

    final double modalDesiredHeight = min(availableModalHeight * 0.9, 900.0);
    double modalActualHeight = min(modalDesiredHeight, availableModalHeight * 0.9);

    final double modalLeftOffset = _leftPanelRect.left + (_leftPanelRect.width - modalActualWidth) / 2;

    double modalTopOffset = _leftPanelRect.top + (_leftPanelRect.height - modalActualHeight) / 2;

    final double calculatedBottomEdge = modalTopOffset + modalActualHeight;
    if (calculatedBottomEdge > availableModalHeight) {
      modalTopOffset = availableModalHeight - modalActualHeight;
      if (modalTopOffset < _leftPanelRect.top) {
        modalTopOffset = _leftPanelRect.top;
      }
    }
    if (modalTopOffset < 0) {
      modalTopOffset = 0;
    }


    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        key: _leftPanelKey,
                        flex: 2,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                _buildSearchBar(),
                                _buildCategoryTabs(),

                                const SizedBox(height: 20),

                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 40),
                                  height: 13,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2D9F9),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                Expanded(child: _buildItemGrid()),
                              ],
                            ),
                            if (_isModalOpen)
                              Positioned.fill(
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
                        padding: _isModalOpen
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(vertical: 20.0),
                        child: const VerticalDivider(
                          width: 2.5,
                          thickness: 2.5,
                          color: Color(0xFFB2B2B2),
                        ),
                      ),

                      Expanded(
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

                // FoodItemDetailsModal (positioned over the whole screen but visually over left panel)
                if (_isModalOpen && _modalFoodItem != null && _leftPanelRect != Rect.zero)
                  Positioned(
                    left: modalLeftOffset,
                    top: modalTopOffset,
                    width: modalActualWidth,
                    height: modalActualHeight,
                    child: FoodItemDetailsModal(
                      foodItem: _modalFoodItem!,
                      onAddToCart: _handleItemAdditionOrUpdate, // Use the new handler
                      onClose: () {
                        setState(() {
                          _isModalOpen = false;
                          _modalFoodItem = null;
                          _editingCartIndex = null; // Ensure index is reset on close
                        });
                      },
                      initialCartItem: _editingCartIndex != null ? _cartItems[_editingCartIndex!] : null,
                      isEditing: _editingCartIndex != null,
                    ),
                  ),
              ],
            ),
          ),

          CustomBottomNavBar(
            selectedIndex: -1,
            onItemSelected: _onBottomNavItemSelected,
            showDivider: true,
          ),

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

              String? selectedSize;
              String? selectedCrust;
              String? selectedBase;
              List<String> toppings = [];
              List<String> sauceDips = [];
              bool hasOptions = false;

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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 30, right: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!hasOptions)
                                              Text(
                                                item.foodItem.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontFamily: 'Poppins',
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                            if (hasOptions) ...[
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

                                const SizedBox(height: 20),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 20),

                                    // Delete button
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
                                          width: 46,
                                          height: 46,
                                          child: Image.asset(
                                            'assets/images/Bin.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 25),

                                    // Decrement button
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
                                          width: 46,
                                          height: 46,
                                          child: const Icon(
                                            Icons.remove,
                                            color: Colors.black,
                                            size: 46,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 25),
                                    // Increment button
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            item.incrementQuantity();
                                          });
                                        },
                                        child: SizedBox(
                                          width: 46,
                                          height: 46,
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.black,
                                            size: 46,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 35),

                                    // NEW: Edit button
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          _editCartItem(item, index);
                                        },
                                        child: SizedBox(
                                          width: 37,
                                          height: 37,
                                          child: Image.asset(
                                            'assets/images/EDIT.png',
                                            fit: BoxFit.contain,
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
                            height: 140,
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '£${(item.pricePerUnit * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 27,
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

                    // NEW: Conditional rendering for comment editing
                    if (_editingCommentIndex == index)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF1C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _commentEditingController,
                            focusNode: _commentFocusNode,
                            maxLines: null, // Allow multiline input
                            keyboardType: TextInputType.text,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.normal,
                              color: Colors.black,
                              fontFamily: 'Poppins',
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add/Edit comment...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _stopEditingComment(), // Save on enter
                            onTapOutside: (_) => _stopEditingComment(), // Save on tap outside
                          ),
                        ),
                      )
                    else if (item.comment != null && item.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () => _startEditingComment(index, item.comment),
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
                      )
                    else // Option to add comment if empty
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () => _startEditingComment(index, null),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0), // A lighter color to indicate editable area
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Text(
                                'Click to add a comment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.center,
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

  void _editCartItem(CartItem cartItem, int cartIndex) {
    setState(() {
      _isModalOpen = true;
      _modalFoodItem = cartItem.foodItem; // The base food item for the modal
      _editingCartIndex = cartIndex; // Store the index of the item being edited
    });

    // Ensure dimensions are calculated after state update and before modal opens visually
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });
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
      "total_price": finalTotalCharge,
      // Ensure comments are collected here for the entire order
      "order_extra_notes": _cartItems.map((item) => item.comment ?? '').where((c) => c.isNotEmpty).join(', ').trim(),
      "status": "yellow",
      "change_due": finalChangeDue,
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
          "comment": cartItem.comment, // This will now contain the updated comment
        };
      }).toList(),
    };

    print("Attempting to submit order with order_type: $_actualOrderType");
    print("Order Data being sent: $orderData");

    String extraNotes = _cartItems.map((item) => item.comment ?? '').where((c) => c.isNotEmpty).join(', ').trim();

    await _handlePrintingAndOrderDirect(
      orderData: orderData,
      id1: id1,
      subtotal: finalTotalCharge,
      totalCharge: finalTotalCharge,
      extraNotes: extraNotes,
      changeDue: finalChangeDue,
    );
  }

  Future<void> _handlePrintingAndOrderDirect({
    required Map<String, dynamic> orderData,
    required String id1,
    required double subtotal,
    required double totalCharge,
    required String extraNotes,
    required double changeDue,
  }) async {
    if (!mounted) return;

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
      if(mounted) {
        _showErrorSnackBar('Printing failed: $e');
      }
    }

    await _placeOrderDirectly(orderData);
  }

  Future<void> _placeOrderDirectly(Map<String, dynamic> orderData) async {
    if (!mounted) return;

    final orderCountsProvider = Provider.of<OrderCountsProvider>(context, listen: false);

    try {
      final orderId = await ApiService.createOrderFromMap(orderData);

      print('Order placed successfully: $orderId for type: $_actualOrderType');

      orderCountsProvider.incrementOrderCount(_actualOrderType);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order placed successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _cartItems.clear();
          _showPayment = false;
          _customerDetails = null;
          _hasProcessedFirstStep = false;
          _selectedBottomNavItem = -1;
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

    setState(() {
      _hasProcessedFirstStep = true;
    });

    if (_actualOrderType.toLowerCase() == 'dinein') {
      setState(() {
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

    if (_customerDetails != null) {
      setState(() {
        _showPayment = true;
      });
    } else {
      setState(() {
      });
    }
  }

  Widget _buildRightPanelContent() {
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
          setState(() {
            _showPayment = false;
            _hasProcessedFirstStep = false;
          });
        },
      );
    }

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
          setState(() {
            _showPayment = false;
          });
        },
      );
    }

    if (_cartItems.isEmpty &&
        (_actualOrderType.toLowerCase() == 'delivery' ||
            _actualOrderType.toLowerCase() == 'takeaway' ||
            _actualOrderType.toLowerCase() == 'collection') &&
        _customerDetails == null &&
        !_hasProcessedFirstStep) {
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(
              height: 0,
              thickness: 2.5,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: CustomerDetailsWidget(
              subtotal: 0.0,
              orderType: _actualOrderType,
              onCustomerDetailsSubmitted: (CustomerDetails details) {
                setState(() {
                  _customerDetails = details;
                  _hasProcessedFirstStep = true;
                });
              },
              onBack: () {
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
            bool switchingFromDineInToOthers = (_actualOrderType.toLowerCase() == 'dinein' &&
                (type.toLowerCase() == 'delivery' || type.toLowerCase() == 'takeaway'));

            bool switchingToDineIn = ((_actualOrderType.toLowerCase() == 'delivery' ||
                _actualOrderType.toLowerCase() == 'takeaway' ||
                _actualOrderType.toLowerCase() == 'collection') &&
                type.toLowerCase() == 'dinein');

            setState(() {
              if (type.toLowerCase() == 'takeaway') {
                _actualOrderType = 'takeaway';
                _takeawaySubType = 'takeaway';
              } else {
                _actualOrderType = type;
                _takeawaySubType = type.toLowerCase() == 'collection' ? 'collection' : 'takeaway';
              }
              _selectedBottomNavItem = _getBottomNavItemIndexForOrderType(type);

              if (switchingFromDineInToOthers || switchingToDineIn) {
                _cartItems.clear();
                _customerDetails = null;
                _hasProcessedFirstStep = false;
                _showPayment = false;
              }
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
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
                    ? Colors.grey.withOpacity(0.5)
                    : (isSelected ? Colors.white : const Color(0xFF616161)),
              ),
            ),
          ),
        ),

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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Padding(
            padding: const EdgeInsets.only(left: 50, right: 120),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
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

                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: _searchFocusNode.hasFocus || _searchController.text.isNotEmpty
                          ? ''
                          : 'Search',
                      hintStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 15),
                      filled: true,
                      fillColor: const Color(0xFFc9c9c9),
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
                    onTap: () {
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildCategoryTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        double baseUnit = screenWidth / 35;

        double itemWidth = screenWidth / 10;
        double itemHeight = itemWidth * 0.7;

        double textFontSize = itemWidth * 0.12;
        double textContainerPaddingVertical = textFontSize * 0.1;
        double minTextContainerHeight = textFontSize * 1.5 + (2 * textContainerPaddingVertical);

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
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: baseUnit * 0),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => SizedBox(width: baseUnit * 0),
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
                          Container(
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
                          SizedBox(height: baseUnit * 0.05),
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
              if (_canScrollRight)
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

  Widget _buildItemGrid() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty || selectedCategory < 0 || selectedCategory >= categories.length) {
      return const Center(child: Text('No categories available or selected category is invalid.'));
    }

    final selectedCategoryName = categories[selectedCategory].name;

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

    Iterable<FoodItem> currentItems = foodItems.where(
          (item) => item.category.toLowerCase() == mappedCategoryKey.toLowerCase(),
    );

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
                return;
              }

              setState(() {
                _isModalOpen = true;
                _modalFoodItem = item;
                _editingCartIndex = null; // Ensure this is null when adding new items
              });
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _getLeftPanelDimensions();
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2D9F9),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14.0, 5.0, 22.0, 5.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _toTitleCase(item.name),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
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
                            width: 41,
                            height: 47,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD887EF),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 43,
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
                      cursor: SystemMouseCursors.click, // Corrected: SystemCustomCursors to SystemMouseCursors
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
}

class Category {
  final String name;
  final String image;

  Category({required this.name, required this.image});
}