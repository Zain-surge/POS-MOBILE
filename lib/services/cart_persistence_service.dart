// lib/services/cart_persistence_service.dart

import 'package:epos/models/food_item.dart';
import 'package:epos/services/offline_storage_service.dart';
import 'package:epos/models/cart_item.dart';
import 'package:uuid/uuid.dart';

class CartPersistenceService {
  static const String _cartSessionKey = 'current_cart_session';

  // Save current cart state (auto-save during ordering)
  static Future<void> saveCartProgress({
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
    try {
      final sessionId = const Uuid().v4();
      final cartData = {
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'order_type': orderType,
        'customer_name': customerName,
        'customer_email': customerEmail,
        'phone_number': phoneNumber,
        'street_address': streetAddress,
        'city': city,
        'postal_code': postalCode,
        'extra_notes': extraNotes,
        'cart_items':
            cartItems
                .map(
                  (item) => {
                    'food_item_id': item.foodItem.id,
                    'food_item_name': item.foodItem.name,
                    'food_item_category': item.foodItem.category,
                    'food_item_price': item.foodItem.effectivePosPrice,
                    'food_item_image': item.foodItem.image,
                    'food_item_availability': item.foodItem.availability,
                    'quantity': item.quantity,
                    'selected_options': item.selectedOptions,
                    'comment': item.comment,
                    'price_per_unit': item.pricePerUnit,
                  },
                )
                .toList(),
      };

      await OfflineStorageService.connectivityBox.put(
        _cartSessionKey,
        cartData,
      );
      print('💾 Cart progress saved (${cartItems.length} items)');
    } catch (e) {
      print('❌ Error saving cart progress: $e');
    }
  }

  // Get saved cart progress
  static Map<String, dynamic>? getSavedCartProgress() {
    try {
      return OfflineStorageService.connectivityBox.get(_cartSessionKey)
          as Map<String, dynamic>?;
    } catch (e) {
      print('❌ Error getting saved cart progress: $e');
      return null;
    }
  }

  // Clear saved cart progress (after successful order or manual clear)
  static Future<void> clearSavedCartProgress() async {
    try {
      await OfflineStorageService.connectivityBox.delete(_cartSessionKey);
      print('🗑️ Cart progress cleared');
    } catch (e) {
      print('❌ Error clearing cart progress: $e');
    }
  }

  // Check if there's a saved cart session
  static bool hasSavedCartProgress() {
    try {
      return OfflineStorageService.connectivityBox.containsKey(_cartSessionKey);
    } catch (e) {
      print('❌ Error checking saved cart progress: $e');
      return false;
    }
  }

  // Save order progress (when user completes order but is offline)
  static Future<String?> saveOrderForLater({
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
    try {
      final transactionId = await OfflineStorageService.saveOfflineOrder(
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

      // Clear cart progress after saving order
      await clearSavedCartProgress();

      print('📝 Order saved for later processing: $transactionId');
      return transactionId;
    } catch (e) {
      print('❌ Error saving order for later: $e');
      return null;
    }
  }

  // Get pending orders count for UI display
  static int getPendingOrdersCount() {
    return OfflineStorageService.getPendingOrdersCount();
  }

  // Get cart progress age (how long ago was it saved)
  static Duration? getCartProgressAge() {
    try {
      final cartData = getSavedCartProgress();
      if (cartData == null) return null;

      final timestampStr = cartData['timestamp'] as String?;
      if (timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      return DateTime.now().difference(timestamp);
    } catch (e) {
      print('❌ Error getting cart progress age: $e');
      return null;
    }
  }

  // Auto-cleanup old cart progress (older than 24 hours)
  static Future<void> cleanupOldCartProgress() async {
    try {
      final age = getCartProgressAge();
      if (age != null && age.inHours > 24) {
        await clearSavedCartProgress();
        print('🧹 Cleaned up old cart progress (${age.inHours} hours old)');
      }
    } catch (e) {
      print('❌ Error cleaning up old cart progress: $e');
    }
  }

  // Restore cart items from saved progress
  static List<CartItem>? restoreCartItems() {
    try {
      final cartData = getSavedCartProgress();
      if (cartData == null) return null;

      final cartItemsData = cartData['cart_items'] as List?;
      if (cartItemsData == null) return null;

      return cartItemsData.map((itemData) {
        final foodItemData = itemData as Map<String, dynamic>;

        // Reconstruct FoodItem
        final foodItem = FoodItem(
          id: foodItemData['food_item_id'] as int,
          name: foodItemData['food_item_name'] as String,
          category: foodItemData['food_item_category'] as String,
          price: Map<String, double>.from(
            foodItemData['food_item_price'] as Map,
          ),
          image: foodItemData['food_item_image'] as String,
          availability: foodItemData['food_item_availability'] as bool,
        );

        // Reconstruct CartItem
        return CartItem(
          foodItem: foodItem,
          quantity: foodItemData['quantity'] as int,
          selectedOptions:
              (foodItemData['selected_options'] as List?)?.cast<String>(),
          comment: foodItemData['comment'] as String?,
          pricePerUnit: foodItemData['price_per_unit'] as double,
        );
      }).toList();
    } catch (e) {
      print('❌ Error restoring cart items: $e');
      return null;
    }
  }
}
