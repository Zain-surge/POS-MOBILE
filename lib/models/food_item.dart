// lib/models/food_item.dart

class FoodItem {
  final int id;
  final String name;
  final String category;
  final Map<String, double> price; // Website/online price
  final Map<String, double>?
  posPrice; // POS-specific price (used in POS system)
  final String image;
  final List<String>? defaultToppings;
  final List<String>? defaultCheese;
  final String? description;
  final String? subType;
  final List<String>? sauces;
  final bool availability;
  final bool pos; // POS visibility flag

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.posPrice, // Optional POS-specific pricing
    required this.image,
    this.defaultToppings,
    this.defaultCheese,
    this.description,
    this.subType,
    this.sauces,
    required this.availability,
    this.pos = true, // Default to true for backward compatibility
  });

  // Helper to get the price to use in POS (prefers posPrice, falls back to price)
  Map<String, double> get effectivePosPrice => posPrice ?? price;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Converting price string to double
    final Map<String, dynamic> rawPrice = Map<String, dynamic>.from(
      json['price'] ?? {},
    );
    final Map<String, double> priceMap = {};
    rawPrice.forEach((key, value) {
      priceMap[key] = double.tryParse(value.toString()) ?? 0.0;
    });

    // Converting pos_price string to double (if exists)
    Map<String, double>? posPriceMap;
    if (json['pos_price'] != null) {
      final Map<String, dynamic> rawPosPrice = Map<String, dynamic>.from(
        json['pos_price'],
      );
      posPriceMap = {};
      rawPosPrice.forEach((key, value) {
        posPriceMap![key] = double.tryParse(value.toString()) ?? 0.0;
      });
    }

    return FoodItem(
      id: (json['id'] ?? json['item_id']) as int,
      name: (json['title'] as String?) ?? (json['item_name'] as String?) ?? '',
      category: (json['type'] as String?) ?? (json['Type'] as String?) ?? '',
      price: priceMap,
      posPrice: posPriceMap, // Parse POS-specific price
      image: (json['image'] as String?) ?? '',
      description: json['description'] as String?,
      subType: json['subType'] as String?,

      defaultToppings:
          (json['toppings'] as List<dynamic>?)
              ?.map((e) => e != null ? e.toString() : null)
              .whereType<String>()
              .toList(),

      defaultCheese:
          (json['cheese'] as List<dynamic>?)
              ?.map((e) => e != null ? e.toString() : null)
              .whereType<String>()
              .toList(),

      sauces:
          (json['sauces'] as List<dynamic>?)
              ?.map((e) => e != null ? e.toString() : null)
              .whereType<String>()
              .toList(),
      availability: json['availability'] as bool? ?? true,
      pos: json['pos'] as bool? ?? true, // Default to true if not provided
    );
  }

  // Add the missing toJson method
  Map<String, dynamic> toJson() {
    // Convert price map to string values for JSON serialization
    final Map<String, String> priceStrings = {};
    price.forEach((key, value) {
      priceStrings[key] = value.toString();
    });

    // Convert pos_price map to string values if it exists
    Map<String, String>? posPriceStrings;
    if (posPrice != null) {
      posPriceStrings = {};
      posPrice!.forEach((key, value) {
        posPriceStrings![key] = value.toString();
      });
    }

    return {
      'id': id,
      'title': name,
      'Type': category,
      'price': priceStrings,
      if (posPriceStrings != null) 'pos_price': posPriceStrings,
      'image': image,
      if (description != null) 'description': description,
      if (subType != null) 'subType': subType,
      if (defaultToppings != null) 'toppings': defaultToppings,
      if (defaultCheese != null) 'cheese': defaultCheese,
      if (sauces != null) 'sauces': sauces,
      'availability': availability,
      'pos': pos,
    };
  }

  FoodItem copyWith({
    int? id,
    String? name,
    String? category,
    Map<String, double>? price,
    Map<String, double>? posPrice,
    String? image,
    List<String>? defaultToppings,
    List<String>? defaultCheese,
    String? description,
    String? subType,
    List<String>? sauces,
    bool? availability,
    bool? pos,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      posPrice: posPrice ?? this.posPrice,
      image: image ?? this.image,
      defaultToppings: defaultToppings ?? this.defaultToppings,
      defaultCheese: defaultCheese ?? this.defaultCheese,
      description: description ?? this.description,
      subType: subType ?? this.subType,
      sauces: sauces ?? this.sauces,
      availability: availability ?? this.availability,
      pos: pos ?? this.pos,
    );
  }
}
