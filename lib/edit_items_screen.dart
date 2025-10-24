// lib/edit_items_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/item_availability_provider.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/services/custom_popup_service.dart';

class EditItemsScreen extends StatefulWidget {
  const EditItemsScreen({Key? key}) : super(key: key);

  @override
  State<EditItemsScreen> createState() => _EditItemsScreenState();
}

class _EditItemsScreenState extends State<EditItemsScreen> {
  String _selectedCategory = 'Pizza';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showAddItemModal = false;
  bool _isEditMode = false; // Track if we're in edit mode
  FoodItem? _editingItem; // Store the item being edited
  bool _isSubmitting = false; // Track if form is being submitted

  // Add item form variables
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _addItemSelectedCategory = '';
  String? _addItemSelectedSubtype;
  bool _websiteEnabled = false;
  Map<String, double> _priceOptions = {};
  Map<String, TextEditingController> _priceControllers =
      {}; // Controllers for price fields
  Set<String> _selectedToppings = {};

  // Available toppings from food_item_details_model.dart
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
    "Chicken",
    "Chicken Tikka",
    "Olives",
    "Sausages",
    "Mozzarella",
    "Emmental",
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

  @override
  void initState() {
    super.initState();
    // Fetch items when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ItemAvailabilityProvider>(
        context,
        listen: false,
      ).fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    // Dispose all price controllers
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _getUniqueCategories(List<FoodItem> items) {
    final categories = items.map((item) => item.category).toSet().toList();
    categories.sort();
    // Ensure Pizza is first if it exists
    if (categories.contains('Pizza')) {
      categories.remove('Pizza');
      categories.insert(0, 'Pizza');
    }
    return categories;
  }

  String _getCategoryIcon(String categoryName) {
    final normalized = categoryName.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );

    const iconMap = {
      'DEALS': 'assets/images/DealS.png',
      'PIZZA': 'assets/images/PizzasS.png',
      'PIZZAS': 'assets/images/PizzasS.png',
      'CALZONE': 'assets/images/CalzonesS.png',
      'CALZONES': 'assets/images/CalzonesS.png',
      'SHAWARMA': 'assets/images/ShawarmaS.png',
      'SHAWARMAS': 'assets/images/ShawarmaS.png',
      'BURGER': 'assets/images/BurgersS.png',
      'BURGERS': 'assets/images/BurgersS.png',
      'GARLICBREAD': 'assets/images/GarlicBreadS.png',
      'GARLICBREADS': 'assets/images/GarlicBreadS.png',
      'WRAP': 'assets/images/WrapsS.png',
      'WRAPS': 'assets/images/WrapsS.png',
      'KIDSMEAL': 'assets/images/KidsMealS.png',
      'KIDSMEALS': 'assets/images/KidsMealS.png',
      'SIDE': 'assets/images/SidesS.png',
      'SIDES': 'assets/images/SidesS.png',
      'SIDEORDERS': 'assets/images/SidesS.png',
      'MILKSHAKE': 'assets/images/MilkshakeS.png',
      'MILKSHAKES': 'assets/images/MilkshakeS.png',
      'COFFEE': 'assets/images/Coffee.png',
      'COFFEES': 'assets/images/Coffee.png',
      'DRINK': 'assets/images/DrinksS.png',
      'DRINKS': 'assets/images/DrinksS.png',
      'COLDDRINKS': 'assets/images/DrinksS.png',
      'LASSI': 'assets/images/DrinksS.png',
      'DIP': 'assets/images/DipsS.png',
      'DIPS': 'assets/images/DipsS.png',
      'SAUCE': 'assets/images/DipsS.png',
      'SAUCES': 'assets/images/DipsS.png',
      'EXTRAS': 'assets/images/DipsS.png',
    };

