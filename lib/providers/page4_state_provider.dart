// lib/providers/page4_state_provider.dart
import 'package:flutter/foundation.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';
import '../models/order_models.dart';

// Single order type state container
class OrderTypeState {
  List<CartItem> cartItems = [];
  CustomerDetails? customerDetails;
  String selectedPaymentType = '';
  bool hasProcessedFirstStep = false;
  bool showPayment = false;
  double appliedDiscountPercentage = 0.0;
  double discountAmount = 0.0;
  bool showDiscountPage = false;
  bool wasDiscountPageShown = false;
  int selectedCategory = 0;
  String searchQuery = '';
  bool isEditMode = false;
  bool isSearchBarExpanded = false;

  // NEW: Add modal state
  bool isModalOpen = false;
  FoodItem? modalFoodItem;
  int? editingCartIndex;

  // NEW: Add comment editing state
  int? editingCommentIndex;
  String commentEditingText = '';

  // Method to reset this order type's state
  void reset() {
    cartItems.clear();
    customerDetails = null;
    selectedPaymentType = '';
    hasProcessedFirstStep = false;
    showPayment = false;
    appliedDiscountPercentage = 0.0;
    discountAmount = 0.0;
    showDiscountPage = false;
    wasDiscountPageShown = false;
    selectedCategory = 0;
    searchQuery = '';
    isEditMode = false;
    isSearchBarExpanded = false;
    isModalOpen = false;
    modalFoodItem = null;
    editingCartIndex = null;
    editingCommentIndex = null;
    commentEditingText = '';
  }

  // Copy constructor for state preservation
  OrderTypeState.from(OrderTypeState other) {
    cartItems = List.from(other.cartItems);
    customerDetails = other.customerDetails;
    selectedPaymentType = other.selectedPaymentType;
    hasProcessedFirstStep = other.hasProcessedFirstStep;
    showPayment = other.showPayment;
    appliedDiscountPercentage = other.appliedDiscountPercentage;
    discountAmount = other.discountAmount;
    showDiscountPage = other.showDiscountPage;
    wasDiscountPageShown = other.wasDiscountPageShown;
    selectedCategory = other.selectedCategory;
    searchQuery = other.searchQuery;
    isEditMode = other.isEditMode;
    isSearchBarExpanded = other.isSearchBarExpanded;
    isModalOpen = other.isModalOpen;
    modalFoodItem = other.modalFoodItem;
    editingCartIndex = other.editingCartIndex;
    editingCommentIndex = other.editingCommentIndex;
    commentEditingText = other.commentEditingText;
  }

  OrderTypeState();
}

class Page4StateProvider extends ChangeNotifier {
  // Separate state for each order type
  final Map<String, OrderTypeState> _orderTypeStates = {
    'collection': OrderTypeState(),
    'delivery': OrderTypeState(),
    'dinein': OrderTypeState(),
    'takeout': OrderTypeState(),
  };

  // Current active order type
  String _currentOrderType = 'collection';
  bool _isDisposed = false;

  String get currentOrderType => _currentOrderType;

  String _takeawaySubType = 'collection';

  String get takeawaySubType => _takeawaySubType;

  // Get current state based on active order type
  OrderTypeState get _currentState {
    return _orderTypeStates[_currentOrderType] ??
        _orderTypeStates['collection']!;
  }

  // Getters that return current order type's state
  List<CartItem> get cartItems => _currentState.cartItems;

  CustomerDetails? get customerDetails => _currentState.customerDetails;

  String get selectedPaymentType => _currentState.selectedPaymentType;

  bool get hasProcessedFirstStep => _currentState.hasProcessedFirstStep;

  bool get showPayment => _currentState.showPayment;

  double get appliedDiscountPercentage =>
      _currentState.appliedDiscountPercentage;

  double get discountAmount => _currentState.discountAmount;

  bool get showDiscountPage => _currentState.showDiscountPage;

  bool get wasDiscountPageShown => _currentState.wasDiscountPageShown;

  int get selectedCategory => _currentState.selectedCategory;

  String get searchQuery => _currentState.searchQuery;

  bool get isEditMode => _currentState.isEditMode;

  bool get isSearchBarExpanded => _currentState.isSearchBarExpanded;

  // NEW: Modal state getters
  bool get isModalOpen => _currentState.isModalOpen;

  FoodItem? get modalFoodItem => _currentState.modalFoodItem;

  int? get editingCartIndex => _currentState.editingCartIndex;

  // NEW: Comment editing state getters
  int? get editingCommentIndex => _currentState.editingCommentIndex;

  String get commentEditingText => _currentState.commentEditingText;

  // NEW: Method to switch order type and load appropriate state
  void switchToOrderType(String orderType, String subType) {
    _currentOrderType = orderType;
    _takeawaySubType = subType;

    // Ensure the state exists for this order type
    if (!_orderTypeStates.containsKey(orderType)) {
      _orderTypeStates[orderType] = OrderTypeState();
    }

    _safeNotifyListeners();
  }

