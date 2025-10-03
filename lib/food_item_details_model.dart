// lib/food_item_details_model.dart

import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:math';
import 'package:epos/services/custom_popup_service.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/item_availability_provider.dart';

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

  // NEW: List of all food items for dynamic deal options
  final List<FoodItem> allFoodItems;

  const FoodItemDetailsModal({
    super.key,
    required this.foodItem,
    required this.onAddToCart,
    this.onClose,
    this.initialCartItem, // Pass the existing CartItem here when editing
    this.isEditing = false, // Flag to indicate if we're in edit mode
    required this.allFoodItems, // Required for dynamic deal options
  });

  @override
  State<FoodItemDetailsModal> createState() => _FoodItemDetailsModalState();
}

class _FoodItemDetailsModalState extends State<FoodItemDetailsModal> {
  late double _calculatedPricePerUnit;
  int _quantity = 1;
  String _selectedOptionCategory = 'Toppings';
  String _selectedDealCategory = '';

  String? _selectedSize;
  Set<String> _selectedToppings = {};
  String? _selectedCrust;
  Set<String> _selectedSauces =
      {}; // For free sauces (Burgers, Wraps, Shawarma, Kebabs) OR paid sauce dips (Pizza, Chicken, Wings, Strips)
  Set<String> _selectedSauceDips =
      {}; // For PAID sauce dips on Kebabs only (in addition to free sauces)

  // _makeItAMeal removed - now handled by Meal size selection
  String? _selectedDrink;
  String? _selectedDrinkFlavor;

  // NEW: Red salt choice
  String? _selectedRedSaltChoice;

  String _saladChoice = 'Yes'; // 'Yes' or 'No' - no specific options needed
  String _sauceChoice = 'Yes'; // 'Yes' or 'No' - similar to salad choice
  bool _noSauce = false; // Keep for backward compatibility
  bool _noCream = false;

  bool _isInSizeSelectionMode = false;
  bool _sizeHasBeenSelected = false;

  final TextEditingController _reviewNotesController = TextEditingController();

  final List<String> _allToppings = [
    "BBQ Sauce",
    "Extra Cheese",
    "Green Chilli",
    "Jalapeno",
    "Mushrooms",
    "Peppers",
    "Pineapple",
    "Pizza sauce",
    "Red onion",
    "Sweet corn",
    "BBQ chicken",
    "Chicken",
    "Pepperoni",
    "Prawns",
    "Spicy Beef",
    "Tandoori Chicken",
    "Tuna",
    "Turkey Ham",
  ];

