// lib/models/order.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/uk_time_service.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class OrderItem {
  final int? itemId;
  final int quantity;
  final String description;
  final double totalPrice;
  final String itemName;
  final String itemType;
  final String? imageUrl;
  final String? comment;
  final FoodItem? foodItem;

  OrderItem({
    this.itemId,
    required this.quantity,
    required this.description,
    required this.totalPrice,
    required this.itemName,
    required this.itemType,
    this.imageUrl,
    this.comment,
    this.foodItem,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double _parseDouble(dynamic value, [String fieldName = '']) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed == null) {
          print(
            'Warning: Failed to parse OrderItem $fieldName "$value" to double.',
          );
          return 0.0;
        }
        return parsed;
      }
      print(
        'Warning: Unexpected type for OrderItem $fieldName: ${value.runtimeType}. Value: $value',
      );
      return 0.0;
    }

    // Try multiple possible comment field names
    final comment =
        json['comment'] ??
        json['item_comment'] ??
        json['order_extra_notes'] ??
        json['notes'] ??
        json['item_notes'] ??
        json['description_comment'] as String?;

    final parsedItem = OrderItem(
      itemId: json['item_id'],
      itemName: json['item_name'] ?? 'Unknown Item',
      itemType: json['type'] ?? json['item_type'] ?? 'Unknown Type',
      quantity: json['quantity'] ?? 0,
      description: json['description'] ?? json['item_description'] ?? '',
      totalPrice: _parseDouble(
        json['total_price'] ?? json['item_total_price'],
        'total_price',
      ),
      imageUrl: json['item_image_url'] ?? json['image_url'],
      comment: comment,
      foodItem:
          json['food_item'] != null
              ? FoodItem.fromJson(json['food_item'])
              : null,
    );

    return parsedItem;
  }

  Map<String, dynamic> toJson() => {
    if (itemId != null) 'item_id': itemId,
    'quantity': quantity,
    'description': description,
    'total_price': totalPrice,
    'item_name': itemName,
    'item_type': itemType,
    if (imageUrl != null) 'image_url': imageUrl,
    if (comment != null) 'comment': comment,
    if (foodItem != null) 'food_item': foodItem!.toJson(),
  };

  // Add copyWith method for completeness
  OrderItem copyWith({
    int? itemId,
    int? quantity,
    String? description,
    double? totalPrice,
    String? itemName,
    String? itemType,
    String? imageUrl,
    String? comment,
    FoodItem? foodItem,
  }) {
    return OrderItem(
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      totalPrice: totalPrice ?? this.totalPrice,
      itemName: itemName ?? this.itemName,
      itemType: itemType ?? this.itemType,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
      foodItem: foodItem ?? this.foodItem,
    );
  }
}

class Order {
  final int orderId; // Internal use only (for API calls)
  final String? orderNumber; // Display to user (on receipts, UI, etc.)
  final String paymentType;
  final String transactionId;
  final String orderType;
  String status;
  final DateTime createdAt;
  final DateTime? updatedAt; // New field to track if order was edited
  final double changeDue;
  final String orderSource;
  final String customerName;
  final String? customerEmail;
  final String? phoneNumber;
  final String? streetAddress;
  final String? city;
  final String? county;
  final String? postalCode;
  final double orderTotalPrice;
  final double? previousTotalPrice; // Track price before edit
  final double? discountPercentage; // Discount percentage applied
  final double? discountAmount; // Discount amount in currency
  final String? orderExtraNotes;
  final List<OrderItem> items;
  final int? driverId;
  final bool paidStatus;

  Order({
    required this.orderId,
    this.orderNumber, // Optional - from backend
    required this.paymentType,
    required this.transactionId,
    required this.orderType,
    required this.status,
    required this.createdAt,
    this.updatedAt, // Optional field
    required this.changeDue,
    required this.orderSource,
    required this.customerName,
    this.customerEmail,
    this.phoneNumber,
    this.streetAddress,
    this.city,
    this.county,
    this.postalCode,
    required this.orderTotalPrice,
    this.previousTotalPrice, // Optional - only set when order is edited
    this.discountPercentage, // Optional discount percentage
    this.discountAmount, // Optional discount amount
    this.orderExtraNotes,
    required this.items,
    this.driverId,
    this.paidStatus = false,
  });

  // Helper to get display order number (fallback to orderId if not available)
  String get displayOrderNumber => orderNumber ?? orderId.toString();

  // Helper method to check if order was edited
  bool get isEdited => updatedAt != null;

  // Helper method to get price difference (positive = increase, negative = decrease)
  double get priceDifference {
    if (previousTotalPrice == null) return 0.0;
    return orderTotalPrice - previousTotalPrice!;
  }

