import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';

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

  const FoodItemDetailsModal({
    super.key,
    required this.foodItem,
    required this.onAddToCart,
  });

  @override
  State<FoodItemDetailsModal> createState() => _FoodItemDetailsModalState();
}

class _FoodItemDetailsModalState extends State<FoodItemDetailsModal> {
  late double _currentPrice;
  int _quantity = 1;

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

  bool _showAllToppings = false;

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

      print(widget.foodItem.defaultToppings);

      //Populate _selectedToppings with default toppings and cheese
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
      price += widget.foodItem.price.values.first;
    }

    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') {
      for (var topping in _selectedToppings) {
        // Only add cost for toppings that are NOT default
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

  void _toggleToppingVisibility() {
    setState(() {
      _showAllToppings = !_showAllToppings;
    });
  }

  void _closeModal() {
    Navigator.of(context).pop();
  }

  void _addToCart() {
    final List<String> selectedOptions = [];

    // Add selected size if applicable
    if (_selectedSize != null && widget.foodItem.price.keys.length > 1) {
      selectedOptions.add('Size: $_selectedSize');
    }

    // Add toppings
    if (_selectedToppings.isNotEmpty) {
      selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
    }

    // Add base
    if (_selectedBase != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Base: $_selectedBase');
    }

    // Add crust
    if (_selectedCrust != null && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    // Add sauces
    if (_selectedSauces.isNotEmpty && (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads')) {
      selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
    }

    // Add meal option and selected drink
    if (_makeItAMeal) {
      selectedOptions.add('Make it a meal');
      if (_selectedDrink != null) {
        selectedOptions.add('Drink: $_selectedDrink');
      }
    }

    // Add burger specific options
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

    // Call the callback to add the item to the cart in Page4
    widget.onAddToCart(cartItem);

    Navigator.of(context).pop(); // Close the modal
    // Snackbar will be shown from Page4
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

    return Dialog(

      insetPadding: const EdgeInsets.all(0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
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
            // Modal Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFCB6CE6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ADD ITEM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: _closeModal,
                    child: const Text(
                      '×',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                    Text(
                      widget.foodItem.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Size Selection
                    if (['Pizza', 'Garlic Breads', 'Shawarmas', 'Wraps', 'Burgers'].contains(widget.foodItem.category) &&
                        widget.foodItem.price.keys.length > 1)
                      _buildOptionSection(
                        label: 'Size',
                        options: widget.foodItem.price.keys.toList(),
                        selectedValue: _selectedSize,
                        onSelected: (value) {
                          setState(() {
                            _selectedSize = value;
                            _calculatePrice();
                          });
                        },
                      ),

                    // Render options based on category
                    if (widget.foodItem.category == 'Pizza' || widget.foodItem.category == 'Garlic Breads') ...[

                      _buildOptionSection(
                        label: 'Toppings',
                        options: _showAllToppings ? reorderedToppings : reorderedToppings.take(4).toList(),
                        selectedValues: _selectedToppings,
                        onToggle: (topping) {
                          // **Prevent unselecting default toppings**
                          final isDefault = (widget.foodItem.defaultToppings ?? []).contains(topping) ||
                              (widget.foodItem.defaultCheese ?? []).contains(topping);
                          if (isDefault) {
                            // If it's a default topping, do nothing (don't allow unselection)
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
                        showSeeMore: _allToppings.length > 4,
                        onSeeMore: _toggleToppingVisibility,
                        // Pass the default checker function to the builder
                        isDefaultChecker: (topping) => (widget.foodItem.defaultToppings ?? []).contains(topping) || (widget.foodItem.defaultCheese ?? []).contains(topping),
                        seeMoreButtonLabel: _showAllToppings ? 'Show Less' : 'See More',
                      ),


                      _buildOptionSection(
                        label: 'Base',
                        options: _allBases,
                        selectedValue: _selectedBase,
                        onSelected: (value) {
                          setState(() {
                            _selectedBase = value;
                            _calculatePrice();
                          });
                        },
                      ),
                      _buildOptionSection(
                        label: 'Crust',
                        options: _allCrusts,
                        selectedValue: _selectedCrust,
                        onSelected: (value) {
                          setState(() {
                            _selectedCrust = value;
                            _calculatePrice();
                          });
                        },
                      ),
                      _buildOptionSection(
                        label: 'Sauce Dips',
                        options: _allSauces,
                        selectedValues: _selectedSauces,
                        onToggle: (sauce) {
                          setState(() {
                            if (_selectedSauces.contains(sauce)) {
                              _selectedSauces.remove(sauce);
                            } else {
                              _selectedSauces.add(sauce);
                            }
                            _calculatePrice();
                          });
                        },
                      ),
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

                    // Quantity Control
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (_quantity > 1) {
                                    _quantity--;
                                    _calculatePrice();
                                  }
                                });
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Icon(Icons.remove, size: 20),
                              ),
                            ),
                            Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _quantity++;
                                  _calculatePrice();
                                });
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Icon(Icons.add, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

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
      ),
    );
  }

  // Widget to build Options section
  Widget _buildOptionSection({
    required String label,
    required List<String> options,
    String? selectedValue,
    Set<String>? selectedValues,
    Function(String)? onSelected,
    Function(String)? onToggle,
    String Function(String)? suffixText,
    bool showSeeMore = false,
    VoidCallback? onSeeMore,
    bool Function(String)? isDefaultChecker,
    String seeMoreButtonLabel = 'See More',
  }) {
    if (options.isEmpty && !showSeeMore) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(
              width: 120,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,

                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),

            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...options.map((option) {
                    final bool isActive = (selectedValue != null && selectedValue == option) ||
                        (selectedValues != null && selectedValues.contains(option));
                    final bool isDefault = isDefaultChecker != null ? isDefaultChecker(option) : false;

                    return InkWell(
                      // **Modified onTap to prevent unselecting default toppings**
                      onTap: () {
                        if (isDefault && (selectedValues != null && selectedValues.contains(option))) {
                          // If it's a default topping and currently selected, do nothing
                          return;
                        }
                        if (onSelected != null) {
                          onSelected(option);
                        }
                        if (onToggle != null) {
                          onToggle(option);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFCB6CE6) // Color for selected toppings
                              : (isDefault ? Colors.grey[400] : Colors.grey[200]), // Slightly darker grey for default but unselectable
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$option${suffixText != null ? suffixText(option) : ''}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  if (showSeeMore && onSeeMore != null)
                    InkWell(
                      onTap: onSeeMore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              seeMoreButtonLabel,
                              style: const TextStyle(color: Color(0xFFCB6CE6)),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              seeMoreButtonLabel == 'See More' ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              size: 18,
                              color: const Color(0xFFCB6CE6),
                            ),
                          ],
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
}
