# Edit Order Implementation Guide

## Overview
Add EDIT functionality to pending orders in dynamic_order_list_screen.dart that opens Page4 with editable cart and updates via API.

## Part 1: Add EDIT Button (dynamic_order_list_screen.dart)

### Location: After Cancel button (around line 2089)

```dart
// Add this AFTER the Cancel button MouseRegion widget and BEFORE the closing ],

// EDIT button - only show for pending orders
if (liveSelectedOrder.status.toLowerCase() == 'pending' ||
    liveSelectedOrder.status.toLowerCase() == 'yellow')
  MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () async {
        // Navigate to Page4 with edit mode
        await _handleEditOrder(liveSelectedOrder);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[700],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/EDIT.png',
              width: 50,
              height: 50,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            const Text(
              'Edit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
const SizedBox(width: 8),
```

### Add the handler method (at end of _DynamicOrderListScreenState class)

```dart
Future<void> _handleEditOrder(Order order) async {
  try {
    // Get food items from API
    final apiService = ApiService();
    List<FoodItem> foodItems = await apiService.fetchFoodItems();

    if (!mounted) return;

    // Navigate to Page4 with edit parameters
    final result = await Navigator.pushNamed(
      context,
      '/page4',
      arguments: {
        'selectedOrderType': order.orderType,
        'foodItems': foodItems,
        'editMode': true,
        'orderId': order.orderId,
      },
    );

    // Refresh orders after returning from edit
    if (result == true && mounted) {
      final eposOrdersProvider = Provider.of<EposOrdersProvider>(
        context,
        listen: false,
      );
      await eposOrdersProvider.refresh();
      _loadOrdersFromProvider();

      CustomPopupService.show(
        context,
        'Order updated successfully',
        type: PopupType.success,
      );
    }
  } catch (e) {
    print('Error opening edit mode: $e');
    if (mounted) {
      CustomPopupService.show(
        context,
        'Failed to open order for editing',
        type: PopupType.failure,
      );
    }
  }
}
```

### Add required import at top of file

```dart
import 'package:epos/services/api_service.dart';
```

## Part 2: Create API Service Method

### In lib/services/api_service.dart, add this method:

```dart
// Update order cart via PUT request
Future<bool> updateOrderCart({
  required int orderId,
  required List<Map<String, dynamic>> items,
  required double totalPrice,
  double? discount,
}) async {
  try {
    final Map<String, dynamic> cartData = {
      'items': items,
      'total_price': totalPrice,
      if (discount != null) 'discount': discount,
    };

    final response = await http.put(
      Uri.parse('${BrandInfo.baseUrl}/orders/cart/edit/$orderId'),
      headers: BrandInfo.getDefaultHeaders(),
      body: jsonEncode(cartData),
    );

    if (response.statusCode == 200) {
      print('✅ Order cart updated successfully for order #$orderId');
      return true;
    } else {
      print('❌ Failed to update cart. Status: ${response.statusCode}');
      print('Response: ${response.body}');
      return false;
    }
  } catch (e) {
    print('❌ Error updating order cart: $e');
    return false;
  }
}
```

## Part 3: Modify Page4 to Support Edit Mode

### 3a. Update Page4 constructor and state variables

In `lib/page4.dart`, modify the class to accept edit parameters:

```dart
class Page4 extends StatefulWidget {
  final String? initialSelectedServiceImage;
  final List<FoodItem> foodItems;
  final String selectedOrderType;
  final bool editMode;  // ADD THIS
  final int? orderId;   // ADD THIS

  const Page4({
    Key? key,
    this.initialSelectedServiceImage,
    required this.foodItems,
    required this.selectedOrderType,
    this.editMode = false,  // ADD THIS
    this.orderId,           // ADD THIS
  }) : super(key: key);

  @override
  _Page4State createState() => _Page4State();
}
```

### 3b. Add edit mode state variables in _Page4State

```dart
// Add these at the top of _Page4State class
bool _isEditMode = false;
int? _editingOrderId;
```

### 3c. Modify initState to handle edit mode

```dart
@override
void initState() {
  super.initState();

  // ADD THIS: Check if in edit mode
  _isEditMode = widget.editMode;
  _editingOrderId = widget.orderId;

  // ... existing initState code ...

  // ADD THIS: Load order data if in edit mode
  if (_isEditMode && _editingOrderId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderForEditing(_editingOrderId!);
    });
  }
}
```

### 3d. Add method to load order data for editing

```dart
Future<void> _loadOrderForEditing(int orderId) async {
  try {
    // Fetch order details from API
    final orderData = await ApiService().fetchOrderById(orderId);

    if (orderData == null) {
      throw Exception('Order not found');
    }

    setState(() {
      // Clear existing cart
      _cartItems.clear();

      // Load order items into cart
      for (var item in orderData['items']) {
        // Find matching FoodItem
        FoodItem? foodItem = foodItems.firstWhere(
          (f) => f.id == item['item_id'],
          orElse: () => FoodItem(
            id: item['item_id'],
            name: item['description'],
            category: item['item_type'] ?? 'OTHER',
            price: {'default': item['total_price'] / item['quantity']},
            image: '',
            availability: true,
          ),
        );

        // Parse selected options from description
        List<String>? selectedOptions;
        if (item['description'] != null && item['description'].toString().isNotEmpty) {
          selectedOptions = item['description']
              .toString()
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }

        _cartItems.add(CartItem(
          foodItem: foodItem,
          quantity: item['quantity'],
          selectedOptions: selectedOptions,
          comment: item['comment'],
          pricePerUnit: item['total_price'] / item['quantity'],
        ));
      }

      // Load customer details
      _customerDetails = CustomerDetails(
        name: orderData['customer_name'] ?? '',
        email: orderData['customer_email'],
        phoneNumber: orderData['phone_number'],
        streetAddress: orderData['street_address'],
        city: orderData['city'],
        postalCode: orderData['postal_code'],
      );

      _selectedPaymentType = orderData['payment_type'];
    });

    CustomPopupService.show(
      context,
      'Order loaded for editing',
      type: PopupType.success,
    );
  } catch (e) {
    print('Error loading order for editing: $e');
    CustomPopupService.show(
      context,
      'Failed to load order',
      type: PopupType.failure,
    );
  }
}
```

