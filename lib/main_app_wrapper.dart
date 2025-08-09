// lib/main_app_wrapper.dart

import 'package:flutter/material.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/models/order.dart';
import 'package:epos/new_order_notification_widget.dart';
import 'package:epos/providers/website_orders_provider.dart';
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

class _MainAppWrapperState extends State<MainAppWrapper>
    with TickerProviderStateMixin {
  late OrderApiService _orderApiService;
  StreamSubscription<Order>? _newOrderSubscription;

  final List<Order> _activeNewOrderNotifications = [];
  final Set<int> _processingOrderIds = {};

  // Animation controllers for each notification
  final Map<int, AnimationController> _animationControllers = {};
  final Map<int, Animation<double>> _slideAnimations = {};
  final Map<int, Animation<double>> _fadeAnimations = {};

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
      _processingOrderIds.add(order.orderId);

      // Create animation controller for this notification
      final controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );

      _animationControllers[order.orderId] = controller;

      // Create slide animation (from top)
      _slideAnimations[order.orderId] = Tween<double>(
        begin: -1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));

      // Create fade animation
      _fadeAnimations[order.orderId] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      // Start the animation
      controller.forward();

      print("MainAppWrapper: New order notification added for order ${order.orderId}. Total active notifications: ${_activeNewOrderNotifications.length}");
    });
  }

  void _removeNewOrderNotification(Order order) async {
    final controller = _animationControllers[order.orderId];

    if (controller != null) {
      // Animate out
      await controller.reverse();

      // Clean up after animation completes
      controller.dispose();
      _animationControllers.remove(order.orderId);
      _slideAnimations.remove(order.orderId);
      _fadeAnimations.remove(order.orderId);
    }

    setState(() {
      _activeNewOrderNotifications.removeWhere((o) => o.orderId == order.orderId);
      _processingOrderIds.remove(order.orderId);
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
    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'accepted');
    if (success) {
      _showSnackBar('Order ${order.orderId} accepted.');
      OrderApiService().addAcceptedOrder(order.copyWith(status: 'accepted'));
      Provider.of<OrderProvider>(context, listen: false).fetchWebsiteOrders();
    } else {
      _showSnackBar('Failed to accept order ${order.orderId}.');
    }
  }

  void _handleDeclineOrder(Order order) async {
    print("MainAppWrapper: Declining order ${order.orderId}");
    bool success = await OrderApiService.updateOrderStatus(order.orderId, 'declined');
    if (success) {
      _showSnackBar('Order ${order.orderId} declined.');
    } else {
      _showSnackBar('Failed to decline order ${order.orderId}.');
    }
  }

  @override
  void dispose() {
    _newOrderSubscription?.cancel();

    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    _slideAnimations.clear();
    _fadeAnimations.clear();

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
            final slideAnimation = _slideAnimations[order.orderId];
            final fadeAnimation = _fadeAnimations[order.orderId];

            if (slideAnimation == null || fadeAnimation == null) {
              return const SizedBox.shrink();
            }

            return AnimatedBuilder(
              animation: _animationControllers[order.orderId]!,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, slideAnimation.value * MediaQuery.of(context).size.height * 0.3),
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: NewOrderNotificationWidget(
                      key: ValueKey(order.orderId),
                      order: order,
                      onAccept: _handleAcceptOrder,
                      onDecline: _handleDeclineOrder,
                      onDismiss: () => _removeNewOrderNotification(order),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}