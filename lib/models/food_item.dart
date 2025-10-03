// lib/models/food_item.dart

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
    final Map<String, dynamic> rawPrice = Map<String, dynamic>.from(
      json['price'] ?? {},
    );
    final Map<String, double> priceMap = {};
    rawPrice.forEach((key, value) {
      priceMap[key] = double.tryParse(value.toString()) ?? 0.0;
    });

    return FoodItem(
      id: (json['id'] ?? json['item_id']) as int,
      name: (json['title'] as String?) ?? (json['item_name'] as String?) ?? '',
      category: (json['type'] as String?) ?? (json['Type'] as String?) ?? '',
      price: priceMap,
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
    );
  }

  // Add the missing toJson method
  Map<String, dynamic> toJson() {
    // Convert price map to string values for JSON serialization
    final Map<String, String> priceStrings = {};
    price.forEach((key, value) {
      priceStrings[key] = value.toString();
    });

    return {
      'id': id,
      'title': name,
      'Type': category,
      'price': priceStrings,
      'image': image,
      if (description != null) 'description': description,
      if (subType != null) 'subType': subType,
      if (defaultToppings != null) 'toppings': defaultToppings,
      if (defaultCheese != null) 'cheese': defaultCheese,
      if (sauces != null) 'sauces': sauces,
      'availability': availability,
    };
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
