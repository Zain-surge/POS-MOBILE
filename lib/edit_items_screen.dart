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

  // Add item form variables
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _addItemSelectedCategory = 'Pizza';
  String? _addItemSelectedSubtype;
  bool _websiteEnabled = false;
  Map<String, double> _priceOptions = {};
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
    switch (categoryName.toUpperCase()) {
      case 'DEALS':
        return 'assets/images/deals.png';
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMAS':
      case 'SHAWARMA':
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLICBREAD':
        return 'assets/images/GarlicBreadS.png';
      case 'WRAPS':
        return 'assets/images/WrapsS.png';
      case 'KIDSMEAL':
        return 'assets/images/KidsMealS.png';
      case 'SIDES':
        return 'assets/images/SidesS.png';
      case 'DRINKS':
        return 'assets/images/DrinksS.png';
      case 'MILKSHAKE':
        return 'assets/images/MilkshakeS.png';
      case 'DIPS':
        return 'assets/images/DipsS.png';
      case 'COFFEE':
        return 'assets/images/Coffee.png';
      case 'CAKE':
      case 'CAKES':
      case 'DESSERTS':
        return 'assets/images/Desserts.png';
      default:
        return 'assets/images/default.png';
    }
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
                      child: Container(
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
            onTap: () {
              setState(() {
                _showAddItemModal = true;
              });
            },
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
              Icon(Icons.add_circle, color: Colors.black, size: 24),
              SizedBox(width: 8),
              Text(
                'Add New Item',
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
    _addItemSelectedCategory = 'Pizza';
    _addItemSelectedSubtype = null;
    _websiteEnabled = false;
    _priceOptions.clear();
    _selectedToppings.clear();
  }

  bool _shouldShowSubtype() {
    return _addItemSelectedCategory == 'Pizza' ||
        _addItemSelectedCategory == 'Shawarma' ||
        _addItemSelectedCategory == 'Wings';
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

  Widget _buildSubtypeSection() {
    List<String> subtypes = _getSubtypesForCategory(_addItemSelectedCategory);

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
            value: _addItemSelectedSubtype,
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
    switch (category) {
      case 'Pizza':
        return [
          'Pizza',
          'Pizze speciali',
          'Pizze le saporite',
          'BBQ Pizza',
          'Fish Pizza',
        ];
      case 'Shawarma':
        return ['Donner & Shawarma kebab', 'Shawarma & kebab tray'];
      case 'Wings':
        return ['Wings', 'BBQ Wings'];
      default:
        return [];
    }
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
      if (_addItemSelectedSubtype == 'Donner & Shawarma kebab') {
        return {"Naan": 6.99, "Pitta": 4.99};
      } else if (_addItemSelectedSubtype == 'Shawarma & kebab tray') {
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
            onTap: _submitAddItem,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Add Item',
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
        _showAddItemModal = false;
        _resetAddItemForm();
      });

      CustomPopupService.show(
        context,
        'Item added successfully!',
        type: PopupType.success,
      );
    } catch (e) {
      CustomPopupService.show(
        context,
        'Failed to add item: $e',
        type: PopupType.failure,
      );
    }
  }
}
