// lib/providers/order_counts_provider.dart

import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:flutter/material.dart'; // For Color

class OrderCountsProvider extends ChangeNotifier {
  // This map will hold the numerical counts for each order type
  Map<String, int> _activeOrdersCount = {
    'takeaway': 0,
    'dinein': 0,
    'delivery': 0,
    'website': 0,
  };

  // This map will hold the DOMINANT COLOR for each order type
  // Default to the yellow color (0xFFFFE26B) which is used as the default notification color
  // in your CustomBottomNavBar, or Colors.transparent if you don't want any color if no orders.
  Map<String, Color> _dominantOrderColors = {
    'takeaway': const Color(0xFFFFE26B),
    'dinein': const Color(0xFFFFE26B),
    'delivery': const Color(0xFFFFE26B),
    'website': const Color(0xFFFFE26B),
  };

  // Getter for numerical order type counts
  Map<String, int> get activeOrdersCount => _activeOrdersCount;

  // Getter for dominant order type colors
  Map<String, Color> get dominantOrderColors => _dominantOrderColors;

  // NEW: Combined method to update both counts and colors
  void updateAllCountsAndColors(Map<String, int> newCounts, Map<String, Color> newColors) {
    bool countsChanged = false;
    newCounts.forEach((key, value) {
      if (_activeOrdersCount[key] != value) {
        countsChanged = true;
      }
    });

    bool colorsChanged = false;
    newColors.forEach((key, value) {
      if (_dominantOrderColors[key] != value) {
        colorsChanged = true;
      }
    });

    if (countsChanged || colorsChanged) {
      _activeOrdersCount = newCounts;
      _dominantOrderColors = newColors;
      notifyListeners(); // Notify listeners only if actual changes occurred
      // debugPrint('OrderCountsProvider: Counts or colors updated and listeners notified.');
    } else {
      // debugPrint('OrderCountsProvider: No changes in counts or colors, no notification sent.');
    }
  }

  // You can keep your individual set/increment/decrement methods if you still use them for specific types
  // They don't affect the dominant color logic, which is based on the *entire* activeOrders list.
  // Note: If you use these individual methods, they will still trigger a rebuild.
  // For comprehensive updates, `updateAllCountsAndColors` is preferred.

  // Method to increment the count for a specific order type
  void incrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) + 1;
      notifyListeners();
      // debugPrint('Incremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}');
    } else {
      debugPrint('Warning: Attempted to increment count for unknown order type: $orderType');
    }
  }

  // Method to decrement the count for a specific order type
  void decrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType) && (_activeOrdersCount[lowerCaseOrderType] ?? 0) > 0) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) - 1;
      notifyListeners();
      // debugPrint('Decremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}');
    } else {
      debugPrint('Warning: Attempted to decrement count for unknown or zero-count order type: $orderType');
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
      'takeaway': const Color(0xFFFFE26B), // Reset to default yellow
      'dinein': const Color(0xFFFFE26B),
      'delivery': const Color(0xFFFFE26B),
      'website': const Color(0xFFFFE26B),
    };
    notifyListeners();
    // debugPrint('OrderCountsProvider: All counts and dominant colors reset.');
  }

  // Method to set the count for a specific order type
  void setOrderCount(String orderType, int count) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      if (_activeOrdersCount[lowerCaseOrderType] != count) {
        _activeOrdersCount[lowerCaseOrderType] = count;
        notifyListeners();
        // debugPrint('Set $lowerCaseOrderType count to: $count');
      } else {
        // debugPrint('OrderCountsProvider: $lowerCaseOrderType count already $count, no change needed.');
      }
    } else {
      debugPrint('Warning: Attempted to set count for unknown order type: $orderType');
    }
  }
}