// lib/providers/order_counts_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OrderCountsProvider extends ChangeNotifier {
  Map<String, int> _activeOrdersCount = {
    'collection': 0,
    'takeout': 0,  // New separate key for takeout
    'dinein': 0,
    'delivery': 0,
    'website': 0,
  };

  Map<String, Color> _dominantOrderColors = {
    'collection': const Color(0xFF8cdd69), // Default to green
    'takeout': const Color(0xFF8cdd69),  // New separate key for takeout
    'dinein': const Color(0xFF8cdd69),
    'delivery': const Color(0xFF8cdd69),
    'website': const Color(0xFF8cdd69),
  };

  // Getter for numerical order type counts
  Map<String, int> get activeOrdersCount => Map.from(_activeOrdersCount);

  // Getter for dominant order type colors
  Map<String, Color> get dominantOrderColors => Map.from(_dominantOrderColors);

  // Helper getter to get combined dinein count (dinein + takeout) for navbar display
  int get combinedDineinCount => (_activeOrdersCount['dinein'] ?? 0) + (_activeOrdersCount['takeout'] ?? 0);

  // Helper getter to get combined dinein color (highest priority between dinein and takeout)
  Color get combinedDineinColor {
    final dineinColor = _dominantOrderColors['dinein'] ?? const Color(0xFF8cdd69);
    final takeoutColor = _dominantOrderColors['takeout'] ?? const Color(0xFF8cdd69);

    final dineinPriority = getColorPriority(dineinColor);
    final takeoutPriority = getColorPriority(takeoutColor);

    // Return the color with higher priority (red > yellow > green)
    return dineinPriority >= takeoutPriority ? dineinColor : takeoutColor;
  }

  // Combined method to update both counts and colors with better logging
  void updateAllCountsAndColors(Map<String, int> newCounts, Map<String, Color> newColors) {

    bool countsChanged = false;
    bool colorsChanged = false;

    // Check for count changes
    newCounts.forEach((key, value) {
      if (_activeOrdersCount[key] != value) {
        countsChanged = true;
      }
    });

    // Check for color changes
    newColors.forEach((key, value) {
      if (_dominantOrderColors[key] != value) {
        colorsChanged = true;
      }
    });

    if (countsChanged || colorsChanged) {
      _activeOrdersCount = Map.from(newCounts);
      _dominantOrderColors = Map.from(newColors);

      Future.microtask(() {
        notifyListeners();
      });

    } else {
    }
  }

  // Helper method to convert Color to readable string
  // String _colorToString(Color color) {
  //   if (color == const Color(0xFF8cdd69)) return 'GREEN';
  //   if (color == const Color(0xFFFFE26B)) return 'YELLOW';
  //   if (color == const Color(0xFFff4848)) return 'RED';
  //   return 'UNKNOWN(${color.value.toRadixString(16)})';
  // }

  int getColorPriority(Color color) {
    if (color == const Color(0xFFff4848)) return 3; // Red - highest priority
    if (color == const Color(0xFFFFE26B)) return 2; // Yellow - medium priority
    if (color == const Color(0xFF8cdd69)) return 1; // Green - lowest priority
    return 0; // Unknown color
  }

  //Reset all counts and colors
  void resetCounts() {

    _activeOrdersCount = {
      'collection': 0,
      'takeout': 0,
      'dinein': 0,
      'delivery': 0,
      'website': 0,
    };
    _dominantOrderColors = {
      'collection': const Color(0xFF8cdd69), // Reset to default green
      'takeout': const Color(0xFF8cdd69),
      'dinein': const Color(0xFF8cdd69),
      'delivery': const Color(0xFF8cdd69),
      'website': const Color(0xFF8cdd69),
    };

    Future.microtask(() {
      notifyListeners();
    });
  }

  //Method to set the count for a specific order type
  void setOrderCount(String orderType, int count) {
    String lowerCaseOrderType = orderType.toLowerCase();
    if (_activeOrdersCount.containsKey(lowerCaseOrderType)) {
      final oldCount = _activeOrdersCount[lowerCaseOrderType];
      if (oldCount != count) {
        _activeOrdersCount[lowerCaseOrderType] = count;
        Future.microtask(() {
          notifyListeners();
        });
      }
    }
  }

  // Method to get individual takeout count (for use in other files)
  int get takeoutCount => _activeOrdersCount['takeout'] ?? 0;

  // Method to get individual dinein count (excluding takeout)
  int get dineinCount => _activeOrdersCount['dinein'] ?? 0;

  // Method to force a UI update (for debugging)
  void forceUpdate() {
    notifyListeners();
  }
}