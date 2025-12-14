// lib/providers/item_availability_provider.dart

import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';
import 'package:epos/services/custom_popup_service.dart';

class ItemAvailabilityProvider with ChangeNotifier {
  List<FoodItem> _allItems = [];
  bool _isLoading = false;
  String? _error;

  // Add a singleton pattern to ensure only one instance exists
  static ItemAvailabilityProvider? _instance;

  factory ItemAvailabilityProvider() {
    _instance ??= ItemAvailabilityProvider._internal();
    return _instance!;
  }

  ItemAvailabilityProvider._internal() {
    // Initial fetch when the provider is created
    fetchItems();
  }

  // Filter to show only items where pos is true
  List<FoodItem> get allItems => _allItems.where((item) => item.pos).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Method to fetch all menu items
  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that loading has started

    try {
      final items = await ApiService.fetchMenuItems();
      _allItems = items;
      print(
        'ItemAvailabilityProvider: Menu items fetched: ${_allItems.length}',
      );
    } catch (e) {
      _error = e.toString();
      print('ItemAvailabilityProvider: Error fetching items: $_error');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading has finished
    }
  }

  // Method to update item availability with immediate consistency
  Future<void> updateItemAvailability(
    BuildContext context,
    int itemId,
    bool newAvailability,
  ) async {
    try {
      final int itemIndex = _allItems.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        if (context.mounted) {
          CustomPopupService.show(
            context,
            'Item not found in list.',
            type: PopupType.failure,
          );
        }
        return;
      }

      // Store original item for potential rollback
      final FoodItem originalItem = _allItems[itemIndex];

      // Immediate optimistic update - this will reflect everywhere instantly
      final FoodItem updatedItem = originalItem.copyWith(
        availability: newAvailability,
      );
      _allItems[itemIndex] = updatedItem;
      notifyListeners(); // This notifies ALL listeners immediately

      // Production-safe logging
      print(
        'ItemAvailabilityProvider: Optimistically updated ${originalItem.name} availability to $newAvailability',
      );

      try {
        // Make API call with timeout for release mode reliability
        await ApiService.setItemAvailability(itemId, newAvailability).timeout(
          const Duration(seconds: 15),
        ); // Increased timeout for production

        // Production-safe logging
        print(
          'ItemAvailabilityProvider: Server confirmed ${originalItem.name} availability: $newAvailability',
        );

        if (context.mounted) {
          CustomPopupService.show(
            context,
            '${originalItem.name} ${newAvailability ? 'enabled' : 'disabled'}!',
            type: PopupType.success,
          );
        }

        // Optionally refresh from server to ensure consistency
        // Uncomment the line below if you want to sync with server after each update
        // await _refreshSingleItem(itemId);
      } catch (e) {
        // Production-safe logging
        print(
          'ItemAvailabilityProvider: Failed to update ${originalItem.name} on server: $e',
        );

        // Revert optimistic update on error - ensure we're still in valid state
        if (itemIndex < _allItems.length && _allItems[itemIndex].id == itemId) {
          _allItems[itemIndex] = originalItem;
          notifyListeners(); // This reverts the change everywhere
        }

        if (context.mounted) {
          CustomPopupService.show(
            context,
            'Failed to update ${originalItem.name} availability. Please check your internet connection.',
            type: PopupType.failure,
          );
        }
      }
    } catch (e) {
      // Catch-all for any unexpected errors
      print(
        'ItemAvailabilityProvider: Unexpected error in updateItemAvailability: $e',
      );
      if (context.mounted) {
        CustomPopupService.show(
          context,
          'An unexpected error occurred. Please try again.',
          type: PopupType.failure,
        );
      }
    }
  }

  // Method to manually refresh all items (useful for periodic syncing)
  Future<void> refresh() async {
    await fetchItems();
  }

  // Helper to get only offline items
  List<FoodItem> get offlineItems =>
      _allItems.where((item) => !item.availability).toList();

  // Helper to get only available items
  List<FoodItem> get availableItems =>
      _allItems.where((item) => item.availability).toList();

  // Method to get item by ID
  FoodItem? getItemById(int itemId) {
    try {
      return _allItems.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  // Method to check if item is available
  bool isItemAvailable(int itemId) {
    final item = getItemById(itemId);
    return item?.availability ?? false;
  }

  // Method to add a new item
  Future<void> addItem({
    required BuildContext context,
    required String itemName,
    required String type,
    required String description,
    required Map<String, double> priceOptions,
    required Map<String, double> posPriceOptions,
    required List<String> toppings,
    required bool website,
    String? subtype,
  }) async {
    try {
      // Call the API service to add the item
      final response = await ApiService.addItem(
        itemName: itemName,
        type: type,
        description: description,
        price: priceOptions, // Send as JSONB field
        posPrice: posPriceOptions,
        toppings: toppings,
        website: website,
        subtype: subtype,
      );

      print('ItemAvailabilityProvider: Item added successfully: $response');

      // Refresh the items list to include the new item
      await fetchItems();

      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Item "$itemName" added successfully!',
          type: PopupType.success,
        );
      }
    } catch (e) {
      print('ItemAvailabilityProvider: Failed to add item: $e');

      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Failed to add item: ${e.toString()}',
          type: PopupType.failure,
        );
      }

      // Re-throw the error so the UI can handle it appropriately
      rethrow;
    }
  }

  // Method to update an existing item
  Future<void> updateItem({
    required BuildContext context,
    required int itemId,
    required String itemName,
    required String type,
    required String description,
    required Map<String, double> priceOptions,
    required Map<String, double> posPriceOptions,
    required List<String> toppings,
    required bool website,
    required bool availability,
    String? subtype,
  }) async {
    try {
      // Call the API service to update the item
      final response = await ApiService.updateItem(
        itemId: itemId,
        itemName: itemName,
        type: type,
        description: description,
        price: priceOptions, // Send as JSONB field
        posPrice: posPriceOptions,
        toppings: toppings,
        website: website,
        availability: availability,
        subtype: subtype,
      );

      print('ItemAvailabilityProvider: Item updated successfully: $response');

      // Refresh the items list to reflect the changes
      await fetchItems();

      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Item "$itemName" updated successfully!',
          type: PopupType.success,
        );
      }
    } catch (e) {
      print('ItemAvailabilityProvider: Failed to update item: $e');

      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Failed to update item: ${e.toString()}',
          type: PopupType.failure,
        );
      }

      // Re-throw the error so the UI can handle it appropriately
      rethrow;
    }
  }

  // Method to delete/disable item from POS
  Future<void> deleteItem(BuildContext context, int itemId) async {
    try {
      final int itemIndex = _allItems.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        if (context.mounted) {
          CustomPopupService.show(
            context,
            'Item not found in list.',
            type: PopupType.failure,
          );
        }
        return;
      }

      // Store original item for potential rollback
      final FoodItem originalItem = _allItems[itemIndex];

      // Optimistically update item to pos: false (hide from POS)
      final FoodItem updatedItem = originalItem.copyWith(pos: false);
      _allItems[itemIndex] = updatedItem;
      notifyListeners(); // This will trigger the filter and hide the item

      print(
        'ItemAvailabilityProvider: Optimistically disabled ${originalItem.name} from POS',
      );

      try {
        // Make API call to disable item from POS
        await ApiService.disableItemFromPOS(
          itemId,
        ).timeout(const Duration(seconds: 15));

        print(
          'ItemAvailabilityProvider: Server confirmed ${originalItem.name} disabled from POS',
        );

        if (context.mounted) {
          CustomPopupService.show(
            context,
            '${originalItem.name} removed from POS!',
            type: PopupType.success,
          );
        }
      } catch (e) {
        // Rollback on failure - restore original item
        _allItems[itemIndex] = originalItem;
        notifyListeners();

        print(
          'ItemAvailabilityProvider: Failed to disable ${originalItem.name} from POS: $e',
        );

        if (context.mounted) {
          CustomPopupService.show(
            context,
            'Failed to remove item from POS: ${e.toString()}',
            type: PopupType.failure,
          );
        }

        rethrow;
      }
    } catch (e) {
      print('ItemAvailabilityProvider: Delete operation failed: $e');

      if (context.mounted) {
        CustomPopupService.show(
          context,
          'Failed to delete item: ${e.toString()}',
          type: PopupType.failure,
        );
      }

      rethrow;
    }
  }
}
