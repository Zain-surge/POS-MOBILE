// lib/providers/food_items_provider.dart
import 'package:flutter/foundation.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/api_service.dart';

class FoodItemsProvider extends ChangeNotifier {
  List<FoodItem> _foodItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;

  // Cache duration - refresh if older than 5 minutes
  static const Duration _cacheDuration = Duration(minutes: 5);

  List<FoodItem> get foodItems => _foodItems;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  bool get hasData => _foodItems.isNotEmpty;

  Future<void> fetchFoodItems({bool forceRefresh = false}) async {
    // Check if cache is still valid
    if (!forceRefresh && _foodItems.isNotEmpty && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheDuration) {
        print(
          '🍕 FoodItemsProvider: Using cached food items (${_foodItems.length} items)',
        );
        return; // Use cached data
      }
    }

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🍕 FoodItemsProvider: Fetching food items from API...');
      final items = await ApiService.fetchMenuItems();
      _foodItems = items;
      _lastFetchTime = DateTime.now();
      _hasError = false;
      _errorMessage = null;
      print(
        '🍕 FoodItemsProvider: Successfully loaded ${_foodItems.length} food items',
      );
    } catch (e) {
      print('🍕 FoodItemsProvider: Error fetching food items: $e');
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<FoodItem> getFoodItemsSync() {
    if (_foodItems.isEmpty && !_isLoading) {
      // Trigger background fetch if cache is empty
      fetchFoodItems();
    }
    return _foodItems;
  }

  /// Update a single food item in the cache (useful for availability toggles)
  void updateFoodItem(FoodItem updatedItem) {
    final index = _foodItems.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _foodItems[index] = updatedItem;
      print('🍕 FoodItemsProvider: Updated food item ${updatedItem.name}');
      notifyListeners();
    }
  }

  /// Clear cache and force next fetch to reload from API
  void clearCache() {
    _foodItems = [];
    _lastFetchTime = null;
    _hasError = false;
    _errorMessage = null;
    print('🍕 FoodItemsProvider: Cache cleared');
    notifyListeners();
  }

  /// Preload food items in the background (non-blocking)
  /// Call this early in app lifecycle to have data ready
  void preloadFoodItems() {
    if (_foodItems.isEmpty && !_isLoading) {
      print('🍕 FoodItemsProvider: Preloading food items...');
      fetchFoodItems();
    }
  }
}
