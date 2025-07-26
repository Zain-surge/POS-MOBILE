// lib/food_item_details_model.dart

import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:math';

// Assuming HexColor extension is in a common utility file or defined here
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

class FoodItemDetailsModal extends StatefulWidget {
  final FoodItem foodItem;
  final Function(CartItem) onAddToCart;
  final VoidCallback? onClose;

  const FoodItemDetailsModal({
    super.key,
    required this.foodItem,
    required this.onAddToCart,
    this.onClose,
  });

  @override
  State<FoodItemDetailsModal> createState() => _FoodItemDetailsModalState();
}

class _FoodItemDetailsModalState extends State<FoodItemDetailsModal> {
  late double _calculatedPricePerUnit;
  int _quantity = 1;
  String _selectedOptionCategory = 'Toppings';

  String? _selectedSize;
  Set<String> _selectedToppings = {};
  String? _selectedBase;
  String? _selectedCrust;
  Set<String> _selectedSauces = {};

  bool _makeItAMeal = false;
  String? _selectedDrink;
  String? _selectedDrinkFlavor; // NEW: For drink flavors

  bool _noSalad = false;
  bool _noSauce = false;
  bool _noCream = false;

  final TextEditingController _reviewNotesController = TextEditingController();

  final List<String> _allToppings = [
    "Mushrooms", "Artichoke", "Carcioffi", "Onion", "Red onion", "Green chillies",
    "Red pepper", "Pepper", "Rocket", "Spinach", "Parsley", "Fresh cherry tomatoes",
    "Capers", "Oregano", "Egg", "Sweetcorn", "Chips", "Pineapple", "Chilli",
    "Basil", "Olives", "Sausages", "Mozzarella", "Emmental", "Taleggio",
    "Gorgonzola", "Brie", "Grana", "Buffalo mozzarella",
  ];

  final List<String> _allBases = ["BBQ", "Garlic", "Tomato"];
  final List<String> _allCrusts = ["Normal", "Stuffed"];
  final List<String> _allSauces = ["Mayo", "Ketchup", "Chilli sauce", "Sweet chilli", "Garlic Sauce"];
  final List<String> _allDrinks = [
    "Coca Cola", "7Up", "Diet Coca Cola", "Fanta", "Pepsi", "Sprite", "J20 GLASS BOTTLE",
  ];

