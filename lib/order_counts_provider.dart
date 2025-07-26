// lib/providers/order_counts_provider.dart

import 'package:flutter/foundation.dart'; // For ChangeNotifier

class OrderCountsProvider extends ChangeNotifier {
  // This map will hold the counts for each order type
  Map<String, int> _activeOrdersCount = {
    'takeaway': 0,
    'dinein': 0,
    'delivery': 0,
    'website': 0,
    // Add any other types you track if necessary
  };

  // Getter to provide read-only access to the counts
  Map<String, int> get activeOrdersCount => _activeOrdersCount;

  // Method to update the counts from anywhere in the app
  // This method will be called by ActiveOrdersList when counts change
  void updateActiveOrdersCount(Map<String, int> newCounts) {
    bool changed = false;
    newCounts.forEach((key, value) {
      if (_activeOrdersCount[key] != value) {
        changed = true;
      }
    });

    if (changed) {
      _activeOrdersCount = newCounts;
      notifyListeners(); // Notify all listening widgets to rebuild
      print('OrderCountsProvider: Counts updated and listeners notified: $_activeOrdersCount');
    } else {
      print('OrderCountsProvider: Counts are the same, no notification sent.');
    }
  }

  // --- NEW METHOD: Set the count for a specific order type ---
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

  // Method to increment the count for a specific order type
  void incrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) + 1;
      notifyListeners(); // Notify listeners that the data has changed
      print('Incremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}'); // Debugging
    } else {
      print('Warning: Attempted to increment count for unknown order type: $orderType');
    }
  }

  // Method to decrement the count for a specific order type (optional, but good for completeness)
  void decrementOrderCount(String orderType) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType) && (_activeOrdersCount[lowerCaseOrderType] ?? 0) > 0) {
      _activeOrdersCount[lowerCaseOrderType] = (_activeOrdersCount[lowerCaseOrderType] ?? 0) - 1;
      notifyListeners();
      print('Decremented $lowerCaseOrderType count to: ${_activeOrdersCount[lowerCaseOrderType]}'); // Debugging
    } else {
      print('Warning: Attempted to decrement count for unknown or zero-count order type: $orderType');
    }
  }

  // You can also add methods to reset counts, etc., if needed
  void resetCounts() {
    _activeOrdersCount = {
      'takeaway': 0,
      'dinein': 0,
      'delivery': 0,
      'website': 0,
    };
    notifyListeners();
  }
}