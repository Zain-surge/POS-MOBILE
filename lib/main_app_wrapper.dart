// lib/main_app_wrapper.dart

import 'package:flutter/material.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/models/order.dart';
import 'package:epos/new_order_notification_widget.dart';
import 'package:epos/providers/order_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

import 'package:epos/main.dart';

class MainAppWrapper extends StatefulWidget {
  final Widget child;

  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  late OrderApiService _orderApiService;
  StreamSubscription<Order>? _newOrderSubscription;

  final List<Order> _activeNewOrderNotifications = [];

  // Change this line:
  final Set<int> _processingOrderIds = {}; // Changed from Set<String> to Set<int>

  @override
  void initState() {
    super.initState();
    _orderApiService = OrderApiService();

    _newOrderSubscription = _orderApiService.newOrderStream.listen((newOrder) {
      print("MainAppWrapper: New order received from socket: ${newOrder.orderId}");
      if ((newOrder.status.toLowerCase() == 'pending' || newOrder.status.toLowerCase() == 'yellow') &&
          !_processingOrderIds.contains(newOrder.orderId)) {
        _addNewOrderNotification(newOrder);
      }
    });

    _orderApiService.connectionStatusStream.listen((isConnected) {
      print("MainAppWrapper: Socket connection status: $isConnected");
    });
  }

  void _addNewOrderNotification(Order order) {
    setState(() {
      _activeNewOrderNotifications.add(order);
      _processingOrderIds.add(order.orderId); // This line will now work
      print("MainAppWrapper: New order notification added for order ${order.orderId}. Total active notifications: ${_activeNewOrderNotifications.length}");
    });
  }

  void _removeNewOrderNotification(Order order) {
    setState(() {
      _activeNewOrderNotifications.removeWhere((o) => o.orderId == order.orderId);
      _processingOrderIds.remove(order.orderId); // This line will now work
      print("MainAppWrapper: Notification for order ${order.orderId} removed. Remaining active notifications: ${_activeNewOrderNotifications.length}");
    });
  }

  void _showSnackBar(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      print("Warning: scaffoldMessengerKey.currentState is null. Cannot show SnackBar.");
    }
  }

  void _handleAcceptOrder(Order order) async {
    print("MainAppWrapper: Accepting order ${order.orderId}");
    // Note: If orderId is int, ensure your API method `updateOrderStatus` can handle it.
    // If it expects a String, you'll need to convert order.orderId.toString() there.
    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'accepted'); // Potentially convert to String for API
    if (success) {
      _showSnackBar('Order ${order.orderId} accepted.');
      Provider.of<OrderProvider>(context, listen: false).fetchWebsiteOrders();
    } else {
      _showSnackBar('Failed to accept order ${order.orderId}.');
    }
  }

  void _handleDeclineOrder(Order order) async {
    print("MainAppWrapper: Declining order ${order.orderId}");
    // Note: If orderId is int, ensure your API method `updateOrderStatus` can handle it.
    // If it expects a String, you'll need to convert order.orderId.toString() there.
    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'declined'); // Potentially convert to String for API
    if (success) {
      _showSnackBar('Order ${order.orderId} declined.');
    } else {
      _showSnackBar('Failed to decline order ${order.orderId}.');
    }
  }

  @override
  void dispose() {
    _newOrderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,

          if (_activeNewOrderNotifications.isNotEmpty)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          ..._activeNewOrderNotifications.map((order) {
            return NewOrderNotificationWidget(
              key: ValueKey(order.orderId),
              order: order,
              onAccept: _handleAcceptOrder,
              onDecline: _handleDeclineOrder,
              onDismiss: () => _removeNewOrderNotification(order),
            );
          }).toList(),
        ],
      ),
    );
  }
}