  // Helper method to check if price changed
  bool get priceChanged => previousTotalPrice != null && priceDifference != 0.0;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Move helper function inside factory constructor
    double parseDouble(dynamic value, String fieldName) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed == null) {
          print(
            'Warning: Failed to parse Order $fieldName "$value" to double.',
          );
          return 0.0;
        }
        return parsed;
      }
      print(
        'Warning: Unexpected type for Order $fieldName: ${value.runtimeType}. Value: $value',
      );
      return 0.0;
    }

    String? parseNullableString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    // Helper to parse discount_details (which might be JSON string, object, or text)
    Map<String, dynamic>? parseDiscountDetails(dynamic discountDetails) {
      if (discountDetails == null) return null;

      // If it's already a map, return it
      if (discountDetails is Map<String, dynamic>) {
        return discountDetails;
      }

      // If it's a string, try to parse it as JSON
      if (discountDetails is String) {
        try {
          return jsonDecode(discountDetails) as Map<String, dynamic>;
        } catch (e) {
          // Not valid JSON (might be promotional text) - return null to fallback
          return null;
        }
      }

      return null;
    }

    // Helper to extract percentage from promotional text like "25% OFF..."
    double? extractPercentageFromText(String? text) {
      if (text == null || text.isEmpty) return null;

      // Look for pattern like "25% OFF" or "25%" in the text
      final regex = RegExp(r'(\d+(?:\.\d+)?)\s*%');
      final match = regex.firstMatch(text);

      if (match != null && match.groupCount >= 1) {
        return double.tryParse(match.group(1)!);
      }

      return null;
    }

    double totalPrice = 0.0;

    // Check various possible field names
    if (json['order_total_price'] != null) {
      totalPrice = parseDouble(json['order_total_price'], 'order_total_price');
    } else if (json['total_price'] != null) {
      totalPrice = parseDouble(json['total_price'], 'total_price');
    } else if (json['total'] != null) {
      totalPrice = parseDouble(json['total'], 'total');
    } else if (json['orderTotalPrice'] != null) {
      totalPrice = parseDouble(json['orderTotalPrice'], 'orderTotalPrice');
    } else {
      final items =
          (json['items'] as List?)
              ?.map((itemJson) => OrderItem.fromJson(itemJson))
              .toList() ??
          [];
      totalPrice = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    }
    final parsedOrder = Order(
      orderId: json['order_id'] ?? 0,
      orderNumber: parseNullableString(json['order_number']),
      paymentType: parseNullableString(json['payment_type']) ?? 'N/A',
      transactionId: parseNullableString(json['transaction_id']) ?? 'N/A',
      orderType: parseNullableString(json['order_type']) ?? 'N/A',
      status: parseNullableString(json['status']) ?? 'unknown',
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at']) ?? UKTimeService.now()
              : UKTimeService.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null, // Parse updated_at if exists
      changeDue: parseDouble(json['change_due'], 'change_due'),
      orderSource: parseNullableString(json['order_source']) ?? 'N/A',
      customerName: parseNullableString(json['customer_name']) ?? 'N/A',
      customerEmail: parseNullableString(json['customer_email']),
      phoneNumber: parseNullableString(json['phone_number']),
      streetAddress: parseNullableString(json['street_address']),
      city: parseNullableString(json['city']),
      county: parseNullableString(json['county']),
      postalCode: parseNullableString(json['postal_code']),
      orderTotalPrice: totalPrice,
      previousTotalPrice: null, // Will be set locally when editing
      discountPercentage: () {
        // Try to parse discount_details first (JSON format)
        final discountDetails = parseDiscountDetails(json['discount_details']);
        if (discountDetails != null) {
          return parseDouble(
            discountDetails['percentage'],
            'discount_details.percentage',
          );
        }
        // Fallback to direct discount_percentage field
        final directPercentage = parseDouble(
          json['discount_percentage'],
          'discount_percentage',
        );
        if (directPercentage > 0) return directPercentage;

        // Fallback to extracting percentage from promotional text
        final extractedPercentage = extractPercentageFromText(
          json['discount_details']?.toString(),
        );
        if (extractedPercentage != null && extractedPercentage > 0) {
          return extractedPercentage;
        }

        return 0.0;
      }(),
      discountAmount: () {
        // Try to parse discount_details first (JSON format)
        final discountDetails = parseDiscountDetails(json['discount_details']);
        if (discountDetails != null) {
          return parseDouble(
            discountDetails['amount'],
            'discount_details.amount',
          );
        }
        // Fallback to direct discount_amount field
        final directAmount = parseDouble(
          json['discount_amount'],
          'discount_amount',
        );
        if (directAmount > 0) return directAmount;

        // Fallback to discount field (used by website orders)
        return parseDouble(json['discount'], 'discount');
      }(),
      orderExtraNotes: parseNullableString(
        json['order_extra_notes'] ?? json['extra_notes'] ?? json['notes'],
      ),
      items:
          (json['items'] as List?)
              ?.map((itemJson) => OrderItem.fromJson(itemJson))
              .toList() ??
          [],
      driverId: json['driver_id'] as int?,
      paidStatus:
          json['paid_status'] as bool? ??
          false, // Default to unpaid if not specified, so orders show in active list
    );

    return parsedOrder;
  }

  Map<String, dynamic> toJson() => {
    'transaction_id': transactionId,
    'payment_type': paymentType,
    'order_type': orderType,
    'total_price': orderTotalPrice,
    'extra_notes': orderExtraNotes,
    'status': status,
    'order_source': orderSource,
    'items': items.map((item) => item.toJson()).toList(),
    if (driverId != null) 'driver_id': driverId,
  };

  Order copyWith({
    int? orderId,
    String? orderNumber,
    String? paymentType,
    String? transactionId,
    String? orderType,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? changeDue,
    String? orderSource,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? county,
    String? postalCode,
    double? orderTotalPrice,
    double? previousTotalPrice,
    double? discountPercentage,
    double? discountAmount,
    String? orderExtraNotes,
    List<OrderItem>? items,
    int? driverId,
    bool? paidStatus,
    double? cardAmount,
    double? cashAmount,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      paymentType: paymentType ?? this.paymentType,
      transactionId: transactionId ?? this.transactionId,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      changeDue: changeDue ?? this.changeDue,
      orderSource: orderSource ?? this.orderSource,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      streetAddress: streetAddress ?? this.streetAddress,
      city: city ?? this.city,
      county: county ?? this.county,
      postalCode: postalCode ?? this.postalCode,
      orderTotalPrice: orderTotalPrice ?? this.orderTotalPrice,
      previousTotalPrice: previousTotalPrice ?? this.previousTotalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      orderExtraNotes: orderExtraNotes ?? this.orderExtraNotes,
      items: items ?? this.items,
      driverId: driverId ?? this.driverId,
      paidStatus: paidStatus ?? this.paidStatus,
    );
  }

  // --- MODIFIED: Time-based statusColor getter ---
  Color get statusColor {
    // First check if order is completed - completed orders should always be grey
    switch (status.toLowerCase()) {
      case 'blue':
      case 'completed':
      case 'delivered':
        return HexColor.fromHex(
          'D6D6D6',
        ); // Always return grey for completed orders
    }
    // For non-completed orders, calculate time-based colors
    final now = UKTimeService.now();
    final timeDifference = now.difference(createdAt);
    final minutesPassed = timeDifference.inMinutes;
    if (minutesPassed < 30) {
      return HexColor.fromHex('DEF5D4'); // Green shade - order just placed
    } else if (minutesPassed >= 30 && minutesPassed < 45) {
      return HexColor.fromHex('FFF6D4'); // Yellow shade - 30-45 minutes
    } else {
      return HexColor.fromHex('ffcaca'); // Red shade - 45+ minutes
    }
  }

  String get statusLabel {
    return getDisplayStatusLabel();
  }

  String getDisplayStatusLabel() {
    // Special handling for offline orders
    if (status.toLowerCase() == 'offline' || orderSource == 'epos_offline') {
      return 'OFFLINE';
    }

    // Special handling for delivery orders (both EPOS and Website)
    final isDeliveryOrder =
        (orderSource.toLowerCase() == 'epos' &&
            orderType.toLowerCase() == 'delivery') ||
        (orderSource.toLowerCase() == 'website' &&
            orderType.toLowerCase() == 'delivery');

    if (isDeliveryOrder) {
      print(
        '🚚 Delivery Order ${orderId}: status=${status}, driverId=${driverId}',
      );

      // For delivery orders with driver assigned and ready status
      if ((status.toLowerCase() == 'ready' ||
              status.toLowerCase() == 'green') &&
          driverId != null) {
        print(
          '🚚 Order ${orderId}: Showing "On Its Way" (status: ${status}, driver: ${driverId})',
        );
        return 'On Its Way';
      }
      // For delivery orders that are completed
      else if (status.toLowerCase() == 'blue' ||
          status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'delivered') {
        print('✅ Order ${orderId}: Showing "Completed" (status: ${status})');
        return 'Completed';
      }
    }

    // Default status mapping for all other cases
    switch (status.toLowerCase()) {
      case 'yellow':
      case 'pending':
      case 'accepted':
        return 'Pending';
      case 'green':
      case 'ready':
      case 'preparing':
        return 'Ready';
      case 'blue':
      case 'completed':
      case 'delivered':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  // Address display in website order incoming
  String get displayAddressSummary {
    final postcode = postalCode ?? '';
    final street = streetAddress ?? '';
    if (postcode.isNotEmpty && street.isNotEmpty) {
      return '$postcode, $street';
    } else if (postcode.isNotEmpty) {
      return postcode;
    } else if (street.isNotEmpty) {
      return street;
    } else {
      return 'No Address Details';
    }
  }

  String get displaySummary {
    if (orderType.toLowerCase() == 'delivery' ||
        orderType.toLowerCase() == 'pickup') {
      return streetAddress ?? 'No Address Provided';
    } else {
      final firstTwoItems = items.take(2).map((e) => e.itemName).join(', ');
      return firstTwoItems.isEmpty ? 'No items' : firstTwoItems;
    }
  }
}
