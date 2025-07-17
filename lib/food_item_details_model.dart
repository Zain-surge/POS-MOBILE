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
    "Coca Cola", "7Up", "Diet Coca Cola", "Fanta", "Pepsi", "Sprite",
  ];

  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.foodItem.price.isNotEmpty) {
      _selectedSize = widget.foodItem.price.keys.first;
    } else {
      _selectedSize = null;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') {
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
    _calculatedPricePerUnit = _calculatePricePerUnit();
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  double _calculatePricePerUnit() {
    double price = 0.0;

    if (_selectedSize != null && widget.foodItem.price.containsKey(_selectedSize)) {
      price = widget.foodItem.price[_selectedSize] ?? 0.0;
    } else if (widget.foodItem.price.isNotEmpty) {
      price = widget.foodItem.price.values.firstOrNull ?? 0.0;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') {
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
    } else if (widget.foodItem.category == 'Shawarmas' || widget.foodItem.category == 'Wraps' || widget.foodItem.category == 'Burgers') {
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
    final List<String> selectedOptions = [];

    if (_selectedSize != null && widget.foodItem.price.keys.length > 1) {
      selectedOptions.add('Size: $_selectedSize');
    }

    if (_selectedToppings.isNotEmpty) {
      selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
    }

    if (_selectedBase != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Base: $_selectedBase');
    }

    if (_selectedCrust != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    if (_selectedSauces.isNotEmpty && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
    }

    if (_makeItAMeal) {
      selectedOptions.add('Make it a meal');
      if (_selectedDrink != null) {
        selectedOptions.add('Drink: $_selectedDrink');
      }
    }

    if (widget.foodItem.category == 'Burgers') {
      if (_noSalad) selectedOptions.add('No Salad');
      if (_noSauce) selectedOptions.add('No Sauce');
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
      MediaQuery.of(context).size.width * 0.5,
      800.0,
    );

    return Container(
      width: modalWidth,
      constraints: BoxConstraints(
        maxWidth: 800,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
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
                  ...(
                      (['Pizza', 'Garlic Breads', 'Shawarmas', 'Wraps', 'Burgers'].contains(widget.foodItem.category) &&
                          widget.foodItem.price.keys.length > 1)
                          ? [_buildSizeWithQuantitySection()] // If true, return a list with this widget
                          : [_buildQuantityControlOnly()]      // If false, return a list with this widget
                  ),


                  if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') ...[
                    _buildOptionCategoryButtons(),
                    _buildSelectedOptionDisplay(),
                  ] else if (widget.foodItem.category == 'Shawarmas' || widget.foodItem.category == 'Wraps' || widget.foodItem.category == 'Burgers') ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _makeItAMeal,
                              onChanged: (bool? value) {
                                setState(() {
                                  _makeItAMeal = value!;
                                  _selectedDrink = null;
                                  _updatePriceDisplay();
                                });
                              },
                              activeColor: const Color(0xFFCB6CE6),
                            ),
                            const Text('Make it a meal ', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        if (_makeItAMeal) ...[
                          const SizedBox(height: 8),
                          const Text('Select Drink', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
                          DropdownButtonFormField<String>(
                            value: _selectedDrink,
                            hint: const Text('Select a drink'),
                            items: _allDrinks.map((drink) {
                              return DropdownMenuItem(
                                value: drink,
                                child: Text(drink),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDrink = value;
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
                                borderSide: const BorderSide(color: Color(0xFFCB6CE6)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],

                  if (widget.foodItem.category == 'Burgers') ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _noSalad,
                              onChanged: (bool? value) {
                                setState(() {
                                  _noSalad = value!;
                                });
                              },
                              activeColor: const Color(0xFFCB6CE6),
                            ),
                            const Text('No Salad', style: TextStyle(fontSize: 16)),
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
                              activeColor: const Color(0xFFCB6CE6),
                            ),
                            const Text('No Sauce', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],

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
                              activeColor: const Color(0xFFCB6CE6),
                            ),
                            const Text('No Cream', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
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
                            borderSide: const BorderSide(color: Color(0xFFCB6CE6)),
                          ),
                          hintText: 'Add any special requests or notes...',
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _closeModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Size',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
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
                    children: widget.foodItem.price.keys.map((size) {
                      final bool isActive = _selectedSize == size;
                      final String displaySize = size.split(' ')[0];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSize = size;
                            _updatePriceDisplay();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.grey : Colors.black,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$displaySize"',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                        fontSize: 16,
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
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[100] : Colors.black, // Background color change
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: TextStyle( // Removed 'const' because color will change dynamically
                        color: isSelected ? Colors.black : Colors.white, // Text color based on selection
                        fontSize: 14,
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
    // We'll still use these calculations as a guide, but won't force 'toppingBoxWidth'
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.5,
      800.0,
    );

    // This is the padding from the SingleChildScrollView that wraps this content.
    // Make sure this accurately reflects the actual horizontal padding applied to the content.
    final double horizontalPaddingOfParent = 20.0 * 2; // From SingleChildScrollView's padding

    // The actual available width for the Wrap is the modalWidth minus its parent's horizontal padding.
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    // Let's assume an average item width for calculation purposes, or a target minimum.
    // Instead of calculating a strict 'toppingBoxWidth', think about what's the maximum
    // comfortable width for each item to allow 4 per row.
    const double itemSpacing = 10.0;
    const int desiredColumns = 4;

    // Calculate the approximate width needed if items were equally sized
    // This is for conceptual understanding; we won't directly use this for SizedBox.width
    final double idealItemWidth = (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 10,
          alignment: WrapAlignment.start, // Ensure items start from the left
          children: reorderedToppings.map((topping) {
            final bool isActive = _selectedToppings.contains(topping);
            final bool isDefault = (widget.foodItem.defaultToppings ?? []).contains(topping) ||
                (widget.foodItem.defaultCheese ?? []).contains(topping);

            return ConstrainedBox( // Use ConstrainedBox to provide a min/max width
              constraints: BoxConstraints(
                minWidth: 0, // Allow it to shrink if needed
                maxWidth: (availableWidthForWrap / desiredColumns) - itemSpacing, // Max width per item for 4 columns
                // A small adjustment to maxWidth might be needed if there's any unaccounted for space.
                // For example: maxWidth: (availableWidthForWrap / desiredColumns) - itemSpacing - 1.0,
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
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), // Add horizontal padding for text
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
                      fontSize: 14,
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
          spacing: 10,
          runSpacing: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  base,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: 14,
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
          spacing: 10,
          runSpacing: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  crust,
                  style: TextStyle(
                    color: isActive? Colors.black : Colors.white,
                    fontSize: 14,
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
          spacing: 10,
          runSpacing: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[100] : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sauce,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: 14,
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