### 3e. Modify the PAY button handler to update instead of create

In the `_submitOrder` method, add check for edit mode:

```dart
Future<void> _submitOrder({
  required PaymentDetails paymentDetails,
}) async {
  // ... existing validation code ...

  // CHECK IF EDIT MODE
  if (_isEditMode && _editingOrderId != null) {
    // UPDATE EXISTING ORDER
    return await _updateExistingOrder(paymentDetails);
  }

  // ... existing create order code ...
}
```

### 3f. Add method to update existing order

```dart
Future<void> _updateExistingOrder(PaymentDetails paymentDetails) async {
  try {
    // Prepare items data
    List<Map<String, dynamic>> items = _cartItems.map((cartItem) {
      // Build description with newlines
      String description = cartItem.foodItem.name;
      if (cartItem.selectedOptions != null && cartItem.selectedOptions!.isNotEmpty) {
        description += '\n' + cartItem.selectedOptions!.join('\n');
      }

      return {
        'item_id': cartItem.foodItem.id.toString(),
        'quantity': cartItem.quantity,
        'description': description,  // ← USING \n FOR LINE BREAKS
        'total_price': cartItem.pricePerUnit * cartItem.quantity,
      };
    }).toList();

    // Calculate total
    double subtotal = _calculateCartItemsTotal();
    double deliveryChargeAmount = 0.0;
    if (_shouldApplyDeliveryCharge(_actualOrderType, _selectedPaymentType)) {
      deliveryChargeAmount = 1.50;
    }
    double totalCharge = subtotal + deliveryChargeAmount - _currentDiscountAmount;

    // Call API to update cart
    bool success = await ApiService().updateOrderCart(
      orderId: _editingOrderId!,
      items: items,
      totalPrice: totalCharge,
      discount: _currentDiscountAmount,
    );

    if (success) {
      CustomPopupService.show(
        context,
        'Order updated successfully!',
        type: PopupType.success,
      );

      // Return to previous screen with success
      Navigator.pop(context, true);
    } else {
      throw Exception('API returned false');
    }
  } catch (e) {
    print('Error updating order: $e');
    CustomPopupService.show(
      context,
      'Failed to update order',
      type: PopupType.failure,
    );
  }
}
```

## Part 4: Fix Description Formatting for NEW Orders

### In the existing `_submitOrder` method where items are prepared:

**FIND THIS** (around line 4209):

```dart
"items": _cartItems.map((cartItem) {
  String description = cartItem.foodItem.name;
  if (cartItem.selectedOptions != null && cartItem.selectedOptions!.isNotEmpty) {
    description += ' (${cartItem.selectedOptions!.join(', ')})';  // ← OLD WAY WITH PARENTHESES
  }
```

**REPLACE WITH**:

```dart
"items": _cartItems.map((cartItem) {
  String description = cartItem.foodItem.name;
  if (cartItem.selectedOptions != null && cartItem.selectedOptions!.isNotEmpty) {
    description += '\n' + cartItem.selectedOptions!.join('\n');  // ← NEW WAY WITH NEWLINES
  }
```

This ensures all NEW orders also have proper line breaks in descriptions for clean receipt printing.

## Part 5: Add API Method to Fetch Order by ID

### In lib/services/api_service.dart:

```dart
// Fetch single order by ID
Future<Map<String, dynamic>?> fetchOrderById(int orderId) async {
  try {
    final response = await http.get(
      Uri.parse('${BrandInfo.baseUrl}/orders/$orderId'),
      headers: BrandInfo.getDefaultHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      print('Failed to fetch order. Status: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error fetching order: $e');
    return null;
  }
}
```

## Testing Checklist

1. ✅ EDIT button appears ONLY for pending orders
2. ✅ Clicking EDIT opens Page4 with order data pre-loaded
3. ✅ Can modify items, quantities, customer details
4. ✅ PAY button updates existing order (not create new)
5. ✅ API receives correct data format with \n separators
6. ✅ After update, returns to dynamic_order_list_screen
7. ✅ Order list refreshes showing updated data
8. ✅ NEW orders also use \n in descriptions
9. ✅ Receipt printing shows clean line breaks (not parentheses)

## Key Points

- **Only pending orders** show EDIT button (status == 'pending' or 'yellow')
- **Description format** uses `\n` for line breaks, NOT `(option1, option2)`
- **Edit mode** is determined by `editMode: true` parameter
- **API endpoint** is `PUT /orders/cart/edit/{orderId}`
- **Return value** from Page4 edit triggers refresh
- **All new orders** also get the newline format fix

## Next Steps

1. Apply Part 1 (EDIT button)
2. Apply Part 2 (API method)
3. Apply Part 3 (Page4 modifications)
4. Apply Part 4 (Fix description format)
5. Apply Part 5 (Fetch order API)
6. Test complete flow
7. Verify receipts print cleanly

This implementation ensures pending orders can be edited, and all descriptions use newlines for proper receipt formatting!
