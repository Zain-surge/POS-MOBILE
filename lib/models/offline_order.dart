// lib/models/offline_order.dart

import 'package:hive/hive.dart';
import 'package:epos/models/cart_item.dart';
import 'package:epos/models/food_item.dart';

part 'offline_order.g.dart';

@HiveType(typeId: 0)
class OfflineOrder extends HiveObject {
  @HiveField(0)
  final String localId;

  @HiveField(1)
  final String transactionId;

  @HiveField(2)
  final String paymentType;

  @HiveField(3)
  final String orderType;

  @HiveField(4)
  final double orderTotalPrice;

  @HiveField(5)
  final String? orderExtraNotes;

  @HiveField(6)
  final String customerName;

  @HiveField(7)
  final String? customerEmail;

  @HiveField(8)
  final String? phoneNumber;

  @HiveField(9)
  final String? streetAddress;

  @HiveField(10)
  final String? city;

  @HiveField(11)
  final String? postalCode;

  @HiveField(12)
  final double changeDue;

  @HiveField(13)
  final List<OfflineCartItem> items;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final String status;

  @HiveField(16)
  final int? syncAttempts;

  @HiveField(17)
  final String? syncError;

  @HiveField(18)
  final int? serverId; // Set when successfully synced

  OfflineOrder({
    required this.localId,
    required this.transactionId,
    required this.paymentType,
    required this.orderType,
    required this.orderTotalPrice,
    this.orderExtraNotes,
    required this.customerName,
    this.customerEmail,
    this.phoneNumber,
    this.streetAddress,
    this.city,
    this.postalCode,
    required this.changeDue,
    required this.items,
    required this.createdAt,
    this.status = 'pending',
    this.syncAttempts = 0,
    this.syncError,
    this.serverId,
  });

  // Convert from CartItems for offline storage
  factory OfflineOrder.fromCartItems({
    required String localId,
    required String transactionId,
    required String paymentType,
    required String orderType,
    required List<CartItem> cartItems,
    required double orderTotalPrice,
    String? orderExtraNotes,
    required String customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    required double changeDue,
  }) {
    return OfflineOrder(
      localId: localId,
      transactionId: transactionId,
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
      items:
          cartItems.map((item) => OfflineCartItem.fromCartItem(item)).toList(),
      createdAt: DateTime.now(),
    );
  }

  // Convert to API JSON format for syncing
  Map<String, dynamic> toApiJson() {
    return {
      'transaction_id': transactionId,
      'payment_type': paymentType,
      'order_type': orderType,
      'total_price': orderTotalPrice,
      'extra_notes': orderExtraNotes,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'phone_number': phoneNumber,
      'street_address': streetAddress,
      'city': city,
      'postal_code': postalCode,
      'change_due': changeDue,
      'status': 'accepted', // Orders created offline are auto-accepted
      'order_source': 'EPOS',
      'created_at': createdAt.toIso8601String(),
      'items': items.map((item) => item.toApiJson()).toList(),
    };
  }

  // Create copy with updated fields
  OfflineOrder copyWith({
    String? status,
    int? syncAttempts,
    String? syncError,
    int? serverId,
  }) {
    return OfflineOrder(
      localId: localId,
      transactionId: transactionId,
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
      items: items,
      createdAt: createdAt,
      status: status ?? this.status,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      serverId: serverId ?? this.serverId,
    );
  }
}

@HiveType(typeId: 1)
class OfflineCartItem extends HiveObject {
  @HiveField(0)
  final OfflineFoodItem foodItem;

  @HiveField(1)
  final int quantity;

  @HiveField(2)
  final List<String>? selectedOptions;

  @HiveField(3)
  final String? comment;

  @HiveField(4)
  final double pricePerUnit;

  OfflineCartItem({
    required this.foodItem,
    required this.quantity,
    this.selectedOptions,
    this.comment,
    required this.pricePerUnit,
  });

  factory OfflineCartItem.fromCartItem(CartItem cartItem) {
    return OfflineCartItem(
      foodItem: OfflineFoodItem.fromFoodItem(cartItem.foodItem),
      quantity: cartItem.quantity,
      selectedOptions: cartItem.selectedOptions?.cast<String>(),
      comment: cartItem.comment,
      pricePerUnit: cartItem.pricePerUnit,
    );
  }

  double get totalPrice => pricePerUnit * quantity;

  Map<String, dynamic> toApiJson() {
    return {
      'item_id': foodItem.id,
      'item_name': foodItem.name,
      'item_type': foodItem.category,
      'quantity': quantity,
      'description': selectedOptions?.join(', ') ?? '',
      'total_price': totalPrice,
      'comment': comment,
      'image_url': foodItem.image,
    };
  }

  // Convert back to CartItem for UI display
  CartItem toCartItem() {
    return CartItem(
      foodItem: foodItem.toFoodItem(),
      quantity: quantity,
      selectedOptions: selectedOptions,
      comment: comment,
      pricePerUnit: pricePerUnit,
    );
  }
}

@HiveType(typeId: 2)
class OfflineFoodItem extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final Map<String, double> price;

  @HiveField(4)
  final String image;

  @HiveField(5)
  final List<String>? defaultToppings;

  @HiveField(6)
  final List<String>? defaultCheese;

  @HiveField(7)
  final String? description;

  @HiveField(8)
  final String? subType;

  @HiveField(9)
  final List<String>? sauces;

  @HiveField(10)
  final bool availability;

  OfflineFoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    this.defaultToppings,
    this.defaultCheese,
    this.description,
    this.subType,
    this.sauces,
    required this.availability,
  });

  factory OfflineFoodItem.fromFoodItem(FoodItem foodItem) {
    return OfflineFoodItem(
      id: foodItem.id,
      name: foodItem.name,
      category: foodItem.category,
      price: Map<String, double>.from(foodItem.effectivePosPrice),
      image: foodItem.image,
      defaultToppings: foodItem.defaultToppings?.cast<String>().toList(),
      defaultCheese: foodItem.defaultCheese?.cast<String>().toList(),
      description: foodItem.description,
      subType: foodItem.subType,
      sauces: foodItem.sauces?.cast<String>().toList(),
      availability: foodItem.availability,
    );
  }

  FoodItem toFoodItem() {
    return FoodItem(
      id: id,
      name: name,
      category: category,
      price: Map<String, double>.from(price),
      image: image,
      defaultToppings: defaultToppings?.toList(),
      defaultCheese: defaultCheese?.toList(),
      description: description,
      subType: subType,
      sauces: sauces?.toList(),
      availability: availability,
    );
  }
}
