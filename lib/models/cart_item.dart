// lib/models/cart_item.dart

import 'package:epos/models/food_item.dart';

class CartItem {
  final FoodItem foodItem;
  int quantity;
  final List<String>? selectedOptions;
  final String? comment;
  final double pricePerUnit;

  // Constructor
  CartItem({
    required this.foodItem,
    this.quantity = 1,
    this.selectedOptions,
    this.comment,
    required this.pricePerUnit,
  });

  // Method to increment quantity
  void incrementQuantity([int amount = 1]) {
    quantity += amount;
  }

  // Method to decrement quantity
  void decrementQuantity([int amount = 1]) {
    if (quantity > amount) {
      quantity -= amount;
    } else {
      quantity = 0; // Or remove from cart if quantity becomes 0
    }
  }

  double get totalPrice => pricePerUnit * quantity;

  // Optional: A string representation of selected options for display
  String get detailsString {
    if (selectedOptions == null || selectedOptions!.isEmpty) {
      return '';
    }
    return selectedOptions!.join(', ');
  }
}
