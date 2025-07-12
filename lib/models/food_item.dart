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
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    //Converting price string to double
    final Map<String, dynamic> rawPrice = Map<String, dynamic>.from(json['price'] ?? {});
    final Map<String, double> priceMap = {};
    rawPrice.forEach((key, value) {
      // Ensure value is treated as a String before parsing to double
      priceMap[key] = double.tryParse(value.toString()) ?? 0.0;
    });

    return FoodItem(
      id: json['id'] as int,
      name: json['title'] as String,
      category: json['Type'] as String,
      price: priceMap,
      image: json['image'] as String,
      description: json['description'] as String?,
      subType: json['subType'] as String?,

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
    );
  }
}