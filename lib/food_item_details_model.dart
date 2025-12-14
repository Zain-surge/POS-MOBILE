// lib/food_item_details_model.dart

import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';
import 'dart:math';
import 'package:epos/services/custom_popup_service.dart';

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
  String? _selectedBase;
  String? _selectedCrust;
  Set<String> _selectedSauces = {};

  bool _makeItAMeal = false;
  String? _selectedDrink;
  String? _selectedDrinkFlavor;

  // NEW: Chip seasoning options
  String? _selectedChipSeasoning;

  String _saladChoice = 'Yes'; // 'Yes' or 'No'
  Set<String> _selectedSaladOptions =
      {}; // Selected salad options when Yes is chosen
  bool _noSauce = false;
  bool _noCream = false;

  bool _isInSizeSelectionMode = false;
  bool _sizeHasBeenSelected = false;

  final TextEditingController _reviewNotesController = TextEditingController();
  final TextEditingController _extraChargeAmountController =
      TextEditingController();
  final TextEditingController _extraChargeReasonController =
      TextEditingController();

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
    "Chicken",
    "Chicken Tikka",
    "Taleggio",
    "Gorgonzola",
    "Shawarma",
    "Brie",
    "Grana",
    "Red onion",
    "Red pepper",
    "Green chillies",
    "Buffalo mozzarella",
    "Fresh cherry tomatoes",
    "Donner",
  ];

  final List<String> _allBases = ["BBQ", "Garlic", "Tomato"];
  final List<String> _allCrusts = ["Normal", "Stuffed"];
  final List<String> _allSauces = [
    "Mayo",
    "Ketchup",
    "Chilli sauce",
    "Sweet chilli",
    "Garlic Sauce",
    "BBQ",
    "Mint Sauce",
  ];
  final List<String> _allDrinks = [
    "Coke",
    "7Up",
    "Diet Coke",
    "Fanta",
    "Pepsi",
    "Sprite",
    "J20 GLASS BOTTLE",
    "Irn Bru",
    "Rubicon Mango",
    "Caprisun",
    "Water",
  ];

  // NEW: Chip seasoning options
  final List<String> _chipSeasoningOptions = [
    "White Salt",
    "Red Salt",
    "Vinegar",
    "Salt and Vinegar",
  ];

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

  // Method to get all pizza flavours from the actual menu items
  List<String> _getPizzaFlavoursFromMenu() {
    return widget.allFoodItems
        .where((item) => item.category == 'Pizza')
        .map((item) => item.name)
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort(); // Sort alphabetically
  }

  // Method to get shawarma options from the actual menu items
  List<String> _getShawarmaOptionsFromMenu() {
    List<String> shawarmaOptions = [];

    // Get items from Shawarma category with "Donner & Shawarma kebab" subType
    shawarmaOptions.addAll(
      widget.allFoodItems
          .where(
            (item) =>
                item.category == 'Shawarma' &&
                item.subType == 'Donner & Shawarma kebab',
          )
          .map((item) => item.name)
          .where((name) => name.isNotEmpty),
    );

    // Get items from Shawarma category with "Shawarma & kebab trays" subType and add "(Tray)" suffix
    shawarmaOptions.addAll(
      widget.allFoodItems
          .where(
            (item) =>
                item.category == 'Shawarma' &&
                item.subType == 'Shawarma & kebab trays',
          )
          .map((item) => '${item.name} (Tray)')
          .where((name) => name.isNotEmpty),
    );

    return shawarmaOptions..sort(); // Sort alphabetically
  }

  // Method to get shawarma options for Shawarma Deal (only Chicken Shawarma (Pitta))
  List<String> _getShawarmaOptionsForDeal() {
    // Only return Chicken Shawarma (Pitta) for all shawarma options
    return ['Chicken Shawarma (Pitta)']..sort(); // Sort alphabetically
  }

  // Method to get burger options from the actual menu items
  List<String> _getBurgerOptionsFromMenu() {
    return widget.allFoodItems
        .where((item) => item.category == 'Burgers')
        .map((item) => item.name)
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort(); // Sort alphabetically
  }

  // Method to get calzone options from the actual menu items
  List<String> _getCalzoneOptionsFromMenu() {
    return widget.allFoodItems
        .where(
          (item) =>
              item.category == 'Calzone' ||
              item.name.toLowerCase().contains('calzone'),
        )
        .map((item) => item.name)
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort(); // Sort alphabetically
  }

  List<String> _getCanDrinkOptionsFromMenu() {
    final drinks =
        widget.allFoodItems
            .where((item) => item.category == 'Drinks')
            .map((item) => item.name)
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (drinks.isNotEmpty) {
      return drinks;
    }

    final fallback = _allDrinks.toSet().toList()..sort();
    return fallback;
  }

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

      // Parse selected options from the cart item
      if (item.selectedOptions != null) {
        for (var option in item.selectedOptions!) {
          String lowerOption = option.toLowerCase();
          if (lowerOption.startsWith('size:')) {
            _selectedSize = option.split(':').last.trim();
            _sizeHasBeenSelected = true;
          } else if (lowerOption.startsWith('toppings:')) {
            _selectedToppings.addAll(
              option.split(':').last.trim().split(',').map((s) => s.trim()),
            );
          } else if (lowerOption.startsWith('base:')) {
            _selectedBase = option.split(':').last.trim();
          } else if (lowerOption.startsWith('crust:')) {
            _selectedCrust = option.split(':').last.trim();
          } else if (lowerOption.startsWith('sauce:')) {
            _selectedSauces.addAll(
              option.split(':').last.trim().split(',').map((s) => s.trim()),
            );
          } else if (lowerOption == 'make it a meal') {
            _makeItAMeal = true;
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
          } else if (lowerOption.startsWith('chips seasoning:')) {
            _selectedChipSeasoning = option.split(':').last.trim();
          } else if (lowerOption == 'no salad') {
            _saladChoice = 'No';
          } else if (lowerOption.startsWith('salad:')) {
            _saladChoice = 'Yes';
            String saladOptionsStr = option.split(':').last.trim();
            _selectedSaladOptions.addAll(
              saladOptionsStr.split(',').map((s) => s.trim()),
            );
          } else if (lowerOption == 'no sauce') {
            _noSauce = true;
          } else if (lowerOption == 'no cream') {
            _noCream = true;
          } else if (lowerOption.startsWith('extra charge:')) {
            // Parse extra charge: "Extra Charge: £2.50 (reason)"
            String extraInfo = option.split(':').last.trim();
            // Extract amount and reason
            if (extraInfo.contains('(') && extraInfo.contains(')')) {
              String amountStr =
                  extraInfo.substring(0, extraInfo.indexOf('(')).trim();
              String reason =
                  extraInfo
                      .substring(
                        extraInfo.indexOf('(') + 1,
                        extraInfo.indexOf(')'),
                      )
                      .trim();
              // Remove currency symbol if present
              amountStr = amountStr.replaceAll('£', '').trim();
              _extraChargeAmountController.text = amountStr;
              _extraChargeReasonController.text = reason;
            }
          } else if (lowerOption.startsWith('flavor:') &&
              !_drinkFlavors.containsKey(widget.foodItem.name)) {
            // This handles standalone drink flavors if not already handled by 'drink:'
            _selectedDrinkFlavor = option.split(':').last.trim();
          }
          // Parse deal-specific options for editing
          else if (widget.foodItem.category == 'Deals') {
            print('🔍 PROCESSING DEAL OPTION: "$option"');
            // Parse deal options like "Pizza: Margherita", "Shawarma: Chicken Shawarma", etc.
            if (option.contains(':')) {
              print('🔍 OPTION CONTAINS COLON: "$option"');
              String sectionName = option.split(':')[0].trim();
              String selectedValue = option.split(':')[1].trim();

              print(
                '🔍 EXTRACTED: sectionName="$sectionName", selectedValue="$selectedValue"',
              );

              // Skip default items that will be re-added automatically for shawarma deal
              bool isDefaultItemToSkip = false;
              if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
                if (sectionName == 'Shawarma Flavour' ||
                    sectionName == 'Fries') {
                  // Only skip these truly default items, NOT user selections like chips seasoning
                  isDefaultItemToSkip = true;
                  print(
                    '🔍 SKIPPING DEFAULT ITEM: "$sectionName" = "$selectedValue"',
                  );
                }
              }
              print(
                '🔍 isDefaultItemToSkip: $isDefaultItemToSkip for "$sectionName"',
              );

              if (!isDefaultItemToSkip) {
                print(
                  '🔍 PARSING DEAL OPTION: "$sectionName" = "$selectedValue"',
                );

                // Map cart format back to modal format for specific keys
                String modalKey = sectionName;
                print(
                  '🔍 DEAL MODAL KEY MAPPING for "${widget.foodItem.name}": "$sectionName" -> "$modalKey"',
                );

                if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
                  if (sectionName == 'Drink') {
                    modalKey = 'Drink & seasoning';
                    print('🔍 MAPPED DRINK: "$sectionName" -> "$modalKey"');
                  } else if (sectionName == 'Shawarma 1 options') {
                    modalKey = 'Shawarma 1 - Shawarma Options';
                  } else if (sectionName == 'Shawarma 2 options') {
                    modalKey = 'Shawarma 2 - Shawarma Options';
                  } else if (sectionName == 'Shawarma 3 options') {
                    modalKey = 'Shawarma 3 - Shawarma Options';
                  } else if (sectionName == 'Shawarma 4 options') {
                    modalKey = 'Shawarma 4 - Shawarma Options';
                  } else if (sectionName == 'Chips Seasoning 1') {
                    modalKey = 'Drink & seasoning - Chips Seasoning 1';
                  } else if (sectionName == 'Chips Seasoning 2') {
                    modalKey = 'Drink & seasoning - Chips Seasoning 2';
                  }
                }

                // Check if this is a multi-select option (like Sauces)
                if (sectionName.toLowerCase().contains('sauce')) {
                  // Handle multi-select options
                  if (!_dealMultiSelections.containsKey(modalKey)) {
                    _dealMultiSelections[modalKey] = <String>{};
                  }
                  // Split comma-separated values for multi-select
                  List<String> values =
                      selectedValue.split(',').map((s) => s.trim()).toList();
                  _dealMultiSelections[modalKey]!.addAll(values);
                  print('🔍 ADDED MULTI-SELECT: $_dealMultiSelections');
                } else {
                  // Handle single-select options
                  _dealSelections[modalKey] = selectedValue;
                  print('🔍 ADDED SINGLE-SELECT: $_dealSelections');
                }
              }
            }
          }
        }

        // Special handling for Shawarma Deal editing - bypass general parsing
        if (widget.foodItem.name.toLowerCase() == 'shawarma deal' &&
            item.selectedOptions != null) {
          print(
            '🔍 BEFORE SPECIAL PARSING - General parsing selections: $_dealSelections',
          );
          print(
            '🔍 BEFORE SPECIAL PARSING - General parsing multi-selections: $_dealMultiSelections',
          );
          // Clear any selections made during general parsing to avoid conflicts
          _dealSelections.clear();
          _dealMultiSelections.clear();
          _parseShawarmaDealeditingOptions(item.selectedOptions!);
          print(
            '🔍 AFTER SPECIAL PARSING - Final selections: $_dealSelections',
          );
          print(
            '🔍 AFTER SPECIAL PARSING - Final multi-selections: $_dealMultiSelections',
          );
          // Additional debug: check each shawarma's sauce selections
          for (int i = 1; i <= 4; i++) {
            String sauceKey = 'Shawarma $i - Sauces (Optional)';
            if (_dealMultiSelections.containsKey(sauceKey)) {
              print(
                '🔍 SHAWARMA $i SAUCES LOADED: ${_dealMultiSelections[sauceKey]}',
              );
            } else {
              print('🔍 SHAWARMA $i SAUCES: NOT FOUND');
            }
          }
        }
        // Special handling for Family Meal editing - bypass general parsing
        else if (widget.foodItem.name.toLowerCase() == 'family meal' &&
            item.selectedOptions != null) {
          print('🔍 FAMILY MEAL SPECIAL PARSING');
          _dealSelections.clear();
          _dealMultiSelections.clear();
          _parseFamilyMealEditingOptions(item.selectedOptions!);
          print(
            '🔍 AFTER FAMILY MEAL PARSING - Final selections: $_dealSelections',
          );
          print(
            '🔍 AFTER FAMILY MEAL PARSING - Final multi-selections: $_dealMultiSelections',
          );
        }
        // Special handling for Combo Meal editing - same logic as Family Meal
        else if (widget.foodItem.name.toLowerCase() == 'combo meal' &&
            item.selectedOptions != null) {
          print('🔍 COMBO MEAL SPECIAL PARSING');
          _dealSelections.clear();
          _dealMultiSelections.clear();
          _parseComboMealEditingOptions(item.selectedOptions!);
          print(
            '🔍 AFTER COMBO MEAL PARSING - Final selections: $_dealSelections',
          );
          print(
            '🔍 AFTER COMBO MEAL PARSING - Final multi-selections: $_dealMultiSelections',
          );
        }
        // Special handling for Pizza Offers editing
        else if (widget.foodItem.name.toLowerCase() == 'pizza offers' &&
            item.selectedOptions != null) {
          print('🔍 PIZZA OFFERS SPECIAL PARSING');
          _dealSelections.clear();
          _dealMultiSelections.clear();
          _parsePizzaOffersEditingOptions(item.selectedOptions!);
          print(
            '🔍 AFTER PIZZA OFFERS PARSING - Final selections: $_dealSelections',
          );
          print(
            '🔍 AFTER PIZZA OFFERS PARSING - Final multi-selections: $_dealMultiSelections',
          );
        } else if (widget.foodItem.name.toLowerCase() == 'wednesday special' &&
            item.selectedOptions != null) {
          print('dY"? WEDNESDAY SPECIAL PARSING');
          _dealSelections.clear();
          _dealMultiSelections.clear();
          _parseWednesdaySpecialEditingOptions(item.selectedOptions!);
          print(
            'dY"? AFTER WEDNESDAY SPECIAL PARSING - Final selections: $_dealSelections',
          );
        }
        // Convert consolidated cart options back to modal structure for editing
        else if (widget.foodItem.category == 'Deals' &&
            _dealSelections.isNotEmpty) {
          Map<String, String?> originalDealSelections = {};
          Map<String, Set<String>> originalDealMultiSelections = {};

          _dealSelections.forEach((storedKey, storedValue) {
            print(
              '🔍 RESTORE: Processing stored key "$storedKey" = "$storedValue" for "${widget.foodItem.name}"',
            );

            if (storedKey.startsWith('Selected ') && storedValue != null) {
              // Handle any consolidated selections (Selected Shawarmas, Selected Pizzas, etc.)
              List<String> itemList =
                  storedValue.split(',').map((s) => s.trim()).toList();

              // Determine the base type from the stored key
              String baseType = '';
              int maxCount = 4; // Default max count

              if (storedKey.contains('Shawarmas')) {
                baseType = 'Shawarma';
                maxCount = 4;
              } else if (storedKey.contains('Pizzas')) {
                baseType = 'Pizza';
                maxCount = 3;
              } else if (storedKey.contains('Burgers')) {
                baseType = 'Burger';
                maxCount = 4;
              } else if (storedKey.contains('Calzones')) {
                baseType = 'Calzone';
                maxCount = 4;
              }

              // Map back to individual selections
              for (int i = 0; i < itemList.length && i < maxCount; i++) {
                String modalKey = '$baseType ${i + 1}';
                originalDealSelections[modalKey] = itemList[i];
                print(
                  '🔍 MAPPED: "$storedKey" -> "$modalKey" = "${itemList[i]}"',
                );
              }
            } else {
              // Direct mapping - stored keys should match modal keys exactly
              String modalKey = storedKey;

              // Special handling for shawarma deal options stored with " - " format
              if (storedKey.contains(' - Shawarma Options') ||
                  storedKey.contains(' - Sauces (Optional)')) {
                modalKey = storedKey; // Keep the full key for shawarma deal
              } else if (storedKey.contains(' - Chips Seasoning')) {
                modalKey = storedKey; // Keep the full key for chips seasoning
              }

              originalDealSelections[modalKey] = storedValue;
              if (modalKey != storedKey) {
                print(
                  '🔍 MAPPED: "$storedKey" -> "$modalKey" = "$storedValue"',
                );
              }
            }
          });

          // Handle multi-select options
          _dealMultiSelections.forEach((storedKey, storedValues) {
            String modalKey = storedKey;

            // Direct mapping since "Choose " prefixes are removed

            originalDealMultiSelections[modalKey] = Set<String>.from(
              storedValues,
            );
            print(
              '🔍 MAPPED MULTI-SELECT: "$storedKey" -> "$modalKey" = "$storedValues"',
            );
          });

          // Replace the stored selections with the converted ones
          _dealSelections.clear();
          _dealSelections.addAll(originalDealSelections);
          _dealMultiSelections.clear();
          _dealMultiSelections.addAll(originalDealMultiSelections);

          print('🔍 FINAL DEAL SELECTIONS: $_dealSelections');
          print('🔍 FINAL DEAL MULTI-SELECTIONS: $_dealMultiSelections');

          // Set deal category for editing - find the first category that has a selection
          Map<String, List<String>> dealOptions = _getDealOptions(
            widget.foodItem.name,
          );
          List<String> dealCategories = _getDealCategories(dealOptions);

          // Find the first category that has a selection to display
          // Prioritize certain categories for better UX
          String? foundCategory;
          List<String> priorityCategories = [
            'Shawarma',
            'Pizza (12")',
            'Pizza (16")',
          ];

          // First check priority categories
          for (String category in priorityCategories) {
            if (dealCategories.contains(category)) {
              bool hasSingleSelection =
                  _dealSelections.containsKey(category) &&
                  _dealSelections[category] != null;
              bool hasMultiSelection =
                  _dealMultiSelections.containsKey(category) &&
                  _dealMultiSelections[category]!.isNotEmpty;

              print(
                '🔍 TAB PRIORITY CHECK for "${widget.foodItem.name}": category="$category", hasSingleSelection=$hasSingleSelection (${_dealSelections[category]}), hasMultiSelection=$hasMultiSelection',
              );

              if (hasSingleSelection || hasMultiSelection) {
                foundCategory = category;
                break;
              }
            }
          }

          // If no priority category found, check all categories
          if (foundCategory == null) {
            for (String category in dealCategories) {
              bool hasSingleSelection =
                  _dealSelections.containsKey(category) &&
                  _dealSelections[category] != null;
              bool hasMultiSelection =
                  _dealMultiSelections.containsKey(category) &&
                  _dealMultiSelections[category]!.isNotEmpty;

              if (hasSingleSelection || hasMultiSelection) {
                foundCategory = category;
                break;
              }
            }
          }

          // If no category with selection found, use the first category
          if (foundCategory != null) {
            _selectedDealCategory = foundCategory;
          } else if (dealCategories.isNotEmpty) {
            // Special handling for Family Meal - default to Pizza tab
            if (widget.foodItem.name.toLowerCase() == 'family meal') {
              _selectedDealCategory = 'Pizza (16")';
            } else {
              _selectedDealCategory = dealCategories.first;
            }
          }

          print('🔍 SET DEAL CATEGORY: "$_selectedDealCategory"');
          print('🔍 AVAILABLE DEAL CATEGORIES: $dealCategories');
          print('🔍 CURRENT SELECTIONS FOR EDITING: $_dealSelections');
        }
      }
      // If we are editing, we don't start in size selection mode, as a size should already be selected or not applicable.
      _isInSizeSelectionMode = false;
      _sizeHasBeenSelected =
          _selectedSize != null ||
          (widget.foodItem.effectivePosPrice.keys.length == 1 &&
              widget.foodItem.effectivePosPrice.isNotEmpty);
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
                'Deals',
              ].contains(widget.foodItem.category) &&
              widget.foodItem.effectivePosPrice.keys.length > 1);

      if (requiresSizeSelection) {
        _isInSizeSelectionMode = true;
        _selectedSize = null;
      } else {
        if (widget.foodItem.effectivePosPrice.keys.length == 1 &&
            widget.foodItem.effectivePosPrice.isNotEmpty) {
          _selectedSize = widget.foodItem.effectivePosPrice.keys.first;
          _sizeHasBeenSelected = true;
        }
        _isInSizeSelectionMode = false;
      }

      if (widget.foodItem.category == 'Pizza' ||
          widget.foodItem.category == 'GarlicBread') {
        _selectedBase = "Tomato";
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

    // Auto-select defaults for Shawarma Deal if not editing
    if (!widget.isEditing &&
        widget.foodItem.name.toLowerCase() == 'shawarma deal') {
      _initializeShawarmaDefaults();
    }

    // Auto-select defaults for Pizza Offers if not editing
    if (!widget.isEditing &&
        widget.foodItem.name.toLowerCase() == 'pizza offers') {
      _initializePizzaOffersDefaults();
    }

    _calculatedPricePerUnit = _calculatePricePerUnit();
  }

  // Initialize default selections for all Shawarma tabs
  void _initializeShawarmaDefaults() {
    List<String> shawarmaKeys = [
      'Shawarma 1',
      'Shawarma 2',
      'Shawarma 3',
      'Shawarma 4',
    ];

    for (String shawarmaKey in shawarmaKeys) {
      // Auto-select "No" for both Salad and Sauce if not already selected
      String saladKey = '$shawarmaKey - Salad';
      String sauceKey = '$shawarmaKey - Sauce';

      if (_dealSelections[saladKey] == null) {
        _dealSelections[saladKey] = 'No';
        print('🔍 INIT AUTO-SELECTED: $saladKey = No');
      }
      if (_dealSelections[sauceKey] == null) {
        _dealSelections[sauceKey] = 'No';
        print('🔍 INIT AUTO-SELECTED: $sauceKey = No');
      }
    }
  }

  // Initialize default selections for all Pizza Offers tabs
  void _initializePizzaOffersDefaults() {
    List<String> pizzaKeys = [
      'Pizza 1 - Crust',
      'Pizza 2 - Crust',
      'Pizza 3 - Crust',
    ];

    for (String crustKey in pizzaKeys) {
      if (_dealSelections[crustKey] == null) {
        _dealSelections[crustKey] = 'Normal';
        print('🔍 INIT AUTO-SELECTED: $crustKey = Normal');
      }
    }
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _extraChargeAmountController.dispose();
    _extraChargeReasonController.dispose();
    super.dispose();
  }

  // Special parsing method for Shawarma Deal editing only
  void _parseShawarmaDealeditingOptions(List<String> selectedOptions) {
    print('🔍 SPECIAL SHAWARMA DEAL PARSING - INPUT: $selectedOptions');

    // Clear existing selections
    _dealSelections.clear();
    _dealMultiSelections.clear();

    for (String option in selectedOptions) {
      print('🔍 SPECIAL PARSING: "$option"');

      // Skip default items that will be re-added automatically
      if (option.startsWith('Shawarma Flavour:') ||
          option.startsWith('Fries:')) {
        print('🔍 SPECIAL SKIP: "$option"');
        continue;
      }

      // Handle new format: "Shawarma 1 (Salad: Cucumber, Lettuce & Sauces: Ketchup, BBQ)" or "Shawarma 1 (No Salad & No Sauce)"
      if (option.startsWith('Shawarma ') &&
          option.contains('(') &&
          option.contains(')')) {
        print('🔍 PARSING NEW FORMAT: "$option"');

        // Extract shawarma number
        String shawarmaNum = option.substring(0, option.indexOf('(')).trim();
        print('🔍 SHAWARMA NUM: "$shawarmaNum"');

        // Extract content inside parentheses
        String content =
            option
                .substring(option.indexOf('(') + 1, option.indexOf(')'))
                .trim();
        print('🔍 CONTENT: "$content"');

        // Split by " & " to get salad and sauce parts
        List<String> parts = content.split(' & ');
        print('🔍 PARTS: $parts');

        for (String part in parts) {
          part = part.trim();

          if (part.startsWith('Salad:')) {
            // Handle "Salad: Cucumber, Lettuce"
            String saladOptionsStr =
                part.substring(6).trim(); // Remove "Salad:"
            List<String> saladOptions =
                saladOptionsStr.split(',').map((s) => s.trim()).toList();

            // Set Salad choice to Yes
            _dealSelections['$shawarmaNum - Salad'] = 'Yes';
            print('🔍 SET SALAD CHOICE: $shawarmaNum - Salad = Yes');

            // Set Salad Options
            String saladOptionsKey = '$shawarmaNum - Salad Options';
            if (!_dealMultiSelections.containsKey(saladOptionsKey)) {
              _dealMultiSelections[saladOptionsKey] = <String>{};
            }
            _dealMultiSelections[saladOptionsKey]!.addAll(saladOptions);
            print('🔍 SET SALAD OPTIONS: $saladOptionsKey = $saladOptions');
          } else if (part.startsWith('Sauces:')) {
            // Handle "Sauces: Ketchup, BBQ"
            String sauceOptionsStr =
                part.substring(7).trim(); // Remove "Sauces:"
            List<String> sauceOptions =
                sauceOptionsStr.split(',').map((s) => s.trim()).toList();

            // Set Sauce choice to Yes
            _dealSelections['$shawarmaNum - Sauce'] = 'Yes';
            print('🔍 SET SAUCE CHOICE: $shawarmaNum - Sauce = Yes');

            // Set Sauce Options
            String sauceOptionsKey = '$shawarmaNum - Sauce Options';
            if (!_dealMultiSelections.containsKey(sauceOptionsKey)) {
              _dealMultiSelections[sauceOptionsKey] = <String>{};
            }
            _dealMultiSelections[sauceOptionsKey]!.addAll(sauceOptions);
            print('🔍 SET SAUCE OPTIONS: $sauceOptionsKey = $sauceOptions');
          } else if (part == 'No Salad') {
            // Set Salad choice to No
            _dealSelections['$shawarmaNum - Salad'] = 'No';
            print('🔍 SET SALAD CHOICE: $shawarmaNum - Salad = No');
          } else if (part == 'No Sauce') {
            // Set Sauce choice to No
            _dealSelections['$shawarmaNum - Sauce'] = 'No';
            print('🔍 SET SAUCE CHOICE: $shawarmaNum - Sauce = No');
          }
        }
      }
      // Handle old format and other options
      else if (option.contains(':')) {
        String sectionName = option.split(':')[0].trim();
        String selectedValue = option.split(':')[1].trim();

        // Direct mapping for shawarma deal
        if (sectionName == 'Drink') {
          _dealSelections['Drink & seasoning'] = selectedValue;
          print(
            '🔍 SPECIAL MAPPED DRINK: "$selectedValue" -> "Drink & seasoning"',
          );
        } else if (sectionName == 'Chips Seasoning 1') {
          _dealSelections['Drink & seasoning - Chips Seasoning 1'] =
              selectedValue;
          print('🔍 SPECIAL MAPPED CHIPS 1: "$selectedValue"');
        } else if (sectionName == 'Chips Seasoning 2') {
          _dealSelections['Drink & seasoning - Chips Seasoning 2'] =
              selectedValue;
          print('🔍 SPECIAL MAPPED CHIPS 2: "$selectedValue"');
        } else if (sectionName == 'Shawarma 1 options') {
          _dealSelections['Shawarma 1 - Shawarma Options'] = selectedValue;
        } else if (sectionName == 'Shawarma 2 options') {
          _dealSelections['Shawarma 2 - Shawarma Options'] = selectedValue;
        } else if (sectionName == 'Shawarma 3 options') {
          _dealSelections['Shawarma 3 - Shawarma Options'] = selectedValue;
        } else if (sectionName == 'Shawarma 4 options') {
          _dealSelections['Shawarma 4 - Shawarma Options'] = selectedValue;
        } else if (sectionName.toLowerCase().contains('sauce')) {
          // Handle all sauce-related options as multi-select
          String modalKey = sectionName;

          // Normalize the key to the expected format
          if (sectionName.endsWith('sauces (optional)')) {
            String shawarmaNum =
                sectionName.split(' ')[0] +
                ' ' +
                sectionName.split(' ')[1]; // "Shawarma 1"
            modalKey = '$shawarmaNum - Sauces (Optional)';
          } else if (!sectionName.contains(' - Sauces (Optional)')) {
            // If it doesn't already have the proper format, try to format it
            RegExp shawarmaPattern = RegExp(r'^Shawarma [1-4]');
            if (shawarmaPattern.hasMatch(sectionName)) {
              String shawarmaNum =
                  shawarmaPattern.firstMatch(sectionName)!.group(0)!;
              modalKey = '$shawarmaNum - Sauces (Optional)';
            }
          }

          if (!_dealMultiSelections.containsKey(modalKey)) {
            _dealMultiSelections[modalKey] = <String>{};
          }
          List<String> values =
              selectedValue.split(',').map((s) => s.trim()).toList();
          _dealMultiSelections[modalKey]!.addAll(values);
          print('🔍 SPECIAL MAPPED ALL SAUCES: $modalKey = $values');
        } else {
          // Default handling for other options
          _dealSelections[sectionName] = selectedValue;
          print('🔍 SPECIAL MAPPED OTHER: $sectionName = $selectedValue');
        }
      }
    }

    print('🔍 SPECIAL FINAL SELECTIONS: $_dealSelections');
    print('🔍 SPECIAL FINAL MULTI-SELECTIONS: $_dealMultiSelections');

    // Set default tab to the shawarma with the most selections for editing
    List<String> shawarmaKeys = [
      'Shawarma 1',
      'Shawarma 2',
      'Shawarma 3',
      'Shawarma 4',
    ];
    String bestTab = 'Shawarma 1'; // default fallback
    int maxSelections = 0;

    for (String key in shawarmaKeys) {
      int selectionCount = 0;
      // Count selections for this shawarma
      if (_dealSelections.containsKey('$key - Shawarma Options'))
        selectionCount++;
      if (_dealMultiSelections.containsKey('$key - Sauces (Optional)') &&
          _dealMultiSelections['$key - Sauces (Optional)']!.isNotEmpty)
        selectionCount++;

      if (selectionCount > maxSelections) {
        maxSelections = selectionCount;
        bestTab = key;
      }
    }

    _selectedDealCategory = bestTab;
    print(
      '🔍 SPECIAL SET TAB TO: $_selectedDealCategory (had $maxSelections selections)',
    );
  }

  // Special parsing method for Family Meal editing only
  void _parseFamilyMealEditingOptions(List<String> selectedOptions) {
    print('🔍 FAMILY MEAL PARSING - INPUT: $selectedOptions');

    // Clear existing selections
    _dealSelections.clear();
    _dealMultiSelections.clear();

    for (String option in selectedOptions) {
      print('🔍 FAMILY MEAL PARSING: "$option"');

      // Parse different item types based on format
      if (option.startsWith('Pizza (16"): ')) {
        _parseFamilyMealItem(option, 'Pizza', 'Pizza (16"): ');
      } else if (option.startsWith('Shawarma: ')) {
        _parseFamilyMealItem(option, 'Shawarma', 'Shawarma: ');
      } else if (option.startsWith('Burger: ')) {
        _parseFamilyMealItem(option, 'Burger', 'Burger: ');
      } else if (option.startsWith('Calzone: ')) {
        _parseFamilyMealItem(option, 'Calzone', 'Calzone: ');
      } else if (option.startsWith('Drink: ')) {
        _parseFamilyMealItem(option, 'Drinks', 'Drink: ');
      } else if (option.contains(':')) {
        // Handle all other options including detailed selections with ' - '
        String sectionName = option.split(':')[0].trim();
        String selectedValue = option.split(':')[1].trim();

        // Check if this is a multi-selection (comma-separated values)
        if (selectedValue.contains(',')) {
          // Multi-selection like "Shawarma - Sauce Options: Mayo, BBQ"
          List<String> selections =
              selectedValue.split(',').map((s) => s.trim()).toList();
          _dealMultiSelections[sectionName] = Set<String>.from(selections);
          print('🔍 FAMILY MEAL MULTI-SELECT: $sectionName = $selections');
        } else {
          // Single selection like "Shawarma - Sauce: Yes"
          _dealSelections[sectionName] = selectedValue;
          print('🔍 FAMILY MEAL SINGLE SELECT: $sectionName = $selectedValue');
        }
      }
    }

    print('🔍 FAMILY MEAL FINAL SELECTIONS: $_dealSelections');
    print('🔍 FAMILY MEAL FINAL MULTI-SELECTIONS: $_dealMultiSelections');

    // Set default tab to Pizza (16") for Family Meal editing
    _selectedDealCategory = 'Pizza (16")';
    print('🔍 FAMILY MEAL SET DEFAULT TAB: $_selectedDealCategory');
  }

  void _parseComboMealEditingOptions(List<String> selectedOptions) {
    // Clear existing selections
    _dealSelections.clear();
    _dealMultiSelections.clear();

    for (String option in selectedOptions) {
      // Parse different item types based on format
      if (option.startsWith('Pizza (12"): ')) {
        _parseComboMealItem(option, 'Pizza', 'Pizza (12"): ');
      } else if (option.startsWith('Shawarma: ')) {
        _parseComboMealItem(option, 'Shawarma', 'Shawarma: ');
      } else if (option.startsWith('Burger: ')) {
        _parseComboMealItem(option, 'Burger', 'Burger: ');
      } else if (option.startsWith('Drink 1: ')) {
        _parseComboMealItem(option, 'Drink 1', 'Drink 1: ');
      } else if (option.startsWith('Drink 2: ')) {
        _parseComboMealItem(option, 'Drink 2', 'Drink 2: ');
      } else if (option.startsWith('Drink: ')) {
        // Legacy support for old format
        _parseComboMealItem(option, 'Drinks', 'Drink: ');
      } else if (option.contains(':')) {
        // Handle all other options including detailed selections with ' - '
        String sectionName = option.split(':')[0].trim();
        String selectedValue = option.split(':')[1].trim();

        // Check if this is a multi-selection (comma-separated values)
        if (selectedValue.contains(',')) {
          // Multi-selection like "Shawarma - Sauce Options: Mayo, BBQ"
          List<String> selections =
              selectedValue.split(',').map((s) => s.trim()).toList();
          _dealMultiSelections[sectionName] = Set<String>.from(selections);
        } else {
          // Single selection like "Shawarma - Sauce: Yes"
          _dealSelections[sectionName] = selectedValue;
        }
      }
    }

    // Set default tab to Pizza (12") for Combo Meal editing
    _selectedDealCategory = 'Pizza (12")';
  }

  void _parseFamilyMealItem(String option, String itemType, String prefix) {
    print('🔍 FAMILY MEAL ITEM PARSING START');
    print('🔍 Input option: "$option"');
    print('🔍 itemType: "$itemType"');
    print('🔍 prefix: "$prefix"');

    // Extract item name and details
    String content = option.substring(prefix.length);
    print('🔍 Extracted content: "$content"');

    // Map item types to exact section names for Family Meal
    String sectionName = '';
    if (itemType == 'Pizza') {
      sectionName = 'Pizza (16")';
    } else if (itemType == 'Shawarma') {
      sectionName = 'Shawarma';
    } else if (itemType == 'Burger') {
      sectionName = 'Burger';
    } else if (itemType == 'Calzone') {
      sectionName = 'Calzone';
    } else if (itemType == 'Drinks') {
      sectionName = 'Drinks';
    }

    print('🔍 FAMILY MEAL MAPPING: $itemType -> $sectionName');

    if (sectionName.isEmpty) {
      print('🔍 FAMILY MEAL WARNING: No available section found for $itemType');
      return;
    }

    if (content.contains('(') && content.contains(')')) {
      // For items with multiple parentheses, find the LAST set containing salad/sauce info
      // Format: "CHICKEN SHAWARMA (Tray) (Salad: Onions, Tomato, Sauce: Chilli Sauce, Sweet Chilli)"
      int lastOpenParen = content.lastIndexOf('(');
      int lastCloseParen = content.lastIndexOf(')');

      String itemName = content.substring(0, lastOpenParen).trim();
      String details =
          content.substring(lastOpenParen + 1, lastCloseParen).trim();

      print('🔍 Extracted itemName: "$itemName"');
      print('🔍 Extracted details: "$details"');

      // Set the main item (use the full name for drinks, partial for others if needed)
      if (itemType == 'Drinks') {
        // For drinks, keep the full format like "Fanta (1.5L)"
        _dealSelections[sectionName] = content;
      } else {
        _dealSelections[sectionName] = itemName;
      }
      print(
        '🔍 FAMILY MEAL ITEM: $sectionName = ${_dealSelections[sectionName]}',
      );

      if (itemType == 'Pizza') {
        // Family Meal Pizza - skip sauce parsing
        print('🔍 FAMILY MEAL PIZZA: No sauce parsing needed');
      } else if (itemType == 'Shawarma' || itemType == 'Burger') {
        // Parse format: "Salad: Cucumber, Lettuce, Sauce: Mayo, BBQ" or "No Salad, No Sauce"
        // Need to handle comma-separated format correctly

        // Check for simple no-option cases first
        if (details == 'No Salad, No Sauce') {
          _dealSelections['$sectionName - Salad'] = 'No';
          _dealSelections['$sectionName - Sauce'] = 'No';
          print(
            '🔍 FAMILY MEAL NO OPTIONS: $sectionName - both salad and sauce = No',
          );
        } else {
          print('🔍 PARSING COMPLEX SHAWARMA/BURGER FORMAT: "$details"');

          // Parse the complex format: need to find "Salad:" and "Sauce:" sections
          String saladPart = '';
          String saucePart = '';

          // Find where "Sauce:" starts
          int sauceIndex = details.indexOf('Sauce:');
          print('🔍 Sauce index found at: $sauceIndex');

          if (sauceIndex != -1) {
            saladPart = details.substring(0, sauceIndex).trim();
            saucePart = details.substring(sauceIndex).trim();
          } else {
            saladPart = details.trim();
          }

          // Remove trailing comma from salad part
          if (saladPart.endsWith(',')) {
            saladPart = saladPart.substring(0, saladPart.length - 1).trim();
          }

          print('🔍 Extracted saladPart: "$saladPart"');
          print('🔍 Extracted saucePart: "$saucePart"');

          // Parse salad section
          if (saladPart.startsWith('Salad: ')) {
            _dealSelections['$sectionName - Salad'] = 'Yes';
            String saladList = saladPart.substring(7); // Remove "Salad: "
            List<String> salads =
                saladList.split(',').map((s) => s.trim()).toList();
            _dealMultiSelections['$sectionName - Salad Options'] =
                Set<String>.from(salads);
            print(
              '🔍 FAMILY MEAL SALADS: $sectionName - Salad Options = $salads',
            );
          } else if (saladPart == 'No Salad') {
            _dealSelections['$sectionName - Salad'] = 'No';
            print('🔍 FAMILY MEAL NO SALAD: $sectionName - Salad = No');
          }

          // Parse sauce section
          if (saucePart.startsWith('Sauce: ')) {
            _dealSelections['$sectionName - Sauce'] = 'Yes';
            String sauceList = saucePart.substring(7); // Remove "Sauce: "
            List<String> sauces =
                sauceList.split(',').map((s) => s.trim()).toList();
            _dealMultiSelections['$sectionName - Sauce Options'] =
                Set<String>.from(sauces);
            print(
              '🔍 FAMILY MEAL SAUCES: $sectionName - Sauce Options = $sauces',
            );
          } else if (saucePart == 'No Sauce') {
            _dealSelections['$sectionName - Sauce'] = 'No';
            print('🔍 FAMILY MEAL NO SAUCE: $sectionName - Sauce = No');
          }
        }
      }
    } else {
      // Simple item without details (Calzone, Drink)
      _dealSelections[sectionName] = content;
      print('🔍 FAMILY MEAL SIMPLE: $sectionName = $content');
    }
  }

  void _parseComboMealItem(String option, String itemType, String prefix) {
    print('🔍 Input option: "$option"');
    print('🔍 itemType: "$itemType"');
    print('🔍 prefix: "$prefix"');

    // Extract item name and details
    String content = option.substring(prefix.length);
    print('🔍 Extracted content: "$content"');

    // Map item types to exact section names for Combo Meal
    String sectionName = '';
    if (itemType == 'Pizza') {
      sectionName = 'Pizza (12")';
    } else if (itemType == 'Shawarma') {
      sectionName = 'Shawarma';
    } else if (itemType == 'Burger') {
      sectionName = 'Burger';
    } else if (itemType == 'Drink 1') {
      sectionName = 'Drink 1';
    } else if (itemType == 'Drink 2') {
      sectionName = 'Drink 2';
    } else if (itemType == 'Drinks') {
      // Legacy support
      sectionName = 'Drinks';
    }

    print('🔍 COMBO MEAL MAPPING: $itemType -> $sectionName');

    if (sectionName.isEmpty) {
      print('🔍 COMBO MEAL WARNING: No available section found for $itemType');
      return;
    }

    if (content.contains('(') && content.contains(')')) {
      // For items with multiple parentheses, find the LAST set containing salad/sauce info
      // Format: "CHICKEN SHAWARMA (Tray) (Salad: Onions, Tomato, Sauce: Chilli Sauce, Sweet Chilli)"
      int lastOpenParen = content.lastIndexOf('(');
      int lastCloseParen = content.lastIndexOf(')');

      String itemName = content.substring(0, lastOpenParen).trim();
      String details =
          content.substring(lastOpenParen + 1, lastCloseParen).trim();

      print('🔍 Extracted itemName: "$itemName"');
      print('🔍 Extracted details: "$details"');

      // Set the main item (use the full name for drinks, partial for others if needed)
      if (itemType == 'Drinks') {
        // For drinks, keep the full format like "Fanta (1.5L)"
        _dealSelections[sectionName] = content;
      } else {
        _dealSelections[sectionName] = itemName;
      }
      print(
        '🔍 COMBO MEAL ITEM: $sectionName = ${_dealSelections[sectionName]}',
      );

      if (itemType == 'Pizza') {
        // Parse pizza sauce: "Sauce: Mayo, Ketchup" or "No Sauce"
        if (details.startsWith('Sauce: ')) {
          _dealSelections['$sectionName - Pizza Sauce'] = 'Yes';
          String sauceList = details.substring(7); // Remove "Sauce: "
          List<String> sauces =
              sauceList.split(',').map((s) => s.trim()).toList();
          _dealMultiSelections['$sectionName - Pizza Sauce Options'] =
              Set<String>.from(sauces);
          print(
            '🔍 COMBO MEAL PIZZA SAUCES: $sectionName - Pizza Sauce Options = $sauces',
          );
        } else if (details == 'No Sauce') {
          _dealSelections['$sectionName - Pizza Sauce'] = 'No';
          print(
            '🔍 COMBO MEAL PIZZA NO SAUCE: $sectionName - Pizza Sauce = No',
          );
        }
      } else if (itemType == 'Shawarma' || itemType == 'Burger') {
        // Parse format: "Salad: Cucumber, Lettuce, Sauce: Mayo, BBQ" or "No Salad, No Sauce"
        // Need to handle comma-separated format correctly

        // Check for simple no-option cases first
        if (details == 'No Salad, No Sauce') {
          _dealSelections['$sectionName - Salad'] = 'No';
          _dealSelections['$sectionName - Sauce'] = 'No';
          print(
            '🔍 COMBO MEAL NO OPTIONS: $sectionName - both salad and sauce = No',
          );
        } else {
          print('🔍 PARSING COMPLEX SHAWARMA/BURGER FORMAT: "$details"');

          // Parse the complex format: need to find "Salad:" and "Sauce:" sections
          String saladPart = '';
          String saucePart = '';

          // Find where "Sauce:" starts
          int sauceIndex = details.indexOf('Sauce:');
          print('🔍 Sauce index found at: $sauceIndex');

          if (sauceIndex != -1) {
            saladPart = details.substring(0, sauceIndex).trim();
            saucePart = details.substring(sauceIndex).trim();
          } else {
            saladPart = details.trim();
          }

          // Remove trailing comma from salad part
          if (saladPart.endsWith(',')) {
            saladPart = saladPart.substring(0, saladPart.length - 1).trim();
          }

          print('🔍 Extracted saladPart: "$saladPart"');
          print('🔍 Extracted saucePart: "$saucePart"');

          // Parse salad section
          if (saladPart.startsWith('Salad: ')) {
            _dealSelections['$sectionName - Salad'] = 'Yes';
            String saladList = saladPart.substring(7); // Remove "Salad: "
            List<String> salads =
                saladList.split(',').map((s) => s.trim()).toList();
            _dealMultiSelections['$sectionName - Salad Options'] =
                Set<String>.from(salads);
            print(
              '🔍 COMBO MEAL SALADS: $sectionName - Salad Options = $salads',
            );
          } else if (saladPart == 'No Salad') {
            _dealSelections['$sectionName - Salad'] = 'No';
            print('🔍 COMBO MEAL NO SALAD: $sectionName - Salad = No');
          }

          // Parse sauce section
          if (saucePart.startsWith('Sauce: ')) {
            _dealSelections['$sectionName - Sauce'] = 'Yes';
            String sauceList = saucePart.substring(7); // Remove "Sauce: "
            List<String> sauces =
                sauceList.split(',').map((s) => s.trim()).toList();
            _dealMultiSelections['$sectionName - Sauce Options'] =
                Set<String>.from(sauces);
            print(
              '🔍 COMBO MEAL SAUCES: $sectionName - Sauce Options = $sauces',
            );
          } else if (saucePart == 'No Sauce') {
            _dealSelections['$sectionName - Sauce'] = 'No';
            print('🔍 COMBO MEAL NO SAUCE: $sectionName - Sauce = No');
          }
        }
      }
    } else {
      // Simple item without details (Drink)
      _dealSelections[sectionName] = content;
      print('🔍 COMBO MEAL SIMPLE: $sectionName = $content');
    }
  }

  void _parsePizzaOffersEditingOptions(List<String> selectedOptions) {
    // Clear existing selections
    _dealSelections.clear();
    _dealMultiSelections.clear();

    print('🔍 PIZZA OFFERS PARSING: Processing options: $selectedOptions');

    for (String option in selectedOptions) {
      print('🔍 Processing Pizza Offers option: "$option"');

      if (option.startsWith('Size: ')) {
        // Extract size and convert back to original format
        String sizeDisplay = option.substring(6).trim(); // Remove "Size: "
        // Remove " inch" if present to get the raw size value
        String sizeValue = sizeDisplay.replaceAll(' inch', '').trim();

        // Map display size back to internal format (e.g., "12" -> "12 inch")
        _selectedSize = '$sizeValue inch';
        _sizeHasBeenSelected = true;
        print('🔍 PIZZA OFFERS SIZE: $_selectedSize');
      } else if (option.startsWith('Selected Pizzas: ')) {
        // Parse pizza list (could be comma-separated or newline-separated)
        String pizzasList =
            option.substring(17).trim(); // Remove "Selected Pizzas: "

        List<String> pizzas;
        if (pizzasList.contains('\n')) {
          // New format with newlines and spacing
          pizzas =
              pizzasList
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .map(
                    (s) => s.replaceAll(RegExp(r'^\s+'), ''),
                  ) // Remove leading spaces
                  .toList();
        } else {
          // Old format with commas
          pizzas = pizzasList.split(',').map((s) => s.trim()).toList();
        }

        // Map each pizza to its Pizza 1, Pizza 2, Pizza 3 sections
        for (int i = 0; i < pizzas.length && i < 3; i++) {
          String sectionName = 'Pizza ${i + 1}';
          String pizzaInfo = pizzas[i];

          // Check if pizza has crust information: "PizzaName(Crust: Stuffed)"
          if (pizzaInfo.contains('(Crust:')) {
            // Extract pizza name and crust
            RegExp regExp = RegExp(r'^(.+?)\(Crust:\s*(.+?)\)');
            Match? match = regExp.firstMatch(pizzaInfo);
            if (match != null) {
              String pizzaName = match.group(1)?.trim() ?? pizzaInfo;
              String crustType = match.group(2)?.trim() ?? 'Normal';

              _dealSelections[sectionName] = pizzaName;
              _dealSelections['$sectionName - Crust'] = crustType;
              print('🔍 PIZZA OFFERS PIZZA: $sectionName = $pizzaName');
              print('🔍 PIZZA OFFERS CRUST: $sectionName - Crust = $crustType');
            } else {
              _dealSelections[sectionName] = pizzaInfo;
              _dealSelections['$sectionName - Crust'] = 'Normal';
              print('🔍 PIZZA OFFERS PIZZA: $sectionName = $pizzaInfo');
              print(
                '🔍 PIZZA OFFERS CRUST: $sectionName - Crust = Normal (default)',
              );
            }
          } else {
            _dealSelections[sectionName] = pizzaInfo;
            _dealSelections['$sectionName - Crust'] = 'Normal';
            print('🔍 PIZZA OFFERS PIZZA: $sectionName = $pizzaInfo');
            print(
              '🔍 PIZZA OFFERS CRUST: $sectionName - Crust = Normal (default)',
            );
          }
        }
      } else if (option.startsWith('Drink: ')) {
        // Extract drink name and remove size info if present
        String drinkInfo = option.substring(7).trim(); // Remove "Drink: "

        // Remove (1.5L) suffix if present to get just the drink name
        String drinkName = drinkInfo.replaceAll(RegExp(r'\s*\(1\.5L\)$'), '');

        _dealSelections['Drink (1.5L)'] = drinkName;
        print('🔍 PIZZA OFFERS DRINK: Drink (1.5L) = $drinkName');
      }
    }

    // Ensure all pizzas have crust selections (for backward compatibility)
    for (int i = 1; i <= 3; i++) {
      String crustKey = 'Pizza $i - Crust';
      if (_dealSelections[crustKey] == null) {
        _dealSelections[crustKey] = 'Normal';
        print('🔍 PIZZA OFFERS INIT MISSING CRUST: $crustKey = Normal');
      }
    }

    // Set default tab for Pizza Offers editing
    _selectedDealCategory = 'Pizza 1';
    print('🔍 PIZZA OFFERS SET DEFAULT TAB: $_selectedDealCategory');
  }

  void _parseWednesdaySpecialEditingOptions(List<String> selectedOptions) {
    _dealSelections.clear();
    _dealMultiSelections.clear();

    for (String option in selectedOptions) {
      final String trimmedOption = option.trim();
      if (trimmedOption.isEmpty) continue;

      final String lowerOption = trimmedOption.toLowerCase();
      if (lowerOption.startsWith('size')) {
        continue;
      }

      if (lowerOption.startsWith('1 garlic bread')) {
        continue;
      }

      // CRITICAL FIX: Skip chips seasoning - not part of Wednesday Special
      if (lowerOption.contains('chips seasoning') ||
          lowerOption.contains('seasoning')) {
        continue;
      }

      if (trimmedOption.startsWith('Selected Pizzas:')) {
        String pizzasList =
            trimmedOption.substring('Selected Pizzas:'.length).trim();

        List<String> pizzas;
        if (pizzasList.contains('\n')) {
          pizzas =
              pizzasList
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
        } else {
          pizzas =
              pizzasList
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
        }

        for (int i = 0; i < pizzas.length && i < 2; i++) {
          final String sectionName = 'Pizza (12") ${i + 1}';
          final String pizzaInfo = pizzas[i];

          final RegExp regExp = RegExp(r'^(.+?)\s*\(Crust:\s*(.+?)\)$');
          final Match? match = regExp.firstMatch(pizzaInfo);
          if (match != null) {
            final String pizzaName = match.group(1)?.trim() ?? pizzaInfo.trim();
            final String crustType = match.group(2)?.trim() ?? 'Normal';
            _dealSelections[sectionName] = pizzaName;
            _dealSelections['$sectionName - Crust'] = crustType;
          } else {
            _dealSelections[sectionName] = pizzaInfo.trim();
            _dealSelections['$sectionName - Crust'] ??= 'Normal';
          }
        }
      } else if (trimmedOption.startsWith('Can 1:')) {
        final String value = trimmedOption.substring('Can 1:'.length).trim();
        if (value.isNotEmpty) {
          _dealSelections['Drinks - Can 1'] = value;
        }
      } else if (trimmedOption.startsWith('Can 2:')) {
        final String value = trimmedOption.substring('Can 2:'.length).trim();
        if (value.isNotEmpty) {
          _dealSelections['Drinks - Can 2'] = value;
        }
      }
    }

    for (int i = 1; i <= 2; i++) {
      final String crustKey = 'Pizza (12") $i - Crust';
      _dealSelections[crustKey] ??= 'Normal';
    }

    _selectedDealCategory = 'Pizza (12") 1';
  }

  double _calculatePricePerUnit() {
    debugPrint("--- Calculating Price for ${widget.foodItem.name} ---");
    debugPrint("Food Item Price Map: ${widget.foodItem.effectivePosPrice}");
    debugPrint("Selected Size: $_selectedSize");
    debugPrint("Selected Base: $_selectedBase");
    debugPrint("Selected Crust: $_selectedCrust");
    debugPrint("Selected Toppings: $_selectedToppings");
    debugPrint("Selected Sauces: $_selectedSauces");

    double price = 0.0;

    if (_selectedSize != null &&
        widget.foodItem.effectivePosPrice.containsKey(_selectedSize)) {
      price = widget.foodItem.effectivePosPrice[_selectedSize] ?? 0.0;
    } else if (widget.foodItem.effectivePosPrice.keys.length == 1 &&
        widget.foodItem.effectivePosPrice.isNotEmpty) {
      price = widget.foodItem.effectivePosPrice.values.first;
    } else {
      debugPrint("No valid size selected or price not found");
      return 0.0;
    }

    debugPrint("Base price: $price");

    if (widget.foodItem.category == 'Pizza' ||
        widget.foodItem.category == 'GarlicBread' ||
        widget.foodItem.category == 'Burgers') {
      // Calculate topping costs
      double toppingCost = 0.0;

      // Special logic for "Create your own pizza" - first 4 toppings are free
      String itemNameLower = widget.foodItem.name.toLowerCase();
      bool isCreateYourOwnPizza =
          (widget.foodItem.category == 'Pizza' ||
              widget.foodItem.category == 'GarlicBread') &&
          (itemNameLower.contains('create your own pizza') ||
              itemNameLower.contains('create your own') ||
              itemNameLower.contains('build your own') ||
              itemNameLower.contains('make your own') ||
              itemNameLower.contains('custom pizza'));

      debugPrint(
        "Pizza item: '${widget.foodItem.name}', Category: ${widget.foodItem.category}",
      );
      debugPrint("Item name lowercase: '$itemNameLower'");
      debugPrint("Is Create Your Own Pizza: $isCreateYourOwnPizza");

      if (isCreateYourOwnPizza) {
        // For "Create your own pizza", count all selected toppings and charge from 5th onwards
        int totalToppings = _selectedToppings.length;
        int chargeableToppings = totalToppings > 4 ? totalToppings - 4 : 0;

        // Calculate cost for toppings beyond the first 4
        for (int i = 0; i < chargeableToppings; i++) {
          if (_selectedSize == "10 inch") {
            toppingCost += 1.0;
          } else if (_selectedSize == "12 inch") {
            toppingCost += 1.5;
          } else if (_selectedSize == "18 inch") {
            toppingCost += 5.5;
          } else if (_selectedSize == "7 inch") {
            toppingCost += 1.0;
          } else if (_selectedSize == "9 inch") {
            toppingCost += 1.5;
          }
        }

        debugPrint(
          "Create your own pizza - Default toppings: ${widget.foodItem.defaultToppings}",
        );
        debugPrint(
          "Create your own pizza - Default cheese: ${widget.foodItem.defaultCheese}",
        );
        debugPrint(
          "Create your own pizza - Selected toppings: $_selectedToppings",
        );
        debugPrint(
          "Create your own pizza - Total toppings: $totalToppings, Chargeable: $chargeableToppings",
        );
        debugPrint("Create your own pizza: Topping cost = £$toppingCost");
      } else {
        // Standard logic for other pizzas/garlic bread/burgers: Charge for extra toppings based on size
        for (var topping in _selectedToppings) {
          bool isExtraTopping =
              !((widget.foodItem.defaultToppings ?? []).contains(topping) ||
                  (widget.foodItem.defaultCheese ?? []).contains(topping));

          if (isExtraTopping) {
            if (widget.foodItem.category == 'Burgers') {
              // For burgers, use burger size-based pricing (same as pizza 12 inch pricing)
              if (_selectedSize == "1/4 lb") {
                toppingCost += 1.0; // Same as 10 inch pizza
              } else if (_selectedSize == "1/2 lb") {
                toppingCost += 1.5; // Same as 12 inch pizza
              } else {
                toppingCost += 1.5; // Default for burgers
              }
            } else {
              // Pizza/GarlicBread pricing
              if (_selectedSize == "10 inch") {
                toppingCost += 1.0;
              } else if (_selectedSize == "12 inch") {
                toppingCost += 1.5;
              } else if (_selectedSize == "18 inch") {
                toppingCost += 5.5;
              } else if (_selectedSize == "7 inch") {
                toppingCost += 1.0;
              } else if (_selectedSize == "9 inch") {
                toppingCost += 1.5;
              }
            }
          }
        }
      }

      price += toppingCost;
      debugPrint("After toppings: $price (added: $toppingCost)");

      // Calculate base cost for Pizza and GarlicBread categories
      double baseCost = 0.0;
      if ((widget.foodItem.category == 'Pizza' ||
              widget.foodItem.category == 'GarlicBread') &&
          _selectedBase != null &&
          _selectedBase != "Tomato") {
        if (_selectedSize == "10 inch") {
          baseCost = 1.0;
        } else if (_selectedSize == "12 inch") {
          baseCost = 1.5;
        } else if (_selectedSize == "18 inch") {
          baseCost = 4.0;
        } else if (_selectedSize == "7 inch") {
          baseCost = 1.0;
        } else if (_selectedSize == "9 inch") {
          baseCost = 1.5;
        }
      }
      price += baseCost;
      debugPrint(
        "After base: $price (added: $baseCost). Selected base: $_selectedBase",
      );

      // Calculate crust cost for Pizza and GarlicBread categories
      double crustCost = 0.0;
      if ((widget.foodItem.category == 'Pizza' ||
              widget.foodItem.category == 'GarlicBread') &&
          _selectedCrust == "Stuffed") {
        if (_selectedSize == "10 inch") {
          crustCost = 1.5;
        } else if (_selectedSize == "12 inch") {
          crustCost = 2.5;
        } else if (_selectedSize == "18 inch") {
          crustCost = 4.5;
        } else if (_selectedSize == "7 inch") {
          crustCost = 1.5;
        } else if (_selectedSize == "9 inch") {
          crustCost = 2.5;
        }
      }
      price += crustCost;
      debugPrint(
        "After crust: $price (added: $crustCost). Selected crust: $_selectedCrust",
      );

      // Calculate sauce costs for Pizza and GarlicBread categories
      double sauceCost = 0.0;
      if (widget.foodItem.category == 'Pizza' ||
          widget.foodItem.category == 'GarlicBread') {
        for (var sauce in _selectedSauces) {
          if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
            sauceCost += 0.75;
          } else {
            sauceCost += 0.5;
          }
        }
      }
      price += sauceCost;
      debugPrint("After sauces: $price (added: $sauceCost)");

      // Add meal pricing for Pizza and GarlicBread
      if (_makeItAMeal) {
        price += 1.9;
        debugPrint("After meal addition: $price");
      }
    } else if ([
      'Shawarma',
      'Wraps',
      'Burgers',
    ].contains(widget.foodItem.category)) {
      // Sauces are now FREE for Burgers, Wraps, and Shawarmas - no sauce cost added
      debugPrint(
        "Sauces are free for ${widget.foodItem.category} - no cost added",
      );

      // Add topping costs for Burgers
      if (widget.foodItem.category == 'Burgers' &&
          _selectedToppings.isNotEmpty) {
        double toppingCost = 0.0;
        int toppingCount = _selectedToppings.length;

        // Calculate cost per topping based on burger size
        double costPerTopping;
        if (_selectedSize == "1/4 lb") {
          costPerTopping = 1.0; // Same as 10 inch pizza
        } else if (_selectedSize == "1/2 lb") {
          costPerTopping = 1.5; // Same as 12 inch pizza
        } else {
          costPerTopping = 1.5; // Default for burgers
        }

        toppingCost = toppingCount * costPerTopping;
        price += toppingCost;
        debugPrint(
          "Burger toppings: $toppingCount x £$costPerTopping = £$toppingCost, total price: $price",
        );
      }

      if (_makeItAMeal) {
        price += 1.9;
        debugPrint("After meal addition: $price");
      }
    } else if (widget.foodItem.category == 'Sides') {
      // Calculate sauce costs for Sides category
      double sauceCost = 0.0;
      for (var sauce in _selectedSauces) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") {
          sauceCost += 0.75;
        } else {
          sauceCost += 0.5;
        }
      }
      price += sauceCost;
      debugPrint("Sides sauce cost: $sauceCost, total price: $price");

      // Calculate seasoning costs for Sides category
      double seasoningCost = 0.0;
      if (_selectedChipSeasoning != null) {
        seasoningCost += 0.5; // Standard seasoning cost
      }
      price += seasoningCost;
      debugPrint("Sides seasoning cost: $seasoningCost, total price: $price");
    } else if (widget.foodItem.category == 'Deals' &&
        widget.foodItem.name.toLowerCase() == 'pizza offers') {
      // Calculate crust costs for Pizza Offers
      double crustCost = 0.0;

      // Check each pizza's crust selection
      for (int i = 1; i <= 3; i++) {
        String crustKey = 'Pizza $i - Crust';
        String? selectedCrust = _dealSelections[crustKey];

        if (selectedCrust == 'Stuffed') {
          // Use the same crust pricing as regular pizzas based on selected size
          if (_selectedSize == "10 inch") {
            crustCost += 1.5;
          } else if (_selectedSize == "12 inch") {
            crustCost += 2.5;
          } else if (_selectedSize == "18 inch") {
            crustCost += 4.5;
          } else if (_selectedSize == "7 inch") {
            crustCost += 1.5;
          } else if (_selectedSize == "9 inch") {
            crustCost += 2.5;
          }
        }
      }

      price += crustCost;
      debugPrint("Pizza Offers crust cost: $crustCost, total price: $price");
    } else if (widget.foodItem.category == 'Deals' &&
        widget.foodItem.name.toLowerCase() == 'wednesday special') {
      double crustCost = 0.0;

      for (int i = 1; i <= 2; i++) {
        String crustKey = 'Pizza (12") $i - Crust';
        String? selectedCrust = _dealSelections[crustKey];

        if (selectedCrust == 'Stuffed') {
          crustCost += 2.5;
        }
      }

      price += crustCost;
      debugPrint(
        "Wednesday Special crust cost: $crustCost, total price: $price",
      );
    }

    // Add extra charge if specified
    if (_extraChargeAmountController.text.isNotEmpty) {
      double extraCharge =
          double.tryParse(_extraChargeAmountController.text) ?? 0.0;
      if (extraCharge > 0) {
        price += extraCharge;
        debugPrint("Extra charge added: £$extraCharge");
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

  // NEW: Helper method to check if chip seasoning options should be shown
  bool _shouldShowChipSeasoningOptions() {
    // Show for "Make it a meal" options
    if (_makeItAMeal) return true;

    // Show for ALL items in sides category (not just chips/fries)
    if (widget.foodItem.category == 'Sides') {
      return true;
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

    // Show for other deals but NOT for specific deals that don't need chips seasoning
    if (widget.foodItem.category == 'Deals') {
      String dealName = widget.foodItem.name.toLowerCase();
      if (dealName == 'shawarma deal' ||
          dealName == 'family meal' ||
          dealName == 'combo meal' ||
          dealName == 'pizza offers' ||
          dealName == 'wednesday special') {
        return false; // These deals don't need chips seasoning
      }
      // For other deals that might have chips, return true
      return true;
    }

    return false;
  }

  // NEW: Helper method to check if sauce options should be shown for Sides category
  bool _shouldShowSaucesForSides() {
    return widget.foodItem.category == 'Sides';
  }

  void _confirmSelection() {
    if (widget.foodItem.effectivePosPrice.keys.length > 1 &&
        _selectedSize == null) {
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

    if ((_makeItAMeal || kidsMealNeedsDrink) && _selectedDrink == null) {
      CustomPopupService.show(
        context,
        'Please select a drink for your meal',
        type: PopupType.failure,
      );
      return;
    }

    if ((_drinkFlavors.containsKey(widget.foodItem.name) &&
            _selectedDrinkFlavor == null) ||
        (_makeItAMeal &&
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
        widget.foodItem.effectivePosPrice.keys.length > 1 &&
        widget.foodItem.category != 'Deals') {
      selectedOptions.add('Size: $_selectedSize');
    }

    if (_selectedToppings.isNotEmpty) {
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
        // For Burgers and other items, show all selected toppings
        selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
      }
    }

    if (_selectedBase != null &&
        (widget.foodItem.category == 'Pizza' ||
            widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Base: $_selectedBase');
    }

    if (_selectedCrust != null &&
        _selectedCrust != 'Normal' &&
        (widget.foodItem.category == 'Pizza' ||
            widget.foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }

    if (_selectedSauces.isNotEmpty &&
        !_noSauce &&
        (widget.foodItem.category == 'Pizza' ||
            widget.foodItem.category == 'GarlicBread' ||
            widget.foodItem.category == 'Burgers' ||
            widget.foodItem.category == 'Shawarma' ||
            widget.foodItem.category == 'Wraps' ||
            widget.foodItem.category == 'Sides')) {
      // Use "Sauce Dip:" for Pizza and Garlic Bread, "Sauce:" for others
      String sauceLabel =
          (widget.foodItem.category == 'Pizza' ||
                  widget.foodItem.category == 'GarlicBread')
              ? 'Sauce Dip'
              : 'Sauce';
      selectedOptions.add('$sauceLabel: ${_selectedSauces.join(', ')}');
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
    } else if (widget.foodItem.category == 'KidsMeal' &&
        _selectedDrink != null) {
      // Kids Meal drink selection (without "Make it a meal" label)
      String drinkOption = 'Drink: $_selectedDrink';
      if (_selectedDrinkFlavor != null) {
        drinkOption += ' ($_selectedDrinkFlavor)';
      }
      selectedOptions.add(drinkOption);
    } else if (_drinkFlavors.containsKey(widget.foodItem.name) &&
        _selectedDrinkFlavor != null) {
      selectedOptions.add('Flavor: $_selectedDrinkFlavor');
    }

    // NEW: Add chip seasoning option
    if (_selectedChipSeasoning != null && _shouldShowChipSeasoningOptions()) {
      String seasoningLabel =
          widget.foodItem.category == 'Sides'
              ? 'Seasoning: $_selectedChipSeasoning'
              : 'Chips Seasoning: $_selectedChipSeasoning';
      selectedOptions.add(seasoningLabel);
    }

    // Only apply salad/sauce logic to regular items, NOT deals
    if (['Shawarma', 'Wraps', 'Burgers'].contains(widget.foodItem.category) &&
        widget.foodItem.category != 'Deals') {
      if (_saladChoice == 'No') {
        selectedOptions.add('No Salad');
      } else if (_saladChoice == 'Yes' && _selectedSaladOptions.isNotEmpty) {
        selectedOptions.add('Salad: ${_selectedSaladOptions.join(', ')}');
      }
      if (_noSauce && _selectedSauces.isEmpty) selectedOptions.add('No Sauce');
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
            } else if (sectionName.contains(' - Chips Seasoning')) {
              // Skip chips seasoning here - will be added in correct order later
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
          List<String> salads =
              (details['salads'] as List<dynamic>?)?.cast<String>() ?? [];
          String sauceChoice = details['sauceChoice'] ?? '';
          List<String> sauces =
              (details['sauces'] as List<dynamic>?)?.cast<String>() ?? [];

          List<String> detailParts = [];

          // Handle salad section
          if (saladChoice == 'Yes' && salads.isNotEmpty) {
            detailParts.add('Salad: ${salads.join(', ')}');
          } else {
            detailParts.add('No Salad');
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

        // Add chips seasoning in correct order (1 then 2)
        String chipsKey1 = 'Drink & seasoning - Chips Seasoning 1';
        String chipsKey2 = 'Drink & seasoning - Chips Seasoning 2';

        if (_dealSelections[chipsKey1] != null) {
          selectedOptions.add(
            'Chips Seasoning 1: ${_dealSelections[chipsKey1]}',
          );
        }
        if (_dealSelections[chipsKey2] != null) {
          selectedOptions.add(
            'Chips Seasoning 2: ${_dealSelections[chipsKey2]}',
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
                List<String> salads =
                    (_dealMultiSelections['$sectionName - Salad Options'] ??
                            <String>{})
                        .toList();
                if (salads.isNotEmpty) {
                  detailParts.add('Salad: ${salads.join(', ')}');
                } else {
                  detailParts.add('No Salad');
                }
              } else {
                detailParts.add('No Salad');
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
                List<String> salads =
                    (_dealMultiSelections['$sectionName - Salad Options'] ??
                            <String>{})
                        .toList();
                if (salads.isNotEmpty) {
                  detailParts.add('Salad: ${salads.join(', ')}');
                } else {
                  detailParts.add('No Salad');
                }
              } else {
                detailParts.add('No Salad');
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
                List<String> salads =
                    (_dealMultiSelections['$sectionName - Salad Options'] ??
                            <String>{})
                        .toList();
                if (salads.isNotEmpty) {
                  detailParts.add('Salad: ${salads.join(', ')}');
                } else {
                  detailParts.add('No Salad');
                }
              } else {
                detailParts.add('No Salad');
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
                List<String> salads =
                    (_dealMultiSelections['$sectionName - Salad Options'] ??
                            <String>{})
                        .toList();
                if (salads.isNotEmpty) {
                  detailParts.add('Salad: ${salads.join(', ')}');
                } else {
                  detailParts.add('No Salad');
                }
              } else {
                detailParts.add('No Salad');
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
      } else if (widget.foodItem.name.toLowerCase() == 'wednesday special') {
        List<String> formattedItems = [];
        formattedItems.add('Size : 12 Inch');

        List<String> selectedPizzas = [];
        for (int i = 1; i <= 2; i++) {
          String sectionName = 'Pizza (12") $i';
          String? selectedPizza = _dealSelections[sectionName];
          if (selectedPizza != null) {
            String? selectedCrust = _dealSelections['$sectionName - Crust'];
            if (selectedCrust != null && selectedCrust != 'Normal') {
              selectedPizzas.add('$selectedPizza (Crust: $selectedCrust)');
            } else {
              selectedPizzas.add(selectedPizza);
            }
          }
        }

        if (selectedPizzas.isNotEmpty) {
          formattedItems.add('Selected Pizzas: ${selectedPizzas.join(', ')}');
        }

        formattedItems.add('1 Garlic Bread');

        String? can1Selection = _dealSelections['Drinks - Can 1'];
        if (can1Selection != null && can1Selection.isNotEmpty) {
          formattedItems.add('Can 1: $can1Selection');
        }

        String? can2Selection = _dealSelections['Drinks - Can 2'];
        if (can2Selection != null && can2Selection.isNotEmpty) {
          formattedItems.add('Can 2: $can2Selection');
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
            !sizeDisplay.toLowerCase().contains('inch')) {
          sizeDisplay = '$sizeDisplay inch';
        }
        formattedItems.add('Size: $sizeDisplay');

        // Get all selected pizzas with crust information
        List<String> selectedPizzas = [];
        for (String sectionName in ['Pizza 1', 'Pizza 2', 'Pizza 3']) {
          String? selectedPizza = _dealSelections[sectionName];
          String? selectedCrust = _dealSelections['$sectionName - Crust'];

          if (selectedPizza != null) {
            // Only add crust info if it's NOT Normal (default)
            if (selectedCrust != null && selectedCrust != 'Normal') {
              selectedPizzas.add('$selectedPizza(Crust: $selectedCrust)');
            } else {
              selectedPizzas.add(selectedPizza);
            }
          }
        }

        if (selectedPizzas.isNotEmpty) {
          // Format with proper line spacing as specified
          String firstPizza =
              selectedPizzas.isNotEmpty ? selectedPizzas[0] : '';
          List<String> remainingPizzas =
              selectedPizzas.length > 1 ? selectedPizzas.sublist(1) : [];

          String pizzaText = 'Selected Pizzas: $firstPizza';
          for (String pizza in remainingPizzas) {
            pizzaText += '\n                 $pizza';
          }
          formattedItems.add(pizzaText);
        }

        // Get selected drink
        String? selectedDrink = _dealSelections['Drink (1.5L)'];
        if (selectedDrink != null) {
          formattedItems.add('Drink: $selectedDrink (1.5L)');
        }

        selectedOptions.addAll(formattedItems);
      } else if (widget.foodItem.name.toLowerCase() != 'pizza offers') {
        // Original logic for other deals (exclude Pizza Offers completely)
        _dealSelections.forEach((sectionName, selectedOption) {
          if (selectedOption != null) {
            // Skip crust selections - they should be handled within pizza formatting
            if (sectionName.contains(' - Crust')) {
              return; // Skip crust keys
            }

            if (sectionName == 'Pizza 1' ||
                sectionName == 'Pizza 2' ||
                sectionName == 'Pizza 3') {
              String groupKey = 'Selected Pizzas';
              groupedSelections[groupKey] ??= [];
              groupedSelections[groupKey]!.add(selectedOption);
            } else {
              selectedOptions.add('$sectionName: $selectedOption');
            }
          }
        });
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
          widget.foodItem.name.toLowerCase() != 'pizza offers') {
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

      // Add default items for specific deals
      if (widget.foodItem.name.toLowerCase() == 'shawarma deal') {
        selectedOptions.add('Fries: 2x Fries');
      }
    }

    // Add extra charge to selected options if specified
    double? extraCharge;
    String? extraChargeReason;
    if (_extraChargeAmountController.text.isNotEmpty) {
      extraCharge = double.tryParse(_extraChargeAmountController.text);
      if (extraCharge != null && extraCharge > 0) {
        extraChargeReason = _extraChargeReasonController.text.trim();
        if (extraChargeReason.isEmpty) {
          extraChargeReason = 'Extra charge';
        }
        // Add to selected options for display
        selectedOptions.add(
          'Extra Charge: £${extraCharge.toStringAsFixed(2)} ($extraChargeReason)',
        );
      }
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
    // Define salad options (same as used in deals category)
    List<String> saladOptions = [
      'Full Salad',
      'Cucumber',
      'Lettuce',
      'Onions',
      'Tomato',
      'Red Cabbage',
    ];

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
                    // Clear selected salad options when No is selected
                    _selectedSaladOptions.clear();
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

        // Show salad options when Yes is selected
        if (_saladChoice == 'Yes') ...[
          const SizedBox(height: 15),
          const Text(
            'Salad Options:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children:
                saladOptions.map((salad) {
                  final bool isSelected = _selectedSaladOptions.contains(salad);
                  return _buildOptionButton(
                    title: salad,
                    isActive: isSelected,
                    onTap: () {
                      setState(() {
                        // Special handling for Full Salad option
                        if (salad == 'Full Salad') {
                          if (isSelected) {
                            // If Full Salad is currently selected and clicked again, deselect it
                            _selectedSaladOptions.remove(salad);
                          } else {
                            // If Full Salad is clicked, clear all other salad options and select only Full Salad
                            _selectedSaladOptions.clear();
                            _selectedSaladOptions.add(salad);
                          }
                        } else if ([
                          'Cucumber',
                          'Lettuce',
                          'Onions',
                          'Tomato',
                          'Red Cabbage',
                        ].contains(salad)) {
                          // If any other salad option is clicked, remove Full Salad if it's selected
                          _selectedSaladOptions.remove('Full Salad');

                          // Then handle normal toggle logic for the clicked salad option
                          if (isSelected) {
                            _selectedSaladOptions.remove(salad);
                          } else {
                            _selectedSaladOptions.add(salad);
                          }
                        } else {
                          // Normal toggle logic for any other options (shouldn't happen in this context)
                          if (isSelected) {
                            _selectedSaladOptions.remove(salad);
                          } else {
                            _selectedSaladOptions.add(salad);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  // --- NEW: Kids Meal options widget ---
  Widget _buildKidsMealOptions() {
    bool hasChips =
        widget.foodItem.name.toLowerCase().contains('chips') ||
        widget.foodItem.name.toLowerCase().contains('fries');
    bool hasDrink = widget.foodItem.name.toLowerCase().contains('drink');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show drinks only if the meal contains 'drink' in name
        if (hasDrink) ...[_buildDrinkSelectionSection()],

        // Show chip seasoning if the meal contains chips/fries
        if (hasChips) ...[
          if (hasDrink) const SizedBox(height: 20),
          _buildChipSeasoningSection(),
        ],
      ],
    );
  }

  // --- NEW: Sides options widget for sauces and seasoning ---
  Widget _buildSidesOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sauce options section
        if (_shouldShowSaucesForSides()) ...[
          _buildSauceOptionsForCategory(),
          const SizedBox(height: 20),
        ],

        // Seasoning options section
        _buildChipSeasoningSection(),
      ],
    );
  }

  // --- NEW: Chip seasoning selection widget ---
  Widget _buildChipSeasoningSection() {
    if (!_shouldShowChipSeasoningOptions()) {
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
        Text(
          widget.foodItem.category == 'Sides'
              ? 'Seasoning:'
              : 'Chips Seasoning:',
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
              _chipSeasoningOptions.map((seasoning) {
                final bool isActive = _selectedChipSeasoning == seasoning;
                return SizedBox(
                  width: idealItemWidth,
                  child: _buildOptionButton(
                    title: seasoning,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        // Toggle selection - allow deselection
                        _selectedChipSeasoning = isActive ? null : seasoning;
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Build toppings section specifically for Burgers
  Widget _buildBurgerToppingsSection() {
    const List<String> burgerToppings = ['Donner', 'Shawarma'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extra Toppings:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 12.0,
          runSpacing: 15,
          children:
              burgerToppings.map((topping) {
                final isSelected = _selectedToppings.contains(topping);

                return _buildOptionButton(
                  title: topping,
                  isActive: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedToppings.remove(topping);
                      } else {
                        _selectedToppings.add(topping);
                      }
                      _updatePriceDisplay();
                    });
                  },
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
                        _selectedChipSeasoning = null; // Reset chip seasoning
                      }
                      _updatePriceDisplay();
                    });
                  },
                ),
              ),
              const SizedBox(width: 15),
              // Salad
              Expanded(child: _buildSaladOption()),
              const SizedBox(width: 15),
              // No Sauce
              Expanded(
                child: _buildOptionButton(
                  title: 'No Sauce',
                  isActive: _noSauce,
                  onTap: () {
                    setState(() {
                      _noSauce = !_noSauce;
                      if (_noSauce) {
                        // Clear all selected sauces when "No Sauce" is selected
                        _selectedSauces.clear();
                      }
                      _updatePriceDisplay();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_makeItAMeal) ...[
            const SizedBox(height: 20),
            _buildDrinkSelectionSection(),
          ],
          // NEW: Add chip seasoning section
          _buildChipSeasoningSection(),
        ],
      ),
    );
  }

  // --- Pizza-specific meal options (only Make it a Meal) ---
  Widget _buildPizzaMealOptions() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Only Make it a Meal button for Pizza category
          _buildOptionButton(
            title: 'Make it a Meal',
            isActive: _makeItAMeal,
            onTap: () {
              setState(() {
                _makeItAMeal = !_makeItAMeal;
                if (!_makeItAMeal) {
                  _selectedDrink = null;
                  _selectedDrinkFlavor = null;
                  _selectedChipSeasoning = null; // Reset chip seasoning
                }
                _updatePriceDisplay();
              });
            },
          ),
          if (_makeItAMeal) ...[
            const SizedBox(height: 20),
            _buildDrinkSelectionSection(),
          ],
          // Add chip seasoning section
          _buildChipSeasoningSection(),
        ],
      ),
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
              _allDrinks.map((drink) {
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

  // --- Add Extra Section ---
  Widget _buildAddExtraSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Row(
        children: [
          const Text(
            'Add Extra:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _extraChargeAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: '£',
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                filled: true,
                fillColor: Colors.grey[800],
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _updatePriceDisplay();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _extraChargeReasonController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                hintText: 'e.g., Extra toppings',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                filled: true,
                fillColor: Colors.grey[800],
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
        _buildChipSeasoningSection(),
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
    if ((widget.foodItem.effectivePosPrice.keys.length > 1 &&
            _selectedSize == null) ||
        (_makeItAMeal && _selectedDrink == null) ||
        (kidsMealNeedsDrinkForValidation && _selectedDrink == null) ||
        (_makeItAMeal &&
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

    // Burger validation (for regular Burgers category, not deals)
    if (widget.foodItem.category == 'Burgers') {
      // Check if sauce is selected (including "No Sauce")
      bool sauceSelected = _selectedSauces.isNotEmpty || _noSauce;

      // If no sauce is selected, validation fails
      if (!sauceSelected) {
        canConfirmSelection = false;
        debugPrint("🔍 BURGER VALIDATION FAILED: No sauce option selected");
      }

      debugPrint(
        "🔍 BURGER VALIDATION: sauceSelected=$sauceSelected, canConfirm=$canConfirmSelection",
      );
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

            // If Salad Yes is selected, check if at least one salad option is selected
            if (_dealSelections[saladYesNoKey] == 'Yes') {
              String saladOptionsKey = '$shawarmaKey - Salad Options';
              print(
                '🔍 VALIDATION CHECK: $saladOptionsKey = ${_dealMultiSelections[saladOptionsKey]}',
              );
              if (_dealMultiSelections[saladOptionsKey] == null ||
                  _dealMultiSelections[saladOptionsKey]!.isEmpty) {
                print(
                  '🔍 VALIDATION FAILED: Salad options not selected for $shawarmaKey',
                );
                canConfirmSelection = false;
                break;
              }
            }

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

              // If Salad Yes selected, check if salad options are selected
              if (_dealSelections[saladKey] == 'Yes') {
                String saladOptionsKey = '$sectionName - Salad Options';
                if (_dealMultiSelections[saladOptionsKey] == null ||
                    _dealMultiSelections[saladOptionsKey]!.isEmpty) {
                  print(
                    '🔍 VALIDATION FAILED: Salad options not selected for $sectionName',
                  );
                  canConfirmSelection = false;
                  break;
                }
              }

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

              // If Salad Yes selected, check if salad options are selected
              if (_dealSelections[saladKey] == 'Yes') {
                String saladOptionsKey = '$sectionName - Salad Options';
                if (_dealMultiSelections[saladOptionsKey] == null ||
                    _dealMultiSelections[saladOptionsKey]!.isEmpty) {
                  print(
                    '🔍 VALIDATION FAILED: Salad options not selected for $sectionName',
                  );
                  canConfirmSelection = false;
                  break;
                }
              }

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
        } else if (widget.foodItem.name.toLowerCase() == 'wednesday special') {
          bool bothPizzasSelected =
              _dealSelections['Pizza (12") 1'] != null &&
              _dealSelections['Pizza (12") 2'] != null;

          bool bothCansSelected =
              (_dealSelections['Drinks - Can 1'] != null &&
                  _dealSelections['Drinks - Can 2'] != null) ||
              _dealSelections['Drinks'] != null ||
              _dealMultiSelections['Drinks']?.isNotEmpty == true;

          if (!bothPizzasSelected || !bothCansSelected) {
            canConfirmSelection = false;
          } else {
            _dealSelections['Pizza (12") 1 - Crust'] ??= 'Normal';
            _dealSelections['Pizza (12") 2 - Crust'] ??= 'Normal';
            if (_dealSelections['Drinks - Can 1'] == null &&
                _dealSelections['Drinks'] != null) {
              final selectedDrinks =
                  _dealMultiSelections['Drinks']?.toList() ??
                  (_dealSelections['Drinks'] != null
                      ? [_dealSelections['Drinks']!]
                      : <String>[]);
              if (selectedDrinks.isNotEmpty) {
                _dealSelections['Drinks - Can 1'] = selectedDrinks[0];
              }
              if (selectedDrinks.length > 1) {
                _dealSelections['Drinks - Can 2'] = selectedDrinks[1];
              }
            }
          }
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
      "Price keys length for rendering: ${widget.foodItem.effectivePosPrice.keys.length}",
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
                      // Add Extra section - always shown at the top
                      _buildAddExtraSection(),

                      if (!_sizeHasBeenSelected) ...[
                        _buildQuantityControlOnly(),
                      ],

                      if (_drinkFlavors.containsKey(widget.foodItem.name)) ...[
                        _buildFlavorSelectionSection(widget.foodItem.name),
                        // NEW: Add chip seasoning for drinks with flavors that might have chips
                        _buildChipSeasoningSection(),
                      ],

                      if (widget.foodItem.category == 'Pizza' ||
                          widget.foodItem.category == 'GarlicBread') ...[
                        _buildOptionCategoryButtons(),
                        _buildSelectedOptionDisplay(),
                        const SizedBox(height: 20),
                        _buildPizzaMealOptions(),
                      ],

                      if ([
                        'Shawarma',
                        'Wraps',
                        'Burgers',
                      ].contains(widget.foodItem.category)) ...[
                        _buildMealAndExclusionOptions(),
                        const SizedBox(height: 20),
                        _buildSauceOptionsForCategory(),
                        // Add toppings section specifically for Burgers
                        if (widget.foodItem.category == 'Burgers') ...[
                          const SizedBox(height: 20),
                          _buildBurgerToppingsSection(),
                        ],
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
                        // NEW: Add chip seasoning for deals
                        _buildChipSeasoningSection(),
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
                widget.foodItem.effectivePosPrice.keys.map((sizeKeyFromData) {
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
    final List<String> categories = ['Toppings', 'Base', 'Crust', 'Sauce Dips'];

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
    List<String> availableToppings;

    // Filter toppings based on category
    if (widget.foodItem.category == 'Burgers') {
      // For Burgers, only show Donner and Shawarma
      availableToppings = ['Donner', 'Shawarma'];
    } else {
      // For other categories, use all toppings
      availableToppings = List.from(_allToppings);
    }

    availableToppings.sort((a, b) {
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
        return _buildToppingsDisplay(availableToppings);
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

  Widget _buildBaseDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 15,
          runSpacing: 15,
          alignment: WrapAlignment.start,
          children:
              _allBases.map((base) {
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
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isActive || isTomato)
                              ? Colors.grey[100]
                              : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      base,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            (isActive || isTomato)
                                ? Colors.black
                                : Colors.white,
                        fontSize: 18,
                        fontWeight:
                            isTomato && isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
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

    // Special handling for Family Meal and Combo Meal
    if (widget.foodItem.name.toLowerCase() == 'family meal' ||
        widget.foodItem.name.toLowerCase() == 'combo meal') {
      return _buildFamilyComboMealTabContent(
        _selectedDealCategory,
        dealOptions,
      );
    }

    // Special handling for Wednesday Special
    if (widget.foodItem.name.toLowerCase() == 'wednesday special') {
      return _buildWednesdaySpecialTabContent(
        _selectedDealCategory,
        dealOptions,
      );
    }

    // Special handling for Pizza Offers - show pizza selection and crust options together
    if (widget.foodItem.name.toLowerCase() == 'pizza offers') {
      return _buildPizzaOffersTabContent(_selectedDealCategory, dealOptions);
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

    // Define the salad and sauce options
    List<String> saladOptions = [
      'Full Salad',
      'Cucumber',
      'Lettuce',
      'Onions',
      'Tomato',
      'Red Cabbage',
    ];
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

        // Show salad options if Yes is selected
        if (hasSalad) ...[
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(saladOptions, '$tabName - Salad Options'),
        ],

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

    // Define the seasoning options for chips
    List<String> seasoningChoices = [
      'No Seasoning',
      'White Salt',
      'Red Salt',
      'Vinegar',
      'Salt and Vinegar',
    ];

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

        // Chips Seasoning 1 section
        const Text(
          'Chips Seasoning 1:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildToppingsStyleGrid(
          seasoningChoices,
          '$tabName - Chips Seasoning 1',
        ),
        const SizedBox(height: 25),

        // Chips Seasoning 2 section
        const Text(
          'Chips Seasoning 2:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildToppingsStyleGrid(
          seasoningChoices,
          '$tabName - Chips Seasoning 2',
        ),
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

    // Define salad options (same as Shawarma Deal)
    List<String> saladOptions = [
      'Full Salad',
      'Cucumber',
      'Lettuce',
      'Onions',
      'Tomato',
      'Red Cabbage',
    ];

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

          // Show salad options if Yes is selected
          if (hasSalad) ...[
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(
              saladOptions,
              '$validationKey - Salad Options',
            ),
          ],

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

          // Show salad options if Yes is selected
          if (hasSalad) ...[
            const SizedBox(height: 15),
            _buildToppingsStyleGrid(
              saladOptions,
              '$validationKey - Salad Options',
            ),
          ],

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
          'Coke',
          'Pepsi',
          '7Up',
          'Fanta',
          'Sprite',
          "Irn Bru",
          "Rubicon Mango",
          "Caprisun",
          "Water",
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

  // Build Pizza Offers tab content - shows pizza selection and crust options together
  Widget _buildPizzaOffersTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    List<String> options = dealOptions[tabName] ?? [];

    // Check if this is a pizza tab or drink tab
    bool isPizzaTab = tabName.startsWith('Pizza ');

    if (isPizzaTab) {
      String crustKey = '$tabName - Crust';
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
          _buildToppingsStyleGrid(options, tabName),
          const SizedBox(height: 25),

          // Crust selection
          const Text(
            'Select Crust:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(['Normal', 'Stuffed'], crustKey),
        ],
      );
    } else {
      // For drink tab - no crust options
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tabName.contains('Drink') ? 'Select Drink:' : 'Select $tabName:',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(options, tabName),
        ],
      );
    }
  }

  Widget _buildWednesdaySpecialTabContent(
    String tabName,
    Map<String, List<String>> dealOptions,
  ) {
    const pizzaTabs = {'Pizza (12") 1', 'Pizza (12") 2'};
    if (pizzaTabs.contains(tabName)) {
      final options = dealOptions[tabName] ?? [];
      final crustKey = '$tabName - Crust';
      _dealSelections[crustKey] ??= 'Normal';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Pizza:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(options, tabName),
          const SizedBox(height: 25),
          const Text(
            'Select Crust:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(['Normal', 'Stuffed'], crustKey),
        ],
      );
    }

    if (tabName == 'Drinks') {
      const can1Key = 'Drinks - Can 1';
      const can2Key = 'Drinks - Can 2';
      final can1Options = dealOptions[can1Key] ?? _getCanDrinkOptionsFromMenu();
      final can2Options = dealOptions[can2Key] ?? _getCanDrinkOptionsFromMenu();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Can 1:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(can1Options, can1Key),
          const SizedBox(height: 25),
          const Text(
            'Select Can 2:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildToppingsStyleGrid(can2Options, can2Key),
        ],
      );
    }

    return _buildToppingsStyleGrid(dealOptions[tabName] ?? [], tabName);
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
    if (widget.foodItem.name.toLowerCase() == 'wednesday special') {
      return ['Pizza (12") 1', 'Pizza (12") 2', 'Drinks'];
    }
    // Return the actual deal keys as tabs (Pizza 1, Pizza (16"), Shawarma, etc.)
    return dealOptions.keys.toList();
  }

  Map<String, List<String>> _getDealOptions(String dealName) {
    // Get dynamic menu items
    final pizzaOptions = _getPizzaFlavoursFromMenu();
    final shawarmaOptions = _getShawarmaOptionsFromMenu();
    final burgerOptions = _getBurgerOptionsFromMenu();
    final calzoneOptions = _getCalzoneOptionsFromMenu();

    switch (dealName.toLowerCase()) {
      case 'family meal':
        // For Family Meal, include Garlic Bread items in Pizza tab
        final familyMealPizzaOptions = [...pizzaOptions];
        final garlicBreadOptions =
            widget.allFoodItems
                .where((item) => item.category == 'GarlicBread')
                .map((item) => item.name)
                .where((name) => name.isNotEmpty)
                .toList();
        familyMealPizzaOptions.addAll(garlicBreadOptions);
        familyMealPizzaOptions.sort(); // Sort alphabetically

        return {
          'Pizza (16")': familyMealPizzaOptions,
          'Shawarma': shawarmaOptions,
          'Burger': burgerOptions,
          'Calzone': calzoneOptions,
          'Drinks': [
            'Coke (1.5L)',
            'Pepsi (1.5L)',
            '7Up (1.5L)',
            'Fanta (1.5L)',
            'Sprite (1.5L)',
          ],
        };
      case 'combo meal':
        // For Combo Meal, include Garlic Bread items in Pizza tab
        final comboMealPizzaOptions = [...pizzaOptions];
        final garlicBreadOptions =
            widget.allFoodItems
                .where((item) => item.category == 'GarlicBread')
                .map((item) => item.name)
                .where((name) => name.isNotEmpty)
                .toList();
        comboMealPizzaOptions.addAll(garlicBreadOptions);
        comboMealPizzaOptions.sort(); // Sort alphabetically

        return {
          'Pizza (12")': comboMealPizzaOptions,
          'Shawarma': shawarmaOptions,
          'Burger': burgerOptions,
          'Drinks': ['Drink 1', 'Drink 2'],
        };
      case 'pizza offers':
        // For Pizza Offers, include Garlic Bread items in all Pizza tabs
        final pizzaOffersPizzaOptions = [...pizzaOptions];
        final garlicBreadOptions =
            widget.allFoodItems
                .where((item) => item.category == 'GarlicBread')
                .map((item) => item.name)
                .where((name) => name.isNotEmpty)
                .toList();
        pizzaOffersPizzaOptions.addAll(garlicBreadOptions);
        pizzaOffersPizzaOptions.sort(); // Sort alphabetically

        return {
          'Pizza 1': pizzaOffersPizzaOptions,
          'Pizza 2': pizzaOffersPizzaOptions,
          'Pizza 3': pizzaOffersPizzaOptions,
          'Drink (1.5L)': ['Coke', 'Pepsi', '7Up', 'Fanta', 'Sprite'],
        };
      case 'shawarma deal':
        final shawarmaOptionsForDeal = _getShawarmaOptionsForDeal();
        return {
          'Shawarma 1': shawarmaOptionsForDeal,
          'Shawarma 2': shawarmaOptionsForDeal,
          'Shawarma 3': shawarmaOptionsForDeal,
          'Shawarma 4': shawarmaOptionsForDeal,
          'Drink & seasoning': [
            'Coke (1.5L)',
            'Pepsi (1.5L)',
            '7Up (1.5L)',
            'Fanta (1.5L)',
            'Sprite (1.5L)',
          ],
        };
      case 'wednesday special':
        // Filter out items that should not be in Wednesday Special
        final wednesdayPizzaOptions =
            pizzaOptions.where((pizza) {
              final lowerName = pizza.toLowerCase();
              // Exclude "Create your own" and "4£ Pizza" (case-insensitive)
              return !lowerName.contains('create your own') &&
                  !lowerName.contains('4£') &&
                  !lowerName.contains('4 £');
            }).toList();
        final drinkOptions = _getCanDrinkOptionsFromMenu();
        return {
          'Pizza (12") 1': wednesdayPizzaOptions,
          'Pizza (12") 2': wednesdayPizzaOptions,
          'Drinks': drinkOptions,
        };
      default:
        return {};
    }
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
          'Sauce Options:',
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
          children: [
            // Add "No Sauce" option first
            SizedBox(
              width: idealItemWidth,
              child: _buildOptionButton(
                title: 'No Sauce',
                isActive: _noSauce,
                onTap: () {
                  setState(() {
                    _noSauce = !_noSauce;
                    if (_noSauce) {
                      // Clear all selected sauces when "No Sauce" is selected
                      _selectedSauces.clear();
                    }
                    _updatePriceDisplay();
                  });
                },
              ),
            ),
            // Add all regular sauce options
            ..._allSauces.map((sauce) {
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
          ],
        ),
      ],
    );
  }
}
