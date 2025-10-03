// lib/providers/offline_provider.dart

import 'package:flutter/foundation.dart';
import 'package:epos/services/connectivity_service.dart';
import 'package:epos/services/cart_persistence_service.dart';
import 'package:epos/models/cart_item.dart';

class OfflineProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingOrdersCount = 0;
  bool _hasSavedCart = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingOrdersCount => _pendingOrdersCount;
  bool get hasSavedCart => _hasSavedCart;

  OfflineProvider() {
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    // Listen to connectivity changes
    _connectivityService.addListener(_onConnectivityChanged);

    // Get initial state
    _isOnline = _connectivityService.isOnline;
    _isSyncing = _connectivityService.isSyncing;
    print(
      '🌐 DEBUG: OfflineProvider initialized - isOnline: $_isOnline, isSyncing: $_isSyncing',
    );
    _updatePendingOrdersCount();
    _checkSavedCart();
  }

  void _onConnectivityChanged(bool isOnline) {
    final wasOnline = _isOnline;
    final wasSyncing = _isSyncing;
    _isOnline = isOnline;
    _isSyncing = _connectivityService.isSyncing;

    print(
      '🔄 OfflineProvider: Connectivity changed - wasOnline: $wasOnline, isOnline: $isOnline, wasSyncing: $wasSyncing, isSyncing: $_isSyncing',
    );

    // Update pending orders count when connectivity changes
    _updatePendingOrdersCount();

    // Show appropriate messages
    if (!wasOnline && isOnline) {
      print(
        '✅ OfflineProvider: Connection restored - sync should begin automatically',
      );
    } else if (wasOnline && !isOnline) {
      print(
        '❌ OfflineProvider: Connection lost - orders will be saved offline',
      );
    }

    notifyListeners();
  }

  void _updatePendingOrdersCount() {
    final oldCount = _pendingOrdersCount;
    _pendingOrdersCount = CartPersistenceService.getPendingOrdersCount();
    print(
      '🔄 OfflineProvider: Pending orders count updated from $oldCount to $_pendingOrdersCount',
    );
  }

  void _checkSavedCart() {
    _hasSavedCart = CartPersistenceService.hasSavedCartProgress();
  }

  // Save cart progress (call this during ordering)
  Future<void> saveCartProgress({
    required List<CartItem> cartItems,
    String? orderType,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? extraNotes,
  }) async {
    await CartPersistenceService.saveCartProgress(
      cartItems: cartItems,
      orderType: orderType,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      extraNotes: extraNotes,
    );

    _checkSavedCart();
    notifyListeners();
  }

  // Save order for later processing (when offline)
  Future<String?> saveOrderForLater({
    required List<CartItem> cartItems,
    required String paymentType,
    required String orderType,
    required double orderTotalPrice,
    String? orderExtraNotes,
    required String customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    required double changeDue,
  }) async {
    final transactionId = await CartPersistenceService.saveOrderForLater(
      cartItems: cartItems,
      paymentType: paymentType,
      orderType: orderType,
      orderTotalPrice: orderTotalPrice,
      orderExtraNotes: orderExtraNotes,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      changeDue: changeDue,
    );

    _updatePendingOrdersCount();
    _checkSavedCart();
    notifyListeners();

    return transactionId;
  }

  // Restore saved cart
  List<CartItem>? restoreSavedCart() {
    final cartItems = CartPersistenceService.restoreCartItems();
    if (cartItems != null) {
      _checkSavedCart();
      notifyListeners();
    }
    return cartItems;
  }

  // Get saved cart data
  Map<String, dynamic>? getSavedCartData() {
    return CartPersistenceService.getSavedCartProgress();
  }

  // Clear saved cart
  Future<void> clearSavedCart() async {
    await CartPersistenceService.clearSavedCartProgress();
    _checkSavedCart();
    notifyListeners();
  }

  // Force sync now
  Future<bool> forceSyncNow() async {
    final result = await _connectivityService.forceSyncNow();
    _isSyncing = _connectivityService.isSyncing;
    _updatePendingOrdersCount();
    notifyListeners();
    return result;
  }

  // Get connectivity info
  Map<String, dynamic> getConnectivityInfo() {
    return _connectivityService.getConnectivityInfo();
  }

  // Get cart progress age
  Duration? getCartProgressAge() {
    return CartPersistenceService.getCartProgressAge();
  }

  // Cleanup old data
  Future<void> cleanup() async {
    await CartPersistenceService.cleanupOldCartProgress();
    _checkSavedCart();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
