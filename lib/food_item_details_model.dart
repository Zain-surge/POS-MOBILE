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
  // This callback will now pass the final CartItem, whether it's new or updated
  final Function(CartItem) onAddToCart;
  final VoidCallback? onClose;

  // NEW: Optional parameters for editing existing cart items
  final CartItem? initialCartItem;
  final bool isEditing;

  const FoodItemDetailsModal({
    super.key,
    required this.foodItem,
    required this.onAddToCart,
    this.onClose,
    this.initialCartItem, // Pass the existing CartItem here when editing
    this.isEditing = false, // Flag to indicate if we're in edit mode
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
  String? _selectedDrinkFlavor;

  bool _noSalad = false;
  bool _noSauce = false;
  bool _noCream = false;

  bool _isInSizeSelectionMode = false;
  bool _sizeHasBeenSelected = false;

  final TextEditingController _reviewNotesController = TextEditingController();

  final List<String> _allToppings = [
    "Mushrooms",
    "Artichoke",
    "Carcioffi",
    "Onion",
    "Pepper",
    "Rocket",
    "Spinach",
    "Parsley",
    "Capers",
    "Oregano",
    "Egg",
    "Sweetcorn",
    "Chips",
    "Pineapple",
    "Chilli",
    "Basil",
    "Olives",
    "Sausages",
    "Mozzarella",
    "Emmental",
    "Taleggio",
    "Gorgonzola",
    "Brie",
    "Grana",
    "Red onion",
    "Red pepper",
    "Green chillies",
    "Buffalo mozzarella",
    "Fresh cherry tomatoes",
  ];

  final List<String> _allBases = ["BBQ", "Garlic", "Tomato"];
  final List<String> _allCrusts = ["Normal", "Stuffed"];
  final List<String> _allSauces = [
    "Mayo",
    "Ketchup",
    "Chilli sauce",
    "Sweet chilli",
    "Garlic Sauce"
  ];
  final List<String> _allDrinks = [
    "Coca Cola",
    "7Up",
    "Diet Coca Cola",
    "Fanta",
    "Pepsi",
    "Sprite",
    "J20 GLASS BOTTLE",
  ];

  final Map<String, List<String>> _drinkFlavors = {
    "J20 GLASS BOTTLE": [
      "Apple & Raspberry",
      "Apple & Mango",
      "Orange & Passion Fruit"
    ],
  };

  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.initialCartItem != null) {
      final CartItem item = widget.initialCartItem!;
      _quantity = item.quantity;
      _reviewNotesController.text = item.comment ?? '';

      // Parse selected options from the cart item
      if (item.selectedOptions != null) {
        for (var option in item.selectedOptions!) {
          String lowerOption = option.toLowerCase();
          if (lowerOption.startsWith('size:')) {
            _selectedSize = option.split(':').last.trim();
            _sizeHasBeenSelected = true;
          } else if (lowerOption.startsWith('toppings:')) {
            _selectedToppings.addAll(option.split(':').last.trim().split(',').map((s) => s.trim()));
          } else if (lowerOption.startsWith('base:')) {
            _selectedBase = option.split(':').last.trim();
          } else if (lowerOption.startsWith('crust:')) {
            _selectedCrust = option.split(':').last.trim();
          } else if (lowerOption.startsWith('sauce dips:')) {
            _selectedSauces.addAll(option.split(':').last.trim().split(',').map((s) => s.trim()));
          } else if (lowerOption == 'make it a meal') {
            _makeItAMeal = true;
          } else if (lowerOption.startsWith('drink:')) {
            String drinkAndFlavor = option.split(':').last.trim();
            if (drinkAndFlavor.contains('(') && drinkAndFlavor.contains(')')) {
              _selectedDrink = drinkAndFlavor.substring(0, drinkAndFlavor.indexOf('(')).trim();
              _selectedDrinkFlavor = drinkAndFlavor.substring(drinkAndFlavor.indexOf('(') + 1, drinkAndFlavor.indexOf(')')).trim();
            } else {
              _selectedDrink = drinkAndFlavor;
            }
          } else if (lowerOption == 'no salad') {
            _noSalad = true;
          } else if (lowerOption == 'no sauce') {
            _noSauce = true;
          } else if (lowerOption == 'no cream') {
            _noCream = true;
          } else if (lowerOption.startsWith('flavor:') && !_drinkFlavors.containsKey(widget.foodItem.name)) {
            // This handles standalone drink flavors if not already handled by 'drink:'
            _selectedDrinkFlavor = option.split(':').last.trim();
          }
        }
      }
      // If we are editing, we don't start in size selection mode, as a size should already be selected or not applicable.
      _isInSizeSelectionMode = false;
      _sizeHasBeenSelected = _selectedSize != null || (widget.foodItem.price.keys.length == 1 && widget.foodItem.price.isNotEmpty);

    } else {
      bool requiresSizeSelection = ([
        'Pizza',
        'GarlicBread',
        'Shawarma',
        'Wraps',
        'Burgers',
        'Chicken',
        'Wings'
      ].contains(widget.foodItem.category) &&
          widget.foodItem.price.keys.length > 1);

      if (requiresSizeSelection) {
        _isInSizeSelectionMode = true;
        _selectedSize = null;
      } else {
        if (widget.foodItem.price.keys.length == 1 &&
            widget.foodItem.price.isNotEmpty) {
          _selectedSize = widget.foodItem.price.keys.first;
          _sizeHasBeenSelected = true;
        }
        _isInSizeSelectionMode = false;
      }

      if (widget.foodItem.category == 'Pizza' ||
          widget.foodItem.category == 'GarlicBread') {
        _selectedBase = "Tomato";
        _selectedCrust = "Normal";

        debugPrint(
            "Default Toppings from FoodItem: ${widget.foodItem.defaultToppings}");
        debugPrint(
            "Default Cheese from FoodItem: ${widget.foodItem.defaultCheese}");

        if (widget.foodItem.defaultToppings != null) {
          _selectedToppings.addAll(widget.foodItem.defaultToppings!);
        }
        if (widget.foodItem.defaultCheese != null) {
          _selectedToppings.addAll(widget.foodItem.defaultCheese!);
        }
      }

      if (_drinkFlavors.containsKey(widget.foodItem.name)) {
        _selectedDrink = widget.foodItem.name;
        _selectedDrinkFlavor = null;
      }
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
    debugPrint("Selected Base: $_selectedBase");
    debugPrint("Selected Crust: $_selectedCrust");
    debugPrint("Selected Toppings: $_selectedToppings");
    debugPrint("Selected Sauces: $_selectedSauces");

    double price = 0.0;

    if (_selectedSize != null && widget.foodItem.price.containsKey(_selectedSize)) {
      price = widget.foodItem.price[_selectedSize] ?? 0.0;
    } else if (widget.foodItem.price.keys.length == 1 && widget.foodItem.price.isNotEmpty) {
      price = widget.foodItem.price.values.first;
    } else {
      debugPrint("No valid size selected or price not found");
      return 0.0;
    }

    debugPrint("Base price: $price");

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'GarlicBread') {
      // Calculate topping costs
      double toppingCost = 0.0;
      for (var topping in _selectedToppings) {
        if (!((widget.foodItem.defaultToppings ?? []).contains(topping) ||
            (widget.foodItem.defaultCheese ?? []).contains(topping))) {
          if (_selectedSize == "10 inch") {
            toppingCost += 1.0;
          } else if (_selectedSize == "12 inch") {
            toppingCost += 1.5;
          } else if (_selectedSize == "18 inch") {
            toppingCost += 5.5;
          }else if (_selectedSize == "7 inch") {
            toppingCost += 1.0;
          }else if (_selectedSize == "9 inch") {
            toppingCost += 1.5;
          }
        }
      }
      price += toppingCost;
      debugPrint("After toppings: $price (added: $toppingCost)");

      // Calculate base cost
      double baseCost = 0.0;
      if (_selectedBase != null && _selectedBase != "Tomato") {
        if (_selectedSize == "10 inch") {
          baseCost = 1.0;
        } else if (_selectedSize == "12 inch") {
          baseCost = 1.5;
        } else if (_selectedSize == "18 inch") {
          baseCost = 4.0;
        }else if (_selectedSize == "7 inch") {
          baseCost = 1.0;
        }else if (_selectedSize == "9 inch") {
          baseCost =1.5;
        }
      }
      price += baseCost;
      debugPrint("After base: $price (added: $baseCost)");

      // Calculate crust cost
      double crustCost = 0.0;
      if (_selectedCrust == "Stuffed") {
        if (_selectedSize == "10 inch") {
          crustCost = 1.5;
        } else if (_selectedSize == "12 inch") {
          crustCost = 2.5;
        } else if (_selectedSize == "18 inch") {
          crustCost = 4.5;
        }else if (_selectedSize == "7 inch") {
          crustCost = 1.5;
        }else if (_selectedSize == "9 inch") {
          crustCost = 2.5;
        }
      }
      price += crustCost;
      debugPrint("After crust: $price (added: $crustCost)");

      // Calculate sauce costs
      double sauceCost = 0.0;
      for (var sauce in _selectedSauces) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
          sauceCost += 0.75;
        } else {
          sauceCost += 0.5;
        }
      }
      price += sauceCost;
      debugPrint("After sauces: $price (added: $sauceCost)");
    } else if (['Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category)) {
      if (_makeItAMeal) {
        price += 1.9;
        debugPrint("After meal addition: $price");
      }
    }

    debugPrint("Final calculated price: $price");
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

  void _onSizeSelected(String size) {
    setState(() {
      _selectedSize = size;
      _sizeHasBeenSelected = true;
      _isInSizeSelectionMode = false;
      _updatePriceDisplay();
    });
  }

  void _changeSize() {
    setState(() {
      _isInSizeSelectionMode = true;
    });
  }

  void _confirmSelection() {
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

    if ((_drinkFlavors.containsKey(widget.foodItem.name) &&
        _selectedDrinkFlavor == null) ||
        (_makeItAMeal && _selectedDrink != null &&
            _drinkFlavors.containsKey(_selectedDrink!) &&
            _selectedDrinkFlavor == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a flavor for your drink.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    final List<String> selectedOptions = [];

    if (_selectedSize != null && widget.foodItem.price.keys.length > 1) {
      selectedOptions.add('Size: $_selectedSize');
    }

    if (_selectedToppings.isNotEmpty) {
      selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
    }

    if (_selectedBase != null && (widget.foodItem.category == 'Pizza' ||
        widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Base: $_selectedBase');
    }

    if (_selectedCrust != null && (widget.foodItem.category == 'Pizza' ||
        widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    if (_selectedSauces.isNotEmpty && (widget.foodItem.category == 'Pizza' ||
        widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
    }

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
    else if (_drinkFlavors.containsKey(widget.foodItem.name) &&
        _selectedDrinkFlavor != null) {
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

    widget.onAddToCart(cartItem); // This will now handle update or add
    widget.onClose?.call();
  }

  // --- NEW Helper Method for button-based UI ---
  Widget _buildOptionButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.grey[100] : Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // --- Original `_buildToppingsDisplay` method (unchanged) ---
  Widget _buildToppingsDisplay(List<String> allToppings) {
    // 1. Get the list of default toppings and cheeses
    final defaultToppingsAndCheese = [
      ...(widget.foodItem.defaultToppings ?? []),
      ...(widget.foodItem.defaultCheese ?? []),
    ].toSet().toList();

    // 2. Get the list of all other toppings
    final allOtherToppings = allToppings
        .where((topping) => !defaultToppingsAndCheese.contains(topping))
        .toList();

    // 3. Sort the other toppings by string length
    allOtherToppings.sort((a, b) => a.length.compareTo(b.length));

    // 4. Combine the two lists, with default toppings first
    final List<String> sortedToppings = [
      ...defaultToppingsAndCheese,
      ...allOtherToppings,
    ];

    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    final double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth = (availableWidthForWrap -
        (itemSpacing * (desiredColumns - 1))) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.spaceBetween,
          children: sortedToppings.map((topping) {
            final bool isActive = _selectedToppings.contains(topping);
            final bool isDefault = defaultToppingsAndCheese.contains(topping);

            return SizedBox(
              width: idealItemWidth,
              child: InkWell(
                onTap: () {
                  // --- DEFAULT TOPPINGS WILL NOT BE UNSELECTED ---
                  if (isDefault) {
                    return; // Do nothing if it's a default topping
                  }
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
                  padding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 18),
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
                    maxLines: 2,
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

  // --- MODIFIED `_buildMealAndExclusionOptions` method ---
  Widget _buildMealAndExclusionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Make it a Meal
            Expanded(
              child: _buildOptionButton(
                title: 'Make it a Meal',
                isActive: _makeItAMeal,
                onTap: () {
                  setState(() {
                    _makeItAMeal = !_makeItAMeal;
                    if (!_makeItAMeal) {
                      _selectedDrink = null;
                      _selectedDrinkFlavor = null;
                    }
                    _updatePriceDisplay();
                  });
                },
              ),
            ),
            const SizedBox(width: 15),
            // No Salad
            Expanded(
              child: _buildOptionButton(
                title: 'No Salad',
                isActive: _noSalad,
                onTap: () {
                  setState(() {
                    _noSalad = !_noSalad;
                  });
                },
              ),
            ),
            const SizedBox(width: 15),
            // No Sauce
            Expanded(
              child: _buildOptionButton(
                title: 'No Sauce',
                isActive: _noSauce,
                onTap: () {
                  setState(() {
                    _noSauce = !_noSauce;
                  });
                },
              ),
            ),
          ],
        ),
        if (_makeItAMeal) ...[
          const SizedBox(height: 20),
          _buildDrinkSelectionSection(),
        ]
      ],
    );
  }

  // --- NEW METHOD for drink selection with buttons ---
  Widget _buildDrinkSelectionSection() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth = (availableWidthForWrap -
        (itemSpacing * (desiredColumns - 1))) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Drink:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children: _allDrinks.map((drink) {
            final bool isActive = _selectedDrink == drink;
            return SizedBox(
              width: idealItemWidth,
              child: _buildOptionButton(
                title: drink,
                isActive: isActive,
                onTap: () {
                  setState(() {
                    _selectedDrink = drink;
                    // Reset flavor if the new drink doesn't have flavors or is different
                    if (!_drinkFlavors.containsKey(drink)) {
                      _selectedDrinkFlavor = null;
                    }
                    _updatePriceDisplay();
                  });
                },
              ),
            );
          }).toList(),
        ),
        if (_selectedDrink != null && _drinkFlavors.containsKey(_selectedDrink!)) ...[
          const SizedBox(height: 20),
          _buildFlavorSelectionSection(_selectedDrink!),
        ],
      ],
    );
  }

  // --- MODIFIED METHOD for flavors with buttons ---
  Widget _buildFlavorSelectionSection(String drinkName) {
    final List<String> flavors = _drinkFlavors[drinkName] ?? [];

    if (flavors.isEmpty) {
      return const SizedBox.shrink();
    }

    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth = (availableWidthForWrap -
        (itemSpacing * (desiredColumns - 1))) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a flavor for ${drinkName.capitalize()}:',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.spaceBetween,
          children: flavors.map((flavor) {
            final bool isActive = _selectedDrinkFlavor == flavor;
            return SizedBox(
              width: idealItemWidth,
              child: _buildOptionButton(
                title: flavor,
                isActive: isActive,
                onTap: () {
                  setState(() {
                    _selectedDrinkFlavor = flavor;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- MODIFIED METHOD for milkshake options with a button ---
  Widget _buildQuantityControlOnly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.foodItem.category == 'Milkshake') ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildOptionButton(
                  title: 'No Cream',
                  isActive: _noCream,
                  onTap: () {
                    setState(() {
                      _noCream = !_noCream;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ]
      ],
    );
  }

  String _getDisplaySize(String size) {
    switch (size.toLowerCase()) {
      case 'regular':
        return 'Reg';
      case 'large':
        return 'Lrg';
      case 'default':
        return 'Def';
      default:
      // Handle sizes like '10 inch', '12 inch', etc.
        final parts = size.split(' ');
        if (parts.isNotEmpty) {
          return parts.first; // e.g., "10"
        }
        return size;
    }
  }

  // --- REPLACED `build` METHOD with your original UI ---
  @override
  Widget build(BuildContext context) {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.8,
      1500.0,
    );

    bool canConfirmSelection = true;
    if ((widget.foodItem.price.keys.length > 1 && _selectedSize == null) ||
        (_makeItAMeal && _selectedDrink == null) ||
        (_makeItAMeal && _selectedDrink != null && _drinkFlavors.containsKey(_selectedDrink!) && _selectedDrinkFlavor == null)) {
      canConfirmSelection = false;
    }
    if ((_drinkFlavors.containsKey(widget.foodItem.name) && _selectedDrinkFlavor == null)) {
      canConfirmSelection = false;
    }

    debugPrint("Item Category: ${widget.foodItem.category}");
    debugPrint("Price keys length for rendering: ${widget.foodItem.price.keys
        .length}");
    debugPrint("Is in size selection mode: $_isInSizeSelectionMode");
    debugPrint("Size has been selected: $_sizeHasBeenSelected");

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxWidth: 1500,
          maxHeight: MediaQuery
              .of(context)
              .size
              .height * 0.9,
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
            // Header with item name, selected size, and quantity controls
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
                  // Left side: Selected size (if any)
                  Expanded(
                    flex: 1,
                    child: _sizeHasBeenSelected && _selectedSize != null &&
                        !_isInSizeSelectionMode
                        ? Row(
                      children: [
                        // Size label with rectangular black background
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Size',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        InkWell(
                          onTap: _changeSize,
                          child: Container(
                            width: 73,
                            height: 73,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _getDisplaySize(_selectedSize!),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: _getDisplaySize(_selectedSize!)
                                      .toLowerCase() == 'default' ? 14 : 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Container(),
                  ),

                  // Center: Item name
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.foodItem.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 25),

                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_sizeHasBeenSelected &&
                            !_isInSizeSelectionMode) ...[
                          // Quantity controls
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
                                _updatePriceDisplay(); // Update price on quantity change
                              });
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _isRemoveButtonPressed
                                    ? Colors.grey[100]
                                    : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[100]!,
                                    width: 4),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 35,
                              ),
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 50,
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
                                fontSize: 22,
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
                                _updatePriceDisplay(); // Update price on quantity change
                              });
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _isAddButtonPressed
                                    ? Colors.grey[100]
                                    : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[100]!,
                                    width: 4),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  InkWell(
                    onTap: _closeModal,
                    child: const Text(
                      '×',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_isInSizeSelectionMode) ...[
                      _buildSizeSelectionSection(),
                    ]
                    else
                      ...[
                        if (!_sizeHasBeenSelected) ...[
                          _buildQuantityControlOnly(),
                        ],

                        if (_drinkFlavors.containsKey(
                            widget.foodItem.name)) ...[
                          _buildFlavorSelectionSection(widget.foodItem.name),
                        ],

                        if (widget.foodItem.category == 'Pizza' ||
                            widget.foodItem.category == 'GarlicBread') ...[
                          _buildOptionCategoryButtons(),
                          _buildSelectedOptionDisplay(),
                        ],

                        if (['Shawarma', 'Wraps', 'Burgers'].contains(
                            widget.foodItem.category)) ...[
                          _buildMealAndExclusionOptions(),
                        ],

                        if (widget.foodItem.category == 'Milkshake') ...[
                          _buildQuantityControlOnly(),
                        ],

                        const SizedBox(height: 20),
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
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey[100]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey[100]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Colors.white),
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
                        const SizedBox(height: 20),
                      ],
                  ],
                ),
              ),
            ),


            // Footer with total and buttons
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
                    'Total: €${(_calculatedPricePerUnit * _quantity)
                        .toStringAsFixed(2)}',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
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
                        onPressed: canConfirmSelection ? _confirmSelection : null, // Changed to _confirmSelection
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canConfirmSelection ? Colors.black : Colors
                              .grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text( // Dynamic text based on mode
                          widget.isEditing ? 'Update Cart' : 'Add to Cart',
                          style: const TextStyle(
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




  Widget _buildSizeSelectionSection() {
    return Container(

      height: MediaQuery.of(context).size.height * 0.5,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Size',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Wrap(
            spacing: 15,
            runSpacing: 15,
            alignment: WrapAlignment.center,
            children: widget.foodItem.price.keys.map((sizeKeyFromData) {
              final bool isActive = _selectedSize == sizeKeyFromData;
              final String displayedText = _getDisplaySize(sizeKeyFromData);

              return InkWell(
                onTap: () => _onSizeSelected(sizeKeyFromData),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.grey[100] : Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayedText,
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.white,
                        fontSize: displayedText.toLowerCase() == 'default' ? 18 : 29,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCategoryButtons() {
    final List<String> categories = ['Toppings', 'Base', 'Crust', 'Sauce Dips'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(categories.length, (index) {
            final category = categories[index];
            final bool isSelected = _selectedOptionCategory == category;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 4.0,
                  right: index == categories.length - 1 ? 0 : 4.0,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOptionCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[100] : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
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

  Widget _buildBaseDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children: _allBases.map((base) {
            final bool isActive = _selectedBase == base;
            final bool isTomato = base == "Tomato";

            return InkWell(
              onTap: () {
                setState(() {
                  if (isTomato && isActive) {
                    return;
                  }
                  _selectedBase = base;
                  _updatePriceDisplay();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: (isActive || isTomato) ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  base,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (isActive || isTomato) ? Colors.black : Colors.white,
                    fontSize: 18,
                    fontWeight: isTomato && isActive ? FontWeight.bold : FontWeight.normal,
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          alignment: WrapAlignment.start,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  crust,
                  textAlign: TextAlign.center,
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

  Widget _buildSauceDisplay() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.9,
      900.0,
    );
    final double horizontalPaddingOfParent = 40.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          children: _allSauces.map((sauce) {
            final bool isActive = _selectedSauces.contains(sauce);
            return SizedBox(
              width: (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) / desiredColumns,
              child: InkWell(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.grey[100] : Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sauce,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white,
                      fontSize: 18,
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
}









































