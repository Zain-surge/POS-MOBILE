// lib/models/cart_item.dart

import 'package:epos/models/food_item.dart'; // Ensure this import path is correct

class CartItem {
  final FoodItem foodItem;
  int quantity;
  final List<String>? selectedOptions;
  final String? comment;
  final double pricePerUnit; // Price of one unit of this item with selected options

  // Constructor
  CartItem({
    required this.foodItem,
    this.quantity = 1,
    this.selectedOptions,
    this.comment,
    required this.pricePerUnit, // Must be provided when creating CartItem
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

  // Getter for the total price of this cart item (quantity * pricePerUnit)
  double get totalPrice => pricePerUnit * quantity;

  // Optional: A string representation of selected options for display
  String get detailsString {
    if (selectedOptions == null || selectedOptions!.isEmpty) {
      return '';
    }
    return selectedOptions!.join(', ');
  }
}