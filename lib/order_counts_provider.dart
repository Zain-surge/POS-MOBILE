// lib/providers/order_counts_provider.dart

import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:flutter/material.dart'; // For Color

class OrderCountsProvider extends ChangeNotifier {
  // This map will hold the numerical counts for each order type (UNCHANGED)
  Map<String, int> _activeOrdersCount = {
    'takeaway': 0,
    'dinein': 0,
    'delivery': 0,
    'website': 0,
  };

  // This map will hold the DOMINANT COLOR for each order type (NEW)
  // Default to a neutral color (e.g., Colors.grey or Colors.green)
  Map<String, Color> _dominantOrderColors = {
    'takeaway': Colors.grey, // Or Colors.green if no orders means green
    'dinein': Colors.grey,
    'delivery': Colors.grey,
    'website': Colors.grey,
  };

  // Getter for numerical order type counts (UNCHANGED)
  Map<String, int> get activeOrdersCount => _activeOrdersCount;

  // NEW: Getter for dominant order colors
  Map<String, Color> get dominantOrderColors => _dominantOrderColors;


  // Method to update the numerical counts (UNCHANGED logic for updating counts)
  void updateActiveOrdersCount(Map<String, int> newCounts) {
    bool changed = false;
    newCounts.forEach((key, value) {
      if (_activeOrdersCount[key] != value) {
        changed = true;
      }
    });

    if (changed) {
      _activeOrdersCount = newCounts;
      notifyListeners();
      print('OrderCountsProvider: Type counts updated and listeners notified: $_activeOrdersCount');
    } else {
      print('OrderCountsProvider: Type counts are the same, no notification sent.');
    }
  }

  // NEW: Method to update the dominant colors
  void updateDominantOrderColors(Map<String, Color> newColors) {
    bool changed = false;
    newColors.forEach((key, value) {
      if (_dominantOrderColors[key] != value) {
        changed = true;
      }
    });

    if (changed) {
      _dominantOrderColors = newColors;
      notifyListeners();
      print('OrderCountsProvider: Dominant colors updated and listeners notified: $_dominantOrderColors');
    } else {
      print('OrderCountsProvider: Dominant colors are the same, no notification sent.');
    }
  }

  // You can keep your individual set/increment/decrement methods if you still use them for specific types
  // They don't affect the dominant color logic, which is based on the *entire* activeOrders list.

  // Method to increment the count for a specific order type (UNCHANGED)
  void incrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) + 1;
      notifyListeners(); // Notify listeners that the data has changed
      print('Incremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}');
    } else {
      print('Warning: Attempted to increment count for unknown order type: $orderType');
    }
  }

  // Method to decrement the count for a specific order type (UNCHANGED)
  void decrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType) && (_activeOrdersCount[lowerCaseOrderType] ?? 0) > 0) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) - 1;
      notifyListeners();
      print('Decremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}');
    } else {
      print('Warning: Attempted to decrement count for unknown or zero-count order type: $orderType');
    }
  }


  // Reset all counts and colors
  void resetCounts() {
    _activeOrdersCount = {
      'takeaway': 0,
      'dinein': 0,
      'delivery': 0,
      'website': 0,
    };
    _dominantOrderColors = { // Reset colors too
      'takeaway': Colors.grey,
      'dinein': Colors.grey,
      'delivery': Colors.grey,
      'website': Colors.grey,
    };
    notifyListeners();
    print('OrderCountsProvider: All counts and dominant colors reset.');
  }

  void setOrderCount(String orderType, int count) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      if (_activeOrdersCount[lowerCaseOrderType] != count) {
        _activeOrdersCount[lowerCaseOrderType] = count;
        notifyListeners();
        print('Set $lowerCaseOrderType count to: $count');
      } else {
        print('OrderCountsProvider: $lowerCaseOrderType count already $count, no change needed.');
      }
    } else {
      print('Warning: Attempted to set count for unknown order type: $orderType');
    }
  }
}