// lib/page4.dart
import 'package:epos/providers/page4_state_provider.dart';
import 'package:epos/website_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/food_item_details_model.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:epos/dynamic_order_list_screen.dart';
import 'package:flutter/scheduler.dart';
import 'package:epos/services/thermal_printer_service.dart';
// import 'package:epos/widgets/receipt_preview_dialog.dart';
import 'package:epos/customer_details_widget.dart';
import 'package:epos/payment_details_widget.dart';
import 'package:epos/settings_screen.dart';
import 'package:epos/models/order_models.dart';
import 'package:epos/models/order.dart' as order_model;
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'package:epos/providers/epos_orders_provider.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'package:epos/discount_page.dart';
import 'package:epos/services/custom_popup_service.dart';
import 'package:epos/providers/item_availability_provider.dart';
import 'package:epos/providers/offline_provider.dart';
import 'package:epos/providers/payment_link_provider.dart';
import 'package:epos/services/offline_order_manager.dart';
import 'package:epos/services/uk_time_service.dart';

class Page4 extends StatefulWidget {
  final String? initialSelectedServiceImage;
  final List<FoodItem> foodItems;
  final String selectedOrderType;
  final bool editMode;
  final int? orderId;
  final order_model.Order? existingOrder;

  const Page4({
    super.key,
    this.initialSelectedServiceImage,
    required this.foodItems,
    required this.selectedOrderType,
    this.editMode = false,
    this.orderId,
    this.existingOrder,
  });

  @override
  State<Page4> createState() => _Page4State();
}

class _Page4State extends State<Page4> {
  int selectedCategory = 0;
  List<FoodItem> foodItems = [];
  String _takeawaySubType = 'takeaway';
  bool isLoading = false;
  bool _isProcessingPayment = false;
  bool _isSendingPaymentLink = false;
  bool _isEditMode = false;
  int? _editingOrderId;
  order_model.Order? _existingOrder;
  String? _currentOrderStatus;
  final List<CartItem> _cartItems = [];
  bool _isModalOpen = false;
  FoodItem? _modalFoodItem;
  String _searchQuery = '';
  bool _hasProcessedFirstStep = false;
  String _selectedPaymentType = '';
  late String selectedServiceImage;
  late String _actualOrderType;
  bool _showPayment = false;
  CustomerDetails? _customerDetails;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int? _editingCartIndex;
  double _appliedDiscountPercentage = 0.0;
  double _discountAmount = 0.0;
  bool _showDiscountPage = false;
  bool _isProcessingUnpaid = false;
  final ScrollController _scrollController = ScrollController();
  int? _editingCommentIndex;
  final TextEditingController _commentEditingController =
      TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSearchBarExpanded = false;
  final GlobalKey _leftPanelKey = GlobalKey();
  Rect _leftPanelRect = Rect.zero;
  bool _wasDiscountPageShown = false;
  bool _isEditingCustomerDetails = false;
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editAddressController = TextEditingController();
  final TextEditingController _editCityController = TextEditingController();
  final TextEditingController _editPostalCodeController =
      TextEditingController();
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();
  int _selectedShawarmaSubcategory = 0;
  final List<String> _shawarmaSubcategories = [
    'Donner & Shawarma kebab',
    'Shawarma & kebab trays',
  ];

  int _selectedWingsSubcategory = 0;
  List<String> _wingsSubcategories = [];

  int _selectedDealsSubcategory = 0;
  List<String> _dealsSubcategories = [];

  int _selectedPizzaSubcategory = 0;
  List<String> _pizzaSubcategories = [];

  bool _showAddItemModal = false;
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