  // Methods to update current order type's state
  void updateCartItems(List<CartItem> items) {
    _currentState.cartItems = List.from(items);
    _safeNotifyListeners();
  }

  void addCartItem(CartItem item) {
    _currentState.cartItems.add(item);
    _safeNotifyListeners();
  }

  void removeCartItem(int index) {
    if (index >= 0 && index < _currentState.cartItems.length) {
      _currentState.cartItems.removeAt(index);
      _safeNotifyListeners();
    }
  }

  void updateCartItem(int index, CartItem item) {
    if (index >= 0 && index < _currentState.cartItems.length) {
      _currentState.cartItems[index] = item;
      _safeNotifyListeners();
    }
  }

  void clearCart() {
    _currentState.cartItems.clear();
    _safeNotifyListeners();
  }

  void updateCustomerDetails(CustomerDetails? details) {
    _currentState.customerDetails = details;
    _safeNotifyListeners();
  }

  void updateOrderType(String orderType, String subType) {
    // This method should now use switchToOrderType instead
    switchToOrderType(orderType, subType);
  }

  void updatePaymentType(String paymentType) {
    _currentState.selectedPaymentType = paymentType;
    _safeNotifyListeners();
  }

  void updateProcessedFirstStep(bool processed) {
    _currentState.hasProcessedFirstStep = processed;
    _safeNotifyListeners();
  }

  void updateShowPayment(bool show) {
    _currentState.showPayment = show;
    _safeNotifyListeners();
  }

  void updateDiscountState({
    double? percentage,
    double? amount,
    bool? showPage,
    bool? wasShown,
  }) {
    if (percentage != null)
      _currentState.appliedDiscountPercentage = percentage;
    if (amount != null) _currentState.discountAmount = amount;
    if (showPage != null) _currentState.showDiscountPage = showPage;
    if (wasShown != null) _currentState.wasDiscountPageShown = wasShown;
    _safeNotifyListeners();
  }

  void updateUIState({
    int? category,
    String? search,
    bool? editMode,
    bool? searchExpanded,
  }) {
    if (category != null) _currentState.selectedCategory = category;
    if (search != null) _currentState.searchQuery = search;
    if (editMode != null) _currentState.isEditMode = editMode;
    if (searchExpanded != null)
      _currentState.isSearchBarExpanded = searchExpanded;
    _safeNotifyListeners();
  }

  // NEW: Modal state management
  void updateModalState({bool? isOpen, FoodItem? foodItem, int? editingIndex}) {
    if (isOpen != null) _currentState.isModalOpen = isOpen;
    if (foodItem != null) _currentState.modalFoodItem = foodItem;
    if (editingIndex != null) _currentState.editingCartIndex = editingIndex;

    // If closing modal, clear related state
    if (isOpen == false) {
      _currentState.modalFoodItem = null;
      _currentState.editingCartIndex = null;
    }

    _safeNotifyListeners();
  }

  // NEW: Comment editing state management
  void updateCommentEditingState({int? editingIndex, String? editingText}) {
    if (editingIndex != null) _currentState.editingCommentIndex = editingIndex;
    if (editingText != null) _currentState.commentEditingText = editingText;

    // If clearing editing index, also clear text
    if (editingIndex == null) {
      _currentState.commentEditingText = '';
    }
    _safeNotifyListeners();
  }

  void resetCurrentOrderType() {
    _currentState.reset();
    _safeNotifyListeners();
  }

  void resetAllOrderTypes() {
    for (var state in _orderTypeStates.values) {
      state.reset();
    }
    _currentOrderType = 'collection';
    _takeawaySubType = 'collection';
    _safeNotifyListeners();
  }

  // Legacy method name kept for compatibility
  void resetAllState() {
    resetAllOrderTypes();
  }

  // NEW: Method to get comprehensive state summary
  Map<String, dynamic> getStateSnapshot() {
    return {
      'currentOrderType': _currentOrderType,
      'takeawaySubType': _takeawaySubType,
      'cartItemsCount': _currentState.cartItems.length,
      'customerName': _currentState.customerDetails?.name ?? 'None',
      'hasProcessedFirstStep': _currentState.hasProcessedFirstStep,
      'showPayment': _currentState.showPayment,
      'selectedCategory': _currentState.selectedCategory,
      'searchQuery': _currentState.searchQuery,
      'isEditMode': _currentState.isEditMode,
      'isSearchBarExpanded': _currentState.isSearchBarExpanded,
      'isModalOpen': _currentState.isModalOpen,
      'editingCartIndex': _currentState.editingCartIndex,
      'appliedDiscountPercentage': _currentState.appliedDiscountPercentage,
    };
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