  final List<String> _allCrusts = ["Normal", "Stuffed"];
  final List<String> _allSauces = [
    "Mayo",
    "Ketchup",
    "Chilli sauce",
    "Spicy Mayo",
    "Garlic Mayo",
    "BBQ",
    "Tomato",
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

  // Kids Meal specific drinks
  final List<String> _kidsMealDrinks = [
    "Blackcurrant Fruit Shoot",
    "Apple Fruit Shoot",
  ];

  // Regular drinks for deals containing "Reg Drink"
  final List<String> _regularDrinks = [
    "Coca Cola",
    "7Up",
    "Diet Coca Cola",
    "Fanta",
    "Pepsi",
    "Sprite",
  ];

  // 1.5L drinks for deals containing "1.5ltr Drink"
  final List<String> _largeBottleDrinks = [
    "Coca Cola (1.5L)",
    "7Up (1.5L)",
    "Diet Coca Cola (1.5L)",
    "Fanta (1.5L)",
    "Pepsi (1.5L)",
    "Sprite (1.5L)",
  ];

  // NEW: Red Salt choice options (Yes/No)
  final List<String> _redSaltOptions = ["Yes", "No"];

  final Map<String, List<String>> _drinkFlavors = {
    "J20 GLASS BOTTLE": [
      "Apple & Raspberry",
      "Apple & Mango",
      "Orange & Passion Fruit",
    ],
  };

  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;

  // Deal-specific selections
  final Map<String, String?> _dealSelections = {};
  final Map<String, Set<String>> _dealMultiSelections = {};

  @override
  void initState() {
    super.initState();
    print('🔍 INIT STATE: Starting initialization for ${widget.foodItem.name}');

    if (widget.isEditing && widget.initialCartItem != null) {
      final CartItem item = widget.initialCartItem!;
      _quantity = item.quantity;
      _reviewNotesController.text = item.comment ?? '';

      print('🔍 EDITING MODE: Deal editing for ${widget.foodItem.name}');
      print('🔍 Cart item options: ${item.selectedOptions}');

      // Parse selected options from the cart item (only for non-deal items)
      if (item.selectedOptions != null && widget.foodItem.category != 'Deals') {
        for (var option in item.selectedOptions!) {
          String lowerOption = option.toLowerCase();
          if (lowerOption.startsWith('size:')) {
            _selectedSize = option.split(':').last.trim();
            _sizeHasBeenSelected = true;
          } else if (lowerOption.startsWith('toppings:')) {
            _selectedToppings.addAll(
              option.split(':').last.trim().split(',').map((s) => s.trim()),
            );
          } else if (lowerOption.startsWith('crust:')) {
            _selectedCrust = option.split(':').last.trim();
          } else if (lowerOption.startsWith('sauce:')) {
            _selectedSauces.addAll(
              option.split(':').last.trim().split(',').map((s) => s.trim()),
            );
          } else if (lowerOption.startsWith('sauces:')) {
            // Handle "Sauces:" format - free sauces for Burgers, Wraps, Kebabs
            _selectedSauces.addAll(
              option.split(':').last.trim().split(',').map((s) => s.trim()),
            );
          } else if (lowerOption.startsWith('sauce dip:')) {
            // For Kebabs: paid sauce dips go to _selectedSauceDips
            // For other categories (Chicken, Wings, Strips, Pizza): paid sauce dips go to _selectedSauces
            if (widget.foodItem.category == 'Kebabs') {
              _selectedSauceDips.addAll(
                option.split(':').last.trim().split(',').map((s) => s.trim()),
              );
            } else {
              _selectedSauces.addAll(
                option.split(':').last.trim().split(',').map((s) => s.trim()),
              );
            }
          } else if (lowerOption == 'make it a meal') {
            // Legacy support - convert to meal size
            _selectedSize = 'Meal';
            _sizeHasBeenSelected = true;
          } else if (lowerOption.startsWith('drink:')) {
            String drinkAndFlavor = option.split(':').last.trim();
            if (drinkAndFlavor.contains('(') && drinkAndFlavor.contains(')')) {
              _selectedDrink =
                  drinkAndFlavor
                      .substring(0, drinkAndFlavor.indexOf('('))
                      .trim();
              _selectedDrinkFlavor =
                  drinkAndFlavor
                      .substring(
                        drinkAndFlavor.indexOf('(') + 1,
                        drinkAndFlavor.indexOf(')'),
                      )
                      .trim();
            } else {
              _selectedDrink = drinkAndFlavor;
            }
          } else if (lowerOption.startsWith('chips seasoning:') ||
              lowerOption.startsWith('red salt:')) {
            _selectedRedSaltChoice = option.split(':').last.trim();
          } else if (lowerOption == 'no salad') {
            _saladChoice = 'No';
          } else if (lowerOption.startsWith('salad:')) {
            _saladChoice = 'Yes';
            // No specific salad options needed anymore
          } else if (lowerOption == 'no sauce') {
            _sauceChoice = 'No';
            _noSauce = true; // Keep for backward compatibility
          } else if (lowerOption.startsWith('sauce:')) {
            String sauceValue = option.split(':').last.trim();
            if (sauceValue.toLowerCase() == 'yes' ||
                sauceValue.toLowerCase() == 'no') {
              _sauceChoice = sauceValue;
              _noSauce = sauceValue.toLowerCase() == 'no';
            } else {
              // Handle actual sauce names like "Sauce: Mayo, Ketchup" (for Shawarma)
              _sauceChoice = 'Yes';
              _selectedSauces.addAll(
                sauceValue.split(',').map((s) => s.trim()),
              );
            }
          } else if (lowerOption.startsWith('sauces:')) {
            // Handle "Sauces: Mayo, Ketchup" format for Burgers and Wraps
            String sauceValue = option.split(':').last.trim();
            _sauceChoice = 'Yes';
            _selectedSauces.addAll(sauceValue.split(',').map((s) => s.trim()));
          } else if (lowerOption == 'no cream') {
            _noCream = true;
          } else if (lowerOption.startsWith('flavor:') &&
              !_drinkFlavors.containsKey(widget.foodItem.name)) {
            // This handles standalone drink flavors if not already handled by 'drink:'
            _selectedDrinkFlavor = option.split(':').last.trim();
          }
        }
      }

      // Deal-specific parsing for editing (separate from regular item parsing)
      if (item.selectedOptions != null && widget.foodItem.category == 'Deals') {
        for (var option in item.selectedOptions!) {
          print('🔍 PROCESSING DEAL OPTION: "$option"');

          // Special parsing for 3X12" Pizza Deal format
          if (widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
            if (option.startsWith('Pizza 1:') ||
                option.startsWith('Pizza 2:') ||
                option.startsWith('Pizza 3:')) {
              // Parse: "Pizza 1: Asian Special (Extra Toppings: Green Chilli)"
              String pizzaKey = option.split(':')[0].trim(); // "Pizza 1"
              String remainingText =
                  option
                      .substring(option.indexOf(':') + 1)
                      .trim(); // "Asian Special (Extra Toppings: Green Chilli)"

              String pizzaName;
              if (remainingText.contains('(')) {
                pizzaName =
                    remainingText
                        .substring(0, remainingText.indexOf('('))
                        .trim(); // "Asian Special"
                String optionsText = remainingText.substring(
                  remainingText.indexOf('(') + 1,
                  remainingText.lastIndexOf(')'),
                ); // "Extra Toppings: Green Chilli"

                // Parse options within parentheses
                List<String> optionParts = optionsText.split(',');
                for (String optionPart in optionParts) {
                  String trimmedOption = optionPart.trim();
                  if (trimmedOption.startsWith('Extra Toppings:')) {
                    String toppingsKey = '$pizzaKey - Toppings';
                    String toppingsValue =
                        trimmedOption
                            .substring(15)
                            .trim(); // Remove "Extra Toppings:"
                    _dealMultiSelections[toppingsKey] =
                        toppingsValue.split(',').map((s) => s.trim()).toSet();
                  } else if (trimmedOption.startsWith('Crust:')) {
                    String crustKey = '$pizzaKey - Crust';
                    String crustValue =
                        trimmedOption.substring(6).trim(); // Remove "Crust:"
                    _dealSelections[crustKey] = crustValue;
                  }
                }
              } else {
                pizzaName = remainingText; // No options in parentheses
              }

              // Set the pizza selection
              String pizzaSelectionKey = '$pizzaKey - Pizza';
              _dealSelections[pizzaSelectionKey] = pizzaName;
              print('🔍 PARSED 3X12 PIZZA: $pizzaSelectionKey = $pizzaName');
            } else if (option.startsWith('Sauce Dips:')) {
              // Parse: "Sauce Dips: Ketchup, Mayo"
              String sauceValue =
                  option.substring(12).trim(); // Remove "Sauce Dips:"
              _dealMultiSelections['Sauce Dips'] =
                  sauceValue.split(',').map((s) => s.trim()).toSet();
              print('🔍 PARSED 3X12 SAUCE DIPS: $sauceValue');
            }
          } else if (_isFamilyDeal()) {
            // Parse Family Deals format: "Side Choice: Coleslaw" or regular deal options
            if (option.startsWith('Side Choice:')) {
              String sideValue =
                  option.substring(12).trim(); // Remove "Side Choice:"
              _dealSelections['Side Choice'] = sideValue;
              print('🔍 PARSED FAMILY DEALS SIDE CHOICE: $sideValue');
            }
            // Parse Red Salt choice
            else if (option.startsWith('Red salt:') ||
                option.startsWith('Red Salt:')) {
              String redSaltValue =
                  option.contains('Red salt:')
                      ? option.substring(17).trim()
                      : option.substring(9).trim();
              _selectedRedSaltChoice = redSaltValue;
              print('🔍 PARSED FAMILY DEALS RED SALT: $redSaltValue');
            }
            // Parse Sauce Dips
            else if (option.startsWith('Sauce Dips:')) {
              String sauceValue = option.substring(12).trim();
              _selectedSauces.addAll(
                sauceValue.split(',').map((s) => s.trim()),
              );
              print('🔍 PARSED FAMILY DEALS SAUCE DIPS: $sauceValue');
            }
            // Parse Drink (only store in _selectedDrink for Family Deals)
            else if (option.startsWith('Drink:')) {
              String drinkText = option.substring(6).trim();

              // For Family Deals, store the full drink name to match UI options
              _selectedDrink = drinkText;
              if (drinkText.contains('(') && drinkText.contains(')')) {
                _selectedDrinkFlavor =
                    drinkText
                        .substring(
                          drinkText.indexOf('(') + 1,
                          drinkText.lastIndexOf(')'),
                        )
                        .trim();
              }
              print(
                '🔍 PARSED FAMILY DEALS DRINK: $drinkText -> _selectedDrink: $_selectedDrink',
              );
            }
            // Parse other deal-specific options
            else if (option.contains(':')) {
              List<String> parts = option.split(':');
              if (parts.length >= 2) {
                String sectionName = parts[0].trim();
                String value = parts[1].trim();
                _dealSelections[sectionName] = value;
                print('🔍 PARSED FAMILY DEALS OPTION: $sectionName = $value');
              }
            }
          } else if (_isPizzaDealWithOptions()) {
            // Parse Pizza Deals format
            if (option.startsWith('Red Salt:')) {
              String redSaltValue =
                  option.substring(9).trim(); // Remove "Red Salt:"
              _selectedRedSaltChoice = redSaltValue;
              print('🔍 PARSED PIZZA DEAL RED SALT: $redSaltValue');
            } else if (option.startsWith('Selected Pizza:')) {
              // Parse: "Selected Pizza: Asian Special (Extra Toppings: Extra Cheese, Green Chilli)"
              String pizzaText =
                  option.substring(15).trim(); // Remove "Selected Pizza:"

              if (pizzaText.contains('(')) {
                String pizzaName =
                    pizzaText.substring(0, pizzaText.indexOf('(')).trim();
                _dealSelections['Selected Pizza'] = pizzaName;

                String optionsText = pizzaText.substring(
                  pizzaText.indexOf('(') + 1,
                  pizzaText.lastIndexOf(')'),
                );

                // Parse options within parentheses
                List<String> optionParts = optionsText.split(',');
                for (String optionPart in optionParts) {
                  String trimmedOption = optionPart.trim();
                  if (trimmedOption.startsWith('Extra Toppings:')) {
                    String toppingsValue = trimmedOption.substring(15).trim();
                    _dealMultiSelections['Extra Toppings'] =
                        toppingsValue.split(',').map((s) => s.trim()).toSet();
                  } else if (trimmedOption.startsWith('Crust:')) {
                    String crustValue = trimmedOption.substring(6).trim();
                    _dealSelections['Crust'] = crustValue;
                  }
                }
              } else {
                _dealSelections['Selected Pizza'] = pizzaText;
              }
              print(
                '🔍 PARSED PIZZA DEAL PIZZA: ${_dealSelections['Selected Pizza']}',
              );
            } else if (option.startsWith('Sauce Dips:')) {
              String sauceValue =
                  option.substring(12).trim(); // Remove "Sauce Dips:"
              _dealMultiSelections['Sauce Dips'] =
                  sauceValue.split(',').map((s) => s.trim()).toSet();
              print('🔍 PARSED PIZZA DEAL SAUCE DIPS: $sauceValue');
            } else if (option.startsWith('Drink:')) {
              String drinkText = option.substring(6).trim(); // Remove "Drink:"
              if (drinkText.contains('(') && drinkText.contains(')')) {
                _selectedDrink =
                    drinkText.substring(0, drinkText.indexOf('(')).trim();
                _selectedDrinkFlavor =
                    drinkText
                        .substring(
                          drinkText.indexOf('(') + 1,
                          drinkText.lastIndexOf(')'),
                        )
                        .trim();
              } else {
                _selectedDrink = drinkText;
              }
              print('🔍 PARSED PIZZA DEAL DRINK: $_selectedDrink');
            }
          } else {
            // General deal parsing for all other deals (except special ones handled above)
            if (!widget.foodItem.name.toLowerCase().contains(
                  '3x12" pizza deal',
                ) &&
                !_isFamilyDeal() &&
                !_isPizzaDealWithOptions()) {
              // Parse Red Salt choice
              if (option.startsWith('Red salt:') ||
                  option.startsWith('Red Salt:')) {
                String redSaltValue =
                    option.contains('Red salt:')
                        ? option.substring(17).trim()
                        : option.substring(9).trim();
                _selectedRedSaltChoice = redSaltValue;
                print('🔍 PARSED GENERAL DEAL RED SALT: $redSaltValue');
              }
              // Parse Sauce Dips
              else if (option.startsWith('Sauce Dips:')) {
                String sauceValue = option.substring(12).trim();
                _selectedSauces.addAll(
                  sauceValue.split(',').map((s) => s.trim()),
                );
                print('🔍 PARSED GENERAL DEAL SAUCE DIPS: $sauceValue');
              }
              // Parse Sauce Options (shows as "Sauce:" in cart for Combo Meals)
              else if (option.startsWith('Sauce:')) {
                String sauceValue =
                    option.substring(6).trim(); // Remove "Sauce:"
                _dealMultiSelections['Sauce Options'] =
                    sauceValue.split(',').map((s) => s.trim()).toSet();
                print('🔍 PARSED COMBO MEAL SAUCE OPTIONS: $sauceValue');
              }
              // Parse Drink
              else if (option.startsWith('Drink:')) {
                String drinkText = option.substring(6).trim();
                if (drinkText.contains('(') && drinkText.contains(')')) {
                  _selectedDrink =
                      drinkText.substring(0, drinkText.indexOf('(')).trim();
                  _selectedDrinkFlavor =
                      drinkText
                          .substring(
                            drinkText.indexOf('(') + 1,
                            drinkText.lastIndexOf(')'),
                          )
                          .trim();
                } else {
                  _selectedDrink = drinkText;
                }
                print('🔍 PARSED GENERAL DEAL DRINK: $_selectedDrink');
              }
              // Parse other deal-specific options (deal selections)
              else if (option.contains(':') && !option.contains('(')) {
                List<String> parts = option.split(':');
                if (parts.length >= 2) {
                  String sectionName = parts[0].trim();
                  String value = parts[1].trim();
                  // Only store if it's not a special format we've already handled
                  if (![
                    'Red salt choice',
                    'Red Salt',
                    'Sauce Dips',
                    'Drink',
                  ].contains(sectionName)) {
                    _dealSelections[sectionName] = value;
                    print(
                      '🔍 PARSED GENERAL DEAL OPTION: $sectionName = $value',
                    );
                  }
                }
              }
            }
          }
          // Add other deal-specific parsing here if needed
        }
      }

      // If we are editing, we don't start in size selection mode, as a size should already be selected or not applicable.
      _isInSizeSelectionMode = false;
      _sizeHasBeenSelected =
          _selectedSize != null ||
          (widget.foodItem.price.keys.length == 1 &&
              widget.foodItem.price.isNotEmpty);
    } else {
      bool requiresSizeSelection =
          ([
                'Pizza',
                'GarlicBread',
                'Shawarma',
                'Wraps',
                'Burgers',
                'Chicken',
                'Wings',
                'Strips',
                'Deals',
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
        _selectedCrust = "Normal";

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

      // Initialize deal category for deals
      if (widget.foodItem.category == 'Deals') {
        Map<String, List<String>> dealOptions = _getDealOptions(
          widget.foodItem.name,
        );
        if (dealOptions.isNotEmpty) {
          // Find the first category with food items (Pizza, Shawarma, Burger)
          List<String> dealCategories = _getDealCategories(dealOptions);
          if (dealCategories.isNotEmpty) {
            _selectedDealCategory = dealCategories.first;
          }
        }
      }
    }

    // No hardcoded deal initialization - all deals come from backend

    // Special initialization for 3X12" Pizza Deal - set default crusts
    if (widget.foodItem.category == 'Deals' &&
        widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
      for (int i = 1; i <= 3; i++) {
        String crustKey = 'Pizza $i - Crust';
        if (_dealSelections[crustKey] == null) {
          _dealSelections[crustKey] = "Normal";
          print('🔍 INIT: Set default crust to Normal for Pizza $i');
        }
      }

      // Ensure the first pizza tab is selected when editing
      if (_selectedDealCategory.isEmpty ||
          !['Pizza 1', 'Pizza 2', 'Pizza 3'].contains(_selectedDealCategory)) {
        _selectedDealCategory = 'Pizza 1';
        print('🔍 INIT: Set selected tab to Pizza 1 for 3X12" Pizza Deal');
      }
    }

    // Initialize default crust for Mega Pizza Deal
    if (_isPizzaDealWithOptions() &&
        widget.foodItem.name.toLowerCase() == 'mega pizza deal') {
      if (_dealSelections['Crust'] == null) {
        _dealSelections['Crust'] = 'Normal';
        print('🔍 INIT: Set default crust to Normal for Mega Pizza Deal');
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
    debugPrint("Selected Crust: $_selectedCrust");
    debugPrint("Selected Toppings: $_selectedToppings");
    debugPrint("Selected Sauces: $_selectedSauces");

    double price = 0.0;

    if (_selectedSize != null &&
        widget.foodItem.price.containsKey(_selectedSize)) {
      price = widget.foodItem.price[_selectedSize] ?? 0.0;
    } else if (widget.foodItem.price.keys.length == 1 &&
        widget.foodItem.price.isNotEmpty) {
      price = widget.foodItem.price.values.first;
    } else {
      debugPrint("No valid size selected or price not found");
      return 0.0;
    }

    debugPrint("Initial price: $price");

    if (widget.foodItem.category == 'Pizza' ||
        widget.foodItem.category == 'GarlicBread') {
      // Calculate topping costs
      double toppingCost = 0.0;

      // Define meat toppings
      final List<String> meatToppings = [
        "BBQ chicken",
        "Chicken",
        "Pepperoni",
        "Prawns",
        "Spicy Beef",
        "Tandoori Chicken",
        "Tuna",
        "Turkey Ham",
      ];

      // For all pizzas: Charge for extra toppings
      for (var topping in _selectedToppings) {
        if (!((widget.foodItem.defaultToppings ?? []).contains(topping) ||
            (widget.foodItem.defaultCheese ?? []).contains(topping))) {
          bool isMeatTopping = meatToppings.contains(topping);

          if (_selectedSize == "7 inch") {
            toppingCost += isMeatTopping ? 0.59 : 0.39;
          } else if (_selectedSize == "9 inch") {
            toppingCost += isMeatTopping ? 0.79 : 0.59;
          } else if (_selectedSize == "12 inch") {
            toppingCost += isMeatTopping ? 0.99 : 0.70;
          } else if (_selectedSize == "10 inch") {
            // Legacy support - using 12 inch pricing
            toppingCost += isMeatTopping ? 0.99 : 0.70;
          } else if (_selectedSize == "18 inch") {
            // Legacy support - using 12 inch pricing
            toppingCost += isMeatTopping ? 0.99 : 0.70;
          }
        }
      }

      price += toppingCost;
      debugPrint("After toppings: $price (added: $toppingCost)");

      // Calculate crust cost
      double crustCost = 0.0;
      if (_selectedCrust == "Stuffed") {
        // Stuffed crust is only available for 12 inch pizzas at +£1.50
        if (_selectedSize == "12 inch") {
          crustCost = 1.5;
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
    } else if ([
      'Chicken',
      'Wings',
      'Strips',
    ].contains(widget.foodItem.category)) {
      // Chicken, Wings, Strips use paid sauce dips
      double sauceCost = 0.0;
      for (var sauce in _selectedSauces) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
          sauceCost += 0.75;
        } else {
          sauceCost += 0.5;
        }
      }
      price += sauceCost;
      debugPrint(
        "After Chicken/Wings/Strips sauces: $price (added: $sauceCost)",
      );
    } else if (widget.foodItem.category == 'Kebabs') {
      // Kebabs have FREE sauces (_selectedSauces) AND paid sauce dips (_selectedSauceDips)
      double sauceCost = 0.0;
      for (var sauce in _selectedSauceDips) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
          sauceCost += 0.75;
        } else {
          sauceCost += 0.5;
        }
      }
      price += sauceCost;
      debugPrint(
        "Kebabs - Free sauces: ${_selectedSauces.length}, Paid sauce dips: ${_selectedSauceDips.length}, cost: $sauceCost",
      );
    } else if ([
      'Shawarma',
      'Wraps',
      'Burgers',
    ].contains(widget.foodItem.category)) {
      // Sauces are now FREE for Burgers, Wraps, and Shawarmas - no sauce cost added
      debugPrint(
        "Sauces are free for ${widget.foodItem.category} - no cost added",
      );
    } else if (widget.foodItem.category == 'Sides') {
      // Sides category: No sauce costs, only red salt for fries/chips items

      // Calculate red salt choice costs only for fries/chips items
      double redSaltCost = 0.0;
      String itemName = widget.foodItem.name.toLowerCase();
      if ((itemName.contains('fries') || itemName.contains('chips')) &&
          _selectedRedSaltChoice == 'Yes') {
        redSaltCost += 0.5; // Standard red salt cost
      }
      price += redSaltCost;
      debugPrint("Sides red salt cost: $redSaltCost, total price: $price");
    } else if (widget.foodItem.category == 'Deals' &&
        widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
      // Special pricing logic for 3X12" Pizza Deal
      double dealExtraCost = 0.0;

      // Define meat toppings (same as regular Pizza category)
      final List<String> meatToppings = [
        "BBQ chicken",
        "Chicken",
        "Pepperoni",
        "Prawns",
        "Spicy Beef",
        "Tandoori Chicken",
        "Tuna",
        "Turkey Ham",
      ];

      // Calculate costs for each of the 3 pizzas
      for (int i = 1; i <= 3; i++) {
        String pizzaKey = 'Pizza $i';

        // Add stuffed crust cost (£1.50 per stuffed crust)
        String crustKey = '$pizzaKey - Crust';
        String? selectedCrust = _dealSelections[crustKey];
        if (selectedCrust == "Stuffed") {
          dealExtraCost += 1.5; // Same price as regular 12" pizza stuffed crust
          debugPrint("Added stuffed crust cost for Pizza $i: £1.50");
        }

        // Add topping costs for extra toppings (12 inch pricing)
        String toppingsKey = '$pizzaKey - Toppings';
        Set<String>? selectedToppings = _dealMultiSelections[toppingsKey];
        if (selectedToppings != null && selectedToppings.isNotEmpty) {
          for (var topping in selectedToppings) {
            bool isMeatTopping = meatToppings.contains(topping);
            double toppingCost = isMeatTopping ? 0.99 : 0.70; // 12 inch pricing
            dealExtraCost += toppingCost;
            debugPrint(
              "Added topping cost for Pizza $i - $topping: £$toppingCost",
            );
          }
        }
      }

      price += dealExtraCost;
      debugPrint(
        "3X12\" Pizza Deal extra costs: £$dealExtraCost, total price: £$price",
      );
    } else if (_isPizzaDealWithOptions()) {
      // Special pricing logic for Pizza Deal 4 One and Mega Pizza Deal
      double dealExtraCost = 0.0;

      // Define meat toppings (same as Pizza category)
      final List<String> meatToppings = [
        'Chicken',
        'Pepperoni',
        'Turkey Ham',
        'Salami',
        'Chicken Tikka',
        'BBQ Chicken',
        'Seekh Kebab',
        'Doner Meat',
        'Chicken Shawarma',
        'Anchovies',
        'Tuna',
        'Prawn',
      ];

      // Calculate topping costs (assuming 12 inch pizza size for deals)
      Set<String>? selectedToppings = _dealMultiSelections['Extra Toppings'];
      if (selectedToppings != null && selectedToppings.isNotEmpty) {
        for (var topping in selectedToppings) {
          bool isMeatTopping = meatToppings.contains(topping);
          dealExtraCost += isMeatTopping ? 0.99 : 0.70; // 12 inch pricing
        }
        debugPrint("Pizza Deal toppings cost: £${dealExtraCost}");
      }

      // Calculate crust cost (for Mega Pizza Deal)
      String? selectedCrust = _dealSelections['Crust'];
      if (selectedCrust == "Stuffed") {
        dealExtraCost += 1.5; // Same as regular 12" pizza stuffed crust
        debugPrint("Added stuffed crust cost for Pizza Deal: £1.50");
      }

      // Calculate sauce costs
      Set<String>? selectedSauces = _dealMultiSelections['Sauce Dips'];
      if (selectedSauces != null && selectedSauces.isNotEmpty) {
        for (var sauce in selectedSauces) {
          if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
            dealExtraCost += 0.75;
          } else {
            dealExtraCost += 0.5;
          }
        }
        debugPrint("Pizza Deal sauce cost added");
      }

      price += dealExtraCost;
      debugPrint(
        "Pizza Deal extra costs: £$dealExtraCost, total price: £$price",
      );
    } else if (widget.foodItem.category == 'Deals' &&
        !_isPizzaDealWithOptions()) {
      // General deal sauce pricing (for all deals except Pizza Deals subtype)
      double dealSauceCost = 0.0;

      // Calculate sauce costs for deals (same pricing as Pizza category)
      if (_selectedSauces.isNotEmpty) {
        for (var sauce in _selectedSauces) {
          if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
            dealSauceCost += 0.75;
          } else {
            dealSauceCost += 0.5;
          }
        }
        debugPrint("Deal sauce cost: £$dealSauceCost");
      }

      price += dealSauceCost;
      debugPrint("Deal sauce costs: £$dealSauceCost, total price: £$price");
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

      // Reset crust selection if size is not 12 inch
      if (size != "12 inch") {
        _selectedCrust = "Normal"; // Reset to default
        // Also switch away from Crust tab if currently selected
        if (_selectedOptionCategory == 'Crust') {
          _selectedOptionCategory = 'Toppings';
        }
      } else {
        // Set default crust for 12 inch if not already set
        if (_selectedCrust == null) {
          _selectedCrust = "Normal";
        }
      }

      // Handle meal size selection - reset drink options when switching away from meal
      if (size.toLowerCase() != 'meal') {
        _selectedDrink = null;
        _selectedDrinkFlavor = null;
        _selectedRedSaltChoice = null;
      }

      _updatePriceDisplay();
    });
  }

  void _changeSize() {
    setState(() {
      _isInSizeSelectionMode = true;
    });
  }

  // Helper method to check if meal size is selected
  bool _isMealSizeSelected() {
    return _selectedSize?.toLowerCase() == 'meal';
  }

  // NEW: Helper method to check if red salt choice should be shown
  bool _shouldShowRedSaltChoice() {
    // Show for meal size selection
    if (_isMealSizeSelected()) return true;

    // Show for Sides category only if item contains fries/chips
    if (widget.foodItem.category == 'Sides') {
      String itemName = widget.foodItem.name.toLowerCase();
      return itemName.contains('fries') || itemName.contains('chips');
    }

    // Show for KidsMeal that contains chips
    if (widget.foodItem.category == 'KidsMeal' &&
        (widget.foodItem.description?.toLowerCase().contains('chips') == true ||
            widget.foodItem.description?.toLowerCase().contains('fries') ==
                true ||
            widget.foodItem.name.toLowerCase().contains('chips') ||
            widget.foodItem.name.toLowerCase().contains('fries'))) {
      return true;
    }

    // Show for deals only if their description contains fries/fires
    if (widget.foodItem.category == 'Deals') {
      String? description = widget.foodItem.description;
      if (description != null) {
        String lowerDescription = description.toLowerCase();
        // Only show if description contains fries or fires
        if (lowerDescription.contains('fries') ||
            lowerDescription.contains('fires')) {
          return true;
        }
      }
      return false; // Don't show for deals without fries in description
    }

    return false;
  }

