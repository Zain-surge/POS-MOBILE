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
  late double _currentPrice;
  int _quantity = 1;
  String _selectedOptionCategory = 'Toppings'; // Default selected category

  // Pizza/Garlic Bread specific
  String? _selectedSize;
  Set<String> _selectedToppings = {};
  String? _selectedBase;
  String? _selectedCrust;
  Set<String> _selectedSauces = {};

  // Shawarma/Wraps/Burgers specific
  bool _makeItAMeal = false;
  String? _selectedDrink;

  // Burgers specific
  bool _noSalad = false;
  bool _noSauce = false;

  final TextEditingController _reviewNotesController = TextEditingController();

  // All possible options
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

  // New state variables for quantity button press feedback
  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;


  @override
  void initState() {
    super.initState();
    if (widget.foodItem.price.isNotEmpty) {
      _selectedSize = widget.foodItem.price.keys.first;
      _currentPrice = widget.foodItem.price[_selectedSize] ?? 0.0;
    } else {
      _currentPrice = 0.0;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') {
      _selectedBase = "Tomato";
      _selectedCrust = "Normal";

      debugPrint("Default Toppings from FoodItem: ${widget.foodItem.defaultToppings}");
      debugPrint("Default Cheese from FoodItem: ${widget.foodItem.defaultCheese}");

      // Populate _selectedToppings with default toppings and cheese
      if (widget.foodItem.defaultToppings != null) {
        _selectedToppings.addAll(widget.foodItem.defaultToppings!);
      }
      if (widget.foodItem.defaultCheese != null) {
        _selectedToppings.addAll(widget.foodItem.defaultCheese!);
      }
    }
    _calculatePrice();
  }


  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    double price = 0.0;

    if (_selectedSize != null && widget.foodItem.price.containsKey(_selectedSize)) {
      price += widget.foodItem.price[_selectedSize] ?? 0.0;
    } else if (widget.foodItem.price.isNotEmpty) {
      price += widget.foodItem.price.values.firstOrNull ?? 0.0;
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

    setState(() {
      _currentPrice = price * _quantity;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Modal Header - Item Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Colors.white,
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
                      fontSize: 20,
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
                      fontSize: 28,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Modal Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Size Selection with Quantity Controls
                  if (['Pizza', 'Garlic Breads', 'Shawarmas', 'Wraps', 'Burgers'].contains(widget.foodItem.category) &&
                      widget.foodItem.price.keys.length > 1)
                    _buildSizeWithQuantitySection(),

                  // Option Category Buttons and Options Display for Pizza/Garlic Breads
                  if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') ...[
                    _buildOptionCategoryButtons(),
                    _buildSelectedOptionDisplay(),
                  ] else if (widget.foodItem.category == 'Shawarmas' || widget.foodItem.category == 'Wraps' || widget.foodItem.category == 'Burgers') ...[
                    // "Make it a meal" option
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
                                  _calculatePrice();
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
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
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

                  // Burger specific options
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

                  // Review Notes
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reviewNotesController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
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

          // Modal Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: €${_currentPrice.toStringAsFixed(2)}',
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
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black),
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
                        style: TextStyle(color: Colors.white),
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

  Widget _buildSizeWithQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Size Label
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

            // Size Options
            Expanded(
              flex: 2, // Give it more flex to occupy available space
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.foodItem.price.keys.map((size) {
                  final bool isActive = _selectedSize == size;
                  final String displaySize = size.split(' ')[0]; // Extracts "10" from "10 inch"
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSize = size;
                        _calculatePrice();
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
              ),
            ),

            // Quantity Controls
            Expanded( // <--- Added Expanded here
              flex: 1, // Give it less flex than size options, adjust as needed
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // <--- Key change: push to end
                mainAxisSize: MainAxisSize.min, // Keep row content compact
                children: [
                  // Decrease Button
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
                          _calculatePrice();
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

                  // Quantity Display
                  Container(
                    width: 50,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
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

                  // Increase Button
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
                        _calculatePrice();
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
                      color: isSelected ? Colors.grey : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
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
      MediaQuery.of(context).size.width * 0.5,
      800.0,
    );

    final double horizontalPaddingOfScrollView = 20.0 * 2;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfScrollView;

    const int desiredColumns = 4;
    const double itemSpacing = 10.0;
    final double totalSpacingBetweenItems = itemSpacing * (desiredColumns - 1);

    final double toppingBoxWidth = (availableWidthForWrap - totalSpacingBetweenItems) / desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 10,
          children: reorderedToppings.map((topping) {
            final bool isActive = _selectedToppings.contains(topping);
            final bool isDefault = (widget.foodItem.defaultToppings ?? []).contains(topping) ||
                (widget.foodItem.defaultCheese ?? []).contains(topping);

            return SizedBox(
              width: toppingBoxWidth,
              child: InkWell(
                onTap: () {
                  if (isDefault && _selectedToppings.contains(topping)) {
                    return;
                  }
                  setState(() {
                    if (_selectedToppings.contains(topping)) {
                      _selectedToppings.remove(topping);
                    } else {
                      _selectedToppings.add(topping);
                    }
                    _calculatePrice();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFCB6CE6)
                        : (isDefault ? Colors.grey[400] : Colors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    topping,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                  _calculatePrice();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey : Colors.black, // Active base is grey
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  base,
                  style: const TextStyle(
                    color: Colors.white,
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
                  _calculatePrice();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey : Colors.black, // Active crust is grey
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  crust,
                  style: const TextStyle(
                    color: Colors.white,
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
                  _calculatePrice();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFCB6CE6) : Colors.black, // Active sauce is purple
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sauce,
                  style: const TextStyle(
                    color: Colors.white,
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