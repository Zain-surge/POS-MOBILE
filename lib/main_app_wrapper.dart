// lib/main_app_wrapper.dart
import 'package:flutter/material.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/models/order.dart';
import 'package:epos/new_order_notification_widget.dart';
import 'package:epos/providers/order_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui'; // Import for ImageFilter

// Import the global key defined in main.dart
import 'package:epos/main.dart'; // <--- IMPORT THE GLOBAL KEY

class MainAppWrapper extends StatefulWidget {
  final Widget child;

  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  late OrderApiService _orderApiService;
  StreamSubscription<Order>? _newOrderSubscription;
  Order? _currentNotificationOrder;

  @override
  void initState() {
    super.initState();
    _orderApiService = OrderApiService();

    _newOrderSubscription = _orderApiService.newOrderStream.listen((newOrder) {
      print("MainAppWrapper: New order received from socket: ${newOrder.orderId}");
      if (newOrder.status.toLowerCase() == 'pending' || newOrder.status.toLowerCase() == 'yellow') {
        setState(() {
          _currentNotificationOrder = newOrder;
        });
      }
    });

    _orderApiService.connectionStatusStream.listen((isConnected) {
      print("MainAppWrapper: Socket connection status: $isConnected");
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
    setState(() {
      _currentNotificationOrder = null;
    });

    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'accepted');
    if (success) {
      _showSnackBar('Order ${order.orderId} accepted.');
      Provider.of<OrderProvider>(context, listen: false).fetchWebsiteOrders();
    } else {
      _showSnackBar('Failed to accept order ${order.orderId}.');
    }
  }

  void _handleDeclineOrder(Order order) async {
    print("MainAppWrapper: Declining order ${order.orderId}");
    setState(() {
      _currentNotificationOrder = null;
    });

    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'declined');
    if (success) {
      _showSnackBar('Order ${order.orderId} declined.');
    } else {
      _showSnackBar('Failed to decline order ${order.orderId}.');
    }
  }

  void _handleDismissNotification() {
    print("MainAppWrapper: Notification dismissed for order: ${_currentNotificationOrder?.orderId}");
    setState(() {
      _currentNotificationOrder = null;
    });
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
          if (_currentNotificationOrder != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _handleDismissNotification,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          if (_currentNotificationOrder != null)
            NewOrderNotificationWidget(
              order: _currentNotificationOrder!,
              onAccept: () => _handleAcceptOrder(_currentNotificationOrder!),
              onDecline: () => _handleDeclineOrder(_currentNotificationOrder!),
              onDismiss: _handleDismissNotification,
            ),
        ],
      ),
    );
  }
}