  // Helper method to determine drink type for deals
  String _getDrinkType() {
    if (widget.foodItem.category != 'Deals') return 'none';

    String name = widget.foodItem.name.toLowerCase();
    String? description = widget.foodItem.description?.toLowerCase();

    // Check for 1.5ltr drink first
    if (name.contains('1.5ltr drink') ||
        name.contains('1.5l drink') ||
        (description != null &&
            (description.contains('1.5ltr drink') ||
                description.contains('1.5l drink')))) {
      return '1.5L';
    }

    // Check for reg drink (case insensitive)
    if (name.contains('reg drink') ||
        (description != null && description.contains('reg drink'))) {
      return 'regular';
    }

    return 'none';
  }

  // Helper method to check if a deal item has any drink
  bool _hasDrink() {
    return _getDrinkType() != 'none';
  }

  void _confirmSelection() {
    if (widget.foodItem.price.keys.length > 1 && _selectedSize == null) {
      CustomPopupService.show(
        context,
        "Please select a size before adding to cart",
        type: PopupType.failure,
      );
      return;
    }

    bool kidsMealNeedsDrink =
        widget.foodItem.category == 'KidsMeal' &&
        widget.foodItem.name.toLowerCase().contains('drink');

    if ((_isMealSizeSelected() || kidsMealNeedsDrink) &&
        _selectedDrink == null) {
      CustomPopupService.show(
        context,
        'Please select a drink for your meal',
        type: PopupType.failure,
      );
      return;
    }

    // Check sauce selection requirement
    if ([
          'Shawarma',
          'Wraps',
          'Burgers',
          'Wings',
          'Chicken',
          'Strips',
        ].contains(widget.foodItem.category) &&
        _sauceChoice == 'Yes' &&
        _selectedSauces.isEmpty) {
      CustomPopupService.show(
        context,
        'Please select at least one sauce',
        type: PopupType.failure,
      );
      return;
    }

    // Red Salt selection is now optional for all categories

    if ((_drinkFlavors.containsKey(widget.foodItem.name) &&
            _selectedDrinkFlavor == null) ||
        (_isMealSizeSelected() &&
            _selectedDrink != null &&
            _drinkFlavors.containsKey(_selectedDrink!) &&
            _selectedDrinkFlavor == null)) {
      CustomPopupService.show(
        context,
        'Please select a flavour fpr your drink',
        type: PopupType.failure,
      );
      return;
    }

    final List<String> selectedOptions = [];

    // Only show size for non-deal items (deals handle sizing differently)
    if (_selectedSize != null &&
        widget.foodItem.price.keys.length > 1 &&
        widget.foodItem.category != 'Deals') {
      selectedOptions.add('Size: $_selectedSize');
    }

    if (_selectedToppings.isNotEmpty && widget.foodItem.category != 'Deals') {
      // For Pizza items, only show user-selected toppings (exclude default toppings)
      if (widget.foodItem.category == 'Pizza' ||
          widget.foodItem.category == 'GarlicBread') {
        List<String> userSelectedToppings =
            _selectedToppings
                .where(
                  (topping) =>
                      !((widget.foodItem.defaultToppings ?? []).contains(
                            topping,
                          ) ||
                          (widget.foodItem.defaultCheese ?? []).contains(
                            topping,
                          )),
                )
                .toList();

        if (userSelectedToppings.isNotEmpty) {
          selectedOptions.add('Toppings: ${userSelectedToppings.join(', ')}');
        }
      } else {
        // For non-Pizza items, show all selected toppings
        selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
      }
    }

    if (_selectedCrust != null &&
        _selectedSize == "12 inch" &&
        (widget.foodItem.category == 'Pizza' ||
            widget.foodItem.category == 'GarlicBread') &&
        widget.foodItem.category != 'Deals') {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    // Only show specific sauce names for Pizza, GarlicBread, Chicken, Wings, Strips
    // Sides category removed from sauce dips
    // Kebabs handled separately below
    if (_selectedSauces.isNotEmpty &&
        !_noSauce &&
        (widget.foodItem.category == 'Pizza' ||
            widget.foodItem.category == 'GarlicBread' ||
            widget.foodItem.category == 'Chicken' ||
            widget.foodItem.category == 'Wings' ||
            widget.foodItem.category == 'Strips')) {
      // Use "Sauce Dip:" for Pizza, Garlic Bread, Chicken, Wings, Strips
      String sauceLabel = 'Sauce Dip';
      selectedOptions.add('$sauceLabel: ${_selectedSauces.join(', ')}');
    }

    // Handle Kebabs - show free sauces and paid sauce dips separately
    if (widget.foodItem.category == 'Kebabs') {
      // Show free sauces (like Burgers)
      if (_selectedSauces.isNotEmpty) {
        selectedOptions.add('Sauces: ${_selectedSauces.join(', ')}');
      }
      // Show paid sauce dips
      if (_selectedSauceDips.isNotEmpty) {
        selectedOptions.add('Sauce Dip: ${_selectedSauceDips.join(', ')}');
      }
    }

    // Only add drinks and red salt choice for non-deal categories
    if (widget.foodItem.category != 'Deals') {
      if (_isMealSizeSelected()) {
        // Don't add 'Make it a meal' label - size already shows 'Meal'
        if (_selectedDrink != null) {
          String drinkOption = 'Drink: $_selectedDrink';
          if (_selectedDrinkFlavor != null) {
            drinkOption += ' ($_selectedDrinkFlavor)';
          }
          selectedOptions.add(drinkOption);
        }
      } else if (widget.foodItem.category == 'KidsMeal' &&
          _selectedDrink != null) {
        // Kids Meal drink selection
        String drinkOption = 'Drink: $_selectedDrink';
        if (_selectedDrinkFlavor != null) {
          drinkOption += ' ($_selectedDrinkFlavor)';
        }
        selectedOptions.add(drinkOption);
      } else if (_drinkFlavors.containsKey(widget.foodItem.name) &&
          _selectedDrinkFlavor != null) {
        selectedOptions.add('Flavor: $_selectedDrinkFlavor');
      }

      // NEW: Add red salt choice option for non-deals
      if (_selectedRedSaltChoice != null && _shouldShowRedSaltChoice()) {
        selectedOptions.add('Red salt: $_selectedRedSaltChoice');
      }
    }

    // Shawarma, Burgers, and Wraps use traditional salad + sauce Yes/No system
    if (['Shawarma', 'Burgers', 'Wraps'].contains(widget.foodItem.category) &&
        widget.foodItem.category != 'Deals') {
      // Handle salad display - keep as Yes/No format
      if (_saladChoice == 'No') {
        selectedOptions.add('No Salad');
      } else if (_saladChoice == 'Yes') {
        selectedOptions.add('Salad: Yes');
      }

      // Handle sauce display - show actual sauces when Yes, No Sauce when No
      if (_sauceChoice == 'No') {
        selectedOptions.add('No Sauce');
      } else if (_sauceChoice == 'Yes' && _selectedSauces.isNotEmpty) {
        // Show "Sauces:" for Burgers and Wraps, "Sauce:" for Shawarma
        String sauceLabel =
            (['Burgers', 'Wraps'].contains(widget.foodItem.category))
                ? 'Sauces:'
                : 'Sauce:';
        selectedOptions.add('$sauceLabel ${_selectedSauces.join(', ')}');
      }
    }

    if (widget.foodItem.category == 'Milkshake') {
      if (_noCream) selectedOptions.add('No Cream');
    }

    if (widget.foodItem.category == 'Deals') {
      // Group multiple selections for cart display while keeping individual entries for editing
      Map<String, List<String>> groupedSelections = {};

      // Special handling for Shawarma Deal - group options and sauces together
      if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
        // Collect shawarma salad/sauce choices and options for each shawarma
        Map<String, Map<String, dynamic>> shawarmaDetails = {
          'Shawarma 1': {
            'saladChoice': null,
            'salads': [],
            'sauceChoice': null,
            'sauces': [],
          },
          'Shawarma 2': {
            'saladChoice': null,
            'salads': [],
            'sauceChoice': null,
            'sauces': [],
          },
          'Shawarma 3': {
            'saladChoice': null,
            'salads': [],
            'sauceChoice': null,
            'sauces': [],
          },
          'Shawarma 4': {
            'saladChoice': null,
            'salads': [],
            'sauceChoice': null,
            'sauces': [],
          },
        };

        _dealSelections.forEach((sectionName, selectedOption) {
          if (selectedOption != null) {
            if (sectionName == 'Shawarma 1' ||
                sectionName == 'Shawarma 2' ||
                sectionName == 'Shawarma 3' ||
                sectionName == 'Shawarma 4') {
              groupedSelections['Selected Shawarmas'] ??= [];
              groupedSelections['Selected Shawarmas']!.add(selectedOption);
            } else if (sectionName.contains(' - Salad') &&
                !sectionName.contains('Options')) {
              // Handle Salad Yes/No choices
              for (String shawarmaKey in shawarmaDetails.keys) {
                if (sectionName.startsWith('$shawarmaKey - ')) {
                  shawarmaDetails[shawarmaKey]!['saladChoice'] = selectedOption;
                  print('🔍 SALAD CHOICE: $shawarmaKey = $selectedOption');
                  break;
                }
              }
            } else if (sectionName.contains(' - Sauce') &&
                !sectionName.contains('Options')) {
              // Handle Sauce Yes/No choices
              for (String shawarmaKey in shawarmaDetails.keys) {
                if (sectionName.startsWith('$shawarmaKey - ')) {
                  shawarmaDetails[shawarmaKey]!['sauceChoice'] = selectedOption;
                  print('🔍 SAUCE CHOICE: $shawarmaKey = $selectedOption');
                  break;
                }
              }
            } else if (sectionName == 'Drink & seasoning') {
              selectedOptions.add('Drink: $selectedOption');
            } else if (sectionName.contains(' - Red Salt Choice')) {
              // Skip red salt choice here - will be added in correct order later
            } else {
              selectedOptions.add('$sectionName: $selectedOption');
            }
          }
        });

        // Handle multi-select salads and sauces for shawarmas
        _dealMultiSelections.forEach((sectionName, selectedOptionsSet) {
          if (selectedOptionsSet.isNotEmpty) {
            if (sectionName.contains(' - Salad Options')) {
              for (String shawarmaKey in shawarmaDetails.keys) {
                if (sectionName.startsWith('$shawarmaKey - ')) {
                  shawarmaDetails[shawarmaKey]!['salads'] =
                      selectedOptionsSet.toList();
                  print(
                    '🔍 SALAD OPTIONS: $shawarmaKey = ${selectedOptionsSet.toList()}',
                  );
                  break;
                }
              }
            } else if (sectionName.contains(' - Sauce Options')) {
              for (String shawarmaKey in shawarmaDetails.keys) {
                if (sectionName.startsWith('$shawarmaKey - ')) {
                  shawarmaDetails[shawarmaKey]!['sauces'] =
                      selectedOptionsSet.toList();
                  print(
                    '🔍 SAUCE OPTIONS: $shawarmaKey = ${selectedOptionsSet.toList()}',
                  );
                  break;
                }
              }
            }
          }
        });

        // Format exactly 4 shawarma details in the new format
        List<String> shawarmaKeys = [
          'Shawarma 1',
          'Shawarma 2',
          'Shawarma 3',
          'Shawarma 4',
        ];
        for (String shawarmaKey in shawarmaKeys) {
          Map<String, dynamic> details = shawarmaDetails[shawarmaKey]!;
          String saladChoice = details['saladChoice'] ?? '';
          String sauceChoice = details['sauceChoice'] ?? '';
          List<String> sauces =
              (details['sauces'] as List<dynamic>?)?.cast<String>() ?? [];

          List<String> detailParts = [];

          // Handle salad section
          if (saladChoice == 'Yes') {
            detailParts.add('Salad: Yes');
          } else {
            detailParts.add('Salad: No');
          }

          // Handle sauce section
          if (sauceChoice == 'Yes' && sauces.isNotEmpty) {
            detailParts.add('Sauces: ${sauces.join(', ')}');
          } else {
            detailParts.add('No Sauce');
          }

          // Format: "Shawarma 1 (Salad: Cucumber, Lettuce & Sauces: Ketchup, BBQ)" or "Shawarma 1 (No Salad, No Sauce)"
          selectedOptions.add('$shawarmaKey (${detailParts.join(' & ')})');
        }

        // Add red salt choice in correct order (1 then 2)
        String redSaltKey1 = 'Drink & seasoning - Red Salt Choice 1';
        String redSaltKey2 = 'Drink & seasoning - Red Salt Choice 2';

        if (_dealSelections[redSaltKey1] != null) {
          selectedOptions.add(
            'Red salt choice 1: ${_dealSelections[redSaltKey1]}',
          );
        }
        if (_dealSelections[redSaltKey2] != null) {
          selectedOptions.add(
            'Red salt choice 2: ${_dealSelections[redSaltKey2]}',
          );
        }
      } else if (widget.foodItem.name.toLowerCase() == 'family meal') {
        // Special formatting for Family Meal
        List<String> formattedItems = [];

        // Define the correct order for Family Meal: Pizza, Shawarma, Burger, Calzone, Drink
        List<String> orderedSections = [
          'Pizza (16")',
          'Shawarma',
          'Burger',
          'Calzone',
          'Drinks',
        ];

        for (String sectionName in orderedSections) {
          String? selectedOption = _dealSelections[sectionName];
          if (selectedOption != null) {
            // This is a main item selection
            String itemName = selectedOption;

            if (sectionName.contains('Pizza')) {
              // Family Meal Pizza - no sauce information
              formattedItems.add('Pizza (16"): $itemName');
            } else if (sectionName.contains('Shawarma')) {
              // Shawarma: flavour name (No Salad, No Sauce) or (Salad: names, Sauce: names)
              String saladYesNo =
                  _dealSelections['$sectionName - Salad'] ?? 'No';
              String sauceYesNo =
                  _dealSelections['$sectionName - Sauce'] ?? 'No';

              List<String> detailParts = [];

              if (saladYesNo == 'Yes') {
                detailParts.add('Salad: Yes');
              } else {
                detailParts.add('Salad: No');
              }

              if (sauceYesNo == 'Yes') {
                List<String> sauces =
                    (_dealMultiSelections['$sectionName - Sauce Options'] ??
                            <String>{})
                        .toList();
                if (sauces.isNotEmpty) {
                  detailParts.add('Sauce: ${sauces.join(', ')}');
                } else {
                  detailParts.add('No Sauce');
                }
              } else {
                detailParts.add('No Sauce');
              }

              formattedItems.add(
                'Shawarma: $itemName (${detailParts.join(', ')})',
              );
            } else if (sectionName.contains('Burger')) {
              // Burger: flavour name (No Salad, No Sauce) or (Salad: names, Sauce: names)
              String saladYesNo =
                  _dealSelections['$sectionName - Salad'] ?? 'No';
              String sauceYesNo =
                  _dealSelections['$sectionName - Sauce'] ?? 'No';

              List<String> detailParts = [];

              if (saladYesNo == 'Yes') {
                detailParts.add('Salad: Yes');
              } else {
                detailParts.add('Salad: No');
              }

              if (sauceYesNo == 'Yes') {
                List<String> sauces =
                    (_dealMultiSelections['$sectionName - Sauce Options'] ??
                            <String>{})
                        .toList();
                if (sauces.isNotEmpty) {
                  detailParts.add('Sauce: ${sauces.join(', ')}');
                } else {
                  detailParts.add('No Sauce');
                }
              } else {
                detailParts.add('No Sauce');
              }

              formattedItems.add(
                'Burger: $itemName (${detailParts.join(', ')})',
              );
            } else if (sectionName.contains('Calzone')) {
              // Calzone: flavour name
              formattedItems.add('Calzone: $itemName');
            } else if (sectionName.contains('Drink')) {
              // Drink: name
              formattedItems.add('Drink: $itemName');
            }
          }
        }

        selectedOptions.addAll(formattedItems);
      } else if (widget.foodItem.name.toLowerCase() == 'combo meal') {
        // Special formatting for Combo Meal (same as Family Meal but with 12" pizza and no calzone)
        List<String> formattedItems = [];

        // Define the correct order for Combo Meal: Pizza (12"), Shawarma, Burger, Drinks
        List<String> orderedSections = [
          'Pizza (12")',
          'Shawarma',
          'Burger',
          'Drink 1',
          'Drink 2',
        ];

        for (String sectionName in orderedSections) {
          String? selectedOption = _dealSelections[sectionName];
          if (selectedOption != null) {
            // This is a main item selection
            String itemName = selectedOption;

            if (sectionName.contains('Pizza')) {
              // Combo Meal Pizza - no sauce information
              formattedItems.add('Pizza (12"): $itemName');
            } else if (sectionName.contains('Shawarma')) {
              // Shawarma: flavour name (No Salad, No Sauce) or (Salad: names, Sauce: names)
              String saladYesNo =
                  _dealSelections['$sectionName - Salad'] ?? 'No';
              String sauceYesNo =
                  _dealSelections['$sectionName - Sauce'] ?? 'No';

              List<String> detailParts = [];

              if (saladYesNo == 'Yes') {
                detailParts.add('Salad: Yes');
              } else {
                detailParts.add('Salad: No');
              }

              if (sauceYesNo == 'Yes') {
                List<String> sauces =
                    (_dealMultiSelections['$sectionName - Sauce Options'] ??
                            <String>{})
                        .toList();
                if (sauces.isNotEmpty) {
                  detailParts.add('Sauce: ${sauces.join(', ')}');
                } else {
                  detailParts.add('No Sauce');
                }
              } else {
                detailParts.add('No Sauce');
              }

              formattedItems.add(
                'Shawarma: $itemName (${detailParts.join(', ')})',
              );
            } else if (sectionName.contains('Burger')) {
              // Burger: flavour name (No Salad, No Sauce) or (Salad: names, Sauce: names)
              String saladYesNo =
                  _dealSelections['$sectionName - Salad'] ?? 'No';
              String sauceYesNo =
                  _dealSelections['$sectionName - Sauce'] ?? 'No';

              List<String> detailParts = [];

              if (saladYesNo == 'Yes') {
                detailParts.add('Salad: Yes');
              } else {
                detailParts.add('Salad: No');
              }

              if (sauceYesNo == 'Yes') {
                List<String> sauces =
                    (_dealMultiSelections['$sectionName - Sauce Options'] ??
                            <String>{})
                        .toList();
                if (sauces.isNotEmpty) {
                  detailParts.add('Sauce: ${sauces.join(', ')}');
                } else {
                  detailParts.add('No Sauce');
                }
              } else {
                detailParts.add('No Sauce');
              }

              formattedItems.add(
                'Burger: $itemName (${detailParts.join(', ')})',
              );
            } else if (sectionName.contains('Drink')) {
              // Drink 1: name or Drink 2: name
              formattedItems.add('$sectionName: $itemName');
            }
          }
        }

        selectedOptions.addAll(formattedItems);
      } else if (widget.foodItem.name.toLowerCase() == 'pizza offers') {
        // Special formatting for Pizza Offers
        List<String> formattedItems = [];

        // Get selected size with inch formatting
        String sizeDisplay =
            _selectedSize != null
                ? _getDisplaySize(_selectedSize!)
                : 'No Size Selected';
        // Add "inch" if it's not already there and it's not "default"
        if (sizeDisplay != 'No Size Selected' &&
            sizeDisplay.toLowerCase() != 'default' &&
            sizeDisplay.toLowerCase() != 'meal' &&
            !sizeDisplay.toLowerCase().contains('inch')) {
          sizeDisplay = '$sizeDisplay inch';
        }
        formattedItems.add('Size: $sizeDisplay');

        // Get all selected pizzas
        List<String> selectedPizzas = [];
        for (String sectionName in ['Pizza 1', 'Pizza 2', 'Pizza 3']) {
          String? selectedPizza = _dealSelections[sectionName];
          if (selectedPizza != null) {
            selectedPizzas.add(selectedPizza);
          }
        }

        if (selectedPizzas.isNotEmpty) {
          formattedItems.add('Selected Pizzas: ${selectedPizzas.join(', ')}');
        }

        // Get selected drink
        String? selectedDrink = _dealSelections['Drink (1.5L)'];
        if (selectedDrink != null) {
          formattedItems.add('Drink: $selectedDrink (1.5L)');
        }

        selectedOptions.addAll(formattedItems);
      } else if (widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
        // Special formatting for 3X12" Pizza Deal
        List<String> formattedPizzas = [];

        for (int i = 1; i <= 3; i++) {
          String pizzaKey = 'Pizza $i';

          // Get selected pizza name
          String? selectedPizza = _dealSelections['$pizzaKey - Pizza'];
          if (selectedPizza != null) {
            List<String> pizzaDetails = [];

            // Get crust selection (only show if not Normal, since Normal is default)
            String? crust = _dealSelections['$pizzaKey - Crust'];
            if (crust != null && crust != 'Normal') {
              pizzaDetails.add('Crust: $crust');
            }

            // Get toppings selection (show as "Extra Toppings" like Page4)
            Set<String>? toppings =
                _dealMultiSelections['$pizzaKey - Toppings'];
            if (toppings != null && toppings.isNotEmpty) {
              pizzaDetails.add('Extra Toppings: ${toppings.join(', ')}');
            }

            // Format: "Pizza 1: Asian Special (Extra Toppings: Green Chilli)"
            if (pizzaDetails.isNotEmpty) {
              formattedPizzas.add(
                '$pizzaKey: $selectedPizza (${pizzaDetails.join(', ')})',
              );
            } else {
              formattedPizzas.add('$pizzaKey: $selectedPizza');
            }
          }
        }

        selectedOptions.addAll(formattedPizzas);

        // Add general sauce dips selection for the entire deal
        Set<String>? generalSauces = _dealMultiSelections['Sauce Dips'];
        if (generalSauces != null && generalSauces.isNotEmpty) {
          selectedOptions.add('Sauce Dips: ${generalSauces.join(', ')}');
        }
      } else if (_isFamilyDeal()) {
        // Special formatting for Family Deals items (check by subType)
        print('🔍 ENTERING FAMILY DEALS FORMATTING SECTION');
        List<String> formattedItems = [];

        // Add all deal selections (including Side Choice)
        _dealSelections.forEach((sectionName, selectedOption) {
          if (selectedOption != null) {
            formattedItems.add('$sectionName: $selectedOption');
          }
        });

        // Add multi-selections for Family Deals
        _dealMultiSelections.forEach((sectionName, selectedOptions) {
          if (selectedOptions.isNotEmpty) {
            formattedItems.add('$sectionName: ${selectedOptions.join(', ')}');
          }
        });

        selectedOptions.addAll(formattedItems);

        // Add sauce dips for Family Deals (same as general deals)
        if (_selectedSauces.isNotEmpty) {
          selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
        }

        // Add drink for Family Deals (same as general deals)
        print('🔍 FAMILY DEALS DRINK CHECK: _selectedDrink = $_selectedDrink');
        if (_selectedDrink != null) {
          String drinkOption = 'Drink: $_selectedDrink';
          // Only add flavor if it's not already in the drink name
          if (_selectedDrinkFlavor != null && !_selectedDrink!.contains('(')) {
            drinkOption += ' ($_selectedDrinkFlavor)';
          }
          selectedOptions.add(drinkOption);
        }
      } else if (_isPizzaDealWithOptions()) {
        // Special formatting for Pizza Deals (Pizza Deal 4 One, Mega Pizza Deal)
        List<String> formattedItems = [];

        // Format: Selected Pizza: Asian Special (Extra Toppings: Extra Cheese, Green Chilli, Jalapeno)
        String? selectedPizza = _dealSelections['Selected Pizza'];
        if (selectedPizza != null) {
          List<String> pizzaDetails = [];

          // Add crust if not Normal (for Mega Pizza Deal)
          String? crust = _dealSelections['Crust'];
          if (crust != null && crust != 'Normal') {
            pizzaDetails.add('Crust: $crust');
          }

          // Add extra toppings
          Set<String>? toppings = _dealMultiSelections['Extra Toppings'];
          if (toppings != null && toppings.isNotEmpty) {
            pizzaDetails.add('Extra Toppings: ${toppings.join(', ')}');
          }

          // Format the pizza line
          if (pizzaDetails.isNotEmpty) {
            formattedItems.add(
              'Selected Pizza: $selectedPizza (${pizzaDetails.join(', ')})',
            );
          } else {
            formattedItems.add('Selected Pizza: $selectedPizza');
          }
        }

        // Format: Sauce Dips: Ketchup, Chilli sauce
        Set<String>? sauces = _dealMultiSelections['Sauce Dips'];
        if (sauces != null && sauces.isNotEmpty) {
          formattedItems.add('Sauce Dips: ${sauces.join(', ')}');
        }

        selectedOptions.addAll(formattedItems);
      } else if (widget.foodItem.name.toLowerCase() != 'pizza offers' &&
          widget.foodItem.name.toLowerCase() != '3x12" pizza deal') {
        // Original logic for other deals (exclude Pizza Offers and 3X12" Pizza Deal)
        _dealSelections.forEach((sectionName, selectedOption) {
          if (selectedOption != null) {
            // Skip drink sections to prevent duplication - drinks are handled separately below
            if (!sectionName.toLowerCase().contains('drink')) {
              selectedOptions.add('$sectionName: $selectedOption');
            }
          }
        });

        // Add sauce dips for general deals (excluding Pizza Deals subtype which already has sauce dips)
        if (widget.foodItem.subType?.toLowerCase() != 'pizza deals' &&
            _selectedSauces.isNotEmpty) {
          selectedOptions.add('Sauce Dips: ${_selectedSauces.join(', ')}');
        }
      }

      // Add special Sauce Options for Combo Meals (Deal 2, Deal 3) - shows as "Sauce:"
      if (_isComboMealWithSauceOptions()) {
        Set<String>? sauceOptions = _dealMultiSelections['Sauce Options'];
        if (sauceOptions != null && sauceOptions.isNotEmpty) {
          selectedOptions.add('Sauce: ${sauceOptions.join(', ')}');
        }
      }

      // Add grouped selections to the TOP of the options list for display
      List<String> groupedDisplayOptions = [];
      groupedSelections.forEach((groupName, selections) {
        if (groupName == 'Selected Shawarmas' && selections.isNotEmpty) {
          // Special format for shawarmas: always show 4X (fixed count for Shawarma Deal)
          String shawarmaName =
              selections
                  .first; // All should be the same (Chicken Shawarma (Pitta))
          groupedDisplayOptions.add('Shawarma Flavour: 4x $shawarmaName');
        } else {
          groupedDisplayOptions.add('$groupName: ${selections.join(', ')}');
        }
      });

      // Insert grouped options at the beginning for cart display
      selectedOptions.insertAll(0, groupedDisplayOptions);

      // Add multi-select deal selections to options - exclude all major deals as they're handled above
      if (widget.foodItem.name.toLowerCase() != 'shawarma deal' &&
          widget.foodItem.name.toLowerCase() != 'family meal' &&
          widget.foodItem.name.toLowerCase() != 'combo meal' &&
          widget.foodItem.name.toLowerCase() != 'pizza offers' &&
          widget.foodItem.name.toLowerCase() != '3x12" pizza deal' &&
          !_isFamilyDeal() &&
          !_isPizzaDealWithOptions()) {
        _dealMultiSelections.forEach((sectionName, selectedOptionsSet) {
          if (selectedOptionsSet.isNotEmpty) {
            // Skip salad and sauce options to prevent corrupted duplicate lines
            if (sectionName.contains('Salad Options') ||
                sectionName.contains('Sauce Options') ||
                sectionName.contains('Pizza Sauce Options')) {
              return; // Skip these to prevent corrupted mixed lines
            }
            selectedOptions.add(
              '$sectionName: ${selectedOptionsSet.join(', ')}',
            );
          }
        });
      }

      // Add drink selection for deals with drinks (except Family Deals which handle it separately)
      if (_hasDrink() && _selectedDrink != null && !_isFamilyDeal()) {
        String drinkOption = 'Drink: $_selectedDrink';
        if (_selectedDrinkFlavor != null) {
          drinkOption += ' ($_selectedDrinkFlavor)';
        }
        selectedOptions.add(drinkOption);
      }

      // Add red salt choice for deals
      if (_selectedRedSaltChoice != null && _shouldShowRedSaltChoice()) {
        selectedOptions.add('Red salt: $_selectedRedSaltChoice');
      }
    }

    final String userComment = _reviewNotesController.text.trim();

    print('🔍 CREATING CARTITEM FOR ${widget.foodItem.name}');
    print('🔍 selectedOptions.length = ${selectedOptions.length}');
    print('🔍 selectedOptions = $selectedOptions');

    final cartItem = CartItem(
      foodItem: widget.foodItem,
      quantity: _quantity,
      selectedOptions: selectedOptions.isEmpty ? null : selectedOptions,
      comment: userComment.isNotEmpty ? userComment : null,
      pricePerUnit: _calculatedPricePerUnit,
    );

    print(
      '🔍 CARTITEM CREATED WITH selectedOptions: ${cartItem.selectedOptions}',
    );
    widget.onAddToCart(cartItem);

    // Add a small delay before closing to ensure state updates
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        widget.onClose?.call();
      }
    });
  }

  // --- NEW Helper Method for button-based UI ---
  Widget _buildOptionButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.grey[100] : Colors.black,
        foregroundColor: isActive ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: isActive ? 4 : 2,
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
    );
  }

  // --- NEW Helper Method for Salad option with Yes/No choices ---
  Widget _buildSaladOption() {
    // Salad is now just Yes/No - no specific options needed

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Salad',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _saladChoice = 'Yes';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _saladChoice == 'Yes' ? Colors.grey[100] : Colors.black,
                  foregroundColor:
                      _saladChoice == 'Yes' ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                  elevation: _saladChoice == 'Yes' ? 4 : 2,
                ),
                child: const Text(
                  'Yes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _saladChoice = 'No';
                    // No specific options needed for salad
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _saladChoice == 'No' ? Colors.grey[100] : Colors.black,
                  foregroundColor:
                      _saladChoice == 'No' ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                  elevation: _saladChoice == 'No' ? 4 : 2,
                ),
                child: const Text(
                  'No',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
              ),
            ),
          ],
        ),

        // No specific salad options needed - just Yes/No choice
      ],
    );
  }

  // --- NEW: Sauce option with Yes/No choices (similar to salad) ---
  Widget _buildSauceOption() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Sauce',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _sauceChoice = 'Yes';
                    _noSauce = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _sauceChoice == 'Yes' ? Colors.grey[100] : Colors.black,
                  foregroundColor:
                      _sauceChoice == 'Yes' ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                  elevation: _sauceChoice == 'Yes' ? 4 : 2,
                ),
                child: const Text(
                  'Yes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _sauceChoice = 'No';
                    _noSauce = true;
                    // Clear all selected sauces when No is selected
                    _selectedSauces.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _sauceChoice == 'No' ? Colors.grey[100] : Colors.black,
                  foregroundColor:
                      _sauceChoice == 'No' ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                  elevation: _sauceChoice == 'No' ? 4 : 2,
                ),
                child: const Text(
                  'No',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
              ),
            ),
          ],
        ),
        // No specific sauce options shown here - they appear in the separate sauce section
      ],
    );
  }

  // --- NEW: Kids Meal options widget ---
  Widget _buildKidsMealOptions() {
    bool hasChips =
        widget.foodItem.name.toLowerCase().contains('chips') ||
        widget.foodItem.name.toLowerCase().contains('fries') ||
        widget.foodItem.description?.toLowerCase().contains('chips') == true ||
        widget.foodItem.description?.toLowerCase().contains('fries') == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show drinks for ALL Kids Meal items
        _buildKidsMealDrinkSelectionSection(),

        // Show chip seasoning if the meal contains chips/fries
        if (hasChips) ...[
          const SizedBox(height: 20),
          _buildRedSaltChoiceSection(),
        ],
      ],
    );
  }

  // --- NEW: Sides options widget for sauces and seasoning ---
  Widget _buildSidesOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sauce options removed from Sides category

        // Red Salt choice section (only for fries/chips items)
        _buildRedSaltChoiceSection(),
      ],
    );
  }

  // --- NEW: Red salt choice selection widget ---
  Widget _buildRedSaltChoiceSection() {
    if (!_shouldShowRedSaltChoice()) {
      return const SizedBox.shrink();
    }

    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 4;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Red salt:',
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
          alignment: WrapAlignment.start,
          children:
              _redSaltOptions.map((option) {
                final bool isActive = _selectedRedSaltChoice == option;
                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: option,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        // Set the selection (Yes or No)
                        _selectedRedSaltChoice = option;
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // --- MODIFIED `_buildMealAndExclusionOptions` method ---
  Widget _buildMealAndExclusionOptions() {
    return Center(
      // Wrap the entire content in a Center widget
      child: Column(
        mainAxisSize:
            MainAxisSize
                .min, // Ensure the column only takes up the space it needs
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Make it a meal option removed - now handled by Meal size selection
              // Salad
              Expanded(child: _buildSaladOption()),
              const SizedBox(width: 15),
              // Sauce Yes/No choice
              Expanded(child: _buildSauceOption()),
            ],
          ),
          // NEW: Add chip seasoning section
          _buildRedSaltChoiceSection(),
        ],
      ),
    );
  }

  // Simplified method for just salad and sauce buttons (without meal drink selection)
  Widget _buildSaladAndSauceOptions() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Salad
          Expanded(child: _buildSaladOption()),
          const SizedBox(width: 15),
          // Sauce Yes/No choice
          Expanded(child: _buildSauceOption()),
        ],
      ),
    );
  }

  // --- NEW METHOD for drink selection with buttons ---
  // --- NEW: Kids Meal drink selection section ---
  Widget _buildKidsMealDrinkSelectionSection() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 2; // Only 2 drinks for Kids Meal

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

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
          children:
              _kidsMealDrinks.map((drink) {
                final bool isActive = _selectedDrink == drink;
                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: drink,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        _selectedDrink = drink;
                        // Kids meal drinks don't have flavors
                        _selectedDrinkFlavor = null;
                        _updatePriceDisplay();
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildDrinkSelectionSection() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    // Choose appropriate drink list based on item type
    List<String> availableDrinks;
    String drinkType = _getDrinkType();
    if (drinkType == 'regular') {
      availableDrinks = _regularDrinks;
    } else if (drinkType == '1.5L') {
      availableDrinks = _largeBottleDrinks;
    } else {
      availableDrinks = _allDrinks;
    }

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
          children:
              availableDrinks.map((drink) {
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
        if (_selectedDrink != null &&
            _drinkFlavors.containsKey(_selectedDrink!)) ...[
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

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

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
          children:
              flavors.map((flavor) {
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
        ],
        // NEW: Add chip seasoning section for sides and kids meals
        _buildRedSaltChoiceSection(),
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
      case 'meal':
        return 'Meal';
      default:
        // Handle sizes like '10 inch', '12 inch', etc.
        final parts = size.split(' ');
        if (parts.isNotEmpty) {
          return parts.first; // e.g., "10"
        }
        return size;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.8,
      1500.0,
    );

    bool kidsMealNeedsDrinkForValidation =
        widget.foodItem.category == 'KidsMeal' &&
        widget.foodItem.name.toLowerCase().contains('drink');

    bool canConfirmSelection = true;
    if ((widget.foodItem.price.keys.length > 1 && _selectedSize == null) ||
        (_isMealSizeSelected() && _selectedDrink == null) ||
        (kidsMealNeedsDrinkForValidation && _selectedDrink == null) ||
        (_isMealSizeSelected() &&
            _selectedDrink != null &&
            _drinkFlavors.containsKey(_selectedDrink!) &&
            _selectedDrinkFlavor == null) ||
        (kidsMealNeedsDrinkForValidation &&
            _selectedDrink != null &&
            _drinkFlavors.containsKey(_selectedDrink!) &&
            _selectedDrinkFlavor == null)) {
      canConfirmSelection = false;
    }
    if ((_drinkFlavors.containsKey(widget.foodItem.name) &&
        _selectedDrinkFlavor == null)) {
      canConfirmSelection = false;
    }

    // Kids Meal validation - ALL Kids Meal items must have drink selected
    if (widget.foodItem.category == 'KidsMeal' && _selectedDrink == null) {
      canConfirmSelection = false;
    }
    // Deal validation - check if drink is required and selected
    if (widget.foodItem.category == 'Deals' &&
        _hasDrink() &&
        _selectedDrink == null) {
      canConfirmSelection = false;
    }

    // Sauce validation for categories using Yes/No sauce choice
    if ([
          'Shawarma',
          'Wraps',
          'Burgers',
          'Wings',
          'Chicken',
          'Strips',
        ].contains(widget.foodItem.category) &&
        _sauceChoice == 'Yes' &&
        _selectedSauces.isEmpty) {
      canConfirmSelection = false;
    }

    // Deal validation - ensure all required selections are made
    if (widget.foodItem.category == 'Deals') {
      // Apply validation for both new items and editing to ensure mandatory selections
      bool shouldValidate = true;

      if (widget.isEditing) {
        print(
          '🔍 EDIT MODE: Applying validation to ensure mandatory selections',
        );
      } else {
        print('🔍 NEW ITEM: Applying validation');
      }

      // Red Salt choice is now optional for all deals

      if (shouldValidate) {
        // For new items, apply strict validation
        Map<String, List<String>> dealOptions = _getDealOptions(
          widget.foodItem.name,
        );

        // Check if all non-optional sections have selections
        if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
          // Special validation for Shawarma Deal - make salad and sauce mandatory
          List<String> shawarmaKeys = [
            'Shawarma 1',
            'Shawarma 2',
            'Shawarma 3',
            'Shawarma 4',
          ];
          for (String shawarmaKey in shawarmaKeys) {
            // Only validate shawarma tabs that have a flavor selected
            if (_dealSelections[shawarmaKey] == null) {
              print(
                '🔍 VALIDATION SKIP: $shawarmaKey has no flavor selected, skipping validation',
              );
              continue;
            }

            // Check if Salad Yes/No choice is selected (mandatory)
            String saladYesNoKey = '$shawarmaKey - Salad';
            print(
              '🔍 VALIDATION CHECK: $saladYesNoKey = ${_dealSelections[saladYesNoKey]}',
            );
            if (_dealSelections[saladYesNoKey] == null) {
              print(
                '🔍 VALIDATION FAILED: Salad choice not selected for $shawarmaKey',
              );
              canConfirmSelection = false;
              break;
            }

            // Salad validation no longer needed - just Yes/No choice

            // Check if Sauce Yes/No choice is selected (mandatory)
            String sauceYesNoKey = '$shawarmaKey - Sauce';
            print(
              '🔍 VALIDATION CHECK: $sauceYesNoKey = ${_dealSelections[sauceYesNoKey]}',
            );
            if (_dealSelections[sauceYesNoKey] == null) {
              print(
                '🔍 VALIDATION FAILED: Sauce choice not selected for $shawarmaKey',
              );
              canConfirmSelection = false;
              break;
            }

            // If Sauce Yes is selected, check if at least one sauce option is selected
            if (_dealSelections[sauceYesNoKey] == 'Yes') {
              String sauceOptionsKey = '$shawarmaKey - Sauce Options';
              print(
                '🔍 VALIDATION CHECK: $sauceOptionsKey = ${_dealMultiSelections[sauceOptionsKey]}',
              );
              if (_dealMultiSelections[sauceOptionsKey] == null ||
                  _dealMultiSelections[sauceOptionsKey]!.isEmpty) {
                print(
                  '🔍 VALIDATION FAILED: Sauce options not selected for $shawarmaKey',
                );
                canConfirmSelection = false;
                break;
              }
            }
          }

          // Drink selection is still mandatory
          print(
            '🔍 VALIDATION CHECK: Drink & seasoning = ${_dealSelections['Drink & seasoning']}',
          );
          if (_dealSelections['Drink & seasoning'] == null) {
            print('🔍 VALIDATION FAILED: Drink not selected');
            canConfirmSelection = false;
          }
          // Chips seasoning remains optional - no validation needed
        } else if (widget.foodItem.name.toLowerCase() == 'family meal') {
          // Special validation for Family Meal - require ALL 5 items: Pizza, Shawarma, Burger, Calzone, Drink
          Map<String, List<String>> dealOptions = _getDealOptions(
            widget.foodItem.name,
          );

          print('🔍 FAMILY MEAL DEAL OPTIONS: ${dealOptions.keys.toList()}');
          print(
            '🔍 FAMILY MEAL CURRENT SELECTIONS: ${_dealSelections.keys.toList()}',
          );

          // Check if ALL required items are selected
          List<String> requiredSections = [
            'Pizza (16")',
            'Shawarma',
            'Burger',
            'Calzone',
            'Drinks',
          ];
          bool allItemsSelected = requiredSections.every(
            (sectionName) => _dealSelections[sectionName] != null,
          );

          if (!allItemsSelected) {
            print('🔍 FAMILY MEAL VALIDATION FAILED: Not all 5 items selected');
            for (String section in requiredSections) {
              print(
                '🔍 $section: ${_dealSelections[section] ?? "NOT SELECTED"}',
              );
            }
            canConfirmSelection = false;
          } else {
            // All 5 items selected - auto-initialize Yes/No choices and validate
            print(
              '🔍 FAMILY MEAL: All 5 items selected, auto-initializing Yes/No choices',
            );
            for (String sectionName in requiredSections) {
              if (sectionName.contains('Pizza')) {
                String sauceKey = '$sectionName - Pizza Sauce';
                if (_dealSelections[sauceKey] == null) {
                  _dealSelections[sauceKey] = 'No';
                  print('🔍 AUTO-INITIALIZED: $sauceKey = No');
                }
              } else if (sectionName.contains('Shawarma') ||
                  sectionName.contains('Burger')) {
                String saladKey = '$sectionName - Salad';
                String sauceKey = '$sectionName - Sauce';
                if (_dealSelections[saladKey] == null) {
                  _dealSelections[saladKey] = 'No';
                  print('🔍 AUTO-INITIALIZED: $saladKey = No');
                }
                if (_dealSelections[sauceKey] == null) {
                  _dealSelections[sauceKey] = 'No';
                  print('🔍 AUTO-INITIALIZED: $sauceKey = No');
                }
              }
            }
            print('🔍 FAMILY MEAL: Auto-initialization complete');
          }

          for (String sectionName in dealOptions.keys) {
            // Only validate sections that have items selected
            if (_dealSelections[sectionName] == null) {
              print(
                '🔍 FAMILY MEAL VALIDATION SKIP: $sectionName has no item selected',
              );
              continue;
            }

            print('🔍 FAMILY MEAL VALIDATION: Checking $sectionName');

            // Check for mandatory Yes/No choices based on section type
            // Family Meal Pizza doesn't have sauce options
            if (sectionName.contains('Pizza')) {
              // Skip pizza sauce validation for Family Meal - no sauce options
              print('🔍 FAMILY MEAL PIZZA: No sauce validation needed');
            } else if (sectionName.contains('Shawarma') ||
                sectionName.contains('Burger')) {
              // Validate Salad Yes/No choice
              String saladKey = '$sectionName - Salad';
              print('🔍 SALAD CHECK: $saladKey = ${_dealSelections[saladKey]}');
              // For Family Meal, auto-initialize to "No" if not set yet
              if (_dealSelections[saladKey] == null) {
                _dealSelections[saladKey] = 'No';
                print('🔍 AUTO-INITIALIZED: $saladKey = No');
              }

              // Salad validation no longer needed - just Yes/No choice

              // Validate Sauce Yes/No choice
              String sauceKey = '$sectionName - Sauce';
              print('🔍 SAUCE CHECK: $sauceKey = ${_dealSelections[sauceKey]}');

              // If Sauce Yes selected, check if sauce options are selected
              if (_dealSelections[sauceKey] == 'Yes') {
                String sauceOptionsKey = '$sectionName - Sauce Options';
                if (_dealMultiSelections[sauceOptionsKey] == null ||
                    _dealMultiSelections[sauceOptionsKey]!.isEmpty) {
                  print(
                    '🔍 VALIDATION FAILED: Sauce options not selected for $sectionName',
                  );
                  canConfirmSelection = false;
                  break;
                }
              }
            }
          }
          print(
            '🔍 FAMILY MEAL VALIDATION COMPLETE: canConfirmSelection = $canConfirmSelection',
          );
        } else if (widget.foodItem.name.toLowerCase() == 'combo meal') {
          // Special validation for Combo Meal - require ALL 4 items: Pizza (12"), Shawarma, Burger, Drinks
          Map<String, List<String>> dealOptions = _getDealOptions(
            widget.foodItem.name,
          );

          // Check if ALL required items are selected (including both drinks)
          List<String> requiredSections = ['Pizza (12")', 'Shawarma', 'Burger'];

          bool allItemsSelected = requiredSections.every(
            (sectionName) => _dealSelections[sectionName] != null,
          );

          // Also check that both drinks are selected
          bool bothDrinksSelected =
              _dealSelections['Drink 1'] != null &&
              _dealSelections['Drink 2'] != null;

          if (!allItemsSelected || !bothDrinksSelected) {
            canConfirmSelection = false;
          } else {
            // All 4 items selected - auto-initialize Yes/No choices and validate
            for (String sectionName in requiredSections) {
              if (sectionName.contains('Pizza')) {
                // Combo Meal Pizza doesn't have sauce options - skip initialization
                print('🔍 COMBO MEAL PIZZA: No sauce initialization needed');
              } else if (sectionName.contains('Shawarma') ||
                  sectionName.contains('Burger')) {
                String saladKey = '$sectionName - Salad';
                String sauceKey = '$sectionName - Sauce';
                if (_dealSelections[saladKey] == null) {
                  _dealSelections[saladKey] = 'No';
                  print('🔍 AUTO-INITIALIZED: $saladKey = No');
                }
                if (_dealSelections[sauceKey] == null) {
                  _dealSelections[sauceKey] = 'No';
                  print('🔍 AUTO-INITIALIZED: $sauceKey = No');
                }
              }
            }
          }

          for (String sectionName in dealOptions.keys) {
            // Only validate sections that have items selected
            if (_dealSelections[sectionName] == null) {
              continue;
            }

            // Check for mandatory Yes/No choices based on section type
            if (sectionName.contains('Pizza')) {
              // Skip pizza sauce validation for Combo Meal - no sauce options
              print('🔍 COMBO MEAL PIZZA: No sauce validation needed');
            } else if (sectionName.contains('Shawarma') ||
                sectionName.contains('Burger')) {
              // Validate Salad Yes/No choice
              String saladKey = '$sectionName - Salad';
              print('🔍 SALAD CHECK: $saladKey = ${_dealSelections[saladKey]}');
              // For Combo Meal, auto-initialize to "No" if not set yet
              if (_dealSelections[saladKey] == null) {
                _dealSelections[saladKey] = 'No';
                print('🔍 AUTO-INITIALIZED: $saladKey = No');
              }

              // Salad validation no longer needed - just Yes/No choice

              // Validate Sauce Yes/No choice
              String sauceKey = '$sectionName - Sauce';
              print('🔍 SAUCE CHECK: $sauceKey = ${_dealSelections[sauceKey]}');

              // If Sauce Yes selected, check if sauce options are selected
              if (_dealSelections[sauceKey] == 'Yes') {
                String sauceOptionsKey = '$sectionName - Sauce Options';
                if (_dealMultiSelections[sauceOptionsKey] == null ||
                    _dealMultiSelections[sauceOptionsKey]!.isEmpty) {
                  print(
                    '🔍 VALIDATION FAILED: Sauce options not selected for $sectionName',
                  );
                  canConfirmSelection = false;
                  break;
                }
              }
            }
          }
        } else if (widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
          // Special validation for 3X12" Pizza Deal
          // Mandatory: Pizza selection and Crust selection for each of the 3 pizzas
          // Optional: Toppings and Sauce Dips (general)

          bool allPizzasValid = true;
          for (int i = 1; i <= 3; i++) {
            String pizzaKey = 'Pizza $i';

            // Check if pizza is selected (mandatory)
            String? selectedPizza = _dealSelections['$pizzaKey - Pizza'];
            if (selectedPizza == null) {
              print('🔍 VALIDATION FAILED: Pizza not selected for $pizzaKey');
              allPizzasValid = false;
              break;
            }

            // Check if crust is selected (mandatory) - should auto-default to Normal
            String? selectedCrust = _dealSelections['$pizzaKey - Crust'];
            if (selectedCrust == null) {
              print('🔍 VALIDATION FAILED: Crust not selected for $pizzaKey');
              allPizzasValid = false;
              break;
            }
          }

          if (!allPizzasValid) {
            canConfirmSelection = false;
          }

          print(
            '🔍 3X12" PIZZA DEAL VALIDATION COMPLETE: canConfirmSelection = $canConfirmSelection',
          );
        } else if (_isFamilyDeal()) {
          // Special validation for Family Deals - require Side Choice selection
          Map<String, List<String>> dealOptions = _getDealOptions(
            widget.foodItem.name,
          );

          // Check if all non-optional sections have selections (existing deal options)
          for (String sectionName in dealOptions.keys) {
            bool isOptional = sectionName.toLowerCase().contains('optional');
            if (!isOptional && _dealSelections[sectionName] == null) {
              canConfirmSelection = false;
              break;
            }
          }

          // Check if Side Choice is selected (mandatory for Family Deals)
          if (_dealSelections['Side Choice'] == null) {
            print(
              '🔍 FAMILY DEALS VALIDATION FAILED: Side Choice not selected',
            );
            canConfirmSelection = false;
          }

          print(
            '🔍 FAMILY DEALS VALIDATION COMPLETE: canConfirmSelection = $canConfirmSelection',
          );
        } else if (_isPizzaDealWithOptions()) {
          // Special validation for Pizza Deals - require pizza selection
          if (_dealSelections['Selected Pizza'] == null) {
            print('🔍 PIZZA DEAL VALIDATION FAILED: Pizza not selected');
            canConfirmSelection = false;
          }

          // For Mega Pizza Deal, ensure crust is selected (should default to Normal)
          if (widget.foodItem.name.toLowerCase() == 'mega pizza deal') {
            if (_dealSelections['Crust'] == null) {
              _dealSelections['Crust'] = 'Normal'; // Auto-set default
              print('🔍 MEGA PIZZA DEAL: Auto-set crust to Normal');
            }
          }

          print(
            '🔍 PIZZA DEAL VALIDATION COMPLETE: canConfirmSelection = $canConfirmSelection',
          );
        } else {
          // Original validation logic for other deals
          for (String sectionName in dealOptions.keys) {
            bool isOptional = sectionName.toLowerCase().contains('optional');

            if (!isOptional) {
              bool isMultiSelect = sectionName.toLowerCase().contains('sauce');

              if (isMultiSelect) {
                // For multi-select sections, check if something is selected
                if (_dealMultiSelections[sectionName] == null ||
                    _dealMultiSelections[sectionName]!.isEmpty) {
                  canConfirmSelection = false;
                  break;
                }
              } else {
                // For single-select sections, check if something is selected
                if (_dealSelections[sectionName] == null) {
                  canConfirmSelection = false;
                  break;
                }
              }
            }
          }
        }
      }
    }

    print(
      '🔍 FINAL VALIDATION RESULT: canConfirmSelection = $canConfirmSelection',
    );

    debugPrint("Item Category: ${widget.foodItem.category}");
    debugPrint(
      "Price keys length for rendering: ${widget.foodItem.price.keys.length}",
    );
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
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100, width: 1.0),
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
                    child:
                        _sizeHasBeenSelected &&
                                _selectedSize != null &&
                                !_isInSizeSelectionMode
                            ? Row(
                              children: [
                                // Size label with rectangular black background (now clickable)
                                InkWell(
                                  onTap: _changeSize,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 18,
                                    ),
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getDisplaySize(_selectedSize!),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize:
                                              _getDisplaySize(
                                                        _selectedSize!,
                                                      ).toLowerCase() ==
                                                      'default'
                                                  ? 12
                                                  : _getDisplaySize(
                                                        _selectedSize!,
                                                      ).length >
                                                      5
                                                  ? 18
                                                  : 22,
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
                        horizontal: 20,
                        vertical: 10,
                      ),
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
                                color:
                                    _isRemoveButtonPressed
                                        ? Colors.grey[100]
                                        : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[100]!,
                                  width: 4,
                                ),
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
                                color:
                                    _isAddButtonPressed
                                        ? Colors.grey[100]
                                        : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[100]!,
                                  width: 4,
                                ),
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
                    ] else ...[
                      if (!_sizeHasBeenSelected) ...[
                        _buildQuantityControlOnly(),
                      ],

                      if (_drinkFlavors.containsKey(widget.foodItem.name)) ...[
                        _buildFlavorSelectionSection(widget.foodItem.name),
                        // NEW: Add chip seasoning for drinks with flavors that might have chips
                        _buildRedSaltChoiceSection(),
                      ],

                      if (widget.foodItem.category == 'Pizza' ||
                          widget.foodItem.category == 'GarlicBread') ...[
                        _buildOptionCategoryButtons(),
                        _buildSelectedOptionDisplay(),
                      ],

                      // Shawarma use salad + sauce Yes/No system
                      if (widget.foodItem.category == 'Shawarma') ...[
                        _buildMealAndExclusionOptions(),
                        // Show sauce options when Yes is selected (in the middle section)
                        if (_sauceChoice == 'Yes') ...[
                          const SizedBox(height: 20),
                          _buildSauceSelectionForTraditionalCategories(),
                        ],
                      ],

                      // Burgers and Wraps use salad + sauce Yes/No system like Shawarma
                      if ([
                        'Burgers',
                        'Wraps',
                      ].contains(widget.foodItem.category)) ...[
                        _buildSaladAndSauceOptions(),
                        // Show sauce options when Yes is selected (in the middle section)
                        if (_sauceChoice == 'Yes') ...[
                          const SizedBox(height: 20),
                          _buildFreeSauceOptionsForBurgersAndWraps(),
                        ],
                        // Add drink selection for meal size (appears below sauces)
                        if (_isMealSizeSelected()) ...[
                          const SizedBox(height: 20),
                          _buildDrinkSelectionSection(),
                        ],
                        // Add red salt choice section
                        const SizedBox(height: 20),
                        _buildRedSaltChoiceSection(),
                      ],

                      // Chicken, Wings, Strips use Sauce Dips (no salad options)
                      if ([
                        'Wings',
                        'Chicken',
                        'Strips',
                      ].contains(widget.foodItem.category)) ...[
                        const SizedBox(height: 20),
                        _buildSauceOptionsForCategory(),
                        // Add drink selection for meal size
                        if (_isMealSizeSelected()) ...[
                          const SizedBox(height: 20),
                          _buildDrinkSelectionSection(),
                        ],
                        // Add red salt choice section
                        _buildRedSaltChoiceSection(),
                      ],

                      // Kebabs use FREE Sauces (like Burgers) AND Paid Sauce Dips
                      if (widget.foodItem.category == 'Kebabs') ...[
                        const SizedBox(height: 20),
                        _buildFreeSauceOptionsForBurgersAndWraps(), // Free sauces
                        const SizedBox(height: 20),
                        _buildPaidSauceDipsForKebabs(), // Paid sauce dips
                        if (_isMealSizeSelected()) ...[
                          const SizedBox(height: 20),
                          _buildDrinkSelectionSection(),
                        ],
                        _buildRedSaltChoiceSection(),
                      ],

                      if (widget.foodItem.category == 'KidsMeal') ...[
                        _buildKidsMealOptions(),
                      ],

                      if (widget.foodItem.category == 'Milkshake') ...[
                        _buildQuantityControlOnly(),
                      ],

                      if (widget.foodItem.category == 'Sides') ...[
                        _buildSidesOptions(),
                      ],

                      if (widget.foodItem.category == 'Deals') ...[
                        _buildDealCategoryButtons(),
                        _buildDealSelectionOptions(),
                        // Add drink selection for deals containing drink options
                        if (_hasDrink()) ...[
                          const SizedBox(height: 20),
                          _buildDrinkSelectionSection(),
                        ],
                        // Add sauce dips for deals (except Pizza Deals subtype which already has them)
                        if (widget.foodItem.subType?.toLowerCase() !=
                            'pizza deals') ...[
                          const SizedBox(height: 20),
                          _buildSauceOptionsForCategory(),
                        ],
                        // NEW: Add chip seasoning for deals
                        _buildRedSaltChoiceSection(),
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
                                  color: Colors.grey[100]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[100]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
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
                    'Total: £${(_calculatedPricePerUnit * _quantity).toStringAsFixed(2)}',
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
                            horizontal: 20,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton(
                        onPressed:
                            canConfirmSelection
                                ? _confirmSelection
                                : null, // Changed to _confirmSelection
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canConfirmSelection ? Colors.black : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          // Dynamic text based on mode
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
          InkWell(
            onTap: () {
              // Close size selection if a size has been selected
              if (_selectedSize != null) {
                setState(() {
                  _isInSizeSelectionMode = false;
                });
              }
            },
            child: Container(
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
          ),
          const SizedBox(width: 10),

          Wrap(
            spacing: 15,
            runSpacing: 15,
            alignment: WrapAlignment.center,
            children:
                widget.foodItem.price.keys.map((sizeKeyFromData) {
                  final bool isActive = _selectedSize == sizeKeyFromData;
                  final String displayedText = _getDisplaySize(sizeKeyFromData);

                  return SizedBox(
                    width: 110,
                    height: 110,
                    child: ElevatedButton(
                      onPressed: () => _onSizeSelected(sizeKeyFromData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isActive ? Colors.grey[100] : Colors.black,
                        foregroundColor: isActive ? Colors.black : Colors.white,
                        shape: const CircleBorder(
                          side: BorderSide(color: Colors.white, width: 4),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: isActive ? 6 : 3,
                      ),
                      child: Text(
                        displayedText,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              displayedText.toLowerCase() == 'default'
                                  ? 16
                                  : displayedText.length > 5
                                  ? 20
                                  : 26,
                          fontWeight: FontWeight.bold,
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

  Widget _buildDealCategoryButtons() {
    Map<String, List<String>> dealOptions = _getDealOptions(
      widget.foodItem.name,
    );
    final List<String> categories = _getDealCategories(dealOptions);

    if (categories.length <= 1) {
      // No tabs needed if only one category
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(categories.length, (index) {
            final category = categories[index];
            final bool isSelected = _selectedDealCategory == category;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 4.0,
                  right: index == categories.length - 1 ? 0 : 4.0,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDealCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[100] : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize:
                              category.length > 15
                                  ? 14
                                  : category.length > 10
                                  ? 16
                                  : 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOptionCategoryButtons() {
    // Filter categories based on selected size
    List<String> categories = ['Toppings'];

    // Only show Crust for 12 inch pizzas
    if (_selectedSize == "12 inch") {
      categories.add('Crust');
    }

    categories.add('Sauce Dips');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              List.generate(categories.length, (index) {
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
      final isDefaultA =
          (widget.foodItem.defaultToppings ?? []).contains(a) ||
          (widget.foodItem.defaultCheese ?? []).contains(a);
      final isDefaultB =
          (widget.foodItem.defaultToppings ?? []).contains(b) ||
          (widget.foodItem.defaultCheese ?? []).contains(b);
      if (isDefaultA && !isDefaultB) return -1;
      if (!isDefaultA && isDefaultB) return 1;
      return a.compareTo(b);
    });

    switch (_selectedOptionCategory) {
      case 'Toppings':
        return _buildToppingsDisplay(reorderedToppings);
      case 'Crust':
        return _buildCrustDisplay();
      case 'Sauce Dips':
        return _buildSauceDisplay();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Original `_buildToppingsDisplay` method (unchanged) ---
  Widget _buildToppingsDisplay(List<String> allToppings) {
    // 1. Get the list of default toppings and cheeses
    final defaultToppingsAndCheese =
        [
          ...(widget.foodItem.defaultToppings ?? []),
          ...(widget.foodItem.defaultCheese ?? []),
        ].toSet().toList();

    // 2. Get the list of all other toppings
    final allOtherToppings =
        allToppings
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

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.spaceBetween,
          children:
              sortedToppings.map((topping) {
                final bool isActive = _selectedToppings.contains(topping);
                final bool isDefault = defaultToppingsAndCheese.contains(
                  topping,
                );

                return SizedBox(
                  width: idealItemWidth,
                  child: InkWell(
                    onTap: () {
                      // --- DEFAULT TOPPINGS WILL NOT BE UNSELECTED ---
                      if (isDefault) {
                        return; // Do nothing if it's a default topping
                      }
                      setState(() {
                        // Special handling for Full Salad option
                        if (topping == 'Full Salad') {
                          if (_selectedToppings.contains(topping)) {
                            // If Full Salad is currently selected and clicked again, deselect it
                            _selectedToppings.remove(topping);
                          } else {
                            // If Full Salad is clicked, remove all other salad options and select only Full Salad
                            List<String> saladOptions = [
                              'Cucumber',
                              'Lettuce',
                              'Onions',
                              'Tomato',
                              'Red Cabbage',
                            ];
                            for (String salad in saladOptions) {
                              _selectedToppings.remove(salad);
                            }
                            _selectedToppings.add(topping);
                          }
                        } else if ([
                          'Cucumber',
                          'Lettuce',
                          'Onions',
                          'Tomato',
                          'Red Cabbage',
                        ].contains(topping)) {
                          // If any other salad option is clicked, remove Full Salad if it's selected
                          _selectedToppings.remove('Full Salad');

                          // Then handle normal toggle logic for the clicked salad option
                          if (_selectedToppings.contains(topping)) {
                            _selectedToppings.remove(topping);
                          } else {
                            _selectedToppings.add(topping);
                          }
                        } else {
                          // Normal toggle logic for non-salad toppings
                          if (_selectedToppings.contains(topping)) {
                            _selectedToppings.remove(topping);
                          } else {
                            _selectedToppings.add(topping);
                          }
                        }
                        _updatePriceDisplay();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 18,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.grey[100] : Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        topping,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? Colors.black : Colors.white,
                          fontSize: 18,
                          fontWeight:
                              isDefault ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildCrustDisplay() {
    // Only show crust options for 12 inch pizzas
    if (_selectedSize != "12 inch") {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              _allCrusts.map((crust) {
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
                      horizontal: 20,
                      vertical: 18,
                    ),
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
          children:
              _allSauces.map((sauce) {
                final bool isActive = _selectedSauces.contains(sauce);
                return SizedBox(
                  width:
                      (availableWidthForWrap -
                          (itemSpacing * (desiredColumns - 1))) /
                      desiredColumns,
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
                        horizontal: 20,
                        vertical: 18,
                      ),
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

  // Deal-specific selection options with tab system
  Widget _buildDealSelectionOptions() {
    // Get deal-specific options based on the deal name
    Map<String, List<String>> dealOptions = _getDealOptions(
      widget.foodItem.name,
    );

    print('🔍 UI: Building deal options for "${widget.foodItem.name}"');
    print('🔍 UI: Available deal options: ${dealOptions.keys.toList()}');
    print('🔍 UI: Selected deal category: "$_selectedDealCategory"');

    // IMPORTANT: Check for Family Deals BEFORE checking if dealOptions is empty
    // since Family Deals have empty dealOptions but need special handling
    if (_isFamilyDeal()) {
      print(
        '🔍 UI: Building Family Deals tab content for category: $_selectedDealCategory',
      );
      print('🔍 UI: Deal options available: ${dealOptions.keys.toList()}');
      return _buildFamilyDealsTabContent(_selectedDealCategory, dealOptions);
    }

    // Check for Combo Meals with Sauce Options (Deal 2, Deal 3)
    if (_isComboMealWithSauceOptions()) {
      print(
        '🔍 UI: Building Combo Meal with Sauce Options for: ${widget.foodItem.name}',
      );
      return _buildComboMealWithSauceOptionsContent();
    }

    // Check for Pizza Deals that need pizza options (Pizza Deal 4 One, Mega Pizza Deal)
    if (_isPizzaDealWithOptions()) {
      print(
        '🔍 UI: Building Pizza Deal with options for: ${widget.foodItem.name}',
      );
      return _buildPizzaDealWithOptionsContent();
    }

    if (dealOptions.isEmpty) {
      // Just show the description for simple deals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deal Includes:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.foodItem.description ?? 'Complete meal deal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    // Special handling for different deal types with multiple sections within each tab
    if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
      if (_selectedDealCategory.startsWith('Shawarma ')) {
        return _buildShawarmaTabContent(_selectedDealCategory, dealOptions);
      } else if (_selectedDealCategory == 'Drink & seasoning') {
        return _buildDrinkAndSeasoningTabContent(
          _selectedDealCategory,
          dealOptions,
        );
      } else {
        // For any other tab in shawarma deal, default to Shawarma 1
        return _buildShawarmaTabContent('Shawarma 1', dealOptions);
      }
    }

    // Special handling for 3X12" Pizza Deal
    if (widget.foodItem.name.toLowerCase() == '3x12" pizza deal') {
      return _buildPizzaDealTabContent(_selectedDealCategory);
    }

    // Special handling for Family Meal and Combo Meal
    if (widget.foodItem.name.toLowerCase() == 'family meal' ||
        widget.foodItem.name.toLowerCase() == 'combo meal') {
      return _buildFamilyComboMealTabContent(
        _selectedDealCategory,
        dealOptions,
      );
    }

    // Original logic for both editing and non-editing mode (show only selected category)
    List<String> currentOptions = dealOptions[_selectedDealCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show options in toppings-style grid layout
        if (currentOptions.isNotEmpty)
          _buildToppingsStyleGrid(currentOptions, _selectedDealCategory)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No options available',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
      ],
    );
  }

  // Special content builder for 3X12" Pizza Deal tabs
  Widget _buildPizzaDealTabContent(String tabName) {
    // Pizza tab names should be "Pizza 1", "Pizza 2", "Pizza 3"
    String pizzaKey = tabName;

    // Handle pizza selection first, then options: Crust, Toppings, Sauce Dips
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pizza Selection
          const Text(
            'Select Pizza:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildPizzaSelectionOptions(pizzaKey),

          const SizedBox(height: 20),

          // Pizza Crust Selection
          const Text(
            'Crust:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildPizzaCrustOptions(pizzaKey),

          const SizedBox(height: 20),

          // Pizza Toppings Selection
          const Text(
            'Toppings:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildPizzaToppingsOptions(pizzaKey),

          const SizedBox(height: 20),

          // Sauce Dips Selection
          const Text(
            'Sauce Dips:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildPizzaSauceOptions(pizzaKey),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Pizza Selection Options Builder
  Widget _buildPizzaSelectionOptions(String pizzaKey) {
    return Consumer<ItemAvailabilityProvider>(
      builder: (context, itemProvider, child) {
        final List<FoodItem> allFoodItems = itemProvider.allItems;

        // Filter for pizza items just like Page4 does
        final List<FoodItem> pizzaItems =
            allFoodItems
                .where((item) => item.category.toLowerCase() == 'pizza')
                .toList();

        if (pizzaItems.isEmpty) {
          return const Text(
            'No pizzas available',
            style: TextStyle(color: Colors.white),
          );
        }

        String pizzaSelectionKey = '$pizzaKey - Pizza';
        String? selectedPizza = _dealSelections[pizzaSelectionKey];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              pizzaItems.map((pizzaItem) {
                bool isSelected = selectedPizza == pizzaItem.name;
                return _buildOptionButton(
                  title: pizzaItem.name,
                  isActive: isSelected,
                  onTap: () {
                    setState(() {
                      _dealSelections[pizzaSelectionKey] = pizzaItem.name;
                    });
                  },
                );
              }).toList(),
        );
      },
    );
  }

  // Pizza Crust Options Builder
  Widget _buildPizzaCrustOptions(String pizzaKey) {
    String crustKey = '$pizzaKey - Crust';
    String? selectedCrust = _dealSelections[crustKey];

    // Set default crust to "Normal" if none selected
    if (selectedCrust == null && _allCrusts.contains("Normal")) {
      selectedCrust = "Normal";
      _dealSelections[crustKey] = "Normal";
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allCrusts.map((crust) {
            bool isSelected = selectedCrust == crust;
            return _buildOptionButton(
              title: crust,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealSelections[crustKey] = crust;
                  // Update price when crust changes for 3X12" Pizza Deal
                  if (widget.foodItem.name.toLowerCase() ==
                      '3x12" pizza deal') {
                    _calculatedPricePerUnit = _calculatePricePerUnit();
                  }
                });
              },
            );
          }).toList(),
    );
  }

  // Pizza Toppings Options Builder (Multi-select)
  Widget _buildPizzaToppingsOptions(String pizzaKey) {
    String toppingsKey = '$pizzaKey - Toppings';
    Set<String> selectedToppings = _dealMultiSelections[toppingsKey] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allToppings.map((topping) {
            bool isSelected = selectedToppings.contains(topping);
            return _buildOptionButton(
              title: topping,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealMultiSelections[toppingsKey] ??= {};
                  if (isSelected) {
                    _dealMultiSelections[toppingsKey]!.remove(topping);
                  } else {
                    _dealMultiSelections[toppingsKey]!.add(topping);
                  }
                  // Update price when toppings change for 3X12" Pizza Deal
                  if (widget.foodItem.name.toLowerCase() ==
                      '3x12" pizza deal') {
                    _calculatedPricePerUnit = _calculatePricePerUnit();
                  }
                });
              },
            );
          }).toList(),
    );
  }

  // Pizza Sauce Dips Options Builder (Multi-select) - General for entire deal
  Widget _buildPizzaSauceOptions(String pizzaKey) {
    String sauceKey = 'Sauce Dips'; // General for entire deal, not tab-specific
    Set<String> selectedSauces = _dealMultiSelections[sauceKey] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allSauces.map((sauce) {
            bool isSelected = selectedSauces.contains(sauce);
            return _buildOptionButton(
              title: sauce,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealMultiSelections[sauceKey] ??= {};
                  if (isSelected) {
                    _dealMultiSelections[sauceKey]!.remove(sauce);
                  } else {
                    _dealMultiSelections[sauceKey]!.add(sauce);
                  }
                });
              },
            );
          }).toList(),
    );
  }

  // Special content builder for Shawarma tabs with multiple sections
  Widget _buildShawarmaTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    List<String> shawarmaOptions = dealOptions[tabName] ?? [];

    // Auto-select the default shawarma flavour immediately if not already selected
    if (shawarmaOptions.isNotEmpty && _dealSelections[tabName] == null) {
      _dealSelections[tabName] =
          shawarmaOptions
              .first; // Auto-select Chicken Shawarma (Pitta) immediately
      print('🔍 AUTO-SELECTED: $tabName = ${shawarmaOptions.first}');
    }

    // Auto-select "No" for both Salad and Sauce if not already selected
    String saladKey = '$tabName - Salad';
    String sauceKey = '$tabName - Sauce';
    if (_dealSelections[saladKey] == null) {
      _dealSelections[saladKey] = 'No';
      print('🔍 AUTO-SELECTED: $saladKey = No');
    }
    if (_dealSelections[sauceKey] == null) {
      _dealSelections[sauceKey] = 'No';
      print('🔍 AUTO-SELECTED: $sauceKey = No');
    }

    // Salad is now just Yes/No - no specific options needed
    List<String> sauceOptions = [
      'Mayo',
      'Ketchup',
      'Chilli Sauce',
      'Sweet Chilli',
      'Garlic Sauce',
      'BBQ',
      'Mint Sauce',
    ];

    // Get current selections for Salad and Sauce Yes/No
    bool hasSalad = _dealSelections['$tabName - Salad'] == 'Yes';
    bool hasSauce = _dealSelections['$tabName - Sauce'] == 'Yes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Shawarma selection section (auto-selected, no text label)
        if (shawarmaOptions.isNotEmpty) ...[
          _buildToppingsStyleGrid(shawarmaOptions, tabName),
          const SizedBox(height: 25),
        ],

        // Salad section
        const Text(
          'Salad:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),

        // Salad Yes/No buttons
        Row(
          children: [
            Expanded(
              child: _buildYesNoButton('$tabName - Salad', 'Yes', hasSalad),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildYesNoButton('$tabName - Salad', 'No', !hasSalad),
            ),
          ],
        ),

        // No specific salad options needed - just Yes/No choice
        // Salad options grid removed since we only need Yes/No
        const SizedBox(height: 25),

        // Sauce section
        const Text(
          'Sauce:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),

        // Sauce Yes/No buttons
        Row(
          children: [
            Expanded(
              child: _buildYesNoButton('$tabName - Sauce', 'Yes', hasSauce),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildYesNoButton('$tabName - Sauce', 'No', !hasSauce),
            ),
          ],
        ),

        // Show sauce options if Yes is selected
        if (hasSauce) ...[
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(sauceOptions, '$tabName - Sauce Options'),
        ],
      ],
    );
  }

  // Yes/No button builder for Shawarma Deal sections
  Widget _buildYesNoButton(
    String sectionKey,
    String buttonText,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _dealSelections[sectionKey] = buttonText;
          print('🔍 YES/NO SELECTION: $sectionKey = $buttonText');

          // Clear options if "No" is selected
          if (buttonText == 'No') {
            String optionsKey = '$sectionKey Options';
            _dealMultiSelections[optionsKey]?.clear();
            print('🔍 CLEARED OPTIONS FOR: $optionsKey');
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[100] : Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          buttonText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Special content builder for Drink & seasoning tab with multiple sections
  Widget _buildDrinkAndSeasoningTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    List<String> drinkOptions = dealOptions[tabName] ?? [];

    // Define the red salt choice options
    List<String> redSaltChoices = ['Yes', 'No'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drink selection section
        if (drinkOptions.isNotEmpty) ...[
          const Text(
            'Select Drink:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(drinkOptions, tabName),
          const SizedBox(height: 25),
        ],

        // Red salt choice 1 section
        const Text(
          'Red salt choice 1:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildToppingsStyleGrid(redSaltChoices, '$tabName - Red Salt Choice 1'),
        const SizedBox(height: 25),

        // Red salt choice 2 section
        const Text(
          'Red salt choice 2:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildToppingsStyleGrid(redSaltChoices, '$tabName - Red Salt Choice 2'),
      ],
    );
  }

  // Special content builder for Family Meal and Combo Meal tabs with multiple sections
  Widget _buildFamilyComboMealTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    List<String> mainOptions = dealOptions[tabName] ?? [];

    // Ensure tabName matches validation keys exactly
    String validationKey = tabName;
    if (tabName.contains('Pizza')) {
      // Use correct pizza size based on deal type
      if (widget.foodItem.name.toLowerCase() == 'family meal') {
        validationKey = 'Pizza (16")';
      } else if (widget.foodItem.name.toLowerCase() == 'combo meal') {
        validationKey = 'Pizza (12")';
      } else {
        validationKey = tabName; // Use original tabName for other deals
      }
    } else if (tabName.contains('Shawarma'))
      validationKey = 'Shawarma';
    else if (tabName.contains('Burger'))
      validationKey = 'Burger';
    else if (tabName.contains('Calzone'))
      validationKey = 'Calzone';
    else if (tabName.contains('Drink'))
      validationKey = 'Drinks';

    // Define sauce options (removed 'No Extra Sauce' - using Yes/No buttons instead)
    List<String> sauceOptions = [
      'Mayo',
      'Ketchup',
      'Chilli Sauce',
      'Sweet Chilli',
      'Garlic Sauce',
      'BBQ',
      'Mint Sauce',
    ];

    // Salad is now just Yes/No - no specific options needed

    // Build content based on tab type
    if (tabName.contains('Pizza')) {
      // Both Family Meal and Combo Meal Pizza - no sauce options
      if (widget.foodItem.name.toLowerCase() == 'family meal' ||
          widget.foodItem.name.toLowerCase() == 'combo meal') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pizza selection only
            const Text(
              'Select Pizza:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(mainOptions, validationKey),
          ],
        );
      } else {
        // Other deals - keep sauce functionality
        bool hasSauce =
            _dealSelections['$validationKey - Pizza Sauce'] == 'Yes';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pizza selection
            const Text(
              'Select Pizza:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(mainOptions, validationKey),
            const SizedBox(height: 25),

            // Pizza Sauce section
            const Text(
              'Pizza Sauce:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            // Sauce Yes/No buttons
            Row(
              children: [
                Expanded(
                  child: _buildYesNoButton(
                    '$validationKey - Pizza Sauce',
                    'Yes',
                    hasSauce,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildYesNoButton(
                    '$validationKey - Pizza Sauce',
                    'No',
                    !hasSauce,
                  ),
                ),
              ],
            ),

            // Show sauce options if Yes is selected
            if (hasSauce) ...[
              const SizedBox(height: 15),
              _buildToppingsStyleGrid(
                sauceOptions,
                '$validationKey - Pizza Sauce Options',
              ),
            ],
          ],
        );
      }
    } else if (tabName.contains('Shawarma')) {
      // Get current salad and sauce selections
      bool hasSalad = _dealSelections['$validationKey - Salad'] == 'Yes';
      bool hasSauce = _dealSelections['$validationKey - Sauce'] == 'Yes';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shawarma selection
          const Text(
            'Select Shawarma:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(mainOptions, validationKey),
          const SizedBox(height: 25),

          // Salad section
          const Text(
            'Salad:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Salad Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Salad',
                  'Yes',
                  hasSalad,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Salad',
                  'No',
                  !hasSalad,
                ),
              ),
            ],
          ),

          // No specific salad options needed - just Yes/No choice
          const SizedBox(height: 25),

          // Sauce section
          const Text(
            'Sauce:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Sauce Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Sauce',
                  'Yes',
                  hasSauce,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Sauce',
                  'No',
                  !hasSauce,
                ),
              ),
            ],
          ),

          // Show sauce options if Yes is selected
          if (hasSauce) ...[
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(
              sauceOptions,
              '$validationKey - Sauce Options',
            ),
          ],
        ],
      );
    } else if (tabName.contains('Burger')) {
      // Get current salad and sauce selections
      bool hasSalad = _dealSelections['$validationKey - Salad'] == 'Yes';
      bool hasSauce = _dealSelections['$validationKey - Sauce'] == 'Yes';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Burger selection
          const Text(
            'Select Burger:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(mainOptions, validationKey),
          const SizedBox(height: 25),

          // Salad section
          const Text(
            'Salad:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Salad Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Salad',
                  'Yes',
                  hasSalad,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Salad',
                  'No',
                  !hasSalad,
                ),
              ),
            ],
          ),

          // No specific salad options needed - just Yes/No choice
          const SizedBox(height: 25),

          // Sauce section
          const Text(
            'Sauce:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Sauce Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Sauce',
                  'Yes',
                  hasSauce,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildYesNoButton(
                  '$validationKey - Sauce',
                  'No',
                  !hasSauce,
                ),
              ),
            ],
          ),

          // Show sauce options if Yes is selected
          if (hasSauce) ...[
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(
              sauceOptions,
              '$validationKey - Sauce Options',
            ),
          ],
        ],
      );
    } else if (tabName.contains('Calzone')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calzone selection
          const Text(
            'Select Calzone:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(mainOptions, validationKey),
        ],
      );
    } else if (tabName.contains('Drinks')) {
      // Special handling for combo meal drinks
      if (widget.foodItem.name.toLowerCase() == 'combo meal') {
        final drinkOptions = [
          'Coca Cola',
          'Pepsi',
          '7Up',
          'Fanta',
          'Sprite',
          'Diet Coca Cola',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drink 1 section
            const Text(
              'Drink 1:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(drinkOptions, 'Drink 1'),
            const SizedBox(height: 25),

            // Drink 2 section
            const Text(
              'Drink 2:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(drinkOptions, 'Drink 2'),
          ],
        );
      } else {
        // Default drink selection for other deals
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drink selection
            const Text(
              'Select Drink:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(mainOptions, validationKey),
          ],
        );
      }
    }

    // Default fallback
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$tabName:',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildToppingsStyleGrid(mainOptions, validationKey),
      ],
    );
  }

  // Special content builder for Pizza Deals with pizza options
  Widget _buildPizzaDealWithOptionsContent() {
    String dealName = widget.foodItem.name.toLowerCase();
    bool hasCrustOption = dealName == 'mega pizza deal';

    return Consumer<ItemAvailabilityProvider>(
      builder: (context, itemProvider, child) {
        final List<FoodItem> allFoodItems = itemProvider.allItems;
        final List<FoodItem> pizzaItems =
            allFoodItems
                .where((item) => item.category.toLowerCase() == 'pizza')
                .toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show deal description
              if (widget.foodItem.description != null &&
                  widget.foodItem.description!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.foodItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.foodItem.description!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],

              // Pizza Selection
              const Text(
                'Select Pizza:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildPizzaSelectionGrid(pizzaItems),
              const SizedBox(height: 25),

              // Crust Selection (only for Mega Pizza Deal)
              if (hasCrustOption) ...[
                const Text(
                  'Crust:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                _buildCrustSelectionGrid(),
                const SizedBox(height: 25),
              ],

              // Toppings Selection
              const Text(
                'Extra Toppings (Optional):',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildToppingsSelectionGrid(),
              const SizedBox(height: 25),

              // Sauce Dips Selection
              const Text(
                'Sauce Dips (Optional):',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildSauceSelectionGrid(),
            ],
          ),
        );
      },
    );
  }

  // Special content builder for Family Deals with Side Choice
  Widget _buildFamilyDealsTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    print('🔍 UI: _buildFamilyDealsTabContent called');
    print('🔍 UI: tabName = "$tabName"');
    print('🔍 UI: dealOptions = $dealOptions');

    // For Family Deals, we just show the Side Choice section
    // since they typically don't have complex tab structures like 3X12" Pizza Deal
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show deal description
        if (widget.foodItem.description != null &&
            widget.foodItem.description!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.foodItem.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.foodItem.description!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
        ],

        // Side Choice section (mandatory for Family Deals)
        const Text(
          'Side Choice:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildSideChoiceOptions(),
      ],
    );
  }

  // Special content builder for Combo Meals with Sauce Options (Deal 2, Deal 3)
  Widget _buildComboMealWithSauceOptionsContent() {
    print('🔍 UI: _buildComboMealWithSauceOptionsContent called');
    print('🔍 UI: Item name: "${widget.foodItem.name}"');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item description
        if (widget.foodItem.description != null &&
            widget.foodItem.description!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.foodItem.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.foodItem.description!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
        ],

        // Sauce Options section for Combo Meals Deal 2 and Deal 3 (free)
        const Text(
          'Sauce Options:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildFamilyDealSauceOptions(), // Reuse the existing sauce options method
      ],
    );
  }

  // Build Side Choice options (Coleslaw or Beans)
  Widget _buildSideChoiceOptions() {
    List<String> sideOptions = ['Coleslaw', 'Beans'];
    String? selectedSide = _dealSelections['Side Choice'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          sideOptions.map((side) {
            bool isSelected = selectedSide == side;
            return _buildOptionButton(
              title: side,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealSelections['Side Choice'] = side;
                });
              },
            );
          }).toList(),
    );
  }

  // Build toppings-style grid for deal options
  Widget _buildToppingsStyleGrid(List<String> options, String dealKey) {
    print('🔍 UI: Building grid for "$dealKey" with options: $options');
    print(
      '🔍 UI: Current single selection for "$dealKey": ${_dealSelections[dealKey]}',
    );
    print(
      '🔍 UI: Current multi-selection for "$dealKey": ${_dealMultiSelections[dealKey]}',
    );
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    final double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              options.map((option) {
                // Check if this is a multi-select option (like sauces and salad options)
                final bool isMultiSelect =
                    dealKey.toLowerCase().contains('sauce') ||
                    dealKey.toLowerCase().contains('salad options');

                final bool isSelected;
                if (isMultiSelect) {
                  // For multi-select options, check _dealMultiSelections
                  isSelected =
                      _dealMultiSelections[dealKey]?.contains(option) ?? false;
                } else {
                  // For single-select options, check _dealSelections
                  isSelected = _dealSelections[dealKey] == option;
                }
                print(
                  '🔍 UI OPTION: "$option" for "$dealKey" - isSelected: $isSelected',
                );

                return SizedBox(
                  width: idealItemWidth,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isMultiSelect) {
                          // Handle multi-select options (sauces and salad options)
                          if (!_dealMultiSelections.containsKey(dealKey)) {
                            _dealMultiSelections[dealKey] = <String>{};
                          }

                          // Special handling for Full Salad option
                          bool isSaladOptionsKey = dealKey
                              .toLowerCase()
                              .contains('salad options');
                          bool isFullSaladOption = option == 'Full Salad';

                          if (isSaladOptionsKey && isFullSaladOption) {
                            if (isSelected) {
                              // If Full Salad is currently selected and clicked again, deselect it
                              _dealMultiSelections[dealKey]!.remove(option);
                            } else {
                              // If Full Salad is clicked, clear all other salad options and select only Full Salad
                              _dealMultiSelections[dealKey]!.clear();
                              _dealMultiSelections[dealKey]!.add(option);
                            }
                          } else if (isSaladOptionsKey && !isFullSaladOption) {
                            // If any other salad option is clicked, remove Full Salad if it's selected
                            if (_dealMultiSelections[dealKey]!.contains(
                              'Full Salad',
                            )) {
                              _dealMultiSelections[dealKey]!.remove(
                                'Full Salad',
                              );
                            }

                            // Then handle the normal multi-select logic for the clicked option
                            if (isSelected) {
                              _dealMultiSelections[dealKey]!.remove(option);
                            } else {
                              _dealMultiSelections[dealKey]!.add(option);
                            }
                          } else {
                            // Normal multi-select logic for non-salad options (like sauces)
                            if (isSelected) {
                              _dealMultiSelections[dealKey]!.remove(option);
                            } else {
                              _dealMultiSelections[dealKey]!.add(option);
                            }
                          }
                        } else {
                          // Handle single-select options
                          _dealSelections[dealKey] = isSelected ? null : option;
                        }
                        _updatePriceDisplay();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 18,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.grey[100] : Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        option,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize:
                              option.length > 20
                                  ? 12
                                  : option.length > 15
                                  ? 14
                                  : 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
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

  List<String> _getDealCategories(Map<String, List<String>> dealOptions) {
    // Return the actual deal keys as tabs (Pizza 1, Pizza (16"), Shawarma, etc.)
    return dealOptions.keys.toList();
  }

  Map<String, List<String>> _getDealOptions(String dealName) {
    // Special case for 3X12" Pizza Deal - provide three pizza tabs
    if (dealName.toLowerCase() == '3x12" pizza deal') {
      return {'Pizza 1': [], 'Pizza 2': [], 'Pizza 3': []};
    }

    // Deals now come from backend, return empty map for other deals
    return {};
  }

  Widget _buildSauceOptionsForCategory() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 5;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sauce Dips:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              _allSauces.map((sauce) {
                final bool isSelected = _selectedSauces.contains(sauce);
                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: sauce,
                    isActive: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSauces.remove(sauce);
                        } else {
                          _selectedSauces.add(sauce);
                          // Clear "No Sauce" flag when selecting actual sauces
                          _noSauce = false;
                        }
                        _updatePriceDisplay();
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Build Sauce Options for Deal 2 and Deal 3 in Family Deals (different from Sauce Dips)
  Widget _buildFamilyDealSauceOptions() {
    // Use a different key for sauce options vs sauce dips
    Set<String> selectedSauceOptions =
        _dealMultiSelections['Sauce Options'] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allSauces.map((sauce) {
            bool isSelected = selectedSauceOptions.contains(sauce);
            return _buildOptionButton(
              title: sauce,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealMultiSelections['Sauce Options'] ??= {};
                  if (isSelected) {
                    _dealMultiSelections['Sauce Options']!.remove(sauce);
                  } else {
                    _dealMultiSelections['Sauce Options']!.add(sauce);
                  }
                  _updatePriceDisplay();
                });
              },
            );
          }).toList(),
    );
  }

  // Free sauce selection for Burgers and Wraps (no price increment)
  Widget _buildFreeSauceOptionsForBurgersAndWraps() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 3;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    // Free sauce options for Burgers and Wraps (no price increment)
    List<String> sauceOptions = [
      'Mayo',
      'Ketchup',
      'Chilli Sauce',
      'Sweet Chilli',
      'Garlic Sauce',
      'BBQ Sauce',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sauces:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              sauceOptions.map((sauce) {
                final bool isSelected = _selectedSauces.contains(sauce);

                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: sauce,
                    isActive: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSauces.remove(sauce);
                        } else {
                          _selectedSauces.add(sauce);
                        }
                        // No price update since sauces are free
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Paid sauce dips for Kebabs (with pricing)
  Widget _buildPaidSauceDipsForKebabs() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 3;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    // Paid sauce dips for Kebabs (£0.50 or £0.75 per sauce)
    List<String> sauceDipOptions = [
      'Mayo',
      'Ketchup',
      'Chilli sauce',
      'Sweet Chilli',
      'Garlic Sauce',
      'BBQ Sauce',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sauce Dips:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              sauceDipOptions.map((sauce) {
                final bool isSelected = _selectedSauceDips.contains(sauce);

                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: sauce,
                    isActive: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSauceDips.remove(sauce);
                        } else {
                          _selectedSauceDips.add(sauce);
                        }
                        // Update price since sauce dips are paid
                        _calculatedPricePerUnit = _calculatePricePerUnit();
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Traditional sauce selection for Burgers, Wraps, Shawarma (free sauces, no pricing)
  Widget _buildSauceSelectionForTraditionalCategories() {
    final double modalWidth = min(
      MediaQuery.of(context).size.width * 0.95,
      1000.0,
    );
    const double horizontalPaddingOfParent = 30.0;
    final double availableWidthForWrap = modalWidth - horizontalPaddingOfParent;

    const double itemSpacing = 12.0;
    const int desiredColumns = 3;

    final double idealItemWidth =
        (availableWidthForWrap - (itemSpacing * (desiredColumns - 1))) /
        desiredColumns;

    // Traditional sauce options for free sauce categories
    List<String> sauceOptions = [
      'Mayo',
      'Ketchup',
      'Chilli Sauce',
      'Sweet Chilli',
      'Garlic Sauce',
      'BBQ Sauce',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sauce Options:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: itemSpacing,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              sauceOptions.map((sauce) {
                final bool isSelected = _selectedSauces.contains(sauce);

                return SizedBox(
                  width: idealItemWidth,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSauces.remove(sauce);
                        } else {
                          _selectedSauces.add(sauce);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFCB6CE6) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFFCB6CE6)
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        sauce,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Helper method to detect if an item is a Family Deal
  // based on subType "Family Deals" OR description containing "coleslaw" or "beans"
  bool _isFamilyDeal() {
    print('🔍 FAMILY DEAL CHECK: Item "${widget.foodItem.name}"');
    print('🔍 Category: "${widget.foodItem.category}"');
    print('🔍 SubType: "${widget.foodItem.subType}"');
    print('🔍 Description: "${widget.foodItem.description}"');

    if (widget.foodItem.category.toLowerCase() != 'deals') {
      print('🔍 NOT A DEAL - returning false');
      return false;
    }

    // Check if subType is "Family Deals" (case-insensitive)
    String? subType = widget.foodItem.subType?.toLowerCase().trim();
    print('🔍 SubType normalized: "$subType"');
    if (subType == 'family deals') {
      print('🔍 MATCHED SUBTYPE "family deals" - returning true');
      return true;
    }

    // Also check if name or description contains coleslaw/beans
    String name = widget.foodItem.name.toLowerCase();
    String description = (widget.foodItem.description ?? '').toLowerCase();

    bool hasColeslaw =
        name.contains('coleslaw') || description.contains('coleslaw');
    bool hasBeans = name.contains('beans') || description.contains('beans');

    print('🔍 Has coleslaw: $hasColeslaw');
    print('🔍 Has beans: $hasBeans');

    bool result = hasColeslaw || hasBeans;
    print('🔍 FAMILY DEAL RESULT: $result');
    return result;
  }

  // Helper method to detect if an item is a Pizza Deal that needs pizza options
  bool _isPizzaDealWithOptions() {
    if (widget.foodItem.category.toLowerCase() != 'deals') return false;
    if (widget.foodItem.subType?.toLowerCase() != 'pizza deals') return false;

    String name = widget.foodItem.name.toLowerCase();
    return name == 'pizza deal 4 one' || name == 'mega pizza deal';
  }

  // Helper method to detect if an item is Deal 2 or Deal 3 in Combo Meals subtype
  bool _isComboMealWithSauceOptions() {
    if (widget.foodItem.category.toLowerCase() != 'deals') return false;
    if (widget.foodItem.subType?.toLowerCase() != 'combo meals') return false;

    String name = widget.foodItem.name.toLowerCase();
    return name.contains('deal 2') || name.contains('deal 3');
  }

  // Build pizza selection grid for Pizza Deals
  Widget _buildPizzaSelectionGrid(List<FoodItem> pizzaItems) {
    String? selectedPizza = _dealSelections['Selected Pizza'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          pizzaItems.map((pizza) {
            bool isSelected = selectedPizza == pizza.name;
            return _buildOptionButton(
              title: pizza.name,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealSelections['Selected Pizza'] = pizza.name;
                  _updatePriceDisplay();
                });
              },
            );
          }).toList(),
    );
  }

  // Build crust selection grid for Mega Pizza Deal
  Widget _buildCrustSelectionGrid() {
    List<String> crustOptions = ['Normal', 'Stuffed'];
    String? selectedCrust = _dealSelections['Crust'] ?? 'Normal';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          crustOptions.map((crust) {
            bool isSelected = selectedCrust == crust;
            return _buildOptionButton(
              title: crust,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealSelections['Crust'] = crust;
                  _updatePriceDisplay();
                });
              },
            );
          }).toList(),
    );
  }

  // Build toppings selection grid for Pizza Deals
  Widget _buildToppingsSelectionGrid() {
    Set<String> selectedToppings = _dealMultiSelections['Extra Toppings'] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allToppings.map((topping) {
            bool isSelected = selectedToppings.contains(topping);
            return _buildOptionButton(
              title: topping,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealMultiSelections['Extra Toppings'] ??= {};
                  if (isSelected) {
                    _dealMultiSelections['Extra Toppings']!.remove(topping);
                  } else {
                    _dealMultiSelections['Extra Toppings']!.add(topping);
                  }
                  _updatePriceDisplay();
                });
              },
            );
          }).toList(),
    );
  }

  // Build sauce selection grid for Pizza Deals
  Widget _buildSauceSelectionGrid() {
    Set<String> selectedSauces = _dealMultiSelections['Sauce Dips'] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _allSauces.map((sauce) {
            bool isSelected = selectedSauces.contains(sauce);
            return _buildOptionButton(
              title: sauce,
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _dealMultiSelections['Sauce Dips'] ??= {};
                  if (isSelected) {
                    _dealMultiSelections['Sauce Dips']!.remove(sauce);
                  } else {
                    _dealMultiSelections['Sauce Dips']!.add(sauce);
                  }
                  _updatePriceDisplay();
                });
              },
            );
          }).toList(),
    );
  }
}
