// lib/models/cart_item.dart
import 'package:epos/models/food_item.dart';

class CartItem {
  final FoodItem foodItem;
  int quantity;
  final List<String>? selectedOptions;
  final String? comment;

  CartItem({
    required this.foodItem,
    this.quantity = 1,
    this.selectedOptions,
    this.comment,
  });

  double get totalPrice {
    return (foodItem.price.isNotEmpty ? foodItem.price.values.first : 0.0) * quantity;
  }

  String get detailsString {
    String details = '${quantity}x ${foodItem.name}';
    if (selectedOptions != null && selectedOptions!.isNotEmpty) {
      details += '\n  ${selectedOptions!.join('\n  ')}';
    }
    return details;
  }

  void incrementQuantity([int value = 1]) {
    quantity += value;
  }

  void decrementQuantity([int value = 1]) {
    if (quantity > value) {
      quantity -= value;
    } else {
      quantity = 0;
    }
  }
}