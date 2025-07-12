// lib/models/order.dart

import 'package:flutter/material.dart';

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

  OrderItem({
    this.itemId,
    required this.quantity,
    required this.description,
    required this.totalPrice,
    required this.itemName,
    required this.itemType,
    this.imageUrl,
    this.comment,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double _parseDouble(dynamic value, [String fieldName = '']) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed == null) {
          print('Warning: Failed to parse OrderItem $fieldName "$value" to double.');
          return 0.0;
        }
        return parsed;
      }
      print('Warning: Unexpected type for OrderItem $fieldName: ${value.runtimeType}. Value: $value');
      return 0.0;
    }

    return OrderItem(
        itemId: json['item_id'],
        itemName: json['item_name'] ?? 'Unknown Item',
        itemType: json['type'] ?? json['item_type'] ?? 'Unknown Type',
        quantity: json['quantity'] ?? 0,
        description: json['description'] ?? json['item_description'] ?? '',
        totalPrice: _parseDouble(json['total_price'] ?? json['item_total_price'], 'total_price'),
        imageUrl: json['item_image_url'] ?? json['image_url'],
        comment: json['comment'] as String?
    );
  }

  Map<String, dynamic> toJson() => {
    if (itemId != null) 'item_id': itemId,
    'quantity': quantity,
    'description': description,
    'total_price': totalPrice,
  };
}

class Order {
  final int orderId;
  final String paymentType;
  final String transactionId;
  final String orderType;
  String status;
  final DateTime createdAt;
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
  final String? orderExtraNotes;
  final List<OrderItem> items;

  Order({
    required this.orderId,
    required this.paymentType,
    required this.transactionId,
    required this.orderType,
    required this.status,
    required this.createdAt,
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
    this.orderExtraNotes,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double _parseDouble(dynamic value, String fieldName) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed == null) {
          print('Warning: Failed to parse Order $fieldName "$value" to double.');
          return 0.0;
        }
        return parsed;
      }
      print('Warning: Unexpected type for Order $fieldName: ${value.runtimeType}. Value: $value');
      return 0.0;
    }

    print('🔍 DEBUG - Full JSON received: $json');
    print('🔍 DEBUG - order_total_price: ${json['order_total_price']}');
    print('🔍 DEBUG - total_price: ${json['total_price']}');
    print('🔍 DEBUG - total: ${json['total']}');
    print('🔍 DEBUG - orderTotalPrice: ${json['orderTotalPrice']}');

    // Try multiple possible field names for the total
    double totalPrice = 0.0;

    // Check various possible field names
    if (json['order_total_price'] != null) {
      totalPrice = _parseDouble(json['order_total_price'], 'order_total_price');
    } else if (json['total_price'] != null) {
      totalPrice = _parseDouble(json['total_price'], 'total_price');
    } else if (json['total'] != null) {
      totalPrice = _parseDouble(json['total'], 'total');
    } else if (json['orderTotalPrice'] != null) {
      totalPrice = _parseDouble(json['orderTotalPrice'], 'orderTotalPrice');
    } else {
      print('🔍 DEBUG - No total field found, calculating from items');
      final items = (json['items'] as List?)
          ?.map((itemJson) => OrderItem.fromJson(itemJson))
          .toList() ?? [];
      totalPrice = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    }

    print('🔍 DEBUG - Final calculated total: $totalPrice');

    return Order(
      orderId: json['order_id'] ?? 0,
      paymentType: json['payment_type'] ?? 'N/A',
      transactionId: json['transaction_id'] ?? 'N/A',
      orderType: json['order_type'] ?? 'N/A',
      status: json['status'] ?? 'unknown',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      changeDue: _parseDouble(json['change_due'], 'change_due'),
      orderSource: json['order_source'] ?? 'N/A',
      customerName: json['customer_name'] ?? 'N/A',
      customerEmail: json['customer_email'],
      phoneNumber: json['phone_number'],
      streetAddress: json['street_address'],
      city: json['city'],
      county: json['county'],
      postalCode: json['postal_code'],
      orderTotalPrice: totalPrice, // Use the calculated total
      orderExtraNotes: json['order_extra_notes'],
      items: (json['items'] as List?)
          ?.map((itemJson) => OrderItem.fromJson(itemJson))
          .toList() ?? [],
    );
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
  };

  Order copyWith({
    int? orderId,
    String? paymentType,
    String? transactionId,
    String? orderType,
    String? status,
    DateTime? createdAt,
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
    String? orderExtraNotes,
    List<OrderItem>? items,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      paymentType: paymentType ?? this.paymentType,
      transactionId: transactionId ?? this.transactionId,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
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
      orderExtraNotes: orderExtraNotes ?? this.orderExtraNotes,
      items: items ?? this.items,
    );
  }

  // --- MODIFIED: statusColor getter to handle all relevant statuses ---
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'accepted': // Map API 'accepted' to UI 'pending' color
        return HexColor.fromHex('FFF6D4'); // Yellow shade
      case 'ready':
      case 'preparing': // Map API 'preparing' to UI 'ready' color
        return HexColor.fromHex('DEF5D4'); // Green shade
      case 'completed':
      case 'delivered':
        return HexColor.fromHex('D6D6D6'); // Grey shade
      case 'blue': // For 'blue' status from API
        return Colors.blue.shade100;
      case 'green':
        return HexColor.fromHex('DEF5D4'); // Green shade
      default:
        print("DEBUG: Unrecognized order status for color: $status. Returning transparent.");
        return Colors.transparent; // Fallback for truly unrecognized statuses
    }
  }

  // --- MODIFIED: statusLabel getter to match the desired labels ---
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'accepted':
        return 'Pending';
      case 'ready':
      case 'preparing':
        return 'Ready';
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
    if (orderType.toLowerCase() == 'delivery' || orderType.toLowerCase() == 'pickup') {
      return streetAddress ?? 'No Address Provided';
    } else {
      final firstTwoItems = items.take(2).map((e) => e.itemName).join(', ');
      return firstTwoItems.isEmpty ? 'No items' : firstTwoItems;
    }
  }
}