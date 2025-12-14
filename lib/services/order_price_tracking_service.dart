// lib/services/order_price_tracking_service.dart

import 'package:hive_flutter/hive_flutter.dart';

/// Service to track price changes for edited orders (frontend only - not stored in DB)
class OrderPriceTrackingService {
  static final OrderPriceTrackingService _instance =
      OrderPriceTrackingService._internal();

  factory OrderPriceTrackingService() => _instance;

  OrderPriceTrackingService._internal();

  static const String _boxName = 'orderPriceChanges';
  Box<Map>? _box;

  // In-memory cache for quick access
  final Map<int, OrderPriceChange> _priceChanges = {};

  /// Initialize the service (call this on app startup after Hive.init())
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
      _loadFromBox();
      print(
        '📥 Loaded ${_priceChanges.length} price change records from storage',
      );
    } catch (e) {
      print('⚠️ Error initializing price tracking service: $e');
    }
  }

  /// Store a price change for an order
  Future<void> storePriceChange({
    required int orderId,
    required double previousPrice,
    required double newPrice,
  }) async {
    final priceChange = OrderPriceChange(
      orderId: orderId,
      previousPrice: previousPrice,
      newPrice: newPrice,
      timestamp: DateTime.now(),
    );

    // Store in memory
    _priceChanges[orderId] = priceChange;

    // Persist to disk
    await _saveToDisk(orderId, priceChange);

    print(
      '💰 Stored price change for order #$orderId: £${previousPrice.toStringAsFixed(2)} → £${newPrice.toStringAsFixed(2)}',
    );
  }

  /// Get price change for an order
  OrderPriceChange? getPriceChange(int orderId) {
    return _priceChanges[orderId];
  }

  /// Check if an order has a price change
  bool hasPriceChange(int orderId) {
    return _priceChanges.containsKey(orderId);
  }

  /// Get price difference for an order (positive = increase, negative = decrease)
  double? getPriceDifference(int orderId) {
    final change = _priceChanges[orderId];
    if (change == null) return null;
    return change.newPrice - change.previousPrice;
  }

  /// Remove price change tracking for an order
  Future<void> removePriceChange(int orderId) async {
    _priceChanges.remove(orderId);
    await _box?.delete(orderId);
  }

  /// Load price changes from Hive box
  void _loadFromBox() {
    if (_box == null) return;

    _priceChanges.clear();
    for (final key in _box!.keys) {
      if (key is int) {
        final data = _box!.get(key);
        if (data != null) {
          try {
            _priceChanges[key] = OrderPriceChange.fromMap(
              Map<String, dynamic>.from(data),
            );
          } catch (e) {
            print('⚠️ Error loading price change for order #$key: $e');
          }
        }
      }
    }
  }

  /// Save a price change to Hive
  Future<void> _saveToDisk(int orderId, OrderPriceChange change) async {
    try {
      await _box?.put(orderId, change.toMap());
    } catch (e) {
      print('⚠️ Error saving price change: $e');
    }
  }

  /// Clear old price changes (e.g., older than 30 days)
  Future<void> cleanupOldRecords({int maxAgeDays = 30}) async {
    final now = DateTime.now();
    final idsToRemove = <int>[];

    _priceChanges.forEach((orderId, change) {
      final age = now.difference(change.timestamp).inDays;
      if (age > maxAgeDays) {
        idsToRemove.add(orderId);
      }
    });

    for (final orderId in idsToRemove) {
      _priceChanges.remove(orderId);
      await _box?.delete(orderId);
    }

    if (idsToRemove.isNotEmpty) {
      print('🧹 Cleaned up ${idsToRemove.length} old price change records');
    }
  }

  /// Clear all price changes
  Future<void> clearAll() async {
    _priceChanges.clear();
    await _box?.clear();
    print('🧹 Cleared all price change records');
  }
}

/// Model to store price change information
class OrderPriceChange {
  final int orderId;
  final double previousPrice;
  final double newPrice;
  final DateTime timestamp;

  OrderPriceChange({
    required this.orderId,
    required this.previousPrice,
    required this.newPrice,
    required this.timestamp,
  });

  double get difference => newPrice - previousPrice;

  bool get priceIncreased => difference > 0;

  bool get priceDecreased => difference < 0;

  String get formattedDifference {
    final sign = priceIncreased ? '+' : '';
    return '$sign£${difference.toStringAsFixed(2)}';
  }

  factory OrderPriceChange.fromMap(Map<String, dynamic> map) {
    return OrderPriceChange(
      orderId: map['orderId'] as int,
      previousPrice: (map['previousPrice'] as num).toDouble(),
      newPrice: (map['newPrice'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'previousPrice': previousPrice,
      'newPrice': newPrice,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OrderPriceChange.fromJson(Map<String, dynamic> json) {
    return OrderPriceChange.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}
