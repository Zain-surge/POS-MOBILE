// lib/models/food_item.dart

import 'package:flutter/foundation.dart';

class FoodItem {
  final int id;
  final String name;
  final String category;
  final Map<String, double> price;
  final String image;
  final List<String>? defaultToppings;
  final List<String>? defaultCheese;
  final String? description;
  final String? subType;
  final List<String>? sauces;
  final bool availability;

  FoodItem({
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

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Converting price string to double
    final Map<String, dynamic> rawPrice = Map<String, dynamic>.from(json['price'] ?? {});
    final Map<String, double> priceMap = {};
    rawPrice.forEach((key, value) {
      priceMap[key] = double.tryParse(value.toString()) ?? 0.0;
    });

    return FoodItem(
      id: (json['id'] ?? json['item_id']) as int,
      // Safely parse String fields, defaulting to empty string if null
      name: (json['title'] as String?) ?? '', // <--- MODIFIED
      category: (json['Type'] as String?) ?? '', // <--- MODIFIED
      price: priceMap,
      image: (json['image'] as String?) ?? '', // <--- MODIFIED
      description: json['description'] as String?, // This was already safe
      subType: json['subType'] as String?, // This was already safe

      defaultToppings: (json['toppings'] as List<dynamic>?)
          ?.map((e) => e != null ? e.toString() : null)
          .whereType<String>()
          .toList(),

      defaultCheese: (json['cheese'] as List<dynamic>?)
          ?.map((e) => e != null ? e.toString() : null)
          .whereType<String>()
          .toList(),

      sauces: (json['sauces'] as List<dynamic>?)
          ?.map((e) => e != null ? e.toString() : null)
          .whereType<String>()
          .toList(),
      availability: json['availability'] as bool? ?? true,
    );
  }

  FoodItem copyWith({
    int? id,
    String? name,
    String? category,
    Map<String, double>? price,
    String? image,
    List<String>? defaultToppings,
    List<String>? defaultCheese,
    String? description,
    String? subType,
    List<String>? sauces,
    bool? availability,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      image: image ?? this.image,
      defaultToppings: defaultToppings ?? this.defaultToppings,
      defaultCheese: defaultCheese ?? this.defaultCheese,
      description: description ?? this.description,
      subType: subType ?? this.subType,
      sauces: sauces ?? this.sauces,
      availability: availability ?? this.availability,
    );
  }
}