  final RegExp _nameRegExp = RegExp(r"^[a-zA-Z\s-']+$");
  final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  bool _validateUKPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[()\s-]'), '');
    final RegExp finalUkPhoneRegex = RegExp(r'^(?:(?:\+|00)44|0)\d{9,10}$');
    return finalUkPhoneRegex.hasMatch(cleanedNumber);
  }

  void _startEditingCustomerDetails() {
    if (_customerDetails != null) {
      _editNameController.text =
          _customerDetails!.name != 'Walk-in Customer'
              ? _customerDetails!.name
              : '';
      _editPhoneController.text =
          _customerDetails!.phoneNumber != 'N/A'
              ? _customerDetails!.phoneNumber
              : '';
      _editEmailController.text = _customerDetails!.email ?? '';
      _editAddressController.text = _customerDetails!.streetAddress ?? '';
      _editCityController.text = _customerDetails!.city ?? '';
      _editPostalCodeController.text = _customerDetails!.postalCode ?? '';
    }

    setState(() {
      _isEditingCustomerDetails = true;
    });
  }

  void _validatePin(String pin) {
    if (pin == '2840') {
      Navigator.of(context).pop();
      setState(() {});
      // Proceed to discount page
      setState(() {
        _showDiscountPage = true;
      });
    } else {
      CustomPopupService.show(
        context,
        'Invalid PIN. Please try again.',
        type: PopupType.failure,
      );
      _pinController.clear();
    }
  }

  void _showPinDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Stack(
            children: [
              // Background blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
              // Dialog
              Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Portal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter PIN to access admin features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                          fontFamily: 'Poppins',
                        ),
                        decoration: InputDecoration(
                          hintText: '••••',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            letterSpacing: 8,
                            fontFamily: 'Poppins',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          counterText: '',
                        ),
                        onSubmitted: (pin) => _validatePin(pin),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => _validatePin(_pinController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Access',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _saveCustomerDetails() {
    if (_editFormKey.currentState?.validate() ?? false) {
      setState(() {
        _customerDetails = CustomerDetails(
          name:
              _editNameController.text.trim().isEmpty
                  ? 'Walk-in Customer'
                  : _editNameController.text.trim(),
          phoneNumber:
              _editPhoneController.text.trim().isEmpty
                  ? 'N/A'
                  : _editPhoneController.text.trim(),
          email:
              _editEmailController.text.trim().isEmpty
                  ? null
                  : _editEmailController.text.trim(),
          streetAddress:
              _editAddressController.text.trim().isEmpty
                  ? null
                  : _editAddressController.text.trim(),
          city:
              _editCityController.text.trim().isEmpty
                  ? null
                  : _editCityController.text.trim(),
          postalCode:
              _editPostalCodeController.text.trim().isEmpty
                  ? null
                  : _editPostalCodeController.text.trim(),
        );
        _isEditingCustomerDetails = false;
      });

      CustomPopupService.show(
        context,
        'Customer details updated successfully',
        type: PopupType.success,
      );
    }
  }

  void _cancelEditingCustomerDetails() {
    setState(() {
      _isEditingCustomerDetails = false;
    });

    // Clear controllers
    _editNameController.clear();
    _editPhoneController.clear();
    _editEmailController.clear();
    _editAddressController.clear();
    _editCityController.clear();
    _editPostalCodeController.clear();
  }

  void _preserveCustomerDataForOrderTypeChange(String newOrderType) {
    // Store current customer data in temporary variables
    final currentName = _customerDetails?.name ?? '';
    final currentPhone = _customerDetails?.phoneNumber ?? '';
    final currentEmail = _customerDetails?.email ?? '';
    final currentAddress = _customerDetails?.streetAddress ?? '';
    final currentCity = _customerDetails?.city ?? '';
    final currentPostalCode = _customerDetails?.postalCode ?? '';

    // Clear current customer details
    _customerDetails = null;

    // If switching to an order type that requires customer details, preserve the data
    bool newTypeRequiresCustomerDetails =
        (newOrderType.toLowerCase() == 'delivery' ||
            newOrderType.toLowerCase() == 'takeaway' ||
            newOrderType.toLowerCase() == 'collection');

    if (newTypeRequiresCustomerDetails &&
        (currentName.isNotEmpty || currentPhone.isNotEmpty)) {
      // Create preserved customer details
      _customerDetails = CustomerDetails(
        name: currentName,
        phoneNumber: currentPhone,
        email: currentEmail.isEmpty ? null : currentEmail,
        streetAddress:
            newOrderType.toLowerCase() == 'delivery'
                ? (currentAddress.isEmpty ? null : currentAddress)
                : null,
        city:
            newOrderType.toLowerCase() == 'delivery'
                ? (currentCity.isEmpty ? null : currentCity)
                : null,
        postalCode:
            newOrderType.toLowerCase() == 'delivery'
                ? (currentPostalCode.isEmpty ? null : currentPostalCode)
                : null,
      );
    }
  }

  void _changeOrderType(String type) {
    setState(() {
      String previousOrderType = _actualOrderType;

      if (type.toLowerCase() == 'takeaway') {
        _actualOrderType = 'takeaway';
        _takeawaySubType = 'takeaway';
      } else if (type.toLowerCase() == 'dinein') {
        _actualOrderType = 'dinein';
        _takeawaySubType = 'dinein';
      } else {
        _actualOrderType = type;
        _takeawaySubType =
            type.toLowerCase() == 'collection' ? 'collection' : 'takeaway';
      }

      // Preserve customer data when changing order type
      if (previousOrderType != _actualOrderType) {
        _preserveCustomerDataForOrderTypeChange(_actualOrderType);

        // Reset some states but preserve data where possible
        _showPayment = false;
        _selectedPaymentType = '';

        // If switching to dinein/takeout, allow immediate cart operations
        if (_actualOrderType.toLowerCase() == 'dinein' ||
            _actualOrderType.toLowerCase() == 'takeout') {
          _hasProcessedFirstStep = true; // Allow immediate cart operations
        } else {
          // For delivery/takeaway/collection, reset to show customer details if no customer data
          _hasProcessedFirstStep = _customerDetails != null;
        }
      }
    });

    // IMPORTANT: Update state provider when order type changes
    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );
    stateProvider.switchToOrderType(_actualOrderType, _takeawaySubType);
    _saveCurrentState(); // Save current state after switching
  }

  // Add this method to show confirmation dialog
  void _showOrderTypeChangeDialog(String newType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Order Type'),
          content: Text(
            'Changing order type will clear your cart. Your customer details will be preserved where applicable. Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _cartItems.clear(); // Clear cart when changing order type
                  _editingCartIndex =
                      null; // Reset editing index when cart is cleared
                });
                _changeOrderType(newType);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _onBottomNavItemSelected(int index) {
    // Save current state before navigation
    _saveCurrentState();

    setState(() {});

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => DynamicOrderListScreen(
                initialBottomNavItemIndex: 0,
                orderType: 'takeaway',
              ),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => DynamicOrderListScreen(
                initialBottomNavItemIndex: 1,
                orderType: 'dinein',
              ),
        ),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => DynamicOrderListScreen(
                initialBottomNavItemIndex: 2,
                orderType: 'delivery',
              ),
        ),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => WebsiteOrdersScreen(initialBottomNavItemIndex: 3),
        ),
      );
    } else if (index == 4) {
      setState(() {});
    } else if (index == 5) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(initialBottomNavItemIndex: 5),
        ),
      );
    }
  }

  final List<Category> categories = [
    Category(name: 'DEALS', image: 'assets/images/deals.png'),
    Category(name: 'PIZZA', image: 'assets/images/PizzasS.png'),
    Category(name: 'CALZONES', image: 'assets/images/CalzonesS.png'),
    Category(name: 'SHAWARMAS', image: 'assets/images/ShawarmaS.png'),
    Category(name: 'BURGERS', image: 'assets/images/BurgersS.png'),
    Category(name: 'GARLIC BREAD', image: 'assets/images/GarlicBreadS.png'),
    Category(name: 'WRAPS', image: 'assets/images/WrapsS.png'),
    Category(name: 'KIDS MEAL', image: 'assets/images/KidsMealS.png'),
    Category(name: 'SIDES', image: 'assets/images/SidesS.png'),
    Category(name: 'MILKSHAKE', image: 'assets/images/MilkshakeS.png'),
    Category(name: 'COFFEE', image: 'assets/images/Coffee.png'),
    Category(name: 'DRINKS', image: 'assets/images/DrinksS.png'),
    Category(name: 'DIPS', image: 'assets/images/DipsS.png'),
    // Category(name: 'CHICKEN', image: 'assets/images/Chicken.png'),
    // Category(name: 'DESSERTS', image: 'assets/images/Desserts.png'),
    // Category(name: 'KEBABS', image: 'assets/images/Kebabs.png'),
    // Category(name: 'WINGS', image: 'assets/images/Wings.png'),
  ];

  String _toTitleCase(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return '';
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildItemDescription(FoodItem item, Color textColor) {
    final description = item.description!;

    // Check if this is a Shawarma & kebab tray item that contains "Tray" text
    if (item.subType == 'Shawarma & kebab trays' &&
        description.toLowerCase().contains('tray')) {
      // Split the description to find "Tray" word and make it bold and larger
      final words = description.split(' ');
      List<TextSpan> spans = [];

      for (String word in words) {
        if (word.toLowerCase().contains('tray')) {
          // Make "Tray" word bold and larger
          spans.add(
            TextSpan(
              text: '$word ',
              style: TextStyle(
                fontSize: 18, // Increased from 14
                fontWeight: FontWeight.bold, // Made bold
                color: textColor.withOpacity(0.9), // Slightly more visible
                fontFamily: 'Poppins',
              ),
            ),
          );
        } else {
          // Regular styling for other words
          spans.add(
            TextSpan(
              text: '$word ',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
                fontFamily: 'Poppins',
              ),
            ),
          );
        }
      }

      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(children: spans),
      );
    } else {
      // Default description styling for other items
      return Text(
        description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: textColor.withOpacity(0.7),
          fontFamily: 'Poppins',
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _isEditMode = widget.editMode;
    _editingOrderId = widget.orderId;
    _existingOrder = widget.existingOrder;
    _currentOrderStatus = _existingOrder?.status;
    if (_isEditMode) {
      print(
        "Page4: Edit mode enabled"
        "${_editingOrderId != null ? ' for order $_editingOrderId' : ''}"
        "${_existingOrder != null ? ' (existing order data supplied)' : ''}",
      );
    }

    // Add automatic recovery mechanism - check for empty items periodically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMenuItemHealthCheck();
    });

    // Get the state provider
    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );

    // IMPORTANT: Switch to the correct order type FIRST before loading state
    final incomingOrderType = widget.selectedOrderType;
    print("Page4 initializing with incoming order type: $incomingOrderType");

    // Determine the correct order type and sub type
    String actualOrderType;
    String takeawaySubType;

    if (incomingOrderType.toLowerCase() == 'takeaway') {
      actualOrderType = 'takeaway';
      takeawaySubType = 'takeaway';
    } else if (incomingOrderType.toLowerCase() == 'dinein') {
      actualOrderType = 'dinein';
      takeawaySubType = 'dinein';
    } else if (incomingOrderType.toLowerCase() == 'collection') {
      actualOrderType = 'collection';
      takeawaySubType = 'collection';
    } else {
      actualOrderType = incomingOrderType;
      takeawaySubType =
          incomingOrderType.toLowerCase() == 'collection'
              ? 'collection'
              : 'takeaway';
    }

    // Defer switching to the correct order type until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stateProvider.switchToOrderType(actualOrderType, takeawaySubType);
    });

    // Set initial values that don't require notifyListeners
    selectedServiceImage = widget.initialSelectedServiceImage ?? 'TakeAway.png';
    _actualOrderType = actualOrderType;
    _takeawaySubType = takeawaySubType;

    // Load current state from the provider for the current order type
    _cartItems.clear(); // Clear first to avoid duplicates
    if (_isEditMode) {
      _customerDetails = null;
      _selectedPaymentType = '';
      _hasProcessedFirstStep = false;
      _showPayment = false;
      _appliedDiscountPercentage = 0.0;
      _discountAmount = 0.0;
      _showDiscountPage = false;
      _wasDiscountPageShown = false;
      selectedCategory = 0;
      _searchQuery = '';
      _searchController.text = '';
      _isSearchBarExpanded = false;
      _isModalOpen = false;
      _modalFoodItem = null;
      _editingCartIndex = null;
      _editingCommentIndex = null;
      _commentEditingController.clear();
    } else {
      _cartItems.addAll(stateProvider.cartItems);
      _customerDetails = stateProvider.customerDetails;
      _selectedPaymentType = stateProvider.selectedPaymentType;
      _hasProcessedFirstStep = stateProvider.hasProcessedFirstStep;
      _showPayment = stateProvider.showPayment;
      _appliedDiscountPercentage = stateProvider.appliedDiscountPercentage;
      _discountAmount = stateProvider.discountAmount;
      _showDiscountPage = stateProvider.showDiscountPage;
      _wasDiscountPageShown = stateProvider.wasDiscountPageShown;
      selectedCategory = stateProvider.selectedCategory;
      _searchQuery = stateProvider.searchQuery;
      _searchController.text = _searchQuery;
      _isSearchBarExpanded = stateProvider.isSearchBarExpanded;

      // NEW: Load modal state
      _isModalOpen = stateProvider.isModalOpen;
      _modalFoodItem = stateProvider.modalFoodItem;
      _editingCartIndex = stateProvider.editingCartIndex;

      // NEW: Load comment editing state
      _editingCommentIndex = stateProvider.editingCommentIndex;
      _commentEditingController.text = stateProvider.commentEditingText;
    }

    foodItems = widget.foodItems;

    // Populate Wings and Deals subcategories from food items
    _populateSubcategories();

    print("Page4 initialized with ${foodItems.length} food items");
    print("Page4 Actual Order Type: $_actualOrderType");
    print("Page4 Cart Items: ${_cartItems.length}");
    print("Page4 Customer Details: ${_customerDetails?.name ?? 'None'}");
    print("Page4 Has Processed First Step: $_hasProcessedFirstStep");
    print("Page4 Modal Open: $_isModalOpen");
    print("Page4 Search Query: '$_searchQuery'");

    final categoriesInData = foodItems.map((e) => e.category).toSet();
    print("Page4 Categories in data: $categoriesInData");

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });

    _categoryScrollController.addListener(_updateScrollButtonVisibility);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtonVisibility();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _searchFocusNode.addListener(() => setState(() {}));

    _commentFocusNode.addListener(() {
      if (!_commentFocusNode.hasFocus) {
        _stopEditingComment();
      }
    });

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_existingOrder != null) {
          _loadOrderFromExisting(_existingOrder!);
        } else if (_editingOrderId != null) {
          _loadOrderForEditing(_editingOrderId!);
        } else {
          print(
            'Page4: Edit mode enabled but no order data or order ID provided.',
          );
          CustomPopupService.show(
            context,
            'Unable to load order for editing. Missing order ID.',
            type: PopupType.failure,
          );
        }
      });
    }
  }

  void _saveCurrentState() {
    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );

    // Ensure we're saving to the correct order type
    if (stateProvider.currentOrderType != _actualOrderType) {
      debugPrint(
        '⚠️ State provider order type mismatch! Provider: ${stateProvider.currentOrderType}, Page: $_actualOrderType',
      );
      stateProvider.switchToOrderType(_actualOrderType, _takeawaySubType);
    }

    stateProvider.updateCartItems(_cartItems);
    stateProvider.updateCustomerDetails(_customerDetails);
    stateProvider.updateOrderType(_actualOrderType, _takeawaySubType);
    stateProvider.updatePaymentType(_selectedPaymentType);
    stateProvider.updateProcessedFirstStep(_hasProcessedFirstStep);
    stateProvider.updateShowPayment(_showPayment);
    stateProvider.updateDiscountState(
      percentage: _appliedDiscountPercentage,
      amount: _discountAmount,
      showPage: _showDiscountPage,
      wasShown: _wasDiscountPageShown,
    );
    stateProvider.updateUIState(
      category: selectedCategory,
      search: _searchQuery,
      searchExpanded: _isSearchBarExpanded,
    );

    // NEW: Save modal state
    stateProvider.updateModalState(
      isOpen: _isModalOpen,
      foodItem: _modalFoodItem,
      editingIndex: _editingCartIndex,
    );

    // NEW: Save comment editing state
    stateProvider.updateCommentEditingState(
      editingIndex: _editingCommentIndex,
      editingText: _commentEditingController.text,
    );

    debugPrint('💾 Saved state for order type: $_actualOrderType');
    debugPrint('   - Cart items: ${_cartItems.length}');
    debugPrint('   - Customer: ${_customerDetails?.name ?? 'None'}');
    debugPrint('   - Has processed first step: $_hasProcessedFirstStep');
    debugPrint('   - Modal open: $_isModalOpen');
    debugPrint('   - Search query: "$_searchQuery"');
  }

  void _applyLoadedOrderData({
    required List<CartItem> items,
    CustomerDetails? customerDetails,
    required String paymentType,
    double? discountPercentage,
    double? discountAmount,
    String? status,
  }) {
    setState(() {
      _cartItems
        ..clear()
        ..addAll(items);
      _customerDetails = customerDetails;
      _selectedPaymentType = paymentType;
      if (discountPercentage != null) {
        _appliedDiscountPercentage = discountPercentage;
      } else {
        _appliedDiscountPercentage = 0.0;
      }
      if (discountAmount != null) {
        _discountAmount = discountAmount;
      } else {
        _discountAmount = 0.0;
      }
      // In edit mode, don't set hasProcessedFirstStep to true - show cart first
      // User must explicitly select payment to see customer details form
      _hasProcessedFirstStep = _isEditMode ? false : true;
      _showPayment = false;
      _showDiscountPage = false;
      _wasDiscountPageShown =
          discountPercentage != null && discountPercentage > 0;
      if (status != null && status.isNotEmpty) {
        _currentOrderStatus = status;
      }
    });

    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );
    stateProvider.updateCartItems(_cartItems);
    stateProvider.updateCustomerDetails(_customerDetails);
    stateProvider.updatePaymentType(_selectedPaymentType);
    // In edit mode, don't mark as processed - user must select payment first
    stateProvider.updateProcessedFirstStep(_isEditMode ? false : true);
    stateProvider.updateDiscountState(
      percentage: discountPercentage,
      amount: discountAmount,
    );
    stateProvider.updateUIState(editMode: true);
  }

  void _loadOrderFromExisting(order_model.Order order) {
    print('Page4: Applying existing order data for order ${order.orderId}');
    print('🔍 DEBUG: Order has ${order.items.length} items');
    _existingOrder = order;
    _editingOrderId ??= order.orderId;

    final List<CartItem> loadedItems =
        order.items.asMap().entries.map((entry) {
          final int index = entry.key;
          final orderItem = entry.value;

          print(
            '🔍 DEBUG: Item $index - description: "${orderItem.description}"',
          );
          print(
            '🔍 DEBUG: Item $index - itemId from OrderItem: ${orderItem.itemId}',
          );
          print('🔍 DEBUG: Item $index - itemName: "${orderItem.itemName}"');
          print(
            '🔍 DEBUG: Item $index - has nested foodItem: ${orderItem.foodItem != null}',
          );

          if (orderItem.foodItem != null) {
            print(
              '🔍 DEBUG: Item $index - nested foodItem.id: ${orderItem.foodItem!.id}',
            );
            print(
              '🔍 DEBUG: Item $index - nested foodItem.name: "${orderItem.foodItem!.name}"',
            );
          }

          final int quantity = orderItem.quantity == 0 ? 1 : orderItem.quantity;
          final double pricePerUnit =
              quantity > 0
                  ? double.parse(
                    (orderItem.totalPrice / quantity).toStringAsFixed(2),
                  )
                  : double.parse(orderItem.totalPrice.toStringAsFixed(2));

          // CRITICAL FIX: Try multiple ways to find the food item
          FoodItem? resolvedFoodItem = orderItem.foodItem;

          // Try by ID if available
          if (resolvedFoodItem == null && orderItem.itemId != null) {
            resolvedFoodItem = _findFoodItemById(orderItem.itemId!);
            print(
              '🔍 DEBUG: Item $index - found by ID: ${resolvedFoodItem != null}',
            );
          }

          // CRITICAL FIX: If still not found, try by name
          if (resolvedFoodItem == null && orderItem.itemName.isNotEmpty) {
            resolvedFoodItem = _findFoodItemByName(orderItem.itemName);
            print(
              '🔍 DEBUG: Item $index - found by name "${orderItem.itemName}": ${resolvedFoodItem != null}',
            );
            if (resolvedFoodItem != null) {
              print(
                '🔍 DEBUG: Item $index - matched to menu item: "${resolvedFoodItem.name}" (id: ${resolvedFoodItem.id})',
              );
            }
          }

          print(
            '🔍 DEBUG: Item $index - resolvedFoodItem after lookup: ${resolvedFoodItem != null}',
          );
          if (resolvedFoodItem != null) {
            print(
              '🔍 DEBUG: Item $index - resolvedFoodItem.id: ${resolvedFoodItem.id}',
            );
          }

          resolvedFoodItem ??= _createFallbackFoodItemFromOrderItem(
            orderItem,
            pricePerUnit,
          );

          print(
            '🔍 DEBUG: Item $index - FINAL resolvedFoodItem.id: ${resolvedFoodItem.id}',
          );

          final List<String> options = _extractOptionsFromDescription(
            orderItem.description,
            resolvedFoodItem.name,
          );

          return CartItem(
            foodItem: resolvedFoodItem,
            quantity: quantity,
            selectedOptions: options.isNotEmpty ? options : null,
            comment: orderItem.comment,
            pricePerUnit: pricePerUnit,
          );
        }).toList();

    final String customerName =
        order.customerName.trim().isNotEmpty
            ? order.customerName.trim()
            : 'N/A';
    final String phoneNumber = (order.phoneNumber ?? '').trim();

    final CustomerDetails customerDetails = CustomerDetails(
      name: customerName,
      phoneNumber: phoneNumber,
      email: order.customerEmail,
      streetAddress: order.streetAddress,
      city: order.city ?? order.county,
      postalCode: order.postalCode,
    );

    _applyLoadedOrderData(
      items: loadedItems,
      customerDetails: customerDetails,
      paymentType: order.paymentType,
      discountPercentage: null,
      discountAmount: null,
      status: order.status,
    );

    _existingOrder = order;

    if (mounted) {
      CustomPopupService.show(
        context,
        'Order loaded for editing',
        type: PopupType.success,
      );
    }
  }

  Future<void> _loadOrderForEditing(int orderId) async {
    print('Page4: Loading order $orderId for editing');
    final apiService = ApiService();

    try {
      final orderData = await apiService.fetchOrderById(orderId);
      if (!mounted) return;

      if (orderData == null) {
        throw Exception('Order not found');
      }

      print('🔍 DEBUG: Full order data structure: $orderData');

      final List<CartItem> loadedItems = [];
      final dynamic rawItems = orderData['items'] ?? orderData['order_items'];

      print('🔍 DEBUG: rawItems type: ${rawItems.runtimeType}');
      print('🔍 DEBUG: rawItems content: $rawItems');

      if (rawItems is List) {
        for (int i = 0; i < rawItems.length; i++) {
          final dynamic rawItem = rawItems[i];
          print('🔍 DEBUG: Item $i raw data: $rawItem');

          if (rawItem is! Map) continue;

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
            rawItem,
          );

          print('🔍 DEBUG: Item $i itemMap keys: ${itemMap.keys.toList()}');
          print(
            '🔍 DEBUG: Item $i item_id value: ${itemMap['item_id']} (type: ${itemMap['item_id'].runtimeType})',
          );

          // CRITICAL FIX: Preserve the actual item_id from the order
          // Try to parse item_id from multiple possible locations
          int? itemId = _tryParseInt(itemMap['item_id']);
          print('🔍 DEBUG: Item $i parsed itemId from item_id: $itemId');

          // If not found, try the nested food_item object
          if (itemId == null && itemMap['food_item'] is Map) {
            final Map<String, dynamic> nestedFood = Map<String, dynamic>.from(
              itemMap['food_item'] as Map,
            );
            itemId = _tryParseInt(nestedFood['id'] ?? nestedFood['item_id']);
            print(
              '🔍 DEBUG: Item $i parsed itemId from nested food_item: $itemId',
            );
          }

          // IMPORTANT: Store the original item_id to preserve it
          final int originalItemId = itemId ?? -1;
          print('🔍 DEBUG: Item $i final originalItemId: $originalItemId');

          // Try to find matching food item in current menu
          final FoodItem? matchedFoodItem =
              itemId != null ? _findFoodItemById(itemId) : null;
          print(
            '🔍 DEBUG: Item $i matchedFoodItem found: ${matchedFoodItem != null}',
          );

          final double totalPrice = _parseToDouble(
            itemMap['total_price'] ?? itemMap['item_total_price'],
          );
          final int quantity = _tryParseInt(itemMap['quantity']) ?? 1;
          final double pricePerUnit =
              quantity > 0 ? totalPrice / quantity : totalPrice;

          FoodItem? effectiveFoodItem = matchedFoodItem;
          if (effectiveFoodItem == null && itemMap['food_item'] is Map) {
            print(
              '🔍 DEBUG: Item $i has nested food_item, attempting to parse',
            );
            print(
              '🔍 DEBUG: Item $i nested food_item data: ${itemMap['food_item']}',
            );
            try {
              effectiveFoodItem = FoodItem.fromJson(
                Map<String, dynamic>.from(itemMap['food_item'] as Map),
              );
              print(
                '🔍 DEBUG: Item $i created FoodItem from nested food_item, id: ${effectiveFoodItem.id}',
              );
            } catch (e) {
              print('🔍 DEBUG: Item $i FAILED to parse nested food_item: $e');
            }
          }

          // CRITICAL FIX: Always use originalItemId to preserve the actual item ID
          final FoodItem resolvedFoodItem =
              effectiveFoodItem ??
              _createFallbackFoodItem(itemMap, originalItemId, pricePerUnit);

          print(
            '🔍 DEBUG: Item $i FINAL resolvedFoodItem.id: ${resolvedFoodItem.id}',
          );
          print(
            '🔍 DEBUG: Item $i FINAL resolvedFoodItem.name: ${resolvedFoodItem.name}',
          );

          final String description =
              itemMap['description']?.toString() ??
              itemMap['item_description']?.toString() ??
              resolvedFoodItem.name;

          final List<String> options = _extractOptionsFromDescription(
            description,
            resolvedFoodItem.name,
          );

          loadedItems.add(
            CartItem(
              foodItem: resolvedFoodItem,
              quantity: quantity,
              selectedOptions: options.isNotEmpty ? options : null,
              comment: itemMap['comment']?.toString(),
              pricePerUnit: double.parse(pricePerUnit.toStringAsFixed(2)),
            ),
          );
        }
      }

      final CustomerDetails? loadedCustomerDetails =
          _buildCustomerDetailsFromOrder(orderData);
      final double? discountPercentage = _parseNullableDouble(
        orderData['discount_percentage'],
      );
      final double? discountAmount = _parseNullableDouble(
        orderData['discount_amount'] ?? orderData['discount'],
      );
      final String paymentType = orderData['payment_type']?.toString() ?? '';

      _applyLoadedOrderData(
        items: loadedItems,
        customerDetails: loadedCustomerDetails,
        paymentType: paymentType,
        discountPercentage: discountPercentage,
        discountAmount: discountAmount,
        status: orderData['status']?.toString(),
      );

      if (mounted) {
        CustomPopupService.show(
          context,
          'Order loaded for editing',
          type: PopupType.success,
        );
      }
    } catch (e) {
      print('Page4: Error loading order for editing: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to load order for editing',
          type: PopupType.failure,
        );
      }
    }
  }

  Future<void> _updateExistingOrder(PaymentDetails paymentDetails) async {
    if (_editingOrderId == null) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Unable to update order: missing order ID',
          type: PopupType.failure,
        );
      }
      return;
    }

    try {
      print(
        'Page4: Updating existing order $_editingOrderId with payment type ${paymentDetails.paymentType}',
      );

      final List<Map<String, dynamic>> itemsPayload =
          _cartItems.map((cartItem) {
            final String description = _buildDescriptionForCartItem(cartItem);
            final double itemTotalPrice = double.parse(
              (cartItem.pricePerUnit * cartItem.quantity).toStringAsFixed(2),
            );

            // CRITICAL WARNING: Check if item_id is -1 (invalid)
            if (cartItem.foodItem.id == -1) {
              print(
                '⚠️⚠️⚠️ WARNING: Cart item "${cartItem.foodItem.name}" has invalid item_id = -1!',
              );
              print(
                '⚠️ This will cause the update to fail. Item should have a valid menu item ID.',
              );
              print('⚠️ Cart item details: ${cartItem.foodItem.toJson()}');
            }

            return {
              "item_id": cartItem.foodItem.id.toString(),
              "quantity": cartItem.quantity,
              "description": description,
              "total_price": itemTotalPrice,
              if ((cartItem.comment ?? '').isNotEmpty)
                "comment": cartItem.comment,
            };
          }).toList();

      final double itemsSubtotal = itemsPayload.fold<double>(
        0.0,
        (sum, item) => sum + (item['total_price'] as double),
      );
      final double deliveryChargeAmount =
          _shouldApplyDeliveryCharge(_actualOrderType, _selectedPaymentType)
              ? 1.50
              : 0.0;
      final double totalBeforeDiscount = double.parse(
        (itemsSubtotal + deliveryChargeAmount).toStringAsFixed(2),
      );
      final double discountAmount = double.parse(
        _calculateDiscountAmount().toStringAsFixed(2),
      );

      print('🔄 Updating order $_editingOrderId:');
      print('   Payment Type: ${paymentDetails.paymentType}');
      print('   Paid Status: ${paymentDetails.paidStatus}');
      print('   Total Price: $totalBeforeDiscount');

      final apiService = ApiService();
      final bool success = await apiService.updateOrderCart(
        orderId: _editingOrderId!,
        items: itemsPayload,
        totalPrice: totalBeforeDiscount,
        discount: discountAmount,
        currentStatus: _currentOrderStatus,
      );

      if (!mounted) return;

      if (success) {
        // Also update payment status separately using existing API
        final bool paymentUpdated = await ApiService.markOrderAsPaid(
          _editingOrderId!,
          paymentType: paymentDetails.paymentType,
        );

        if (!mounted) return;

        if (!paymentUpdated) {
          print('⚠️ Warning: Cart updated but payment status update failed');
        }

        final stateProvider = Provider.of<Page4StateProvider>(
          context,
          listen: false,
        );
        stateProvider.resetCurrentOrderType();
        Navigator.pop(context, true);
      } else {
        CustomPopupService.show(
          context,
          'Failed to update order',
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Page4: Error updating order $_editingOrderId: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to update order',
          type: PopupType.failure,
        );
      }
    }
  }

  void _populateSubcategories() {
    // Extract unique subtypes for Wings category
    final wingsItems = foodItems.where(
      (item) => item.category.toLowerCase() == 'wings',
    );
    final wingsSubtypes =
        wingsItems
            .map((item) => item.subType)
            .where((subType) => subType != null && subType.trim().isNotEmpty)
            .map((subType) => subType!.trim())
            .toSet()
            .toList();
    wingsSubtypes.sort(); // Sort alphabetically
    _wingsSubcategories = wingsSubtypes;

    // Extract unique subtypes for Deals category
    final dealsItems = foodItems.where(
      (item) => item.category.toLowerCase() == 'deals',
    );
    final dealsSubtypes =
        dealsItems
            .map((item) => item.subType)
            .where((subType) => subType != null && subType.trim().isNotEmpty)
            .map((subType) => subType!.trim())
            .toSet()
            .toList();
    dealsSubtypes.sort(); // Sort alphabetically
    _dealsSubcategories = dealsSubtypes;

    // Extract unique subtypes for Pizza category
    final pizzaItems = foodItems.where(
      (item) => item.category.toLowerCase() == 'pizza',
    );
    final pizzaSubtypes =
        pizzaItems
            .map((item) => item.subType)
            .where((subType) => subType != null && subType.trim().isNotEmpty)
            .map((subType) => subType!.trim())
            .toSet()
            .toList();
    pizzaSubtypes.sort(); // Sort alphabetically
    _pizzaSubcategories = pizzaSubtypes;

    print("Page4: Wings subcategories: $_wingsSubcategories");
    print("Page4: Deals subcategories: $_dealsSubcategories");
    print("Page4: Pizza subcategories: $_pizzaSubcategories");
  }

  void _getLeftPanelDimensions() {
    final RenderBox? renderBox =
        _leftPanelKey.currentContext?.findRenderObject() as RenderBox?;
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
  void deactivate() {
    // Skip state saving during deactivation to avoid build cycle conflicts
    // State should already be saved during normal user interactions throughout the widget lifecycle
    debugPrint(
      '🔄 Page4: Widget deactivating - state already saved during normal lifecycle',
    );
    super.deactivate();
  }

  @override
  void dispose() {
    // State is saved throughout normal widget lifecycle, no need to save during disposal

    _categoryScrollController.removeListener(_updateScrollButtonVisibility);
    _categoryScrollController.dispose();
    _searchController.removeListener(() => setState(() {}));
    _searchController.dispose();
    _searchFocusNode.dispose();
    _commentEditingController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _pinController.dispose();

    // Add these new disposals
    _editNameController.dispose();
    _editPhoneController.dispose();
    _editEmailController.dispose();
    _editAddressController.dispose();
    _editCityController.dispose();
    _editPostalCodeController.dispose();

    super.dispose();
  }

  void _updateScrollButtonVisibility() {
    setState(() {
      _canScrollLeft =
          _categoryScrollController.offset >
          _categoryScrollController.position.minScrollExtent;
      _canScrollRight =
          _categoryScrollController.offset <
          _categoryScrollController.position.maxScrollExtent;
    });
  }

  void fetchItems() async {
    try {
      final items = await ApiService.fetchMenuItems();
      print("Page4: Items fetched successfully: ${items.length}");

      final categoriesInData = items.map((e) => e.category).toSet();
      print("Page4: Categories in data: $categoriesInData");

      setState(() {
        foodItems = items;
        isLoading = false;
      });

      // Also update the ItemAvailabilityProvider if items were fetched successfully
      if (mounted) {
        final itemProvider = Provider.of<ItemAvailabilityProvider>(
          context,
          listen: false,
        );
        if (itemProvider.allItems.isEmpty) {
          print("Page4: Updating ItemAvailabilityProvider with fetched items");
          itemProvider.refresh();
        }
      }
    } catch (e) {
      print('Page4: Error fetching items: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        // Only show error popup if we don't have any fallback data
        final hasAnyData = widget.foodItems.isNotEmpty || foodItems.isNotEmpty;
        if (!hasAnyData) {
          CustomPopupService.show(
            context,
            'Failed to load menu items. Please check your internet connection and try again.',
            type: PopupType.failure,
          );
        } else {
          print("Page4: Using fallback data while connection is restored");
        }
      }
    }
  }

  // Production-safe menu item health check
  void _startMenuItemHealthCheck() {
    if (!mounted) return;

    // Check every 30 seconds if menu items are available
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final itemProvider = Provider.of<ItemAvailabilityProvider>(
        context,
        listen: false,
      );
      final providerHasItems = itemProvider.allItems.isNotEmpty;
      final widgetHasItems = widget.foodItems.isNotEmpty;
      final localHasItems = foodItems.isNotEmpty;

      // If all sources are empty, try to refresh
      if (!providerHasItems && !widgetHasItems && !localHasItems) {
        print(
          "🚨 Page4 Health Check: All menu item sources empty! Attempting recovery...",
        );

        // Try to refresh the provider first
        itemProvider.refresh();

        // Also try local fetch as backup
        fetchItems();
      }

      // If provider is empty but we have local data, sync it
      if (!providerHasItems && (widgetHasItems || localHasItems)) {
        print(
          "🔄 Page4 Health Check: Provider empty but local data available, syncing...",
        );
        itemProvider.refresh();
      }
    });
  }

  double _calculateCartItemsTotal() {
    double total = 0.0;
    for (var item in _cartItems) {
      // Use item.totalPrice to include extraAmount (e.g., rush fees)
      total += item.totalPrice;
    }
    return total;
  }

  double _calculateTotalPrice() {
    double total = _calculateCartItemsTotal();

    // Add delivery charge for delivery orders
    if (_shouldApplyDeliveryCharge(_actualOrderType, _selectedPaymentType)) {
      total += 1.50;
    }

    return total;
  }

  //Method to calculate discount amount based on current cart total
  double _calculateDiscountAmount() {
    if (_appliedDiscountPercentage <= 0) {
      return 0.0;
    }
    return (_calculateTotalPrice() * _appliedDiscountPercentage) / 100;
  }

  //  Method to get final total after discount
  double _getFinalTotal() {
    return _calculateTotalPrice() - _calculateDiscountAmount();
  }

  FoodItem? _findFoodItemById(int itemId) {
    try {
      return foodItems.firstWhere((item) => item.id == itemId);
    } catch (_) {
      return null;
    }
  }

  FoodItem? _findFoodItemByName(String itemName) {
    try {
      // Try exact match first
      final exactMatch = foodItems.firstWhere(
        (item) => item.name.toLowerCase() == itemName.toLowerCase(),
      );
      return exactMatch;
    } catch (_) {
      // Try partial match (contains)
      try {
        final partialMatch = foodItems.firstWhere(
          (item) =>
              item.name.toLowerCase().contains(itemName.toLowerCase()) ||
              itemName.toLowerCase().contains(item.name.toLowerCase()),
        );
        return partialMatch;
      } catch (_) {
        return null;
      }
    }
  }

  FoodItem _createFallbackFoodItem(
    Map<String, dynamic> itemMap,
    int itemId,
    double pricePerUnit,
  ) {
    final String rawDescription =
        itemMap['description']?.toString() ??
        itemMap['item_name']?.toString() ??
        '';
    final List<String> descriptionLines =
        rawDescription
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    final String candidateName =
        itemMap['item_name']?.toString() ??
        (descriptionLines.isNotEmpty ? descriptionLines.first : rawDescription);
    final String name =
        candidateName.isNotEmpty ? candidateName : 'Unknown Item';
    final String category =
        itemMap['item_type']?.toString() ??
        itemMap['type']?.toString() ??
        'OTHER';

    return FoodItem(
      id: itemId,
      name: name,
      category: category,
      price: {'default': double.parse(pricePerUnit.toStringAsFixed(2))},
      image: '',
      availability: true,
    );
  }

  FoodItem _createFallbackFoodItemFromOrderItem(
    order_model.OrderItem orderItem,
    double pricePerUnit,
  ) {
    final List<String> descriptionLines =
        orderItem.description
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    final String fallbackFromDescription =
        descriptionLines.isNotEmpty
            ? descriptionLines.first
            : orderItem.description;

    final String candidateName =
        orderItem.itemName.isNotEmpty
            ? orderItem.itemName
            : fallbackFromDescription;

    final String name =
        candidateName.isNotEmpty ? candidateName : 'Unknown Item';

    final String category =
        orderItem.itemType.isNotEmpty ? orderItem.itemType : 'OTHER';

    return FoodItem(
      id: orderItem.itemId ?? -1,
      name: name,
      category: category,
      price: {'default': double.parse(pricePerUnit.toStringAsFixed(2))},
      image: orderItem.imageUrl ?? '',
      availability: true,
    );
  }

  List<String> _extractOptionsFromDescription(
    String description,
    String itemName,
  ) {
    final String trimmed = description.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final List<String> lines =
        trimmed
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    if (lines.length > 1) {
      final String normalizedItemName = itemName.trim().toLowerCase();
      return lines
          .skip(1)
          .where((line) => line.trim().toLowerCase() != normalizedItemName)
          .toList();
    }

    final int start = trimmed.indexOf('(');
    final int end = trimmed.lastIndexOf(')');
    if (start != -1 && end != -1 && end > start) {
      final String inside = trimmed.substring(start + 1, end);
      return inside
          .split(',')
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toList();
    }

    return [];
  }

  String _buildDescriptionForCartItem(CartItem cartItem) {
    final List<String> options =
        cartItem.selectedOptions
            ?.map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList() ??
        [];

    if (options.isEmpty) {
      return cartItem.foodItem.name;
    }

    final StringBuffer buffer = StringBuffer(cartItem.foodItem.name);
    for (final option in options) {
      buffer.writeln();
      buffer.write(option);
    }

    return buffer.toString();
  }

  double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
      if (sanitized.isEmpty) return null;
      return double.tryParse(sanitized);
    }
    return null;
  }

  double _parseToDouble(dynamic value) {
    return _parseNullableDouble(value) ?? 0.0;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9-]'), '');
      if (sanitized.isEmpty) return null;
      return int.tryParse(sanitized);
    }
    return null;
  }

  CustomerDetails? _buildCustomerDetailsFromOrder(
    Map<String, dynamic> orderData,
  ) {
    final Map<String, dynamic>? guest =
        orderData['guest'] is Map
            ? Map<String, dynamic>.from(orderData['guest'] as Map)
            : null;

    String name = orderData['customer_name']?.toString() ?? '';
    if (name.isEmpty) {
      name = guest?['name']?.toString() ?? '';
    }

    String phoneNumber = orderData['phone_number']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      phoneNumber =
          guest?['phone_number']?.toString() ??
          guest?['phone']?.toString() ??
          '';
    }

    String? email = orderData['customer_email']?.toString();
    email =
        (email != null && email.isNotEmpty)
            ? email
            : guest?['email']?.toString();

    String? streetAddress = orderData['street_address']?.toString();
    streetAddress =
        (streetAddress != null && streetAddress.isNotEmpty)
            ? streetAddress
            : guest?['street_address']?.toString();

    String? city = orderData['city']?.toString();
    city =
        (city != null && city.isNotEmpty) ? city : guest?['city']?.toString();

    String? postalCode = orderData['postal_code']?.toString();
    postalCode =
        (postalCode != null && postalCode.isNotEmpty)
            ? postalCode
            : guest?['postal_code']?.toString();

    final bool hasBasicInfo =
        name.isNotEmpty ||
        phoneNumber.isNotEmpty ||
        (email?.isNotEmpty ?? false);

    if (!hasBasicInfo) {
      return null;
    }

    return CustomerDetails(
      name: name.isNotEmpty ? name : 'N/A',
      phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : 'N/A',
      email: email?.isNotEmpty == true ? email : null,
      streetAddress: streetAddress?.isNotEmpty == true ? streetAddress : null,
      city: city?.isNotEmpty == true ? city : null,
      postalCode: postalCode?.isNotEmpty == true ? postalCode : null,
    );
  }

  String generateTransactionId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  void _startEditingComment(int index, String? currentComment) {
    setState(() {
      _editingCommentIndex = index;
      _commentEditingController.text = currentComment ?? '';
    });

    // NEW: Save comment editing state to provider
    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );
    stateProvider.updateCommentEditingState(
      editingIndex: index,
      editingText: currentComment ?? '',
    );

    if (_commentFocusNode.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

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
          comment:
              newComment.isEmpty ? null : newComment, // Set to null if empty
        );

        setState(() {
          _cartItems[_editingCommentIndex!] = updatedCartItem;
        });

        print(
          'Simulating backend update for item comment: ${itemToUpdate.foodItem.name} new comment: "$newComment"',
        );
        print(
          'The updated CartItem is now: ${updatedCartItem.foodItem.name}, Comment: ${updatedCartItem.comment}',
        );

        if (mounted) {
          CustomPopupService.show(
            context,
            'Comment updated locally',
            type: PopupType.success,
          );
        }
      }

      setState(() {
        _editingCommentIndex = null;
        _commentEditingController.clear();
      });

      // NEW: Clear comment editing state in provider
      final stateProvider = Provider.of<Page4StateProvider>(
        context,
        listen: false,
      );
      stateProvider.updateCommentEditingState(
        editingIndex: null,
        editingText: '',
      );
    }
  }

  Widget _buildCustomerDetailsDisplay() {
    if (_customerDetails == null ||
        _actualOrderType.toLowerCase() != 'delivery') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child:
              _isEditingCustomerDetails
                  ? _buildEditingCustomerDetails()
                  : _buildDisplayCustomerDetails(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDisplayCustomerDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.person, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Poppins',
              ),
            ),
            const Spacer(),
            // Edit button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _startEditingCustomerDetails,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Customer details in a compact row format
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            // Name
            _buildDetailChip(
              icon: Icons.person_outline,
              label: 'Name',
              value: _customerDetails!.name,
            ),

            // Phone
            if (_customerDetails!.phoneNumber.isNotEmpty)
              _buildDetailChip(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _customerDetails!.phoneNumber,
              ),

            // Email (if provided)
            if (_customerDetails!.email != null &&
                _customerDetails!.email!.isNotEmpty)
              _buildDetailChip(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _customerDetails!.email!,
              ),

            // Address (if provided)
            if (_customerDetails!.streetAddress != null &&
                _customerDetails!.streetAddress!.isNotEmpty)
              _buildDetailChip(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value:
                    '${_customerDetails!.streetAddress!}${_customerDetails!.city != null ? ', ${_customerDetails!.city!}' : ''}${_customerDetails!.postalCode != null ? ' ${_customerDetails!.postalCode!}' : ''}',
                isAddress: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditingCustomerDetails() {
    return Form(
      key: _editFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.edit, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Edit Customer Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name field
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editNameController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter customer name';
                }
                if (!_nameRegExp.hasMatch(value)) {
                  return 'Name can only contain letters, spaces, hyphens, or apostrophes';
                }
                return null;
              },
            ),
          ),

          // Phone field
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editPhoneController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'e.g., 07123456789',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                hintStyle: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (!_validateUKPhoneNumber(value)) {
                  return 'Please enter a valid UK phone number';
                }
                return null;
              },
            ),
          ),

          // Email field
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editEmailController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Email (Optional)',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                // Email is now optional - only validate format if provided
                if (value != null &&
                    value.isNotEmpty &&
                    !_emailRegExp.hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),

          // Address field
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editAddressController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Street Address *',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter street address';
                }
                return null;
              },
            ),
          ),

          // City field
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editCityController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'City *',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter city';
                }
                return null;
              },
            ),
          ),

          // Postal Code field
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _editPostalCodeController,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Postal Code *',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB6CE6),
                    width: 2.0,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter postal code';
                }
                return null;
              },
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _cancelEditingCustomerDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _saveCustomerDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
    bool isAddress = false,
  }) {
    double getMaxWidth() {
      if (isAddress) return double.infinity;
      if (label == 'Email') return 250;
      return 200;
    }

    return Container(
      constraints: BoxConstraints(maxWidth: getMaxWidth()),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold, // Made bold
                      color: Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isAddress ? 2 : 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<OrderCountsProvider>(context);
    final itemProvider = Provider.of<ItemAvailabilityProvider>(context);
    final List<FoodItem> foodItems = itemProvider.allItems;
    final bool isLoading = itemProvider.isLoading;

    // Handle loading and error states from the provider
    if (isLoading && foodItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    const double bottomNavBarHeight = 80.0;

    final double availableModalHeight = screenHeight - bottomNavBarHeight;

    final double modalDesiredWidth = min(screenWidth * 0.6, 1200.0);
    final double modalActualWidth = min(modalDesiredWidth, screenWidth * 0.9);

    final double modalDesiredHeight = min(availableModalHeight * 0.9, 900.0);
    double modalActualHeight = min(
      modalDesiredHeight,
      availableModalHeight * 0.9,
    );

    final double modalLeftOffset =
        _leftPanelRect.left + (_leftPanelRect.width - modalActualWidth) / 2;

    double modalTopOffset =
        _leftPanelRect.top + (_leftPanelRect.height - modalActualHeight) / 2;

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
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Dismiss keyboard when tapping outside
              FocusScope.of(context).unfocus();
              _searchFocusNode.unfocus();

              // Collapse search bar if expanded
              if (_isSearchBarExpanded) {
                setState(() {
                  _isSearchBarExpanded = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              }
            },
            child: Column(
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
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                        ),
                                        height: 13,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF2D9F9),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      _buildShawarmaSubcategoryTabs(),
                                      Expanded(child: _buildItemGrid()),
                                    ],
                                  ),

                                  if (_isModalOpen)
                                    Positioned.fill(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10.0,
                                          sigmaY: 10.0,
                                        ),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  _isModalOpen
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.symmetric(
                                        vertical: 20.0,
                                      ),
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
                                    Expanded(child: _buildRightPanelContent()),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // FoodItemDetailsModal (positioned over the whole screen but visually over left panel)
                      if (_isModalOpen &&
                          _modalFoodItem != null &&
                          _leftPanelRect != Rect.zero)
                        Positioned(
                          left: modalLeftOffset,
                          top: modalTopOffset,
                          width: modalActualWidth,
                          height: modalActualHeight,
                          child: Consumer<ItemAvailabilityProvider>(
                            builder: (context, itemProvider, child) {
                              final List<FoodItem> providerItems =
                                  itemProvider.allItems;
                              final List<FoodItem> allAvailableItems =
                                  providerItems.isNotEmpty
                                      ? providerItems
                                      : (widget.foodItems.isNotEmpty
                                          ? widget.foodItems
                                          : foodItems);

                              return FoodItemDetailsModal(
                                foodItem: _modalFoodItem!,
                                allFoodItems: allAvailableItems,
                                onAddToCart: _handleItemAdditionOrUpdate,
                                onClose: () {
                                  setState(() {
                                    _isModalOpen = false;
                                    _modalFoodItem = null;
                                    _editingCartIndex = null;
                                  });

                                  // NEW: Save modal state to provider
                                  final stateProvider =
                                      Provider.of<Page4StateProvider>(
                                        context,
                                        listen: false,
                                      );
                                  stateProvider.updateModalState(
                                    isOpen: false,
                                    foodItem: null,
                                    editingIndex: null,
                                  );
                                },
                                initialCartItem:
                                    _editingCartIndex != null &&
                                            _editingCartIndex! >= 0 &&
                                            _editingCartIndex! <
                                                _cartItems.length
                                        ? _cartItems[_editingCartIndex!]
                                        : null,
                                isEditing: _editingCartIndex != null,
                              );
                            },
                          ),
                        ),

                      // Add Item Modal
                      if (_showAddItemModal)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Container(
                                  margin: EdgeInsets.all(20),
                                  constraints: BoxConstraints(
                                    maxWidth: 500,
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                        0.8,
                                  ),
                                ),
                              ),
                            ),
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
          ),

          // Blur overlay when sending payment link
          if (_isSendingPaymentLink)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFCB6CE6),
                              ),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Sending Payment Link...',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please wait while we send the payment link to the customer',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'DEALS':
        return 'assets/images/deals.png';
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMAS':
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
      // case 'DESSERTS':
      //   return 'assets/images/Desserts.png';
      // case 'CHICKEN':
      //   return 'assets/images/Chicken.png';
      // case 'KEBABS':
      //   return 'assets/images/Kebabs.png';
      // case 'WINGS':
      //   return 'assets/images/Wings.png';
      default:
        return 'assets/images/default.png';
    }
  }

  List<String> _formatDealOptions(List<String> selectedOptions) {
    List<String> formattedOptions = [];

    // Group options by type
    List<String> dealFlavours = [];
    Map<String, List<String>> itemGroups = {};
    List<String> drinks = [];
    List<String> sides = [];

    for (String option in selectedOptions) {
      String lowerOption = option.toLowerCase();

      // Check if this is already a properly formatted Combo Meal or Pizza Offers item
      if (option.startsWith('Pizza (12"): ') ||
          option.startsWith('Shawarma: ') ||
          option.startsWith('Burger: ') ||
          (option.startsWith('Drink: ') && lowerOption.contains('1.5l')) ||
          option.startsWith('Size: ') ||
          option.startsWith('Selected Pizzas: ')) {
        // Already formatted by Combo Meal or Pizza Offers logic - add as-is
        formattedOptions.add(option);
        continue;
      }

      if (lowerOption.contains('flavour') || lowerOption.contains('flavor')) {
        dealFlavours.add(option);
      } else if (lowerOption.contains('shawarma')) {
        if (!itemGroups.containsKey('Shawarmas')) itemGroups['Shawarmas'] = [];
        itemGroups['Shawarmas']!.add(option);
      } else if (lowerOption.contains('pizza')) {
        if (!itemGroups.containsKey('Pizzas')) itemGroups['Pizzas'] = [];
        itemGroups['Pizzas']!.add(option);
      } else if (lowerOption.contains('burger')) {
        if (!itemGroups.containsKey('Burgers')) itemGroups['Burgers'] = [];
        itemGroups['Burgers']!.add(option);
      } else if (lowerOption.contains('drink') ||
          lowerOption.contains('can') ||
          lowerOption.contains('bottle') ||
          lowerOption.contains('pepsi') ||
          lowerOption.contains('coke') ||
          lowerOption.contains('sprite') ||
          lowerOption.contains('1.5l') ||
          lowerOption.contains('330ml')) {
        drinks.add(option);
      } else if (lowerOption.contains('chips') ||
          lowerOption.contains('fries') ||
          lowerOption.contains('side')) {
        sides.add(option);
      } else {
        // Add other options as-is for now
        if (!lowerOption.contains('selected') &&
            !lowerOption.contains('options')) {
          if (!itemGroups.containsKey('Items')) itemGroups['Items'] = [];
          itemGroups['Items']!.add(option);
        }
      }
    }

    // Add deal flavours first
    formattedOptions.addAll(dealFlavours);

    // Format each group
    itemGroups.forEach((groupName, items) {
      if (groupName == 'Shawarmas') {
        formattedOptions.addAll(_formatShawarmaGroup(items));
      } else if (groupName == 'Pizzas') {
        formattedOptions.addAll(_formatPizzaGroup(items));
      } else if (groupName == 'Burgers') {
        formattedOptions.addAll(_formatBurgerGroup(items));
      } else {
        formattedOptions.addAll(items);
      }
    });

    // Add drinks
    for (String drink in drinks) {
      // Avoid duplicate "Drink:" prefix if already present
      if (drink.startsWith('Drink:')) {
        formattedOptions.add(drink);
      } else {
        formattedOptions.add('Drink: $drink');
      }
    }

    // Add sides without "Sides:" prefix
    formattedOptions.addAll(sides);

    return formattedOptions;
  }

  List<String> _formatShawarmaGroup(List<String> shawarmas) {
    List<String> formattedItems = [];

    for (int i = 0; i < shawarmas.length; i++) {
      String shawarma = shawarmas[i];

      // The cart items now come in the NEW format: "Shawarma 1 (Salad: Cucumber, Lettuce & Sauces: Ketchup, BBQ)"
      // or "Shawarma 1 (No Salad & No Sauce)"
      // Format them for receipt with proper line breaks for better readability
      if (shawarma.startsWith('Shawarma ') && shawarma.contains('(')) {
        // Format for receipt with line breaks
        String formattedShawarma = _formatShawarmaForReceipt(shawarma);
        formattedItems.add(formattedShawarma);
      } else {
        // Fallback for legacy format - extract salad and sauce info
        List<String> itemDetails = [];

        // Check for salad
        if (shawarma.toLowerCase().contains('salad')) {
          itemDetails.add('Salad');
        } else {
          itemDetails.add('No Salad');
        }

        // Check for sauces
        List<String> sauces = _extractSauces(shawarma);
        if (sauces.isNotEmpty) {
          itemDetails.add('Sauce: ${sauces.join(', ')}');
        } else {
          itemDetails.add('No Sauce');
        }

        // Apply same receipt formatting logic for legacy format
        String legacyFormatted =
            'Shawarma ${i + 1} (${itemDetails.join(' & ')})';
        formattedItems.add(_formatShawarmaForReceipt(legacyFormatted));
      }
    }

    return formattedItems;
  }

  /// Formats a Shawarma item for receipt with proper line breaks for salads and sauces
  String _formatShawarmaForReceipt(String shawarma) {
    // Example input: "Shawarma 1 (Salad: Onions, Tomato & Sauces: Chilli Sauce, Sweet Chilli)"
    // Example output: "Shawarma 1\n(Salad: Onions, Tomato &\nSauces: Chilli Sauce, Sweet Chilli);"

    if (!shawarma.contains('(') || !shawarma.contains(')')) {
      return '$shawarma;'; // Return as-is if no parentheses
    }

    // Extract the shawarma number and the details in parentheses
    int openParenIndex = shawarma.indexOf('(');
    String shawarmaName = shawarma.substring(0, openParenIndex).trim();
    String details =
        shawarma
            .substring(openParenIndex + 1, shawarma.lastIndexOf(')'))
            .trim();

    // Check if it's "No Salad & No Sauce" - keep on same line
    if (details.contains('No Salad & No Sauce')) {
      return '$shawarma;';
    }

    // Check if it contains salads or sauces
    bool hasSalad = details.contains('Salad:');
    bool hasSauce = details.contains('Sauces:');

    if (!hasSalad && !hasSauce) {
      return '$shawarma;'; // No salads or sauces, keep as-is
    }

    // Start formatting with line breaks for receipt
    if (hasSalad || hasSauce) {
      // Split the details by '&' to separate salad and sauce sections
      List<String> sections = details.split('&').map((s) => s.trim()).toList();

      String formattedDetails = '(';
      for (int i = 0; i < sections.length; i++) {
        String section = sections[i].trim();

        if (i == 0) {
          // First section (usually salad)
          formattedDetails += section;
        } else {
          // Subsequent sections (usually sauces) - add newline before
          formattedDetails += '\n$section';
        }

        if (i < sections.length - 1) {
          formattedDetails += ' &';
        }
      }
      formattedDetails += ');';

      // Add line break before the details if they contain salad or sauce info
      return '$shawarmaName\n$formattedDetails';
    }

    return '$shawarma;';
  }

  /// Formats Family Meal and Combo Meal items with line breaks for Burger/Shawarma components
  List<String> _formatFamilyComboMealOptions(List<String> selectedOptions) {
    List<String> formattedOptions = [];

    for (String option in selectedOptions) {
      // Check if this is a Burger or Shawarma component with Salad/Sauces
      if ((option.contains('Burger') || option.contains('Shawarma')) &&
          option.contains('(') &&
          option.contains(')') &&
          (option.contains('Salad:') || option.contains('Sauces:'))) {
        // Apply line break formatting using the same logic as Shawarma receipts
        String formattedOption = _formatShawarmaForReceipt(option);
        formattedOptions.add(formattedOption);
      } else {
        // For non-Burger/Shawarma items (Pizza, Drinks, etc.), keep as-is
        formattedOptions.add(option);
      }
    }

    return formattedOptions;
  }

  /// Formats cart items for receipt preview by applying deal formatting
  List<CartItem> _formatCartItemsForReceipt(List<CartItem> cartItems) {
    return cartItems.map((item) {
      // Create a copy of the item with formatted options for deals
      if (item.foodItem.category == 'Deals' &&
          item.selectedOptions != null &&
          item.selectedOptions!.isNotEmpty) {
        List<String> formattedOptions;
        if (item.foodItem.name.toLowerCase() == 'family meal' ||
            item.foodItem.name.toLowerCase() == 'combo meal') {
          formattedOptions = _formatFamilyComboMealOptions(
            item.selectedOptions!,
          );
        } else {
          formattedOptions = _formatDealOptions(item.selectedOptions!);
        }

        return CartItem(
          foodItem: item.foodItem,
          quantity: item.quantity,
          selectedOptions: formattedOptions,
          pricePerUnit: item.pricePerUnit,
          comment: item.comment,
        );
      }

      // Return original item if not a deal
      return item;
    }).toList();
  }

  List<String> _formatPizzaGroup(List<String> pizzas) {
    List<String> formattedItems = [];

    for (int i = 0; i < pizzas.length; i++) {
      String pizza = pizzas[i];
      String formattedItem = _extractItemName(pizza);

      // Extract sauce info for Pizza
      List<String> sauces = _extractSauces(pizza);
      String sauceInfo;
      if (sauces.isNotEmpty) {
        sauceInfo =
            sauces.length == 1
                ? 'Sauce Dip: ${sauces[0]}'
                : 'Sauce Dips: ${sauces.join(', ')}';
      } else {
        sauceInfo = 'No Sauce';
      }

      formattedItems.add('${formattedItem} (${sauceInfo});');
    }

    return formattedItems;
  }

  List<String> _formatBurgerGroup(List<String> burgers) {
    List<String> formattedItems = [];

    for (int i = 0; i < burgers.length; i++) {
      String burger = burgers[i];

      // Check if the burger already has the new format with parentheses and salad/sauce info
      if (burger.contains('(') &&
          burger.contains(')') &&
          (burger.contains('Salad:') || burger.contains('Sauces:'))) {
        // Format for receipt with line breaks using same logic as Shawarma
        String formattedBurger = _formatShawarmaForReceipt(burger);
        formattedItems.add(formattedBurger);
      } else {
        // Legacy format - extract item name and build format
        String formattedItem = _extractItemName(burger);

        // Extract salad and sauce info for Burger
        List<String> itemDetails = [];

        // Check for salad
        if (burger.toLowerCase().contains('salad')) {
          itemDetails.add('Salad');
        } else {
          itemDetails.add('No Salad');
        }

        // Check for sauces
        List<String> sauces = _extractSauces(burger);
        if (sauces.isNotEmpty) {
          itemDetails.add('Sauces: ${sauces.join(', ')}');
        } else {
          itemDetails.add('No Sauce');
        }

        // Apply same receipt formatting logic for legacy format
        String legacyFormatted =
            '${formattedItem} (${itemDetails.join(' & ')})';
        formattedItems.add(_formatShawarmaForReceipt(legacyFormatted));
      }
    }

    return formattedItems;
  }

  String _extractItemName(String option) {
    // Extract the main item name from the option string
    if (option.contains(':')) {
      return option.split(':')[0].trim();
    }
    return option.trim();
  }

  List<String> _extractSauces(String option) {
    List<String> sauces = [];
    String lowerOption = option.toLowerCase();

    // Common sauce names
    List<String> sauceNames = [
      'ketchup',
      'mint sauce',
      'bbq',
      'mayo',
      'garlic',
      'hot sauce',
      'chili',
    ];

    for (String sauce in sauceNames) {
      if (lowerOption.contains(sauce)) {
        sauces.add(sauce);
      }
    }

    return sauces;
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_isSearchBarExpanded) {
          setState(() {
            _isSearchBarExpanded = false;
            _searchController.clear();
            _searchQuery = '';
          });
        } else {
          // Save state before going back
          _saveCurrentState();
          Navigator.pop(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 50, right: 120, top: 20),
            child: Row(
              children: [
                // Back Arrow Button
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    if (_isSearchBarExpanded) {
                      setState(() {
                        _isSearchBarExpanded = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    } else {
                      Navigator.pop(context);
                    }
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
                // Animated search bar container
                GestureDetector(
                  onTap: () {
                    // Prevent the outside tap from closing when tapping on search bar
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width:
                        _isSearchBarExpanded
                            ? 850 // Your preferred width
                            : 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (!_isSearchBarExpanded) {
                            _isSearchBarExpanded = true;
                            _searchFocusNode.requestFocus();
                          }
                        });
                      },
                      child:
                          _isSearchBarExpanded
                              ? TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText:
                                      _searchFocusNode.hasFocus ||
                                              _searchController.text.isNotEmpty
                                          ? ''
                                          : 'Search',
                                  hintStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 15,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[300]!,
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(
                                      left: 20.0,
                                      right: 8.0,
                                    ),
                                    child: Icon(
                                      Icons.search,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(
                                        right: 20.0,
                                        left: 8.0,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 30,
                                      ),
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
                              )
                              : Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFc9c9c9),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                    ),
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

  //This method handles both adding new items and updating existing ones
  void _handleItemAdditionOrUpdate(CartItem newItem) {
    // FIXED: Only require customer details for delivery, takeaway, collection
    // NOT for dinein or takeout
    bool requiresCustomerDetails =
        (_actualOrderType.toLowerCase() == 'delivery' ||
            _actualOrderType.toLowerCase() == 'takeaway' ||
            _actualOrderType.toLowerCase() == 'collection');

    if (requiresCustomerDetails &&
        _customerDetails == null &&
        _editingCartIndex == null) {
      CustomPopupService.show(
        context,
        'Please enter customer details first.',
        type: PopupType.failure,
      );
      return;
    }

    setState(() {
      // Store the editing index before any state changes to prevent race conditions
      final int? currentEditingIndex = _editingCartIndex;
      print(
        '🔍 CART OPERATION: currentEditingIndex = $currentEditingIndex, _editingCartIndex = $_editingCartIndex',
      );

      if (currentEditingIndex != null) {
        print(
          '🔍 CART UPDATE: Updating existing item at index $currentEditingIndex',
        );
        print(
          '🔍 OLD ITEM: ${_cartItems[currentEditingIndex].selectedOptions}',
        );
        print('🔍 NEW ITEM: ${newItem.selectedOptions}');
        _cartItems[currentEditingIndex] = newItem;
        CustomPopupService.show(
          context,
          '${newItem.foodItem.name} updated in cart!',
          type: PopupType.success,
        );
      } else {
        // If not editing, add or increment as before
        int existingIndex = _cartItems.indexWhere((item) {
          bool sameFoodItem = item.foodItem.id == newItem.foodItem.id;
          String existingOptions = (item.selectedOptions ?? []).join();
          String newOptions = (newItem.selectedOptions ?? []).join();
          bool sameOptions = existingOptions == newOptions;
          bool sameComment = (item.comment ?? '') == (newItem.comment ?? '');

          print(
            '🔍 CART COMPARISON: sameFoodItem=$sameFoodItem, sameOptions=$sameOptions, sameComment=$sameComment',
          );
          print('🔍 EXISTING OPTIONS: "$existingOptions"');
          print('🔍 NEW OPTIONS: "$newOptions"');

          return sameFoodItem && sameOptions && sameComment;
        });

        if (existingIndex != -1) {
          _cartItems[existingIndex].incrementQuantity(newItem.quantity);
        } else {
          _cartItems.add(newItem);
        }
        CustomPopupService.show(
          context,
          '${newItem.foodItem.name} added to cart!',
          type: PopupType.success,
        );
      }
      _isModalOpen = false; // Close modal after action
      _modalFoodItem = null;
      _editingCartIndex = null; // Reset editing index
    });
  }

  Widget _buildShawarmaSubcategoryTabs() {
    if (selectedCategory >= 0 &&
        selectedCategory < categories.length &&
        categories[selectedCategory].name.toLowerCase() == 'shawarmas') {
      return _buildSubcategoryTabs(
        subcategories: _shawarmaSubcategories,
        selectedIndex: _selectedShawarmaSubcategory,
        onTap: (index) {
          setState(() {
            _selectedShawarmaSubcategory = index;
          });
        },
      );
    } else if (selectedCategory >= 0 &&
        selectedCategory < categories.length &&
        categories[selectedCategory].name.toLowerCase() == 'wings' &&
        _wingsSubcategories.isNotEmpty) {
      return _buildSubcategoryTabs(
        subcategories: _wingsSubcategories,
        selectedIndex: _selectedWingsSubcategory,
        onTap: (index) {
          setState(() {
            _selectedWingsSubcategory = index;
          });
        },
      );
    } else if (selectedCategory >= 0 &&
        selectedCategory < categories.length &&
        categories[selectedCategory].name.toLowerCase() == 'deals' &&
        _dealsSubcategories.isNotEmpty) {
      return _buildSubcategoryTabs(
        subcategories: _dealsSubcategories,
        selectedIndex: _selectedDealsSubcategory,
        onTap: (index) {
          setState(() {
            _selectedDealsSubcategory = index;
          });
        },
      );
    } else if (selectedCategory >= 0 &&
        selectedCategory < categories.length &&
        categories[selectedCategory].name.toLowerCase() == 'pizza' &&
        _pizzaSubcategories.isNotEmpty) {
      return _buildSubcategoryTabs(
        subcategories: _pizzaSubcategories,
        selectedIndex: _selectedPizzaSubcategory,
        onTap: (index) {
          setState(() {
            _selectedPizzaSubcategory = index;
          });
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubcategoryTabs({
    required List<String> subcategories,
    required int selectedIndex,
    required Function(int) onTap,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 15, bottom: 15),
      child: Row(
        children: [
          for (int i = 0; i < subcategories.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i < subcategories.length - 1 ? 20 : 0,
              ),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selectedIndex == i
                            ? const Color(0xFFCB6CE6)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          selectedIndex == i
                              ? const Color(0xFFCB6CE6)
                              : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    subcategories[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: selectedIndex == i ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemGrid() {
    return Consumer<ItemAvailabilityProvider>(
      builder: (context, itemProvider, child) {
        final List<FoodItem> providerItems = itemProvider.allItems;
        final bool isLoading = itemProvider.isLoading;

        // ROBUST FALLBACK: Use provider items if available, otherwise fallback to widget.foodItems
        final List<FoodItem> allFoodItems =
            providerItems.isNotEmpty
                ? providerItems
                : (widget.foodItems.isNotEmpty ? widget.foodItems : foodItems);

        // Production-safe logging
        if (providerItems.isEmpty && widget.foodItems.isNotEmpty) {
          print(
            '⚠️ Page4: Provider items empty, falling back to widget.foodItems (${widget.foodItems.length} items)',
          );
        }
        if (providerItems.isEmpty &&
            foodItems.isNotEmpty &&
            widget.foodItems.isEmpty) {
          print(
            '⚠️ Page4: Provider items empty, falling back to local foodItems (${foodItems.length} items)',
          );
        }

        // Show loading only if we have no data at all
        if (isLoading && allFoodItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // If still no items available, try to trigger a refresh
        if (allFoodItems.isEmpty) {
          print(
            '🔄 Page4: No items available, attempting to refresh ItemAvailabilityProvider',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            itemProvider.refresh();
          });
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading menu items...'),
              ],
            ),
          );
        }

        if (categories.isEmpty ||
            selectedCategory < 0 ||
            selectedCategory >= categories.length) {
          return const Center(
            child: Text(
              'No categories available or selected category is invalid.',
            ),
          );
        }

        final selectedCategoryName = categories[selectedCategory].name;

        String mappedCategoryKey;
        if (selectedCategoryName.toLowerCase() == 'deals') {
          mappedCategoryKey = 'Deals';
        } else if (selectedCategoryName.toLowerCase() == 'calzones') {
          mappedCategoryKey = 'Calzones';
        } else if (selectedCategoryName.toLowerCase() == 'shawarmas') {
          mappedCategoryKey = 'Shawarma';
        } else if (selectedCategoryName.toLowerCase() == 'kids meal') {
          mappedCategoryKey = 'KidsMeal';
        } else if (selectedCategoryName.toLowerCase() == 'garlic bread') {
          mappedCategoryKey = 'GarlicBread';
        } else {
          mappedCategoryKey = selectedCategoryName.toLowerCase();
        }

        Iterable<FoodItem> currentItems = allFoodItems.where(
          (item) =>
              item.category.toLowerCase() == mappedCategoryKey.toLowerCase(),
        );

        // Filter by subcategory for Shawarma items
        if (selectedCategoryName.toLowerCase() == 'shawarmas') {
          final selectedSubcategory =
              _shawarmaSubcategories[_selectedShawarmaSubcategory];
          currentItems = currentItems.where(
            (item) => item.subType?.trim() == selectedSubcategory.trim(),
          );
        }

        // Filter by subcategory for Wings items
        if (selectedCategoryName.toLowerCase() == 'wings' &&
            _wingsSubcategories.isNotEmpty) {
          final selectedSubcategory =
              _wingsSubcategories[_selectedWingsSubcategory];
          currentItems = currentItems.where(
            (item) => item.subType?.trim() == selectedSubcategory.trim(),
          );
        }

        // Filter by subcategory for Deals items
        if (selectedCategoryName.toLowerCase() == 'deals' &&
            _dealsSubcategories.isNotEmpty) {
          final selectedSubcategory =
              _dealsSubcategories[_selectedDealsSubcategory];
          currentItems = currentItems.where(
            (item) => item.subType?.trim() == selectedSubcategory.trim(),
          );
        }

        // Filter by subcategory for Pizza items
        if (selectedCategoryName.toLowerCase() == 'pizza' &&
            _pizzaSubcategories.isNotEmpty) {
          final selectedSubcategory =
              _pizzaSubcategories[_selectedPizzaSubcategory];
          currentItems = currentItems.where(
            (item) => item.subType?.trim() == selectedSubcategory.trim(),
          );
        }

        if (_searchQuery.isNotEmpty) {
          final lowerCaseQuery = _searchQuery.toLowerCase();
          currentItems = currentItems.where((item) {
            return item.name.toLowerCase().contains(lowerCaseQuery) ||
                (item.description?.toLowerCase().contains(lowerCaseQuery) ??
                    false) ||
                (item.subType?.toLowerCase().contains(lowerCaseQuery) ?? false);
          });
        }

        final filteredItems = currentItems.toList();

        if (filteredItems.isEmpty) {
          if (_searchQuery.isNotEmpty) {
            return Center(
              child: Text(
                'No items found matching "$_searchQuery" in this category.',
              ),
            );
          } else {
            return const Center(
              child: Text('No items found in this category.'),
            );
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

            // Always use normal color and text since edit mode is removed
            final Color containerColor = const Color(0xFFF2D9F9);
            final Color textColor = Colors.black;

            return ElevatedButton(
              onPressed: () {
                // Check item availability
                if (!item.availability) {
                  CustomPopupService.show(
                    context,
                    '${item.name} is currently unavailable',
                    type: PopupType.failure,
                  );
                  return;
                }

                bool requiresCustomerDetails =
                    (_actualOrderType.toLowerCase() == 'delivery' ||
                        _actualOrderType.toLowerCase() == 'takeaway' ||
                        _actualOrderType.toLowerCase() == 'collection');

                if (requiresCustomerDetails && _customerDetails == null) {
                  CustomPopupService.show(
                    context,
                    'Please enter customer details first.',
                    type: PopupType.failure,
                  );
                  return;
                }

                setState(() {
                  _isModalOpen = true;
                  _modalFoodItem = item;
                  _editingCartIndex = null;
                });

                final stateProvider = Provider.of<Page4StateProvider>(
                  context,
                  listen: false,
                );
                stateProvider.updateModalState(
                  isOpen: true,
                  foodItem: item,
                  editingIndex: null,
                );

                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _getLeftPanelDimensions();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: containerColor,
                padding: const EdgeInsets.fromLTRB(14.0, 5.0, 22.0, 5.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
                elevation: 4.0,
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Display item image if available
                      if (item.image.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            item.image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => const Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _toTitleCase(item.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                fontFamily: 'Poppins',
                                color: textColor,
                              ),
                            ),
                            if (item.description != null &&
                                item.description!.isNotEmpty)
                              _buildItemDescription(item, textColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Show the "+" button
                      Container(
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
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRightPanelContent() {
    // Create a placeholder customer for non-delivery orders
    final CustomerDetails safeCustomerDetails =
        _customerDetails ??
        CustomerDetails(name: 'Walk-in Customer', phoneNumber: '');

    // Show discount page if requested
    if (_showDiscountPage) {
      return DiscountPage(
        subtotal: _calculateTotalPrice(),
        currentOrderType: _actualOrderType,
        customerDetails: _customerDetails,
        onDiscountApplied: (double finalTotal, double discountPercentage) {
          setState(() {
            _appliedDiscountPercentage = discountPercentage;
            _showDiscountPage = false;
            _wasDiscountPageShown = true;
            _selectedPaymentType = '';
          });

          CustomPopupService.show(
            context,
            '${discountPercentage.toStringAsFixed(0)}% discount applied!',
            type: PopupType.success,
          );
        },
        onOrderTypeChanged: (newOrderType) {
          setState(() {
            _actualOrderType = newOrderType;
          });
        },
        onBack: () {
          setState(() {
            _showDiscountPage = false;
            _selectedPaymentType = '';
            _wasDiscountPageShown = true;
          });
        },
      );
    }

    if (_showPayment) {
      return PaymentWidget(
        subtotal: _getFinalTotal(),
        customerDetails: _customerDetails,
        paymentType: _selectedPaymentType,
        isProcessing: _isProcessingPayment, // Pass loading state
        onPaymentConfirmed:
            _isProcessingPayment
                ? null
                : (PaymentDetails paymentDetails) {
                  _handleOrderCompletion(
                    customerDetails: safeCustomerDetails,
                    paymentDetails: paymentDetails,
                  );
                },
        onBack:
            _isProcessingPayment
                ? null
                : () {
                  setState(() {
                    _showPayment = false;
                    _hasProcessedFirstStep = false;
                    _selectedPaymentType = '';
                  });
                },
        onPaymentTypeChanged:
            _isProcessingPayment
                ? null
                : (String newPaymentType) {
                  setState(() {
                    _selectedPaymentType = newPaymentType;
                  });
                  print("🔍 PAGE4 PAYMENT TYPE UPDATED: $_selectedPaymentType");
                },
      );
    }

    // Only show customer details widget for delivery, takeaway, collection when cart is empty
    if (_cartItems.isEmpty &&
        (_actualOrderType.toLowerCase() == 'delivery' ||
            _actualOrderType.toLowerCase() == 'takeaway' ||
            _actualOrderType.toLowerCase() == 'collection') &&
        _customerDetails == null &&
        !_hasProcessedFirstStep) {
      return Column(
        children: [
          // Service highlights row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              _buildServiceHighlight('dinein', 'DineIn.png'),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(height: 0, thickness: 2.5, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: CustomerDetailsWidget(
              subtotal: 0.0,
              orderType: _actualOrderType,
              onCustomerDetailsSubmitted: (CustomerDetails details) async {
                setState(() {
                  _customerDetails = details;
                  _hasProcessedFirstStep = true;
                });
              },
              onBack: () {},
            ),
          ),
        ],
      );
    }

    // NEW: Show customer details form for delivery/takeaway/collection when card_through_link is selected
    // Show only when cart has items AND payment type is selected AND email is missing
    if ((_actualOrderType.toLowerCase() == 'delivery' ||
            _actualOrderType.toLowerCase() == 'takeaway' ||
            _actualOrderType.toLowerCase() == 'collection') &&
        _hasProcessedFirstStep &&
        !_showPayment &&
        _selectedPaymentType == 'card_through_link' &&
        _cartItems.isNotEmpty &&
        (_customerDetails == null ||
            _customerDetails!.email == null ||
            _customerDetails!.email!.trim().isEmpty)) {
      return Column(
        children: [
          // Service highlights row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              _buildServiceHighlight('dinein', 'DineIn.png'),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(height: 0, thickness: 2.5, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: CustomerDetailsWidget(
              subtotal: _calculateTotalPrice() - _calculateDiscountAmount(),
              orderType: _actualOrderType,
              isCardThroughLink: true, // NEW: Mark as card through link payment
              initialCustomerData: _customerDetails, // Pre-fill existing data
              onCustomerDetailsSubmitted: (CustomerDetails details) async {
                // NEW: Call payment link API when Next is clicked
                await _handleCardThroughLinkSubmission(details);
              },
              onBack: () {
                setState(() {
                  _hasProcessedFirstStep = false;
                  _selectedPaymentType = '';
                });
              },
            ),
          ),
        ],
      );
    }

    // NEW: Show customer details form for dinein/takeout when card_through_link is selected
    // Show only when cart has items AND payment type is selected AND email is missing
    if ((_actualOrderType.toLowerCase() == 'dinein' ||
            _actualOrderType.toLowerCase() == 'takeout') &&
        _hasProcessedFirstStep &&
        !_showPayment &&
        _selectedPaymentType == 'card_through_link' &&
        _cartItems.isNotEmpty &&
        (_customerDetails == null ||
            _customerDetails!.email == null ||
            _customerDetails!.email!.trim().isEmpty)) {
      return Column(
        children: [
          // Service highlights row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              _buildServiceHighlight('dinein', 'DineIn.png'),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(height: 0, thickness: 2.5, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: CustomerDetailsWidget(
              subtotal: _calculateTotalPrice() - _calculateDiscountAmount(),
              orderType: _actualOrderType,
              isCardThroughLink: true, // NEW: Mark as card through link payment
              onCustomerDetailsSubmitted: (CustomerDetails details) async {
                // NEW: Call payment link API when Next is clicked
                await _handleCardThroughLinkSubmission(details);
              },
              onBack: () {
                setState(() {
                  _hasProcessedFirstStep = false;
                  _selectedPaymentType = '';
                });
              },
            ),
          ),
        ],
      );
    }

    // MODIFIED: Show service highlights with radio buttons for dinein/takeout (removed _cartItems.isEmpty condition)
    if ((_actualOrderType.toLowerCase() == 'dinein' ||
            _actualOrderType.toLowerCase() == 'takeout') &&
        !_hasProcessedFirstStep &&
        _cartItems.isEmpty) {
      return Column(
        children: [
          // Service highlights row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              Column(
                children: [
                  _buildServiceHighlight('dinein', 'DineIn.png'),
                  // Radio buttons below dinein option
                  Padding(
                    padding: const EdgeInsets.only(top: 7.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRadioOption('takeout', 'Takeout'),
                        const SizedBox(width: 20),
                        _buildRadioOption('dinein', 'Dinein'),
                      ],
                    ),
                  ),
                ],
              ),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(height: 0, thickness: 2.5, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          // Simple message instead of customer details form
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Start adding items to your cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // NEW: Always show cart summary with service highlights and radio options for dinein/takeout
    return Column(
      children: [
        // Service highlights row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildServiceHighlight('takeaway', 'TakeAway.png'),
            Column(
              children: [
                _buildServiceHighlight('dinein', 'DineIn.png'),
                // Show radio buttons for dinein/takeout orders
                if (_actualOrderType.toLowerCase() == 'dinein' ||
                    _actualOrderType.toLowerCase() == 'takeout')
                  Padding(
                    padding: const EdgeInsets.only(top: 7.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRadioOption('takeout', 'Takeout'),
                        const SizedBox(width: 20),
                        _buildRadioOption('dinein', 'Dinein'),
                      ],
                    ),
                  ),
              ],
            ),
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

        _buildCustomerDetailsDisplay(),
        // Cart summary section
        Expanded(child: _buildCartSummaryContent()),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF3D9FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFFCB6CE6) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: const Color(0xFFCB6CE6).withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFFCB6CE6)
                            : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: Colors.white,
                ),
                child:
                    isSelected
                        ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFCB6CE6),
                            ),
                          ),
                        )
                        : null,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  color:
                      isSelected ? const Color(0xFFCB6CE6) : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummaryContent() {
    double cartItemsTotal = _calculateCartItemsTotal();
    double deliveryCharge =
        _shouldApplyDeliveryCharge(_actualOrderType, _selectedPaymentType)
            ? 1.50
            : 0.0;
    double subtotal = cartItemsTotal + deliveryCharge;
    double currentDiscountAmount = _calculateDiscountAmount();
    double finalTotal = subtotal - currentDiscountAmount;

    return _cartItems.isEmpty
        ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_customerDetails != null &&
                (_actualOrderType.toLowerCase() == 'delivery' ||
                    _actualOrderType.toLowerCase() == 'takeaway'))
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
        : Column(
          children: [
            // Cart items list
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
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];

                    String? selectedSize;
                    String? selectedCrust;
                    String? selectedBase;
                    String? selectedDrink;
                    bool isMeal = false;
                    List<String> toppings = [];
                    List<String> sauceDips = [];
                    List<String> saladOptions = [];
                    String? selectedSeasoning;
                    bool hasOptions = false;

                    if (item.selectedOptions?.isNotEmpty ?? false) {
                      hasOptions = true;
                      for (var option in item.selectedOptions!) {
                        String lowerOption = option.toLowerCase();

                        // Check for meal option
                        if (lowerOption.contains('make it a meal')) {
                          isMeal = true;
                          hasOptions = true;
                        } else if (lowerOption.contains('drink:')) {
                          String drink = option.split(':').last.trim();
                          if (drink.isNotEmpty) {
                            selectedDrink = drink;
                            hasOptions = true;
                          }
                        } else if (lowerOption.contains('size:')) {
                          // Skip individual size extraction for Pizza Offers - it's handled in deal formatting
                          if (item.foodItem.name.toLowerCase() !=
                              'pizza offers') {
                            String size = option.split(':').last.trim();
                            if (size.toLowerCase() != 'default') {
                              selectedSize = size;
                              hasOptions = true;
                            }
                          }
                        } else if (lowerOption.contains('crust:')) {
                          // Skip individual crust extraction for Pizza Offers - it's handled in deal formatting
                          if (item.foodItem.name.toLowerCase() !=
                              'pizza offers') {
                            String crust = option.split(':').last.trim();
                            if (crust.toLowerCase() != 'normal') {
                              selectedCrust = crust;
                              hasOptions = true;
                            }
                          }
                        } else if (lowerOption.contains('base:')) {
                          String base = option.split(':').last.trim();
                          if (base.toLowerCase() != 'tomato') {
                            selectedBase = base;
                            hasOptions = true;
                          }
                        } else if (lowerOption.contains('toppings:') ||
                            lowerOption.contains('extra toppings:')) {
                          String toppingsValue = option.split(':').last.trim();
                          if (toppingsValue.isNotEmpty &&
                              toppingsValue.toLowerCase() != 'none' &&
                              toppingsValue.toLowerCase() != 'no toppings' &&
                              toppingsValue.toLowerCase() != 'standard' &&
                              toppingsValue.toLowerCase() != 'default') {
                            List<String> toppingsList =
                                toppingsValue
                                    .split(',')
                                    .map((t) => t.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toList();

                            final defaultToppingsAndCheese =
                                [
                                  ...(item.foodItem.defaultToppings ?? []),
                                  ...(item.foodItem.defaultCheese ?? []),
                                ].toSet().toList();

                            List<String> filteredToppings =
                                toppingsList.where((topping) {
                                  String trimmedTopping = topping.trim();
                                  return !defaultToppingsAndCheese.contains(
                                    trimmedTopping,
                                  );
                                }).toList();

                            if (filteredToppings.isNotEmpty) {
                              toppings.addAll(filteredToppings);
                              hasOptions = true;
                            }
                          }
                        } else if (lowerOption.contains('sauce:') ||
                            lowerOption.contains('sauce dip:')) {
                          // Skip individual sauce parsing for deals - they have their own formatting
                          if (item.foodItem.category != 'Deals') {
                            String dipsValue = option.split(':').last.trim();
                            if (dipsValue.isNotEmpty) {
                              List<String> dipsList =
                                  dipsValue
                                      .split(',')
                                      .map((t) => t.trim())
                                      .where((t) => t.isNotEmpty)
                                      .toList();
                              sauceDips.addAll(dipsList);
                            }
                          }
                        } else if (lowerOption.contains('salad:')) {
                          // Skip individual salad parsing for deals - they have their own formatting
                          if (item.foodItem.category != 'Deals') {
                            String saladValue = option.split(':').last.trim();
                            if (saladValue.isNotEmpty) {
                              List<String> saladList =
                                  saladValue
                                      .split(',')
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .toList();
                              saladOptions.addAll(saladList);
                              hasOptions = true;
                            }
                          }
                        } else if (lowerOption.contains('seasoning:') ||
                            lowerOption.contains('chips seasoning:')) {
                          String seasoningValue = option.split(':').last.trim();
                          if (seasoningValue.isNotEmpty) {
                            selectedSeasoning = seasoningValue;
                            hasOptions = true;
                          }
                        } else if (lowerOption == 'no salad' ||
                            lowerOption == 'no sauce' ||
                            lowerOption == 'no cream') {
                          toppings.add(option);
                        }
                      }
                    }

                    // Handle deal-specific options display
                    List<String> dealOptions = [];
                    if (item.foodItem.category == 'Deals' && hasOptions) {
                      // Apply line break formatting for Family Meal and Combo Meal
                      if (item.foodItem.name.toLowerCase() == 'family meal' ||
                          item.foodItem.name.toLowerCase() == 'combo meal') {
                        dealOptions = _formatFamilyComboMealOptions(
                          item.selectedOptions!,
                        );
                      } else {
                        dealOptions = _formatDealOptions(item.selectedOptions!);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 20,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                              padding: const EdgeInsets.only(
                                                left: 30,
                                                right: 10,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (!hasOptions)
                                                    Text(
                                                      item.foodItem.name,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontFamily: 'Poppins',
                                                        color: Colors.grey,
                                                        fontStyle:
                                                            FontStyle.normal,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (selectedCrust != null)
                                                      Text(
                                                        'Crust: $selectedCrust',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (selectedBase != null)
                                                      Text(
                                                        'Base: $selectedBase',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (toppings.isNotEmpty)
                                                      Text(
                                                        'Extra Toppings: ${toppings.join(', ')}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        maxLines: 3,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (sauceDips.isNotEmpty)
                                                      Text(
                                                        '${(item.foodItem.category == 'Pizza' || item.foodItem.category == 'GarlicBread') ? 'Sauce Dip' : 'Sauce'}: ${sauceDips.join(', ')}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (saladOptions.isNotEmpty)
                                                      Text(
                                                        'Salad: ${saladOptions.join(', ')}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    if (selectedSeasoning !=
                                                        null)
                                                      Text(
                                                        'Seasoning: $selectedSeasoning',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    // Display deal-specific options with proper line breaks
                                                    if (dealOptions.isNotEmpty)
                                                      ...dealOptions
                                                          .map(
                                                            (
                                                              dealOption,
                                                            ) => Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children:
                                                                  dealOption
                                                                      .split(
                                                                        '\n',
                                                                      )
                                                                      .map(
                                                                        (
                                                                          line,
                                                                        ) => Text(
                                                                          line,
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                15,
                                                                            fontFamily:
                                                                                'Poppins',
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                            ),
                                                          )
                                                          .toList(),
                                                    // Display meal information
                                                    if (isMeal &&
                                                        selectedDrink !=
                                                            null) ...[
                                                      const Text(
                                                        'MEAL',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      Text(
                                                        'Drink: $selectedDrink',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontFamily: 'Poppins',
                                                          color: Colors.black,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 20),
                                          // Delete button
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _cartItems.removeAt(index);

                                                  // Reset editing index if it becomes invalid
                                                  if (_editingCartIndex !=
                                                          null &&
                                                      (_editingCartIndex! >=
                                                              _cartItems
                                                                  .length ||
                                                          _editingCartIndex! ==
                                                              index)) {
                                                    _editingCartIndex = null;
                                                  } else if (_editingCartIndex !=
                                                          null &&
                                                      _editingCartIndex! >
                                                          index) {
                                                    // Adjust editing index if item was removed before it
                                                    _editingCartIndex =
                                                        _editingCartIndex! - 1;
                                                  }
                                                });

                                                CustomPopupService.show(
                                                  context,
                                                  '${item.foodItem.name} removed from cart!',
                                                  type: PopupType.success,
                                                );
                                              },
                                              child: SizedBox(
                                                width: 46,
                                                height: 46,
                                                child: Image.asset(
                                                  'assets/images/Bin.png',
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Icon(
                                                        Icons.delete,
                                                        size: 46,
                                                        color: Colors.red,
                                                      ),
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
                                              child: const SizedBox(
                                                width: 46,
                                                height: 46,
                                                child: Icon(
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
                                              child: const SizedBox(
                                                width: 46,
                                                height: 46,
                                                child: Icon(
                                                  Icons.add,
                                                  color: Colors.black,
                                                  size: 46,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 35),
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
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Icon(
                                                        Icons.edit,
                                                        size: 37,
                                                        color: Colors.blue,
                                                      ),
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
                                  width: 3,
                                  height: 140,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: const Color(0xFFB2B2B2),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 110,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                        child: Image.asset(
                                          _getCategoryIcon(
                                            item.foodItem.category,
                                          ),
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.fastfood,
                                                    size: 80,
                                                    color: Colors.grey,
                                                  ),
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
                                        '${(item.pricePerUnit * item.quantity).toStringAsFixed(2)}',
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
                          // Comment section
                          GestureDetector(
                            onTap:
                                () => _startEditingComment(index, item.comment),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _editingCommentIndex == index
                                          ? const Color(0xFFFDF1C7)
                                          : (item.comment != null &&
                                              item.comment!.isNotEmpty)
                                          ? const Color(0xFFFDF1C7)
                                          : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      (item.comment == null ||
                                              item.comment!.isEmpty)
                                          ? Border.all(
                                            color: Colors.grey.shade300,
                                          )
                                          : null,
                                ),
                                child:
                                    _editingCommentIndex == index
                                        ? TextField(
                                          controller: _commentEditingController,
                                          focusNode: _commentFocusNode,
                                          maxLines: null,
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
                                          onSubmitted:
                                              (_) => _stopEditingComment(),
                                          onTapOutside:
                                              (_) => _stopEditingComment(),
                                        )
                                        : Center(
                                          child: Text(
                                            (item.comment != null &&
                                                    item.comment!.isNotEmpty)
                                                ? 'Comment: ${item.comment!}'
                                                : 'Click to add a comment',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontStyle:
                                                  (item.comment == null ||
                                                          item.comment!.isEmpty)
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                              color:
                                                  (item.comment == null ||
                                                          item.comment!.isEmpty)
                                                      ? Colors.grey
                                                      : Colors.black,
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
            ),

            // Horizontal divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 55.0),
              child: Divider(
                height: 0,
                thickness: 3,
                color: const Color(0xFFB2B2B2),
              ),
            ),

            const SizedBox(height: 10),

            // Show delivery charges for delivery orders
            if (_shouldApplyDeliveryCharge(
              _actualOrderType,
              _selectedPaymentType,
            )) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items Total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '£${cartItemsTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delivery Charges',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '£${deliveryCharge.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
            ],

            // Show discount information if applied
            if (_appliedDiscountPercentage > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '£${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount (${_appliedDiscountPercentage.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '- £${currentDiscountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _appliedDiscountPercentage > 0 ? 'Final Total' : 'Subtotal',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '£${finalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // First row: Cash, Card, Unpaid
            Row(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isProcessingUnpaid,
                    child: Opacity(
                      opacity: _isProcessingUnpaid ? 0.3 : 1.0,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            _selectedPaymentType = 'cash';
                          });
                          _proceedToNextStep();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _selectedPaymentType == 'cash'
                                    ? Colors.grey[300]
                                    : Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _selectedPaymentType == 'cash'
                                    ? Border.all(color: Colors.grey)
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              'Cash',
                              style: TextStyle(
                                color:
                                    _selectedPaymentType == 'cash'
                                        ? Colors.black
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 29,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isProcessingUnpaid,
                    child: Opacity(
                      opacity: _isProcessingUnpaid ? 0.3 : 1.0,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            _selectedPaymentType = 'card';
                          });
                          _proceedToNextStep();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _selectedPaymentType == 'card'
                                    ? Colors.grey[300]
                                    : Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _selectedPaymentType == 'card'
                                    ? Border.all(color: Colors.grey)
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              'Card',
                              style: TextStyle(
                                color:
                                    _selectedPaymentType == 'card'
                                        ? Colors.black
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 29,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        _isProcessingUnpaid
                            ? null
                            : () async {
                              setState(() {
                                _isProcessingUnpaid = true;
                              });
                              // Process unpaid order immediately
                              await _processUnpaidOrder();
                            },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child:
                            _isProcessingUnpaid
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                )
                                : Text(
                                  'Unpaid',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 29,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Second row: Card Link, Discount
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AbsorbPointer(
                    absorbing: _isProcessingUnpaid,
                    child: Opacity(
                      opacity: _isProcessingUnpaid ? 0.3 : 1.0,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            _selectedPaymentType = 'card_through_link';
                          });
                          _proceedToNextStep();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _selectedPaymentType == 'card_through_link'
                                    ? Colors.grey[300]
                                    : const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _selectedPaymentType == 'card_through_link'
                                    ? Border.all(color: Colors.grey)
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              'Card Through Link',
                              style: TextStyle(
                                color:
                                    _selectedPaymentType == 'card_through_link'
                                        ? Colors.black
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 29,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isProcessingUnpaid,
                    child: Opacity(
                      opacity: _isProcessingUnpaid ? 0.3 : 1.0,
                      child: GestureDetector(
                        onTap: () {
                          if (_cartItems.isNotEmpty) {
                            _showPinDialog();
                          } else {
                            CustomPopupService.show(
                              context,
                              'Please add items to cart first',
                              type: PopupType.failure,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '%',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 29,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        );
  }

  void _editCartItem(CartItem cartItem, int cartIndex) {
    setState(() {
      _isModalOpen = true;
      _modalFoodItem = cartItem.foodItem; // The base food item for the modal
      _editingCartIndex = cartIndex; // Store the index of the item being edited
    });

    // NEW: Save modal state to provider
    final stateProvider = Provider.of<Page4StateProvider>(
      context,
      listen: false,
    );
    stateProvider.updateModalState(
      isOpen: true,
      foodItem: cartItem.foodItem,
      editingIndex: cartIndex,
    );

    // Ensure dimensions are calculated after state update and before modal opens visually
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _getLeftPanelDimensions();
    });
  }

  // Widget _buildCartSummary() {
  //   return Column(
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceAround,
  //         children: [
  //           _buildServiceHighlight('takeaway', 'TakeAway.png'),
  //           _buildServiceHighlight('dinein', 'DineIn.png'),
  //           _buildServiceHighlight('delivery', 'Delivery.png'),
  //         ],
  //       ),
  //       const SizedBox(height: 20),
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 60.0),
  //         child: Divider(
  //           height: 0,
  //           thickness: 3,
  //           color: const Color(0xFFB2B2B2),
  //         ),
  //       ),
  //       const SizedBox(height: 20),
  //       Expanded(
  //         child: _buildCartSummaryContent(),
  //       ),
  //     ],
  //   );
  // }

  /// NEW: Handle card through link submission
  /// Calls payment link API immediately when customer details are submitted
  /// Handles differential payment for order updates
  Future<void> _handleCardThroughLinkSubmission(CustomerDetails details) async {
    // Save customer details and set loading state
    setState(() {
      _customerDetails = details;
      _isSendingPaymentLink = true;
    });

    try {
      // Get payment link provider
      final paymentLinkProvider = Provider.of<PaymentLinkProvider>(
        context,
        listen: false,
      );

      // Calculate new total
      final double originalSubtotal = _calculateTotalPrice();
      final double dynamicDiscountAmount = _calculateDiscountAmount();
      final double newTotalCharge = originalSubtotal - dynamicDiscountAmount;

      // Determine payment link amount based on edit mode and paid status
      double paymentLinkAmount = newTotalCharge;

      if (_isEditMode && _existingOrder != null) {
        // IN EDIT MODE: Check if order was already paid
        final bool wasAlreadyPaid = _existingOrder!.paidStatus == true;
        final double originalTotal = _existingOrder!.orderTotalPrice;

        print(
          '💳 Edit Mode: wasAlreadyPaid=$wasAlreadyPaid, originalTotal=$originalTotal, newTotal=$newTotalCharge',
        );

        if (wasAlreadyPaid) {
          // Order was already paid - send only the difference
          final double difference = newTotalCharge - originalTotal;

          if (difference > 0) {
            // Price increased - send only the additional amount
            paymentLinkAmount = difference;
            print(
              '💳 Sending payment link for additional amount: £${difference.toStringAsFixed(2)}',
            );
          } else {
            // Price decreased or stayed same - no payment link needed
            print(
              '💳 No additional payment needed (difference: £${difference.toStringAsFixed(2)})',
            );

            if (mounted) {
              CustomPopupService.show(
                context,
                difference < 0
                    ? 'Order total decreased. No additional payment required.'
                    : 'Order total unchanged. No additional payment required.',
                type: PopupType.success,
              );
            }

            // Proceed to payment screen without sending link
            setState(() {
              _showPayment = true;
            });
            return;
          }
        } else {
          // Order was not paid - send complete new total
          paymentLinkAmount = newTotalCharge;
          print(
            '💳 Order was unpaid - sending complete amount: £${newTotalCharge.toStringAsFixed(2)}',
          );
        }
      } else {
        // NEW ORDER: Send complete total
        paymentLinkAmount = newTotalCharge;
        print(
          '💳 New order - sending complete amount: £${newTotalCharge.toStringAsFixed(2)}',
        );
      }

      // Show loading popup
      if (mounted) {
        CustomPopupService.show(
          context,
          _isEditMode && _existingOrder?.paidStatus == true
              ? 'Sending payment link for additional £${paymentLinkAmount.toStringAsFixed(2)}...'
              : 'Sending payment link to customer...',
          type: PopupType.success,
          duration: const Duration(seconds: 2),
        );
      }

      // Send payment link via provider
      final bool success = await paymentLinkProvider.sendPaymentLink(
        customerName: details.name,
        customerEmail: details.email ?? '',
        customerPhone: details.phoneNumber,
        cartItems: _cartItems,
        totalPrice:
            paymentLinkAmount, // Send calculated amount (full or differential)
      );

      if (!mounted) return;

      if (success) {
        // Success - show payment screen
        CustomPopupService.show(
          context,
          _isEditMode && _existingOrder?.paidStatus == true
              ? 'Payment link sent for additional £${paymentLinkAmount.toStringAsFixed(2)}!'
              : 'Payment link sent successfully!',
          type: PopupType.success,
        );

        setState(() {
          _showPayment = true;
          _isSendingPaymentLink = false;
        });
      } else {
        // Failed - show error
        setState(() {
          _isSendingPaymentLink = false;
        });
        CustomPopupService.show(
          context,
          'Failed to send payment link: ${paymentLinkProvider.errorMessage}',
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Error in _handleCardThroughLinkSubmission: $e');
      if (mounted) {
        setState(() {
          _isSendingPaymentLink = false;
        });
        CustomPopupService.show(
          context,
          'Error sending payment link: $e',
          type: PopupType.failure,
        );
      }
    }
  }

  Future<void> _handleOrderCompletion({
    required CustomerDetails customerDetails,
    required PaymentDetails paymentDetails,
  }) async {
    if (_cartItems.isEmpty) {
      if (mounted) {
        CustomPopupService.show(
          context,
          'Cart is empty. Please add items to place order',
          type: PopupType.failure,
        );
      }
      return;
    }

    // Set loading state to prevent double clicks
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      if (_isEditMode && _editingOrderId != null) {
        await _updateExistingOrder(paymentDetails);
        return;
      }

      final String transactionId = generateTransactionId();
      print("Generated Transaction ID: $transactionId");

      // Calculate totals with dynamic discount
      final double originalSubtotal = _calculateTotalPrice();
      final double dynamicDiscountAmount =
          _calculateDiscountAmount(); // Dynamic calculation
      final double finalTotalCharge = originalSubtotal - dynamicDiscountAmount;

      // Use the discount percentage from state
      final double finalDiscountPercentage = _appliedDiscountPercentage;
      final double finalChangeDue = paymentDetails.changeDue;
      final double finalAmountReceived = paymentDetails.amountReceived ?? 0.0;

      final Map<String, dynamic> orderData = {
        "guest": {
          "name": customerDetails.name,
          "email": customerDetails.email ?? "N/A",
          "phone_number": customerDetails.phoneNumber,
          "street_address": customerDetails.streetAddress ?? "N/A",
          "city": customerDetails.city ?? "N/A",
          "county": customerDetails.city ?? "N/A",
          "postal_code": customerDetails.postalCode ?? "N/A",
        },
        "transaction_id": transactionId,
        "payment_type": _selectedPaymentType,
        "amount_received": finalAmountReceived,
        "discount_percentage": finalDiscountPercentage,
        "order_type":
            _actualOrderType.toLowerCase() == 'collection'
                ? 'takeaway'
                : _actualOrderType,
        "total_price": finalTotalCharge,
        "original_total_price": originalSubtotal,
        "discount_amount": dynamicDiscountAmount,
        "order_extra_notes":
            _cartItems
                .map((item) => item.comment ?? '')
                .where((c) => c.isNotEmpty)
                .join(', ')
                .trim(),
        "status": "yellow",
        "change_due": finalChangeDue,
        "order_source": "EPOS",
        "paid_status": paymentDetails.paidStatus,
        "items":
            _cartItems.map((cartItem) {
              final String description = _buildDescriptionForCartItem(cartItem);
              final double pricePerUnit = double.parse(
                cartItem.pricePerUnit.toStringAsFixed(2),
              );
              // Use cartItem.totalPrice to include extraAmount (e.g., rush fees)
              final double itemTotalPrice = double.parse(
                cartItem.totalPrice.toStringAsFixed(2),
              );
              return {
                "item_id": cartItem.foodItem.id,
                "quantity": cartItem.quantity,
                "description": description,
                "price_per_unit": pricePerUnit,
                "total_price": itemTotalPrice,
                "comment": cartItem.comment,
                "extra_amount": cartItem.extraAmount,
                "extra_reason": cartItem.extraReason,
              };
            }).toList(),
      };

      print("Attempting to submit order with order_type: $_actualOrderType");
      print("Payment Details: ${paymentDetails.paymentType}");
      print("Order Data being sent: $orderData");

      // NOTE: Payment link is now sent earlier when customer details are submitted
      // via _handleCardThroughLinkSubmission for card_through_link payment type

      final String extraNotes =
          _cartItems
              .map((item) => item.comment ?? '')
              .where((c) => c.isNotEmpty)
              .join(', ')
              .trim();

      // First submit order to backend and get order ID
      final String? backendOrderId = await _submitOrderAndGetId(orderData);

      // Always use UK time for receipts and dialogs
      final DateTime orderCreationTime = UKTimeService.now();

      // Format cart items for receipt preview (same as printing)
      final List<CartItem> formattedCartItems = _formatCartItemsForReceipt(
        _cartItems,
      );

      // Then print receipt with the order ID
      await _printReceiptWithOrderId(
        orderData: orderData,
        transactionId: transactionId,
        subtotal: originalSubtotal,
        totalCharge: finalTotalCharge,
        extraNotes: extraNotes,
        changeDue: finalChangeDue,
        paidStatus: paymentDetails.paidStatus,
        orderId: backendOrderId,
        orderDateTime: orderCreationTime,
        orderSource: 'EPOS', // POS orders from page4
        formattedCartItems: formattedCartItems,
      );
    } catch (e) {
      print('Error in order completion: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          'Failed to process order: $e',
          type: PopupType.failure,
        );
      }
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Future<String?> _submitOrderAndGetId(Map<String, dynamic> orderData) async {
    final offlineProvider = Provider.of<OfflineProvider>(
      context,
      listen: false,
    );
    final eposOrdersProvider = Provider.of<EposOrdersProvider>(
      context,
      listen: false,
    );

    // Check if we're online
    if (!offlineProvider.isOnline) {
      // OFFLINE MODE: Create local order
      try {
        final offlineOrder = await OfflineOrderManager.createOfflineOrder(
          cartItems: _cartItems,
          paymentType: _selectedPaymentType,
          orderType: _actualOrderType,
          orderTotalPrice: orderData['total_price'] as double,
          orderExtraNotes: orderData['order_extra_notes'] as String?,
          customerName: _customerDetails?.name ?? "Unknown Customer",
          customerEmail: _customerDetails?.email,
          phoneNumber: _customerDetails?.phoneNumber,
          streetAddress: _customerDetails?.streetAddress,
          city: _customerDetails?.city,
          postalCode: _customerDetails?.postalCode,
          changeDue: orderData['change_due'] as double? ?? 0.0,
        );

        // Add offline order to the orders list in background
        eposOrdersProvider.addOfflineOrder(offlineOrder).catchError((error) {
          print('⚠️ Background addOfflineOrder failed: $error');
        });

        // Return null for offline orders (no backend order ID)
        return null;
      } catch (e) {
        print('❌ Failed to create offline order: $e');
        throw Exception('Failed to save order offline: $e');
      }
    }

    // ONLINE MODE: Submit to backend and get order ID
    try {
      final orderId = await ApiService.createOrderFromMap(orderData);
      print(
        '✅ Order placed successfully online: $orderId for type: $_actualOrderType',
      );

      // Refresh provider in background
      eposOrdersProvider.refresh().catchError((error) {
        print('⚠️ Background refresh failed after order placement: $error');
      });

      return orderId;
    } catch (e) {
      print('❌ Failed to submit order online: $e');

      // Try to save offline as fallback
      try {
        final offlineOrder = await OfflineOrderManager.createOfflineOrder(
          cartItems: _cartItems,
          paymentType: _selectedPaymentType,
          orderType: _actualOrderType,
          orderTotalPrice: orderData['total_price'] as double,
          orderExtraNotes: orderData['order_extra_notes'] as String?,
          customerName: _customerDetails?.name ?? "Unknown Customer",
          customerEmail: _customerDetails?.email,
          phoneNumber: _customerDetails?.phoneNumber,
          streetAddress: _customerDetails?.streetAddress,
          city: _customerDetails?.city,
          postalCode: _customerDetails?.postalCode,
          changeDue: orderData['change_due'] as double? ?? 0.0,
        );

        eposOrdersProvider.addOfflineOrder(offlineOrder).catchError((error) {
          print('⚠️ Background addOfflineOrder failed: $error');
        });

        print('✅ Order saved offline as fallback');
        return null; // No backend order ID for offline orders
      } catch (offlineError) {
        print('❌ Offline fallback also failed: $offlineError');
        throw Exception(
          'Failed to submit order online and offline fallback failed: $offlineError',
        );
      }
    }
  }

  Future<void> _printReceiptWithOrderId({
    required Map<String, dynamic> orderData,
    required String transactionId,
    required double subtotal,
    required double totalCharge,
    required String extraNotes,
    required double changeDue,
    required bool paidStatus,
    String? orderId,
    DateTime? orderDateTime,
    String? orderSource,
    List<CartItem>? formattedCartItems,
  }) async {
    try {
      // Extract customer details from orderData
      final guestData = orderData['guest'] as Map<String, dynamic>?;

      // Calculate delivery charge for delivery orders
      double? deliveryChargeAmount;
      if (_shouldApplyDeliveryCharge(_actualOrderType, _selectedPaymentType)) {
        deliveryChargeAmount = 1.50; // Delivery charge amount
      }

      await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId: transactionId,
        orderType: _actualOrderType,
        cartItems: formattedCartItems ?? _cartItems,
        subtotal: subtotal,
        totalCharge: totalCharge,
        extraNotes: extraNotes,
        changeDue: changeDue,
        customerName: guestData?['name'] as String?,
        customerEmail: guestData?['email'] as String?,
        phoneNumber: guestData?['phone_number'] as String?,
        streetAddress: guestData?['street_address'] as String?,
        city: guestData?['city'] as String?,
        postalCode: guestData?['postal_code'] as String?,
        paymentType: _selectedPaymentType,
        paidStatus: paidStatus,
        orderId: orderId != null ? int.tryParse(orderId) : null,
        deliveryCharge: deliveryChargeAmount,
        orderDateTime: orderDateTime,
        onShowMethodSelection: (availableMethods) {
          if (mounted) {
            CustomPopupService.show(
              context,
              'No printer connections detected. Available methods: ${availableMethods.join(", ")}',
              type: PopupType.failure,
            );
          }
        },
      );
    } catch (e) {
      print('Error printing receipt: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          "Printing failed: $e",
          type: PopupType.failure,
        );
      }
      // Don't rethrow - order was already placed successfully
    }

    // Show success message and clear cart after printing (or print failure)
    if (mounted) {
      CustomPopupService.show(
        context,
        "Order placed successfully",
        type: PopupType.success,
      );
      _clearOrderState();
    }
  }

  // Future<void> _handlePrintingAndOrderDirect({
  //   required Map<String, dynamic> orderData,
  //   required String id1,
  //   required double subtotal,
  //   required double totalCharge,
  //   required String extraNotes,
  //   required double changeDue,
  //   required bool paidStatus,
  // }) async {
  //   if (!mounted) return;

  //   try {
  //     // Extract customer details from orderData
  //     final guestData = orderData['guest'] as Map<String, dynamic>?;

  //     await ThermalPrinterService().printReceiptWithUserInteraction(
  //       transactionId: id1,
  //       orderType: _actualOrderType,
  //       cartItems: _cartItems,
  //       subtotal: subtotal,
  //       totalCharge: totalCharge,
  //       extraNotes: extraNotes.isNotEmpty ? extraNotes : null,
  //       changeDue: changeDue,
  //       // Add customer details
  //       customerName: guestData?['name'] as String?,
  //       customerEmail: guestData?['email'] as String?,
  //       phoneNumber: guestData?['phone_number'] as String?,
  //       streetAddress: guestData?['street_address'] as String?,
  //       city: guestData?['city'] as String?,
  //       postalCode: guestData?['postal_code'] as String?,
  //       paymentType: _selectedPaymentType,
  //       paidStatus: paidStatus,
  //       onShowMethodSelection: (availableMethods) {
  //         if (mounted) {
  //           CustomPopupService.show(
  //             context,
  //             "Available printing methods: ${availableMethods.join(', ')}. Please check printer connections.",
  //             type: PopupType.success,
  //           );
  //         }
  //       },
  //     );
  //   } catch (e) {
  //     print('Background printing failed: $e');
  //     if (mounted) {
  //       CustomPopupService.show(
  //         context,
  //         "Printing failed !",
  //         type: PopupType.failure,
  //       );
  //     }
  //   }

  //   await _placeOrderDirectly(orderData);
  // }

  // Future<void> _placeOrderDirectly(Map<String, dynamic> orderData) async {
  //   if (!mounted) return;

  //   final offlineProvider = Provider.of<OfflineProvider>(
  //     context,
  //     listen: false,
  //   );
  //   final eposOrdersProvider = Provider.of<EposOrdersProvider>(
  //     context,
  //     listen: false,
  //   );

  //   // Check if we're online
  //   print(
  //     '🌐 DEBUG: Page4 order placement - OfflineProvider.isOnline: ${offlineProvider.isOnline}',
  //   );
  //   print(
  //     '🌐 DEBUG: Page4 order placement - ConnectivityService.isOnline: ${ConnectivityService().isOnline}',
  //   );
  //   if (!offlineProvider.isOnline) {
  //     // OFFLINE MODE: Create local order that appears in orders list immediately
  //     try {
  //       final offlineOrder = await OfflineOrderManager.createOfflineOrder(
  //         cartItems: _cartItems,
  //         paymentType: _selectedPaymentType,
  //         orderType: _actualOrderType,
  //         orderTotalPrice: orderData['total_price'] as double,
  //         orderExtraNotes: orderData['order_extra_notes'] as String?,
  //         customerName: _customerDetails?.name ?? "Unknown Customer",
  //         customerEmail: _customerDetails?.email,
  //         phoneNumber: _customerDetails?.phoneNumber,
  //         streetAddress: _customerDetails?.streetAddress,
  //         city: _customerDetails?.city,
  //         postalCode: _customerDetails?.postalCode,
  //         changeDue: orderData['change_due'] as double? ?? 0.0,
  //       );

  //       // Show success popup immediately
  //       if (mounted) {
  //         CustomPopupService.show(
  //           context,
  //           "Order saved offline: ${offlineOrder.transactionId}\nWill appear in orders list and be processed when connection is restored",
  //           type: PopupType.success,
  //         );

  //         // Clear cart like successful order
  //         _clearOrderState();
  //       }

  //       // Add offline order to the orders list in background
  //       eposOrdersProvider.addOfflineOrder(offlineOrder).catchError((error) {
  //         print('⚠️ Background addOfflineOrder failed: $error');
  //       });
  //       return;
  //     } catch (e) {
  //       print('❌ Failed to create offline order: $e');
  //       if (mounted) {
  //         CustomPopupService.show(
  //           context,
  //           "Failed to save order offline: $e",
  //           type: PopupType.failure,
  //         );
  //       }
  //       return;
  //     }
  //   }

  //   // ONLINE MODE: Try normal processing first, fallback to offline
  //   try {
  //     final orderId = await ApiService.createOrderFromMap(orderData);

  //     print(
  //       '✅ Order placed successfully online: $orderId for type: $_actualOrderType',
  //     );

  //     // Show success popup immediately after order placement
  //     if (mounted) {
  //       CustomPopupService.show(
  //         context,
  //         "Order placed successfully",
  //         type: PopupType.success,
  //       );
  //       _clearOrderState();
  //     }

  //     // Refresh provider in background (don't await to avoid UI delay)
  //     eposOrdersProvider.refresh().catchError((error) {
  //       print('⚠️ Background refresh failed after order placement: $error');
  //     });
  //   } catch (e) {
  //     print('❌ Online order placement failed: $e');

  //     // FALLBACK: Try to save offline if online fails
  //     try {
  //       print('🔄 Attempting to save order offline as fallback...');

  //       final offlineOrder = await OfflineOrderManager.createOfflineOrder(
  //         cartItems: _cartItems,
  //         paymentType: _selectedPaymentType,
  //         orderType: _actualOrderType,
  //         orderTotalPrice: orderData['total_price'] as double,
  //         orderExtraNotes: orderData['order_extra_notes'] as String?,
  //         customerName: _customerDetails?.name ?? "Unknown Customer",
  //         customerEmail: _customerDetails?.email,
  //         phoneNumber: _customerDetails?.phoneNumber,
  //         streetAddress: _customerDetails?.streetAddress,
  //         city: _customerDetails?.city,
  //         postalCode: _customerDetails?.postalCode,
  //         changeDue: orderData['change_due'] as double? ?? 0.0,
  //       );

  //       // Show success popup immediately
  //       if (mounted) {
  //         CustomPopupService.show(
  //           context,
  //           "Connection failed, order saved offline: ${offlineOrder.transactionId}\nWill be processed when connection is restored",
  //           type: PopupType.success,
  //         );
  //         _clearOrderState();
  //       }

  //       // Add offline order to the orders list in background
  //       eposOrdersProvider.addOfflineOrder(offlineOrder).catchError((error) {
  //         print('⚠️ Background addOfflineOrder failed: $error');
  //       });
  //     } catch (offlineError) {
  //       print('❌ Failed to save order offline: $offlineError');
  //       if (mounted) {
  //         CustomPopupService.show(
  //           context,
  //           "Failed to place order: $e",
  //           type: PopupType.failure,
  //         );
  //       }
  //     }
  //   }
  // }

  void _clearOrderState() {
    setState(() {
      _cartItems.clear();
      _editingCartIndex = null; // Reset editing index when cart is cleared
      _showPayment = false;
      _customerDetails = null;
      _hasProcessedFirstStep = false;
      _appliedDiscountPercentage = 0.0;
      _discountAmount = 0.0;
      _showDiscountPage = false;
      _selectedPaymentType = '';
      _wasDiscountPageShown = false;
    });
  }

  Future<void> _processUnpaidOrder() async {
    if (_cartItems.isEmpty) {
      CustomPopupService.show(
        context,
        'Cart is empty. Please add items to continue.',
        type: PopupType.failure,
      );
      return;
    }

    // Create unpaid payment details
    PaymentDetails paymentDetails = PaymentDetails(
      paymentType: 'unpaid',
      amountReceived: 0.0,
      discountPercentage: _appliedDiscountPercentage,
      totalCharge: _calculateTotalPrice(),
      paidStatus: false, // Unpaid status
    );

    print("🔍 PROCESSING UNPAID ORDER:");
    print("Payment Type: ${paymentDetails.paymentType}");
    print("Paid Status: ${paymentDetails.paidStatus}");
    print("Total Amount: £${paymentDetails.totalCharge}");

    // Create a safe customer details (same pattern used elsewhere)
    final CustomerDetails safeCustomerDetails =
        _customerDetails ??
        CustomerDetails(name: 'Walk-in Customer', phoneNumber: '');

    try {
      await _handleOrderCompletion(
        customerDetails: safeCustomerDetails,
        paymentDetails: paymentDetails,
      );
    } catch (e) {
      print("Error processing unpaid order: $e");
      // Show error to user if needed
      if (mounted) {
        CustomPopupService.show(
          context,
          "Failed to process unpaid order: $e",
          type: PopupType.failure,
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isProcessingUnpaid = false;
        });
      }
    }
  }

  void _proceedToNextStep() {
    if (_cartItems.isEmpty) {
      CustomPopupService.show(
        context,
        "Please add items to cart first",
        type: PopupType.failure,
      );
      return;
    }

    setState(() {
      _hasProcessedFirstStep = true;
    });

    // For card_through_link payment, always require customer details with email
    if (_selectedPaymentType == 'card_through_link') {
      // In edit mode, always show customer details form to allow verification/updates
      if (_isEditMode) {
        setState(() {
          _showPayment = false; // Stay on customer details screen
          _hasProcessedFirstStep = true; // Mark as processed to show form
        });
        return;
      }

      // In new order mode: If customer details already exist and have email, send payment link
      if (_customerDetails != null &&
          _customerDetails!.email != null &&
          _customerDetails!.email!.trim().isNotEmpty) {
        // Customer details exist with email - send payment link API call
        print(
          '💳 Customer details exist with email - calling payment link API',
        );
        _handleCardThroughLinkSubmission(_customerDetails!);
        return;
      }

      // Customer details missing or email missing - need to collect/re-collect
      // Check if we need to validate existing customer details
      if (_customerDetails != null &&
          (_customerDetails!.email == null ||
              _customerDetails!.email!.trim().isEmpty)) {
        // Customer details exist but email is missing
        CustomPopupService.show(
          context,
          'Email is required for Card Through Link payment. Please update customer details.',
          type: PopupType.failure,
        );
      }

      // Show customer details form (will populate existing data if available)
      setState(() {
        _showPayment = false; // Stay on customer details screen
        _hasProcessedFirstStep = true; // Mark as processed to show form
      });
      return;
    }

    // For other payment types, use existing logic
    if (_actualOrderType.toLowerCase() == 'dinein' ||
        _actualOrderType.toLowerCase() == 'takeout') {
      setState(() {
        _customerDetails = CustomerDetails(
          name:
              _actualOrderType.toLowerCase() == 'dinein'
                  ? 'Dine-in Customer'
                  : 'Takeout Customer',
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
      setState(() {});
    }
  }

  // Updated _buildServiceHighlight method to always allow interaction
  Widget _buildServiceHighlight(String type, String imageName) {
    // For dinein flow, keep dinein service highlight selected for both radio options
    bool isSelected;
    if (type.toLowerCase() == 'dinein' &&
        (_actualOrderType.toLowerCase() == 'dinein' ||
            _actualOrderType.toLowerCase() == 'takeout')) {
      isSelected = true; // Keep dinein highlighted for both dinein and takeout
    } else {
      isSelected =
          _actualOrderType.toLowerCase() == type.toLowerCase() ||
          (type.toLowerCase() == 'takeaway' &&
              _actualOrderType.toLowerCase() == 'collection');
    }

    String displayImage =
        isSelected && !imageName.contains('white.png')
            ? imageName.replaceAll('.png', 'white.png')
            : imageName;

    String baseImageNameForSizing = imageName.replaceAll('white.png', '.png');

    return InkWell(
      // REMOVED: _hasProcessedFirstStep condition to always allow selection
      onTap: () {
        bool switchingFromDineInToOthers =
            ((_actualOrderType.toLowerCase() == 'dinein' ||
                    _actualOrderType.toLowerCase() == 'takeout') &&
                (type.toLowerCase() == 'delivery' ||
                    type.toLowerCase() == 'takeaway'));

        bool switchingToDineIn =
            ((_actualOrderType.toLowerCase() == 'delivery' ||
                    _actualOrderType.toLowerCase() == 'takeaway' ||
                    _actualOrderType.toLowerCase() == 'collection') &&
                type.toLowerCase() == 'dinein');

        // Show confirmation dialog if cart has items and switching between different order types
        bool significantChange =
            switchingFromDineInToOthers || switchingToDineIn;

        if (_cartItems.isNotEmpty && significantChange) {
          _showOrderTypeChangeDialog(type);
        } else {
          _changeOrderType(type);
        }
      },
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          // REMOVED: Grayed out appearance when processed
          border:
              !isSelected
                  ? Border.all(color: Colors.grey.withOpacity(0.3), width: 1)
                  : null,
        ),
        child: Center(
          child: Image.asset(
            'assets/images/$displayImage',
            width: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
            height: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
            fit: BoxFit.contain,
            // REMOVED: Grayed out color when processed
            color: isSelected ? Colors.white : const Color(0xFF616161),
          ),
        ),
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
        double minTextContainerHeight =
            textFontSize * 1.5 + (2 * textContainerPaddingVertical);

        double totalHeight =
            itemHeight + (baseUnit * 0.05) + minTextContainerHeight;

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
                          _selectedShawarmaSubcategory = 0;
                          _selectedWingsSubcategory = 0;
                          _selectedDealsSubcategory = 0;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: itemWidth,
                            height: itemHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                baseUnit * 0.6,
                              ),
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
                                color:
                                    isSelected
                                        ? const Color(0xFFF3D9FF)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  baseUnit * 1.0,
                                ),
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

  // Helper function to determine if delivery charges should apply
  bool _shouldApplyDeliveryCharge(String? orderType, String? paymentType) {
    if (orderType == null) return false;

    // Check if orderType is delivery
    if (orderType.toLowerCase() == 'delivery') {
      return true;
    }

    // Check if paymentType indicates delivery (COD, Cash on delivery, etc.)
    if (paymentType != null) {
      final paymentTypeLower = paymentType.toLowerCase();
      if (paymentTypeLower.contains('cod') ||
          paymentTypeLower.contains('cash on delivery') ||
          paymentTypeLower.contains('delivery')) {
        return true;
      }
    }

    return false;
  }
}

class Category {
  final String name;
  final String image;
  Category({required this.name, required this.image});
}
