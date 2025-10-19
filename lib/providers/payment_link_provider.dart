// lib/providers/payment_link_provider.dart
import 'package:flutter/foundation.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/models/cart_item.dart';

/// Provider for managing payment link state and API calls
/// Handles sending payment links to customers for card_through_link payments
class PaymentLinkProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _paymentLinkSent = false;
  Map<String, dynamic>? _paymentLinkResponse;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  bool get paymentLinkSent => _paymentLinkSent;
  Map<String, dynamic>? get paymentLinkResponse => _paymentLinkResponse;
  String? get errorMessage => _errorMessage;

  /// Send payment link to customer
  /// Call this when customer details are submitted for card_through_link payment
  Future<bool> sendPaymentLink({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<CartItem> cartItems,
    required double totalPrice,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('💳 PaymentLinkProvider: Sending payment link...');
      print('💳 Customer: $customerName ($customerEmail)');
      print('💳 Total: £${totalPrice.toStringAsFixed(2)}');

      // Prepare cart items for API
      final List<Map<String, dynamic>> paymentLinkCartItems =
          cartItems.map((cartItem) {
            final String itemTitle = _buildItemDescription(cartItem);
            final double itemTotal = cartItem.pricePerUnit * cartItem.quantity;
            return {
              'title': itemTitle,
              'itemQuantity': cartItem.quantity,
              'totalPrice': double.parse(itemTotal.toStringAsFixed(2)),
            };
          }).toList();

      // Call API
      final result = await ApiService.sendPaymentLink(
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        cartItems: paymentLinkCartItems,
        totalPrice: totalPrice,
      );

      if (result['success'] == true) {
        _paymentLinkSent = true;
        _paymentLinkResponse = result;
        print('💳 PaymentLinkProvider: Payment link sent successfully!');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Failed to send payment link';
        print('💳 PaymentLinkProvider: Error: $_errorMessage');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error sending payment link: $e';
      print('💳 PaymentLinkProvider: Exception: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Build item description for cart item (same logic as page4)
  String _buildItemDescription(CartItem cartItem) {
    final StringBuffer description = StringBuffer();
    description.write(cartItem.foodItem.name);

    if (cartItem.selectedOptions != null &&
        cartItem.selectedOptions!.isNotEmpty) {
      final filteredOptions =
          cartItem.selectedOptions!
              .where((option) => !_shouldExcludeOption(option))
              .toList();

      if (filteredOptions.isNotEmpty) {
        description.write(' - ');
        description.write(filteredOptions.join(', '));
      }
    }

    return description.toString();
  }

  /// Check if option should be excluded from description
  bool _shouldExcludeOption(String option) {
    final upperOption = option.toUpperCase().trim();
    return upperOption == 'BASE: TOMATO' || upperOption == 'CRUST: NORMAL';
  }

  /// Reset provider state (call this when starting a new order)
  void reset() {
    _isLoading = false;
    _paymentLinkSent = false;
    _paymentLinkResponse = null;
    _errorMessage = null;
    notifyListeners();
    print('💳 PaymentLinkProvider: State reset');
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
