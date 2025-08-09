// lib/providers/food_item_details_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/models/cart_item.dart';

// Helper extensions - Keep these if they are not defined elsewhere
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

class FoodItemDetailsProvider extends ChangeNotifier {
  // State variables
  late FoodItem _foodItem;
  late double _calculatedPricePerUnit;
  int _quantity = 1;
  String _selectedOptionCategory = 'Toppings';
  bool _isRemoveButtonPressed = false;
  bool _isAddButtonPressed = false;

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
    "Mushrooms", "Artichoke", "Carcioffi", "Onion", "Pepper", "Rocket", "Spinach", "Parsley", "Capers", "Oregano",
    "Egg", "Sweetcorn", "Chips", "Pineapple", "Chilli", "Basil", "Olives", "Sausages", "Mozzarella", "Emmental",
    "Taleggio", "Gorgonzola", "Brie", "Grana", "Red onion", "Red pepper", "Green chillies", "Buffalo mozzarella",
    "Fresh cherry tomatoes",
  ];

  final List<String> _allBases = ["BBQ", "Garlic", "Tomato"];
  final List<String> _allCrusts = ["Normal", "Stuffed"];
  final List<String> _allSauces = ["Mayo", "Ketchup", "Chilli sauce", "Sweet chilli", "Garlic Sauce"];
  final List<String> _allDrinks = ["Coca Cola", "7Up", "Diet Coca Cola", "Fanta", "Pepsi", "Sprite", "J20 GLASS BOTTLE"];

  final Map<String, List<String>> _drinkFlavors = {
    "J20 GLASS BOTTLE": ["Apple & Raspberry", "Apple & Mango", "Orange & Passion Fruit"],
  };

  // Getters to access the state
  FoodItem get foodItem => _foodItem;
  double get calculatedPricePerUnit => _calculatedPricePerUnit;
  int get quantity => _quantity;
  String get selectedOptionCategory => _selectedOptionCategory;
  bool get isRemoveButtonPressed => _isRemoveButtonPressed;
  bool get isAddButtonPressed => _isAddButtonPressed;
  String? get selectedSize => _selectedSize;
  Set<String> get selectedToppings => _selectedToppings;
  String? get selectedBase => _selectedBase;
  String? get selectedCrust => _selectedCrust;
  Set<String> get selectedSauces => _selectedSauces;
  bool get makeItAMeal => _makeItAMeal;
  String? get selectedDrink => _selectedDrink;
  String? get selectedDrinkFlavor => _selectedDrinkFlavor;
  bool get noSalad => _noSalad;
  bool get noSauce => _noSauce;
  bool get noCream => _noCream;
  bool get isInSizeSelectionMode => _isInSizeSelectionMode;
  bool get sizeHasBeenSelected => _sizeHasBeenSelected;
  TextEditingController get reviewNotesController => _reviewNotesController;
  List<String> get allToppings => _allToppings;
  List<String> get allBases => _allBases;
  List<String> get allCrusts => _allCrusts;
  List<String> get allSauces => _allSauces;
  List<String> get allDrinks => _allDrinks;
  Map<String, List<String>> get drinkFlavors => _drinkFlavors;

  // Initialization method to set the state based on the passed food item
  void initialize(FoodItem foodItem, CartItem? initialCartItem, bool isEditing) {
    _foodItem = foodItem;
    // Reset state if it's a new item or if we're not in edit mode
    if (!isEditing || initialCartItem == null) {
      _quantity = 1;
      _selectedSize = null;
      _selectedToppings = {};
      _selectedBase = null;
      _selectedCrust = null;
      _selectedSauces = {};
      _makeItAMeal = false;
      _selectedDrink = null;
      _selectedDrinkFlavor = null;
      _noSalad = false;
      _noSauce = false;
      _noCream = false;
      _reviewNotesController.text = '';
      _isAddButtonPressed = false;
      _isRemoveButtonPressed = false;


      bool requiresSizeSelection = ([
        'Pizza', 'GarlicBread', 'Shawarma', 'Wraps', 'Burgers', 'Chicken', 'Wings'
      ].contains(_foodItem.category) && _foodItem.price.keys.length > 1);

      if (requiresSizeSelection) {
        _isInSizeSelectionMode = true;
        _sizeHasBeenSelected = false;
      } else {
        if (_foodItem.price.keys.length == 1 && _foodItem.price.isNotEmpty) {
          _selectedSize = _foodItem.price.keys.first;
          _sizeHasBeenSelected = true;
        }
        _isInSizeSelectionMode = false;
      }

      if (_foodItem.category == 'Pizza' || _foodItem.category == 'GarlicBread') {
        _selectedBase = "Tomato";
        _selectedCrust = "Normal";
        _selectedToppings.addAll(_foodItem.defaultToppings ?? []);
        _selectedToppings.addAll(_foodItem.defaultCheese ?? []);
      }

      if (_drinkFlavors.containsKey(_foodItem.name)) {
        _selectedDrink = _foodItem.name;
        _selectedDrinkFlavor = null;
      }
    } else {
      // Logic for editing an existing item
      _quantity = initialCartItem.quantity;
      _reviewNotesController.text = initialCartItem.comment ?? '';
      _parseCartItemOptions(initialCartItem.selectedOptions);
      _isInSizeSelectionMode = false;
      _sizeHasBeenSelected = _selectedSize != null || (_foodItem.price.keys.length == 1 && _foodItem.price.isNotEmpty);
    }
    _updatePricePerUnit();
  }

  void _parseCartItemOptions(List<String>? selectedOptions) {
    if (selectedOptions == null) return;
    for (var option in selectedOptions) {
      String lowerOption = option.toLowerCase();
      if (lowerOption.startsWith('size:')) {
        _selectedSize = option.split(':').last.trim();
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
      } else if (lowerOption.startsWith('flavor:') && !_drinkFlavors.containsKey(_foodItem.name)) {
        _selectedDrinkFlavor = option.split(':').last.trim();
      }
    }
  }

  // State modification methods
  void incrementQuantity() {
    _quantity++;
    _updatePricePerUnit();
    notifyListeners();
  }

  void decrementQuantity() {
    if (_quantity > 1) {
      _quantity--;
      _updatePricePerUnit();
    }
    notifyListeners();
  }

  void changeSize() {
    _isInSizeSelectionMode = true;
    notifyListeners();
  }

  void onSizeSelected(String size) {
    _selectedSize = size;
    _sizeHasBeenSelected = true;
    _isInSizeSelectionMode = false;
    _updatePricePerUnit();
    notifyListeners();
  }

  void updateSelectedToppings(String topping, {bool isDefault = false}) {
    if (isDefault) return;
    if (_selectedToppings.contains(topping)) {
      _selectedToppings.remove(topping);
    } else {
      _selectedToppings.add(topping);
    }
    _updatePricePerUnit();
    notifyListeners();
  }

  void setSelectedOptionCategory(String category) {
    _selectedOptionCategory = category;
    notifyListeners();
  }

  void setSelectedBase(String base) {
    _selectedBase = base;
    _updatePricePerUnit();
    notifyListeners();
  }

  void setSelectedCrust(String crust) {
    _selectedCrust = crust;
    _updatePricePerUnit();
    notifyListeners();
  }

  void updateSelectedSauces(String sauce) {
    if (_selectedSauces.contains(sauce)) {
      _selectedSauces.remove(sauce);
    } else {
      _selectedSauces.add(sauce);
    }
    _updatePricePerUnit();
    notifyListeners();
  }

  void setMakeItAMeal(bool value) {
    _makeItAMeal = value;
    if (!value) {
      _selectedDrink = null;
      _selectedDrinkFlavor = null;
    }
    _updatePricePerUnit();
    notifyListeners();
  }

  void setSelectedDrink(String? value) {
    _selectedDrink = value;
    _selectedDrinkFlavor = null;
    notifyListeners();
  }

  void setSelectedDrinkFlavor(String? value) {
    _selectedDrinkFlavor = value;
    notifyListeners();
  }

  void setNoSalad(bool value) {
    _noSalad = value;
    notifyListeners();
  }

  void setNoSauce(bool value) {
    _noSauce = value;
    notifyListeners();
  }

  void setNoCream(bool value) {
    _noCream = value;
    notifyListeners();
  }

  void _updatePricePerUnit() {
    _calculatedPricePerUnit = _calculatePricePerUnit();
  }

  double _calculatePricePerUnit() {
    double price = 0.0;
    if (_selectedSize != null && _foodItem.price.containsKey(_selectedSize)) {
      price = _foodItem.price[_selectedSize] ?? 0.0;
    } else if (_foodItem.price.keys.length == 1 && _foodItem.price.isNotEmpty) {
      price = _foodItem.price.values.first;
    } else {
      return 0.0;
    }

    if (_foodItem.category == 'Pizza' || _foodItem.category == 'GarlicBread') {
      double toppingCost = 0.0;
      for (var topping in _selectedToppings) {
        if (!((_foodItem.defaultToppings ?? []).contains(topping) || (_foodItem.defaultCheese ?? []).contains(topping))) {
          if (_selectedSize == "10 inch" || _selectedSize == "7 inch") toppingCost += 1.0;
          else if (_selectedSize == "12 inch" || _selectedSize == "9 inch") toppingCost += 1.5;
          else if (_selectedSize == "18 inch") toppingCost += 5.5;
        }
      }
      price += toppingCost;

      double baseCost = 0.0;
      if (_selectedBase != null && _selectedBase != "Tomato") {
        if (_selectedSize == "10 inch" || _selectedSize == "7 inch") baseCost = 1.0;
        else if (_selectedSize == "12 inch" || _selectedSize == "9 inch") baseCost = 1.5;
        else if (_selectedSize == "18 inch") baseCost = 4.0;
      }
      price += baseCost;

      double crustCost = 0.0;
      if (_selectedCrust == "Stuffed") {
        if (_selectedSize == "10 inch" || _selectedSize == "7 inch") crustCost = 1.5;
        else if (_selectedSize == "12 inch" || _selectedSize == "9 inch") crustCost = 2.5;
        else if (_selectedSize == "18 inch") crustCost = 4.5;
      }
      price += crustCost;

      double sauceCost = 0.0;
      for (var sauce in _selectedSauces) {
        if (sauce == "Chilli sauce" || sauce == "Garlic Sauce") sauceCost += 0.75;
        else sauceCost += 0.5;
      }
      price += sauceCost;
    } else if (['Shawarma', 'Wraps', 'Burgers'].contains(_foodItem.category)) {
      if (_makeItAMeal) price += 1.9;
    }

    return price;
  }

  CartItem createCartItem() {
    final List<String> selectedOptions = [];
    if (_selectedSize != null && _foodItem.price.keys.length > 1) {
      selectedOptions.add('Size: $_selectedSize');
    }
    if (_selectedToppings.isNotEmpty) {
      selectedOptions.add('Toppings: ${_selectedToppings.join(', ')}');
    }
    if (_selectedBase != null && (_foodItem.category == 'Pizza' || _foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Base: $_selectedBase');
    }
    if (_selectedCrust != null && (_foodItem.category == 'Pizza' || _foodItem.category == 'GarlicBread')) {
      selectedOptions.add('Crust: $_selectedCrust');
    }
    if (_selectedSauces.isNotEmpty && (_foodItem.category == 'Pizza' || _foodItem.category == 'GarlicBread')) {
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
    } else if (_drinkFlavors.containsKey(_foodItem.name) && _selectedDrinkFlavor != null) {
      selectedOptions.add('Flavor: $_selectedDrinkFlavor');
    }
    if (['Shawarma', 'Wraps', 'Burgers'].contains(_foodItem.category)) {
      if (_noSalad) selectedOptions.add('No Salad');
      if (_noSauce) selectedOptions.add('No Sauce');
    }
    if (_foodItem.category == 'Milkshake') {
      if (_noCream) selectedOptions.add('No Cream');
    }
    final String userComment = _reviewNotesController.text.trim();
    return CartItem(
      foodItem: _foodItem,
      quantity: _quantity,
      selectedOptions: selectedOptions.isEmpty ? null : selectedOptions,
      comment: userComment.isNotEmpty ? userComment : null,
      pricePerUnit: _calculatedPricePerUnit,
    );
  }

  // Changed from private to public
  String getDisplaySize(String sizeKey) {
    final Map<String, Map<String, String>> categorySizeDisplayMap = {
      'Shawarma': {'naan': 'Large', 'pitta': 'Small'},
    };
    final Map<String, String>? currentCategoryMap = categorySizeDisplayMap[_foodItem.category];
    if (currentCategoryMap != null && currentCategoryMap.containsKey(sizeKey)) {
      return currentCategoryMap[sizeKey]!;
    } else if (sizeKey.toLowerCase().contains('inch')) {
      return '${sizeKey.split(' ')[0]}"';
    } else {
      return sizeKey.capitalize();
    }
  }

  void disposeProvider() {
    _reviewNotesController.dispose();
  }
}