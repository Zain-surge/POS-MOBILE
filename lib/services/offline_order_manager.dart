// lib/services/offline_order_manager.dart

import 'package:epos/models/order.dart';
import 'package:epos/models/cart_item.dart';
import 'package:epos/services/offline_storage_service.dart';
import 'package:epos/services/uk_time_service.dart';

class OfflineOrderManager {
  static int _nextOfflineId = -1; // Use negative IDs for offline orders

  /// Creates a local Order from cart items that will appear in the orders list
  /// This order shows as "OFFLINE" status until synced with backend
  static Future<Order> createOfflineOrder({
    required List<CartItem> cartItems,
    required String paymentType,
    required String orderType,
    required double orderTotalPrice,
    String? orderExtraNotes,
    required String customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    required double changeDue,
    String? transactionIdOverride,
  }) async {
    // Generate unique offline transaction ID
    final String transactionId =
        (transactionIdOverride != null && transactionIdOverride.isNotEmpty)
            ? transactionIdOverride
            : OfflineStorageService.generateOfflineTransactionId();
    final offlineOrderId = _nextOfflineId--;

    // Convert CartItems to OrderItems
    final orderItems =
        cartItems.map((cartItem) {
          return OrderItem(
            itemId: cartItem.foodItem.id,
            quantity: cartItem.quantity,
            description: cartItem.selectedOptions?.join(', ') ?? '',
            totalPrice: cartItem.totalPrice,
            itemName: cartItem.foodItem.name,
            itemType: cartItem.foodItem.category,
            imageUrl: cartItem.foodItem.image,
            comment: cartItem.comment,
            foodItem: cartItem.foodItem,
          );
        }).toList();

    // Create the local Order that will appear in orders list
    final order = Order(
      orderId: offlineOrderId,
      paymentType: paymentType,
      transactionId: transactionId,
      orderType: orderType,
      status: 'offline', // Special status for offline orders
      createdAt: UKTimeService.now(),
      changeDue: changeDue,
      orderSource: 'epos_offline', // Indicate this is an offline order
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      orderTotalPrice: orderTotalPrice,
      orderExtraNotes: orderExtraNotes,
      items: orderItems,
    );

    // Save the offline order data for later sync
    await OfflineStorageService.saveOfflineOrder(
      cartItems: cartItems,
      paymentType: paymentType,
      orderType: orderType,
      orderTotalPrice: orderTotalPrice,
      orderExtraNotes: orderExtraNotes,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      changeDue: changeDue,
      transactionIdOverride: transactionId,
    );

    print(
      '📱 Created offline order: $transactionId (Local ID: $offlineOrderId)',
    );
    return order;
  }

  /// Gets all offline orders as Order objects for display
  static List<Order> getOfflineOrdersAsOrders() {
    try {
      final offlineOrders = OfflineStorageService.getPendingOrders();

      return offlineOrders.map((offlineOrder) {
        // Convert OfflineOrder back to Order for display
        final orderItems =
            offlineOrder.items.map((offlineItem) {
              return OrderItem(
                itemId: offlineItem.foodItem.id,
                quantity: offlineItem.quantity,
                description: offlineItem.selectedOptions?.join(', ') ?? '',
                totalPrice: offlineItem.totalPrice,
                itemName: offlineItem.foodItem.name,
                itemType: offlineItem.foodItem.category,
                imageUrl: offlineItem.foodItem.image,
                comment: offlineItem.comment,
                foodItem: offlineItem.foodItem.toFoodItem(),
              );
            }).toList();

        return Order(
          orderId: int.tryParse(offlineOrder.localId.hashCode.toString()) ?? -1,
          paymentType: offlineOrder.paymentType,
          transactionId: offlineOrder.transactionId,
          orderType: offlineOrder.orderType,
          status:
              offlineOrder.status == 'pending'
                  ? 'offline'
                  : offlineOrder.status,
          createdAt: offlineOrder.createdAt,
          changeDue: offlineOrder.changeDue,
          orderSource: 'epos_offline',
          customerName: offlineOrder.customerName,
          customerEmail: offlineOrder.customerEmail,
          phoneNumber: offlineOrder.phoneNumber,
          streetAddress: offlineOrder.streetAddress,
          city: offlineOrder.city,
          postalCode: offlineOrder.postalCode,
          orderTotalPrice: offlineOrder.orderTotalPrice,
          orderExtraNotes: offlineOrder.orderExtraNotes,
          items: orderItems,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting offline orders as Orders: $e');
      return [];
    }
  }

  /// Updates an offline order status when it gets synced
  static Future<void> markOrderAsSynced(
    String transactionId,
    int backendOrderId,
  ) async {
    try {
      final offlineOrders = OfflineStorageService.getPendingOrders();
      final order = offlineOrders.firstWhere(
        (order) => order.transactionId == transactionId,
        orElse: () => throw Exception('Order not found'),
      );

      await OfflineStorageService.markOrderAsSynced(
        order.localId,
        backendOrderId,
      );
      print(
        '✅ Offline order $transactionId synced with backend ID: $backendOrderId',
      );
    } catch (e) {
      print('❌ Error marking order as synced: $e');
    }
  }

  /// Checks if an order is offline based on its source
  static bool isOfflineOrder(Order order) {
    return order.orderSource == 'epos_offline' || order.status == 'offline';
  }

  /// Gets the display status for offline orders
  static String getOfflineOrderDisplayStatus(Order order) {
    if (isOfflineOrder(order)) {
      return 'OFFLINE';
    }
    return order.statusLabel;
  }
}