  // NEW: Define flavors for specific drinks (key is the drink name)
  final Map<String, List<String>> _drinkFlavors = {
    "J20 GLASS BOTTLE": ["Apple & Raspberry", "Apple & Mango", "Orange & Passion Fruit"],
    // Add other drinks with flavors here if you want them to have the "size-like" flavor selection
    // e.g., "Fancy Soda": ["Lime", "Cherry", "Cola"],
  };

  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.foodItem.price.keys.length == 1 && widget.foodItem.price.isNotEmpty) {
      _selectedSize = widget.foodItem.price.keys.first;
    } else {
      _selectedSize = null;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread') { // Corrected category name
      _selectedBase = "Tomato";
      _selectedCrust = "Normal";

      debugPrint("Default Toppings from FoodItem: ${widget.foodItem.defaultToppings}");
      debugPrint("Default Cheese from FoodItem: ${widget.foodItem.defaultCheese}");

      if (widget.foodItem.defaultToppings != null) {
        _selectedToppings.addAll(widget.foodItem.defaultToppings!);
      }
      if (widget.foodItem.defaultCheese != null) {
        _selectedToppings.addAll(widget.foodItem.defaultCheese!);
      }
    }

    // Initialize _selectedDrink for drinks that have flavors displayed like sizes
    // This is crucial for the _drinkFlavors.containsKey check in _addToCart
    if (_drinkFlavors.containsKey(widget.foodItem.name)) {
      _selectedDrink = widget.foodItem.name; // Pre-select the drink itself
      _selectedDrinkFlavor = null; // Ensure no flavor is selected by default
    }


    _calculatedPricePerUnit = _calculatePricePerUnit();
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  double _calculatePricePerUnit() {
    debugPrint("--- Calculating Price for ${widget.foodItem.name} ---");
    debugPrint("Food Item Price Map: ${widget.foodItem.price}");
    debugPrint("Selected Size: $_selectedSize");
    debugPrint("Price keys length: ${widget.foodItem.price.keys.length}");

    double price = 0.0;

    if (_selectedSize != null && widget.foodItem.price.containsKey(_selectedSize)) {
      price = widget.foodItem.price[_selectedSize] ?? 0.0;
    }  else if (widget.foodItem.price.keys.length == 1 && widget.foodItem.price.isNotEmpty) {
      price = widget.foodItem.price.values.first;
    } else {
      return 0.0;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread') { // Corrected category name
      for (var topping in _selectedToppings) {
        if (!((widget.foodItem.defaultToppings ?? []).contains(topping) || (widget.foodItem.defaultCheese ?? []).contains(topping))) {
          if (_selectedSize == "10 inch") {
            price += 1.0;
          } else if (_selectedSize == "12 inch") {
            price += 1.5;
          } else if (_selectedSize == "18 inch") {
            price += 5.5;
          }
        }
      }

      if (_selectedBase != null && _selectedBase != "Tomato") {
        if (_selectedSize == "10 inch") {
          price += 1.0;
        } else if (_selectedSize == "12 inch") {
          price += 1.5;
        } else if (_selectedSize == "18 inch") {
          price += 4.0;
        }
      }

      if (_selectedCrust == "Stuffed") {
        if (_selectedSize == "10 inch") {
          price += 1.5;
        } else if (_selectedSize == "12 inch") {
          price += 2.5;
        } else if (_selectedSize == "18 inch") {
          price += 4.5;
        }
      }

      for (var sauce in _selectedSauces) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
          price += 0.75;
        } else {
          price += 0.5;
        }
      }
    } else if (['Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category)) {
      if (_makeItAMeal) {
        price += 1.9;
      }
    }

    return price;
  }

  void _updatePriceDisplay() {
    setState(() {
      _calculatedPricePerUnit = _calculatePricePerUnit();
    });
  }

  void _closeModal() {
    widget.onClose?.call();
  }

  void _addToCart() {
    // Check for size selection
    if (widget.foodItem.price.keys.length > 1 && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size before adding to cart.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    // NEW: Check if "Make it a meal" is selected but no drink is chosen
    if (_makeItAMeal && _selectedDrink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a drink for your meal.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    if ((_drinkFlavors.containsKey(widget.foodItem.name) && _selectedDrinkFlavor == null) ||
        (_makeItAMeal && _selectedDrink != null && _drinkFlavors.containsKey(_selectedDrink!) && _selectedDrinkFlavor == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a flavor for your drink.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.grey,
        ),
      );
      return; // Stop the function execution
    }


    final List<String> selectedOptions = [];

    if (_selectedSize != null && widget.foodItem.price.keys.length > 1) {
      selectedOptions.add('Size: $_selectedSize');
    }

    if (_selectedToppings.isNotEmpty) {
      selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
    }

    if (_selectedBase != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Base: $_selectedBase');
    }

    if (_selectedCrust != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    if (_selectedSauces.isNotEmpty && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
    }

    // Handle "Make it a Meal" drinks
    if (_makeItAMeal) {
      selectedOptions.add('Make it a meal');
      if (_selectedDrink != null) {
        String drinkOption = 'Drink: $_selectedDrink';
        if (_selectedDrinkFlavor != null) {
          drinkOption += ' ($_selectedDrinkFlavor)';
        }
        selectedOptions.add(drinkOption);
      }
    }
    // Handle standalone drinks with flavors (like J20 Glass Bottle)
    else if (_drinkFlavors.containsKey(widget.foodItem.name) && _selectedDrinkFlavor != null) {
      selectedOptions.add('Flavor: $_selectedDrinkFlavor');
    }


    if (['Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category)) {
      if (_noSalad) selectedOptions.add('No Salad');
      if (_noSauce) selectedOptions.add('No Sauce');
    }

    if (widget.foodItem.category == 'Milkshake') {
      if (_noCream) selectedOptions.add('No Cream');
    }

    final String userComment = _reviewNotesController.text.trim();

    final cartItem = CartItem(
      foodItem: widget.foodItem,
      quantity: _quantity,
      selectedOptions: selectedOptions.isEmpty ? null : selectedOptions,
      comment: userComment.isNotEmpty ? userComment : null,
      pricePerUnit: _calculatedPricePerUnit,
    );

    widget.onAddToCart(cartItem);
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reorderedToppings = List.from(_allToppings);
    reorderedToppings.sort((a, b) {
      final isDefaultA = (widget.foodItem.defaultToppings ?? []).contains(a) ||
          (widget.foodItem.defaultCheese ?? []).contains(a);
      final isDefaultB = (widget.foodItem.defaultToppings ?? []).contains(b) ||
          (widget.foodItem.defaultCheese ?? []).contains(b);
      if (isDefaultA && !isDefaultB) return -1;
      if (!isDefaultA && isDefaultB) return 1;
      return a.compareTo(b);
    });

    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.8,
      1500.0,
    );

    bool canAddToCart = true;
    if ((widget.foodItem.price.keys.length > 1 && _selectedSize == null) ||(_makeItAMeal && _selectedDrink == null) ) {
      canAddToCart = false;
    }
    // NEW/UPDATED: Add condition for drink flavor selection
    if ((_drinkFlavors.containsKey(widget.foodItem.name) && _selectedDrinkFlavor == null) || // For standalone drinks
        (_makeItAMeal && _selectedDrink != null && _drinkFlavors.containsKey(_selectedDrink!) && _selectedDrinkFlavor == null)) { // For meal deal drinks
      canAddToCart = false;
    }


    debugPrint("Item Category: ${widget.foodItem.category}");
    debugPrint("Price keys length for rendering: ${widget.foodItem.price.keys.length}");
    debugPrint("Should render size selection? ${(['Pizza', 'GarlicBread', 'Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category) && widget.foodItem.price.keys.length > 1)}");

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        print('Modal background tapped, keyboard dismissed (if open).');
      },
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxWidth: 1500,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.foodItem.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _closeModal,
                    child: const Text(
                      '×',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Quantity Control ---
                    // If it's a size-based item, show size + quantity. Else, just quantity.
                    ...(
                        (['Pizza', 'GarlicBread', 'Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category) &&
                            widget.foodItem.price.keys.length > 1)
                            ? [_buildSizeWithQuantitySection()]
                            : [_buildQuantityControlOnly()]
                    ),

                    // --- Flavor Selection for Specific Drinks (e.g., J20 Glass Bottle) ---
                    // This is the new section for specific drink flavors
                    if (_drinkFlavors.containsKey(widget.foodItem.name)) ...[
                      _buildFlavorSelectionSection(widget.foodItem.name),
                    ],

                    // --- Pizza/Garlic Bread Options ---
                    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread') ...[
                      _buildOptionCategoryButtons(),
                      _buildSelectedOptionDisplay(),
                    ],

                    // --- Make it a Meal / No Salad / No Sauce for Shawarma, Wraps, Burgers ---
                    // Note: This section will still handle drink selection if 'Make it a Meal' is chosen for these items.
                    if (['Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category)) ...[
                      _buildMealAndExclusionOptions(),
                    ],

                    // --- Milkshake Options ---
                    if (widget.foodItem.category == 'Milkshake') ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _noCream,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _noCream = value!;
                                  });
                                },
                                activeColor: Colors.grey[100],
                              ),
                              const Text('No Cream', style: TextStyle(fontSize: 16, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ],

                    // --- Review Notes ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewNotesController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[100]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[100]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white),
                            ),

                            hintText: 'Add any special requests or notes...',
                            hintStyle: const TextStyle(color: Colors.white),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: €${(_calculatedPricePerUnit * _quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _closeModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: canAddToCart ? _addToCart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:  canAddToCart ? Colors.black : Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControlOnly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTapDown: (_) {
                setState(() {
                  _isRemoveButtonPressed = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _isRemoveButtonPressed = false;
                });
              },
              onTapCancel: () {
                setState(() {
                  _isRemoveButtonPressed = false;
                });
              },
              onTap: () {
                setState(() {
                  if (_quantity > 1) {
                    _quantity--;
                  }
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isRemoveButtonPressed ? Colors.grey : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Container(
              width: 50,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[100]!),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            InkWell(
              onTapDown: (_) {
                setState(() {
                  _isAddButtonPressed = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _isAddButtonPressed = false;
                });
              },
              onTapCancel: () {
                setState(() {
                  _isAddButtonPressed = false;
                });
              },
              onTap: () {
                setState(() {
                  _quantity++;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isAddButtonPressed ? Colors.grey : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSizeWithQuantitySection() {
    final Map<String, Map<String, String>> categorySizeDisplayMap = {
      'Shawarma': { // Corrected category name
        'naan': 'Large',
        'pitta': 'Small',
      },
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Size',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  debugPrint('Available width for Wrap: ${constraints.maxWidth}');
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.foodItem.price.keys.map((sizeKeyFromData) {
                      final bool isActive = _selectedSize == sizeKeyFromData;

                      String displayedText;
                      // Get the specific map for the current food item's category
                      final Map<String, String>? currentCategoryMap =
                      categorySizeDisplayMap[widget.foodItem.category];

                      if (currentCategoryMap != null && currentCategoryMap.containsKey(sizeKeyFromData)) {
                        displayedText = currentCategoryMap[sizeKeyFromData]!;
                      } else if (sizeKeyFromData.toLowerCase().contains('inch')) {
                        displayedText = '${sizeKeyFromData.split(' ')[0]}"';
                      } else {
                        displayedText = sizeKeyFromData.capitalize();
                      }


                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSize = sizeKeyFromData;
                            _updatePriceDisplay();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.grey : Colors.black,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            displayedText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTapDown: (_) {
                      setState(() {
                        _isRemoveButtonPressed = true;
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        _isRemoveButtonPressed = false;
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        _isRemoveButtonPressed = false;
                      });
                    },
                    onTap: () {
                      setState(() {
                        if (_quantity > 1) {
                          _quantity--;
                        }
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isRemoveButtonPressed ? Colors.grey : Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[100]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTapDown: (_) {
                      setState(() {
                        _isAddButtonPressed = true;
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        _isAddButtonPressed = false;
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        _isAddButtonPressed = false;
                      });
                    },
                    onTap: () {
                      setState(() {
                        _quantity++;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isAddButtonPressed ? Colors.grey : Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // NEW WIDGET: _buildFlavorSelectionSection for specific drinks like J20 Glass Bottle
  Widget _buildFlavorSelectionSection(String drinkName) {
    final List<String> flavors = _drinkFlavors[drinkName] ?? [];

    if (flavors.isEmpty) {
      return const SizedBox.shrink(); // Don't show if no flavors are defined
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Flavor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: flavors.map((flavor) {
            final bool isActive = _selectedDrinkFlavor == flavor;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedDrinkFlavor = flavor;
                  // No price update needed here unless flavors change the price.
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey : Colors.black,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Text(
                  flavor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }


  // UPDATED WIDGET: _buildMealAndExclusionOptions (Only for 'Make it a meal' for non-drink items)
  Widget _buildMealAndExclusionOptions() {
    final bool isShawarmaOrWrap = ['Shawarma', 'Wraps'].contains(widget.foodItem.category); // Corrected category name
    final bool isBurger = widget.foodItem.category == 'Burgers';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // "Make it a meal" checkbox - only show for Shawarma, Wraps, Burgers
        Row(
          children: [
            Checkbox(
              value: _makeItAMeal,
              onChanged: (bool? value) {
                setState(() {
                  _makeItAMeal = value!;
                  _selectedDrink = null; // Reset drink and flavor when 'Make it a Meal' changes
                  _selectedDrinkFlavor = null;
                  _updatePriceDisplay();
                });
              },
              activeColor: Colors.grey[100],
            ),
            const Text('Make it a meal ', style: TextStyle(fontSize: 20, color: Colors.white)),
          ],
        ),

        // Drink selection dropdown for "Make it a meal"
        if (_makeItAMeal) ...[
          const SizedBox(height: 8),
          const Text('Select Drink', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: Colors.white)),
          DropdownButtonFormField<String>(
            value: _selectedDrink,
            hint: const Text('Select a drink', style: TextStyle(color: Colors.white)),
            items: _allDrinks.map((drink) {
              return DropdownMenuItem(
                value: drink,
                child: Text(drink),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDrink = value;
                _selectedDrinkFlavor = null; // Reset flavor when drink changes
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[100]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[100]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[100]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          // Conditional display for drink flavors if the selected meal drink has flavors
          if (_selectedDrink != null && _drinkFlavors.containsKey(_selectedDrink!)) ...[
            const SizedBox(height: 8),
            const Text('Select Flavor', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16, color: Colors.white)),
            DropdownButtonFormField<String>(
              value: _selectedDrinkFlavor,
              hint: const Text('Select a flavor', style: TextStyle(color: Colors.white)),
              items: _drinkFlavors[_selectedDrink!]!.map((flavor) {
                return DropdownMenuItem(
                  value: flavor,
                  child: Text(flavor),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDrinkFlavor = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[100]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[100]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[100]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ],
        // No Salad / No Sauce checkboxes - only show for Shawarma, Wraps, and Burgers
        if (isShawarmaOrWrap || isBurger) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _noSalad,
                onChanged: (bool? value) {
                  setState(() {
                    _noSalad = value!;
                  });
                },
                  activeColor: Colors.grey[100],
              ),
              const Text('No Salad', style: TextStyle(fontSize: 20, color: Colors.white)),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _noSauce,
                onChanged: (bool? value) {
                  setState(() {
                    _noSauce = value!;
                  });
                },
                activeColor: Colors.grey[100],
              ),
              const Text('No Sauce', style: TextStyle(fontSize: 20, color: Colors.white)),
            ],
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
  //helper
  Widget _buildOptionCategoryButtons() {
    final List<String> categories = ['Toppings', 'Base', 'Crust', 'Sauce Dips'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: categories.map((category) {
            final bool isSelected = _selectedOptionCategory == category;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOptionCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[100] : Colors.black, // Background color change
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: TextStyle( // Removed 'const' because color will change dynamically
                        color: isSelected ? Colors.black : Colors.white, // Text color based on selection
                        fontSize: 20,
                        fontWeight: FontWeight.bold, // Text is always bold
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSelectedOptionDisplay() {
    final List<String> reorderedToppings = List.from(_allToppings);
    reorderedToppings.sort((a, b) {
      final isDefaultA = (widget.foodItem.defaultToppings ?? []).contains(a) ||
          (widget.foodItem.defaultCheese ?? []).contains(a);
      final isDefaultB = (widget.foodItem.defaultToppings ?? []).contains(b) ||
          (widget.foodItem.defaultCheese ?? []).contains(b);
      if (isDefaultA && !isDefaultB) return -1;
      if (!isDefaultA && isDefaultB) return 1;
      return a.compareTo(b);
    });

    switch (_selectedOptionCategory) {
      case 'Toppings':
        return _buildToppingsDisplay(reorderedToppings);
      case 'Base':
        return _buildBaseDisplay();
      case 'Crust':
        return _buildCrustDisplay();
      case 'Sauce Dips':
        return _buildSauceDisplay();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildToppingsDisplay(List<String> reorderedToppings) {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.9,
      900.0,
    );
    final double horizontalPaddingOfParent = 20.0 * 0.99;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;


    const double itemSpacing = 10.0;
    const int desiredColumns = 4;

    final double idealItemWidth = (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start, // Ensure items start from the left
          children: reorderedToppings.map((topping) {
            final bool isActive = _selectedToppings.contains(topping);
            final bool isDefault = (widget.foodItem.defaultToppings ?? []).contains(topping) ||
                (widget.foodItem.defaultCheese ?? []).contains(topping);

            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 0,
                maxWidth: (availableWidthForWrap / desiredColumns) - itemSpacing, // Max width per item for 4 columns

              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedToppings.contains(topping)) {
                      _selectedToppings.remove(topping);
                    } else {
                      _selectedToppings.add(topping);
                    }
                    _updatePriceDisplay();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15), // Add horizontal padding for text
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.grey[100]
                        : Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    topping,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white,
                      fontSize: 18,
                      fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBaseDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: _allBases.map((base) {
            final bool isActive = _selectedBase == base;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedBase = base;
                  _updatePriceDisplay();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  base,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCrustDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: _allCrusts.map((crust) {
            final bool isActive = _selectedCrust == crust;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCrust = crust;
                  _updatePriceDisplay();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  crust,
                  style: TextStyle(
                    color: isActive? Colors.black : Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSauceDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: _allSauces.map((sauce) {
            final bool isActive = _selectedSauces.contains(sauce);
            return InkWell(
              onTap: () {
                setState(() {
                  if (_selectedSauces.contains(sauce)) {
                    _selectedSauces.remove(sauce);
                  } else {
                    _selectedSauces.add(sauce);
                  }
                  _updatePriceDisplay();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sauce,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}