    return iconMap[normalized] ?? 'assets/images/PizzasS.png';
  }

  List<FoodItem> _getFilteredItems(List<FoodItem> allItems) {
    List<FoodItem> filtered = allItems;

    // Apply search filter across all categories
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((item) {
            return item.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                item.category.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    }

    // Sort items: selected category items first, then others
    filtered.sort((a, b) {
      if (a.category == _selectedCategory && b.category != _selectedCategory) {
        return -1;
      } else if (a.category != _selectedCategory &&
          b.category == _selectedCategory) {
        return 1;
      } else if (a.category == _selectedCategory &&
          b.category == _selectedCategory) {
        return a.name.compareTo(b.name);
      } else {
        // Both are not in selected category, sort by category then name
        int categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare == 0) {
          return a.name.compareTo(b.name);
        }
        return categoryCompare;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Header with back button
                _buildHeader(),

                // Main content
                Expanded(
                  child: Consumer<ItemAvailabilityProvider>(
                    builder: (context, itemProvider, child) {
                      if (itemProvider.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        );
                      }

                      if (itemProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading items',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                itemProvider.error!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => itemProvider.fetchItems(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final allItems = itemProvider.allItems;
                      final categories = _getUniqueCategories(allItems);
                      final filteredItems = _getFilteredItems(allItems);

                      return Column(
                        children: [
                          // Header with category selector and search
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Category selector (left side)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value:
                                              categories.contains(
                                                    _selectedCategory,
                                                  )
                                                  ? _selectedCategory
                                                  : (categories.isNotEmpty
                                                      ? categories.first
                                                      : null),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                          items:
                                              categories.map((category) {
                                                return DropdownMenuItem<String>(
                                                  value: category,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 24,
                                                        height: 24,
                                                        child: Image.asset(
                                                          _getCategoryIcon(
                                                            category,
                                                          ),
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Icon(
                                                              Icons.category,
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade600,
                                                              size: 20,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        category,
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedCategory = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Search box (right side)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Search Items',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          style: TextStyle(color: Colors.black),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search across all categories...',
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.search,
                                              color: Colors.black,
                                            ),
                                            suffixIcon:
                                                _searchQuery.isNotEmpty
                                                    ? IconButton(
                                                      icon: Icon(
                                                        Icons.clear,
                                                        color: Colors.black,
                                                      ),
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        setState(() {
                                                          _searchQuery = '';
                                                        });
                                                      },
                                                    )
                                                    : null,
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _searchQuery = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Items list
                          Expanded(
                            child:
                                filteredItems.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 64,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No items found matching "$_searchQuery"'
                                                : 'No items available',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: filteredItems.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredItems[index];

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: 1,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                // Item image
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    color: Colors.grey.shade100,
                                                  ),
                                                  child:
                                                      item.image.isNotEmpty
                                                          ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.network(
                                                              item.image,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                  child: Image.asset(
                                                                    _getCategoryIcon(
                                                                      item.category,
                                                                    ),
                                                                    fit:
                                                                        BoxFit
                                                                            .contain,
                                                                    errorBuilder: (
                                                                      context,
                                                                      error,
                                                                      stackTrace,
                                                                    ) {
                                                                      return Icon(
                                                                        Icons
                                                                            .fastfood,
                                                                        color:
                                                                            Colors.grey.shade400,
                                                                      );
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          )
                                                          : ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.asset(
                                                              _getCategoryIcon(
                                                                item.category,
                                                              ),
                                                              fit:
                                                                  BoxFit
                                                                      .contain,
                                                              errorBuilder: (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return Icon(
                                                                  Icons
                                                                      .fastfood,
                                                                  color:
                                                                      Colors
                                                                          .grey
                                                                          .shade400,
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Item details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.name,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade200,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          item.category,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      if (item.description !=
                                                              null &&
                                                          item
                                                              .description!
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          item.description!,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Delete button
                                                GestureDetector(
                                                  onTap: () {
                                                    _deleteItem(item);
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.red,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Edit button
                                                GestureDetector(
                                                  onTap: () {
                                                    _openEditModal(item);
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.black,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.edit,
                                                      color: Colors.black,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Availability toggle
                                                Column(
                                                  children: [
                                                    Switch(
                                                      value: item.availability,
                                                      onChanged: (
                                                        bool newValue,
                                                      ) {
                                                        itemProvider
                                                            .updateItemAvailability(
                                                              context,
                                                              item.id,
                                                              newValue,
                                                            );
                                                      },
                                                      activeColor: Colors.green,
                                                      inactiveThumbColor:
                                                          Colors.red.shade300,
                                                      inactiveTrackColor:
                                                          Colors.red.shade100,
                                                    ),
                                                    Text(
                                                      item.availability
                                                          ? 'Available'
                                                          : 'Unavailable',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            item.availability
                                                                ? Colors
                                                                    .green
                                                                    .shade700
                                                                : Colors
                                                                    .red
                                                                    .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

            // Add Item Modal
            if (_showAddItemModal)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: SafeArea(
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.9,
                            height: MediaQuery.of(context).size.height * 0.8,
                            constraints: BoxConstraints(maxWidth: 600),
                            margin: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 50,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: _buildAddItemModal(),
                          ),
                          // Loading overlay
                          if (_isSubmitting)
                            Positioned.fill(
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 50,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                        strokeWidth: 3,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        _isEditMode
                                            ? 'Updating item...'
                                            : 'Adding item...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Edit Items title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Items',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Add Item button
          GestureDetector(
            onTap: _openAddModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemModal() {
    final availableCategories = _getAvailableCategoriesForAddItem();
    final fallbackCategory =
        availableCategories.isNotEmpty ? availableCategories.first : '';

    if ((_addItemSelectedCategory.isEmpty && fallbackCategory.isNotEmpty) ||
        (fallbackCategory.isNotEmpty &&
            _addItemSelectedCategory != fallbackCategory &&
            !availableCategories.contains(_addItemSelectedCategory))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _addItemSelectedCategory = fallbackCategory;
          _addItemSelectedSubtype = null;
          _priceOptions.clear();
          _selectedToppings.clear();
        });
      });
    }

    return Column(
      children: [
        // Header - Fixed
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isEditMode ? Icons.edit : Icons.add_circle,
                color: Colors.black,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                _isEditMode ? 'Edit Item' : 'Add New Item',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAddItemModal = false;
                    _isEditMode = false;
                    _editingItem = null;
                    _resetAddItemForm();
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),

        // Scrollable content - Expanded
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category dropdown
                _buildCategorySection(availableCategories),
                SizedBox(height: 16),

                // Subtype dropdown (conditional)
                if (_shouldShowSubtype()) ...[
                  _buildSubtypeSection(),
                  SizedBox(height: 16),
                ],

                // Item name
                _buildItemNameSection(),
                SizedBox(height: 16),

                // Description
                _buildDescriptionSection(),
                SizedBox(height: 16),

                // Price options
                _buildPriceSection(),
                SizedBox(height: 16),

                // Toppings (conditional)
                if (_shouldShowToppings()) ...[
                  _buildToppingsSection(),
                  SizedBox(height: 16),
                ],

                // Website checkbox
                _buildWebsiteSection(),
                SizedBox(height: 24),

                // Action buttons
                _buildActionButtons(),
                SizedBox(height: 20), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getAvailableCategoriesForAddItem() {
    // Get all categories except 'Deals'
    final provider = Provider.of<ItemAvailabilityProvider>(
      context,
      listen: false,
    );
    final allCategories =
        provider.allItems.map((item) => item.category).toSet().toList();
    allCategories.removeWhere((category) => category.toLowerCase() == 'deals');
    allCategories.sort();

    // Ensure Pizza is first if it exists
    if (allCategories.contains('Pizza')) {
      allCategories.remove('Pizza');
      allCategories.insert(0, 'Pizza');
    }

    return allCategories;
  }

  void _resetAddItemForm() {
    _itemNameController.clear();
    _descriptionController.clear();
    final availableCategories = _getAvailableCategoriesForAddItem();
    if (availableCategories.isNotEmpty) {
      _addItemSelectedCategory = availableCategories.first;
    } else {
      _addItemSelectedCategory = '';
    }
    _addItemSelectedSubtype = null;
    _websiteEnabled = false;
    _priceOptions.clear();
    _selectedToppings.clear();
    // Clear all price controllers
    for (var controller in _priceControllers.values) {
      controller.clear();
    }
  }

  void _openEditModal(FoodItem item) {
    setState(() {
      _isEditMode = true;
      _editingItem = item;
      _showAddItemModal = true;

      // Pre-fill form with item data
      _itemNameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _addItemSelectedCategory = item.category;
      _addItemSelectedSubtype = item.subType;
      // Note: FoodItem model doesn't include 'website' field, defaulting to true
      // The backend stores this but Flutter model doesn't expose it
      _websiteEnabled = true;
      _priceOptions = Map<String, double>.from(item.price);
      _selectedToppings = Set<String>.from(item.defaultToppings ?? []);
    });
  }

  void _openAddModal() {
    setState(() {
      _isEditMode = false;
      _editingItem = null;
      _showAddItemModal = true;
      _resetAddItemForm();
    });
  }

  bool _shouldShowSubtype() {
    return _getSubtypesForCategory(_addItemSelectedCategory).isNotEmpty;
  }

  bool _shouldShowToppings() {
    return _addItemSelectedCategory == 'Pizza' ||
        _addItemSelectedCategory == 'GarlicBread';
  }

  Widget _buildCategorySection(List<String> availableCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: DropdownButtonFormField<String>(
            value:
                availableCategories.contains(_addItemSelectedCategory)
                    ? _addItemSelectedCategory
                    : (availableCategories.isNotEmpty
                        ? availableCategories.first
                        : null),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items:
                availableCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          child: Image.asset(
                            _getCategoryIcon(category),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.category,
                                color: Colors.grey.shade600,
                                size: 20,
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          category,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _addItemSelectedCategory = newValue;
                  _addItemSelectedSubtype =
                      null; // Reset subtype when category changes
                  _priceOptions.clear(); // Reset price options
                  _selectedToppings.clear(); // Reset toppings
                });
              }
            },
          ),
        ),
      ],
    );
  }

  void _deleteItem(FoodItem item) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text(
            'Are you sure you want to delete "${item.name}"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _performDelete(item);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performDelete(FoodItem item) async {
    print('🗑️ Delete item requested: ${item.name} (ID: ${item.id})');

    try {
      // Call the provider's delete method
      final itemProvider = Provider.of<ItemAvailabilityProvider>(
        context,
        listen: false,
      );
      await itemProvider.deleteItem(context, item.id);

      // Success message is already shown by the provider
      print('🗑️ Item ${item.name} successfully removed from POS');
    } catch (e) {
      print('🗑️ Failed to delete item ${item.name}: $e');
      // Error message is already shown by the provider
    }
  }

  Widget _buildSubtypeSection() {
    List<String> subtypes = _getSubtypesForCategory(_addItemSelectedCategory);

    if (_addItemSelectedSubtype != null &&
        !subtypes.contains(_addItemSelectedSubtype)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _addItemSelectedSubtype = null;
          _priceOptions.clear();
        });
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subtype *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: DropdownButtonFormField<String>(
            value:
                subtypes.contains(_addItemSelectedSubtype)
                    ? _addItemSelectedSubtype
                    : null,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: 'Select subtype',
            ),
            items:
                subtypes.map((subtype) {
                  return DropdownMenuItem<String>(
                    value: subtype,
                    child: Text(subtype, style: TextStyle(color: Colors.black)),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _addItemSelectedSubtype = newValue;
                _priceOptions
                    .clear(); // Reset price options when subtype changes
              });
            },
          ),
        ),
      ],
    );
  }

  List<String> _getSubtypesForCategory(String category) {
    if (category.isEmpty) {
      return [];
    }

    final provider = Provider.of<ItemAvailabilityProvider>(
      context,
      listen: false,
    );
    final uniqueSubtypes = <String>{};

    for (final item in provider.allItems) {
      if (item.category == category) {
        final subtype = item.subType?.trim();
        if (subtype != null && subtype.isNotEmpty) {
          uniqueSubtypes.add(subtype);
        }
      }
    }

    final subtypeList = uniqueSubtypes.toList()..sort();
    return subtypeList;
  }

  Widget _buildItemNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Name *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: TextField(
            controller: _itemNameController,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Enter item name',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: TextField(
            controller: _descriptionController,
            style: TextStyle(color: Colors.black),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter item description (optional)',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    Map<String, double> defaultPrices = _getDefaultPricesForCategory();

    // Initialize or update controllers for each price option
    for (var key in defaultPrices.keys) {
      if (!_priceControllers.containsKey(key)) {
        // Create new controller
        _priceControllers[key] = TextEditingController();
      }

      // Update controller text with existing price
      // Check both exact match and case-insensitive match for existing prices
      if (_priceOptions.containsKey(key)) {
        _priceControllers[key]!.text = _priceOptions[key].toString();
      } else {
        // Try case-insensitive match for existing prices
        final matchingKey = _priceOptions.keys.firstWhere(
          (existingKey) => existingKey.toLowerCase() == key.toLowerCase(),
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          _priceControllers[key]!.text = _priceOptions[matchingKey].toString();
          // Also update _priceOptions with the correct key
          _priceOptions[key] = _priceOptions[matchingKey]!;
        } else {
          // Clear the controller if no matching price exists
          _priceControllers[key]!.text = '';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Options *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children:
                  defaultPrices.entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: _priceControllers[entry.key],
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: '${entry.value}',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  prefixText: '£',
                                  prefixStyle: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onChanged: (value) {
                                  double? price = double.tryParse(value);
                                  if (price != null) {
                                    _priceOptions[entry.key] = price;
                                  } else {
                                    _priceOptions.remove(entry.key);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, double> _getDefaultPricesForCategory() {
    if (_addItemSelectedCategory == 'Pizza' ||
        _addItemSelectedCategory == 'GarlicBread') {
      return {
        "10 inch": 6.99,
        "12 inch": 8.99,
        "16 inch": 13.99,
        "18 inch": 18.99,
      };
    } else if (_addItemSelectedCategory == 'Burgers') {
      return {"1/2 lb": 5.95, "1/4 lb": 3.99};
    } else if (_addItemSelectedCategory == 'Shawarma') {
      // Case-insensitive comparison for subtype
      final subtypeLower = _addItemSelectedSubtype?.toLowerCase() ?? '';
      if (subtypeLower.contains('donner') || subtypeLower.contains('kebab')) {
        // For "Donner & Shawarma kebab" - check if it's NOT a tray
        if (!subtypeLower.contains('tray')) {
          return {"Naan": 6.99, "Pitta": 4.99};
        }
      }
      // For "Shawarma & kebab tray" OR any tray subtype
      if (subtypeLower.contains('tray')) {
        return {"Large": 5.49, "Small": 4.49};
      }
    }
    return {"default": 0.0}; // For other categories - single price as "default"
  }

  Widget _buildToppingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toppings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _allToppings.map((topping) {
                    final isSelected = _selectedToppings.contains(topping);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedToppings.remove(topping);
                          } else {
                            _selectedToppings.add(topping);
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          topping,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebsiteSection() {
    return Row(
      children: [
        Checkbox(
          value: _websiteEnabled,
          onChanged: (bool? value) {
            setState(() {
              _websiteEnabled = value ?? false;
            });
          },
          activeColor: Colors.black,
        ),
        Text(
          'Available on Website',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showAddItemModal = false;
                _isEditMode = false;
                _editingItem = null;
                _resetAddItemForm();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Text(
                'Cancel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _isEditMode ? _submitEditItem : _submitAddItem,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isEditMode ? 'Update Item' : 'Add Item',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submitAddItem() async {
    // Validation
    if (_itemNameController.text.trim().isEmpty) {
      CustomPopupService.show(
        context,
        'Please enter item name',
        type: PopupType.failure,
      );
      return;
    }

    if (_shouldShowSubtype() && _addItemSelectedSubtype == null) {
      CustomPopupService.show(
        context,
        'Please select a subtype',
        type: PopupType.failure,
      );
      return;
    }

    if (_priceOptions.isEmpty) {
      CustomPopupService.show(
        context,
        'Please enter at least one price option',
        type: PopupType.failure,
      );
      return;
    }

    // Show loading
    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = Provider.of<ItemAvailabilityProvider>(
        context,
        listen: false,
      );

      // Transform price options for single-price items
      Map<String, double> finalPriceOptions;
      if (_priceOptions.length == 1 &&
          _priceOptions.keys.first.toLowerCase() == 'default') {
        // For single price items, use "default" key
        finalPriceOptions = {"default": _priceOptions.values.first};
      } else {
        // For multi-price items, use as-is
        finalPriceOptions = _priceOptions;
      }

      // Call the provider method to add the item
      await provider.addItem(
        context: context,
        itemName: _itemNameController.text.trim(),
        type: _addItemSelectedCategory, // Category as type
        description: _descriptionController.text.trim(),
        priceOptions: finalPriceOptions,
        toppings: _selectedToppings.toList(),
        website: _websiteEnabled,
        subtype: _addItemSelectedSubtype, // Pass subtype if selected
      );

      // Close modal and reset form
      setState(() {
        _isSubmitting = false;
        _showAddItemModal = false;
        _isEditMode = false;
        _editingItem = null;
        _resetAddItemForm();
      });

      CustomPopupService.show(
        context,
        'Item added successfully!',
        type: PopupType.success,
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      CustomPopupService.show(
        context,
        'Failed to add item: $e',
        type: PopupType.failure,
      );
    }
  }

  void _submitEditItem() async {
    // Validation
    if (_itemNameController.text.trim().isEmpty) {
      CustomPopupService.show(
        context,
        'Please enter item name',
        type: PopupType.failure,
      );
      return;
    }

    if (_shouldShowSubtype() && _addItemSelectedSubtype == null) {
      CustomPopupService.show(
        context,
        'Please select a subtype',
        type: PopupType.failure,
      );
      return;
    }

    if (_priceOptions.isEmpty) {
      CustomPopupService.show(
        context,
        'Please enter at least one price option',
        type: PopupType.failure,
      );
      return;
    }

    if (_editingItem == null) {
      CustomPopupService.show(
        context,
        'Error: No item selected for editing',
        type: PopupType.failure,
      );
      return;
    }

    // Show loading
    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = Provider.of<ItemAvailabilityProvider>(
        context,
        listen: false,
      );

      // Transform price options for single-price items
      Map<String, double> finalPriceOptions;
      if (_priceOptions.length == 1 &&
          _priceOptions.keys.first.toLowerCase() == 'default') {
        // For single price items, use "default" key
        finalPriceOptions = {"default": _priceOptions.values.first};
      } else {
        // For multi-price items, use as-is
        finalPriceOptions = _priceOptions;
      }
      // Call the provider method to update the item
      await provider.updateItem(
        context: context,
        itemId: _editingItem!.id,
        itemName: _itemNameController.text.trim(),
        type: _addItemSelectedCategory, // Category as type
        description: _descriptionController.text.trim(),
        priceOptions: finalPriceOptions,
        toppings: _selectedToppings.toList(),
        website: _websiteEnabled,
        availability: _editingItem!.availability,
        subtype: _addItemSelectedSubtype,
      );

      // Close modal and reset form
      setState(() {
        _isSubmitting = false;
        _showAddItemModal = false;
        _isEditMode = false;
        _editingItem = null;
        _resetAddItemForm();
      });

      CustomPopupService.show(
        context,
        'Item updated successfully!',
        type: PopupType.success,
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      CustomPopupService.show(
        context,
        'Failed to update item: $e',
        type: PopupType.failure,
      );
    }
  }
}
