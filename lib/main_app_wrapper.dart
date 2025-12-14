import 'package:flutter/material.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/services/uk_time_service.dart';
// import 'package:epos/widgets/receipt_preview_dialog.dart';
import 'package:epos/models/order.dart';
import 'package:epos/models/cart_item.dart';
import 'package:epos/models/food_item.dart';
import 'package:epos/new_order_notification_widget.dart';
import 'package:epos/cancelled_order_notification_widget.dart';
import 'package:epos/providers/website_orders_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:epos/services/custom_popup_service.dart';
import 'package:epos/main.dart';

class MainAppWrapper extends StatefulWidget {
  final Widget child;

  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  // Helper method to check if an option should be excluded (same logic as thermal printer)
  bool _shouldExcludeOption(String? value) {
    if (value == null || value.isEmpty) return true;

    final trimmedValue = value.trim().toUpperCase();

    // Exclude N/A values
    if (trimmedValue == 'N/A') return true;

    // Exclude default pizza options (case insensitive)
    if (trimmedValue == 'BASE: TOMATO' || trimmedValue == 'CRUST: NORMAL') {
      return true;
    }

    return false;
  }

  late OrderApiService _orderApiService;
  StreamSubscription<Order>? _newOrderSubscription;

  // NUCLEAR FIX: Use Map with unique keys to prevent duplicates
  final Map<int, Order> _activeNewOrderNotifications = {};
  final Map<int, Order> _activeCancelledOrderNotifications = {};

  // NUCLEAR FIX: Global dismissed tracking - these orders NEVER reappear
  static final Set<int> _globalDismissedNewOrders = {};
  static final Set<int> _globalDismissedCancelledOrders = {};

  // FIXED: Separate tracking systems for different purposes
  // Track stream processing to prevent rapid-fire duplicates (short-term, 30 seconds)
  static final Map<int, DateTime> _streamProcessingTimestamps = {};

  // Track notification creation to prevent duplicate notifications (permanent until dismissed)
  static final Set<int> _notificationCreated = {};

  // Track receipt printing (5 minutes)
  static final Set<int> _globalPrintedReceipts = {};
  static final Map<int, DateTime> _receiptPrintingTimestamps = {};

  // Track cancelled order processing (30 seconds)
  static final Map<int, DateTime> _cancelledProcessingTimestamps = {};

  // Track previous order statuses
  Map<int, String> _previousOrderStatuses = {};

  @override
  void initState() {
    super.initState();
    _orderApiService = OrderApiService();

    _newOrderSubscription = _orderApiService.newOrderStream.listen((newOrder) {
      _handleNewOrderFromStream(newOrder);
    });

    _orderApiService.connectionStatusStream.listen((isConnected) {
      print("MainAppWrapper: Socket connection status: $isConnected");
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePreviousOrderStatuses();
      _startProcessingCleanup();
    });
  }

  // Cleanup old processed orders every 5 minutes to prevent memory leaks
  void _startProcessingCleanup() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();

      // Clean up stream processing timestamps (30 seconds old)
      final streamKeysToRemove = <int>[];
      _streamProcessingTimestamps.forEach((orderId, processedTime) {
        if (now.difference(processedTime).inSeconds > 30) {
          streamKeysToRemove.add(orderId);
        }
      });

      for (final orderId in streamKeysToRemove) {
        _streamProcessingTimestamps.remove(orderId);
      }

      // Clean up cancelled processing timestamps (30 seconds old)
      final cancelledKeysToRemove = <int>[];
      _cancelledProcessingTimestamps.forEach((orderId, processedTime) {
        if (now.difference(processedTime).inSeconds > 30) {
          cancelledKeysToRemove.add(orderId);
        }
      });

      for (final orderId in cancelledKeysToRemove) {
        _cancelledProcessingTimestamps.remove(orderId);
      }

      // Clean up receipt printing timestamps (1 hour old)
      final receiptKeysToRemove = <int>[];
      _receiptPrintingTimestamps.forEach((orderId, printedTime) {
        if (now.difference(printedTime).inHours > 1) {
          receiptKeysToRemove.add(orderId);
        }
      });

      for (final orderId in receiptKeysToRemove) {
        _globalPrintedReceipts.remove(orderId);
        _receiptPrintingTimestamps.remove(orderId);
      }

      // Clean up notification created tracking for very old orders (24 hours)
      // Only if they're not in active notifications and not dismissed
      final notificationKeysToRemove = <int>[];
      for (final orderId in _notificationCreated) {
        if (!_activeNewOrderNotifications.containsKey(orderId) &&
            !_globalDismissedNewOrders.contains(orderId)) {
          // This is an orphaned notification creation record - clean it up
          notificationKeysToRemove.add(orderId);
        }
      }

      for (final orderId in notificationKeysToRemove) {
        _notificationCreated.remove(orderId);
      }

      if (streamKeysToRemove.isNotEmpty ||
          receiptKeysToRemove.isNotEmpty ||
          notificationKeysToRemove.isNotEmpty ||
          cancelledKeysToRemove.isNotEmpty) {
        print(
          "MainAppWrapper: Cleaned up ${streamKeysToRemove.length} stream timestamps, ${receiptKeysToRemove.length} receipt timestamps, ${notificationKeysToRemove.length} orphaned notifications, ${cancelledKeysToRemove.length} cancelled timestamps",
        );
      }
    });
  }

  void _handleNewOrderFromStream(Order newOrder) {
    print(
      "MainAppWrapper: Stream received order ${newOrder.orderId} with status ${newOrder.status}",
    );

    final orderId = newOrder.orderId;
    final now = DateTime.now();

    // FIXED: Stream duplicate protection (short-term, 30 seconds)
    // This prevents rapid-fire duplicate stream events
    final lastStreamProcessed = _streamProcessingTimestamps[orderId];
    if (lastStreamProcessed != null &&
        now.difference(lastStreamProcessed).inSeconds < 30) {
      print(
        "MainAppWrapper: Order $orderId stream was processed ${now.difference(lastStreamProcessed).inSeconds}s ago - STREAM DUPLICATE BLOCKED",
      );
      return;
    }

    // Update stream processing timestamp
    _streamProcessingTimestamps[orderId] = now;

    // NUCLEAR FIX: Check global dismissed list (permanent)
    if (_globalDismissedNewOrders.contains(orderId)) {
      print("MainAppWrapper: Order $orderId is globally dismissed - BLOCKED");
      return;
    }

    // FIXED: Check if notification was already created (until dismissed)
    if (_notificationCreated.contains(orderId)) {
      print(
        "MainAppWrapper: Notification for order $orderId already created - BLOCKED",
      );
      return;
    }

    // Layer 3: Check if notification already exists in UI
    if (_activeNewOrderNotifications.containsKey(orderId)) {
      print(
        "MainAppWrapper: Notification for order $orderId already exists in UI - BLOCKED",
      );
      return;
    }

    // Layer 4: Check status validity
    if (!(newOrder.status.toLowerCase() == 'pending' ||
        newOrder.status.toLowerCase() == 'yellow')) {
      print(
        "MainAppWrapper: Order $orderId status '${newOrder.status}' not eligible for notification - BLOCKED",
      );
      return;
    }

    // Layer 5: Add notification
    print("MainAppWrapper: Adding notification for order $orderId - ALLOWED");
    _addNewOrderNotification(newOrder);
  }

  void _initializePreviousOrderStatuses() {
    if (!mounted) return;

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      for (var order in orderProvider.websiteOrders) {
        final status = order.status.toLowerCase();
        _previousOrderStatuses[order.orderId] = status;
      }
      print(
        "MainAppWrapper: Initialized ${_previousOrderStatuses.length} order statuses",
      );
    } catch (e) {
      print("MainAppWrapper: Error initializing order statuses: $e");
    }
  }

  void _addNewOrderNotification(Order order) {
    if (!mounted) return;

    final orderId = order.orderId;

    // Mark notification as created
    _notificationCreated.add(orderId);

    setState(() {
      _activeNewOrderNotifications[orderId] = order;
      print(
        "MainAppWrapper: Added notification for order $orderId. Total: ${_activeNewOrderNotifications.length}",
      );
    });

    // CRITICAL FIX: Immediately refresh orders in UI when new order notification is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final orderProvider = Provider.of<OrderProvider>(
            context,
            listen: false,
          );
          print(
            "MainAppWrapper: Triggering immediate order refresh for new order $orderId",
          );
          orderProvider.fetchWebsiteOrders();
        } catch (e) {
          print(
            "MainAppWrapper: Error refreshing orders after new notification: $e",
          );
        }
      }
    });
  }

  void _removeNewOrderNotification(Order order) {
    print("MainAppWrapper: REMOVING notification for order ${order.orderId}");

    if (!mounted) return;

    final orderId = order.orderId;

    setState(() {
      // Remove from active notifications
      _activeNewOrderNotifications.remove(orderId);

      // NUCLEAR FIX: Add to global dismissed list - THIS ORDER NEVER SHOWS AGAIN
      _globalDismissedNewOrders.add(orderId);

      // FIXED: Remove from notification created tracking since it's now dismissed
      _notificationCreated.remove(orderId);

      print(
        "MainAppWrapper: Order $orderId PERMANENTLY DISMISSED. Active: ${_activeNewOrderNotifications.length}, Dismissed: ${_globalDismissedNewOrders.length}",
      );
    });
  }

  void _addCancelledOrderNotification(Order order) {
    final orderId = order.orderId;
    final now = DateTime.now();

    // FIXED: Same pattern as new orders - separate stream processing
    final lastCancelledProcessed = _cancelledProcessingTimestamps[orderId];
    if (lastCancelledProcessed != null &&
        now.difference(lastCancelledProcessed).inSeconds < 30) {
      print(
        "MainAppWrapper: Cancelled order $orderId was processed ${now.difference(lastCancelledProcessed).inSeconds}s ago - STREAM DUPLICATE BLOCKED",
      );
      return;
    }

    // Update cancelled processing timestamp
    _cancelledProcessingTimestamps[orderId] = now;

    // NUCLEAR FIX: Check global dismissed list
    if (_globalDismissedCancelledOrders.contains(orderId)) {
      print(
        "MainAppWrapper: Cancelled order $orderId is globally dismissed - BLOCKED",
      );
      return;
    }

    if (_activeCancelledOrderNotifications.containsKey(orderId)) {
      print(
        "MainAppWrapper: Cancelled notification for order $orderId already exists - BLOCKED",
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _activeCancelledOrderNotifications[orderId] = order;
      print(
        "MainAppWrapper: Added cancelled notification for order $orderId. Total: ${_activeCancelledOrderNotifications.length}",
      );
    });
  }

  void _removeCancelledOrderNotification(Order order) {
    print(
      "MainAppWrapper: REMOVING cancelled notification for order ${order.orderId}",
    );

    if (!mounted) return;

    setState(() {
      // NUCLEAR FIX: Remove from active notifications
      _activeCancelledOrderNotifications.remove(order.orderId);

      // NUCLEAR FIX: Add to global dismissed list - THIS ORDER NEVER SHOWS AGAIN
      _globalDismissedCancelledOrders.add(order.orderId);

      print(
        "MainAppWrapper: Cancelled order ${order.orderId} PERMANENTLY DISMISSED. Active: ${_activeCancelledOrderNotifications.length}, Dismissed: ${_globalDismissedCancelledOrders.length}",
      );
    });
  }

  // Updated horizontal notifications with centered layout
  Widget _buildHorizontalNotifications() {
    // Combine all notifications into a single list
    List<MapEntry<Order, String>> allNotifications = [];

    // Add new order notifications
    for (var order in _activeNewOrderNotifications.values) {
      allNotifications.add(MapEntry(order, 'new'));
    }

    // Add cancelled order notifications
    for (var order in _activeCancelledOrderNotifications.values) {
      allNotifications.add(MapEntry(order, 'cancelled'));
    }

    // Sort ASCENDING by order ID (oldest first, newest last)
    allNotifications.sort((a, b) => a.key.orderId.compareTo(b.key.orderId));

    if (allNotifications.isEmpty) {
      return const SizedBox.shrink();
    }

    final double cardWidth = 450.0;
    final double cardSpacing = 20.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double availableWidth =
        screenWidth - 40.0; // 20px padding on each side

    // Calculate positioning for centering
    final double totalContentWidth =
        (allNotifications.length * cardWidth) +
        ((allNotifications.length - 1) * cardSpacing);

    // Determine if we need horizontal scrolling
    final bool needsScroll = totalContentWidth > availableWidth;

    return Positioned(
      top: 50.0,
      left: 0,
      right: 0,
      child: Container(
        height: 580.0, // Increased height to accommodate larger cancelled cards
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          physics:
              needsScroll
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
          child: Container(
            width: needsScroll ? null : screenWidth - 40.0,
            child:
                needsScroll
                    ? Row(
                      children: _buildNotificationCards(
                        allNotifications,
                        cardWidth,
                        cardSpacing,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: _getMainAxisAlignment(
                        allNotifications.length,
                      ),
                      children: _buildNotificationCards(
                        allNotifications,
                        cardWidth,
                        cardSpacing,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  // Helper method to determine alignment based on number of notifications
  MainAxisAlignment _getMainAxisAlignment(int count) {
    switch (count) {
      case 1:
        return MainAxisAlignment.center;
      case 2:
        return MainAxisAlignment.center;
      default:
        return MainAxisAlignment.spaceEvenly;
    }
  }

  // Helper method to build notification cards
  List<Widget> _buildNotificationCards(
    List<MapEntry<Order, String>> allNotifications,
    double cardWidth,
    double cardSpacing,
  ) {
    return allNotifications.asMap().entries.map((entry) {
      final int index = entry.key;
      final MapEntry<Order, String> notificationEntry = entry.value;
      final order = notificationEntry.key;
      final type = notificationEntry.value;
      final isNewest = index == allNotifications.length - 1;

      return Container(
        margin: EdgeInsets.only(
          right: index < allNotifications.length - 1 ? cardSpacing : 0,
        ),
        width: cardWidth,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: 1.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            offset: Offset.zero,
            child:
                type == 'new'
                    ? NewOrderNotificationWidget(
                      key: ValueKey('horizontal_new_${order.orderId}'),
                      order: order,
                      onAccept: _handleAcceptOrder,
                      onDecline: _handleDeclineOrder,
                      onDismiss: () {
                        _removeNewOrderNotification(order);
                      },
                      shouldPlaySound: isNewest,
                    )
                    : CancelledOrderNotificationWidget(
                      key: ValueKey('horizontal_cancelled_${order.orderId}'),
                      order: order,
                      onDismiss: () {
                        _removeCancelledOrderNotification(order);
                      },
                      shouldPlaySound: isNewest,
                    ),
          ),
        ),
      );
    }).toList();
  }

  void _showPopup(String message, {PopupType type = PopupType.failure}) {
    try {
      final scaffoldMessenger = scaffoldMessengerKey.currentState;
      if (scaffoldMessenger == null) return;

      scaffoldMessenger.clearSnackBars();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                type == PopupType.success
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
              type == PopupType.success ? Colors.green[700]! : Colors.red[700]!,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      print('MainAppWrapper: Error showing popup: $e');
    }
  }

  List<CartItem> _convertOrderToCartItems(Order order) {
    return order.items.map((orderItem) {
      double pricePerUnit =
          orderItem.quantity > 0
              ? (orderItem.totalPrice / orderItem.quantity)
              : 0.0;

      // For website orders, use the description directly without parsing
      // The website order description already contains all necessary information
      List<String> selectedOptions = [];

      if (orderItem.description.isNotEmpty &&
          orderItem.description != orderItem.itemName) {
        // Split description by newlines and use each line directly
        List<String> descriptionLines =
            orderItem.description
                .split('\n')
                .map((line) => line.trim())
                .where(
                  (line) =>
                      line.isNotEmpty &&
                      line != orderItem.itemName &&
                      !_shouldExcludeOption(
                        line,
                      ), // Filter out default/N/A options
                )
                .toList();

        selectedOptions.addAll(descriptionLines);
      }

      // Use the original comment as-is
      String? finalComment = orderItem.comment;

      return CartItem(
        foodItem:
            orderItem.foodItem ??
            FoodItem(
              id: orderItem.itemId ?? 0,
              name: orderItem.itemName,
              category: orderItem.itemType,
              price: {'default': pricePerUnit},
              image: orderItem.imageUrl ?? '',
              availability: true,
            ),
        quantity: orderItem.quantity,
        selectedOptions: selectedOptions.isNotEmpty ? selectedOptions : null,
        comment: finalComment,
        pricePerUnit: pricePerUnit,
      );
    }).toList();
  }

  Future<void> _printOrderReceipt(Order order) async {
    try {
      // ULTIMATE FIX: Separate receipt tracking system
      final orderId = order.orderId;
      final now = DateTime.now();

      // Check if receipt was already printed recently (5-minute blocking)
      if (_globalPrintedReceipts.contains(orderId)) {
        final lastPrinted = _receiptPrintingTimestamps[orderId];
        if (lastPrinted != null && now.difference(lastPrinted).inMinutes < 5) {
          print(
            "MainAppWrapper: Receipt for order $orderId was printed ${now.difference(lastPrinted).inMinutes}m ago - DUPLICATE PRINT BLOCKED",
          );
          return;
        }
      }

      // Mark receipt as being printed
      _globalPrintedReceipts.add(orderId);
      _receiptPrintingTimestamps[orderId] = now;

      print("MainAppWrapper: Printing receipt for order ${order.orderId}");
      List<CartItem> cartItems = _convertOrderToCartItems(order);

      // Calculate delivery charge for delivery orders
      double? deliveryChargeAmount;
      if (_shouldApplyDeliveryCharge(order.orderType, order.paymentType)) {
        deliveryChargeAmount = 1.50; // Delivery charge amount
      }

      // Show receipt preview dialog before printing
      // await ReceiptPreviewDialog.show(
      //   context,
      //   transactionId: order.orderId.toString(),
      //   orderType: order.orderType,
      //   cartItems: cartItems,
      //   subtotal: order.orderTotalPrice,
      //   totalCharge: order.orderTotalPrice,
      //   extraNotes: order.orderExtraNotes,
      //   changeDue: order.changeDue,
      //   customerName: order.customerName,
      //   customerEmail: order.customerEmail,
      //   phoneNumber: order.phoneNumber,
      //   streetAddress: order.streetAddress,
      //   city: order.city,
      //   postalCode: order.postalCode,
      //   paymentType: order.paymentType,
      //   paidStatus: order.paidStatus,
      //   orderId: order.orderId,
      //   deliveryCharge: deliveryChargeAmount,
      //   orderDateTime: UKTimeService.now(),
      // );

      bool
      success = await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId: order.orderId.toString(),
        orderType: order.orderType,
        cartItems: cartItems,
        subtotal: order.orderTotalPrice,
        totalCharge: order.orderTotalPrice,
        changeDue: order.changeDue,
        extraNotes: order.orderExtraNotes,
        customerName: order.customerName,
        customerEmail: order.customerEmail,
        phoneNumber: order.phoneNumber,
        streetAddress: order.streetAddress,
        city: order.city,
        postalCode: order.postalCode,
        paymentType: order.paymentType,
        paidStatus: order.paidStatus, // FIXED: Add missing paidStatus parameter
        orderId: order.orderId,
        orderNumber: order.displayOrderNumber,
        deliveryCharge: deliveryChargeAmount,
        orderDateTime: UKTimeService.now(), // Always use UK time for printing
        discountPercentage: order.discountPercentage,
        discountAmount: order.discountAmount,
        onShowMethodSelection: (availableMethods) {
          _showPopup(
            "Available printing methods: ${availableMethods.join(', ')}",
            type: PopupType.success,
          );
        },
      );

      _showPopup(
        success
            ? 'Receipt printed for order ${order.displayOrderNumber}'
            : 'Failed to print receipt for order ${order.displayOrderNumber}',
        type: success ? PopupType.success : PopupType.failure,
      );
    } catch (e) {
      print('MainAppWrapper: Error printing receipt: $e');
      _showPopup('Error printing receipt: $e', type: PopupType.failure);
    }
  }

  Future<void> _handleAcceptOrder(Order order) async {
    print("MainAppWrapper: ACCEPTING order ${order.orderId}");

    try {
      bool success = await OrderApiService.updateOrderStatus(
        order.orderId,
        'yellow',
      );

      if (success) {
        _showPopup(
          'Order ${order.displayOrderNumber} accepted.',
          type: PopupType.success,
        );

        // Print receipt
        await Future.delayed(const Duration(milliseconds: 500));
        await _printOrderReceipt(order);

        // Immediate refresh orders
        if (mounted && context.mounted) {
          print(
            "MainAppWrapper: Triggering immediate order refresh after accepting order ${order.orderId}",
          );
          Provider.of<OrderProvider>(
            context,
            listen: false,
          ).fetchWebsiteOrders();
        }
      } else {
        _showPopup(
          'Failed to accept order ${order.displayOrderNumber}',
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('MainAppWrapper: Error accepting order: $e');
      _showPopup(
        'Error accepting order ${order.displayOrderNumber}',
        type: PopupType.failure,
      );
    }
  }

  Future<void> _handleDeclineOrder(Order order) async {
    print("MainAppWrapper: DECLINING order ${order.orderId}");

    try {
      bool success = await OrderApiService.updateOrderStatus(
        order.orderId,
        'declined',
      );

      _showPopup(
        success
            ? 'Order ${order.displayOrderNumber} declined.'
            : 'Failed to decline order ${order.displayOrderNumber}',
        type: success ? PopupType.success : PopupType.failure,
      );

      // Immediate refresh orders after declining
      if (success && mounted && context.mounted) {
        print(
          "MainAppWrapper: Triggering immediate order refresh after declining order ${order.orderId}",
        );
        Provider.of<OrderProvider>(context, listen: false).fetchWebsiteOrders();
      }
    } catch (e) {
      print('MainAppWrapper: Error declining order: $e');
      _showPopup(
        'Error declining order ${order.displayOrderNumber}',
        type: PopupType.failure,
      );
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
      child: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          // NUCLEAR FIX: Only check for cancelled orders, completely separate from new orders
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkForCancelledOrdersOnly(orderProvider.websiteOrders);
            }
          });

          return Stack(
            children: [
              widget.child,

              // Backdrop filter
              if (_activeNewOrderNotifications.isNotEmpty ||
                  _activeCancelledOrderNotifications.isNotEmpty)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),

              // Horizontal notification system - combines new and cancelled orders
              _buildHorizontalNotifications(),
            ],
          );
        },
      ),
    );
  }

  // NUCLEAR FIX: Separate method that ONLY handles cancelled order detection
  void _checkForCancelledOrdersOnly(List<Order> currentOrders) {
    for (var order in currentOrders) {
      final currentStatus = order.status.toLowerCase();
      final previousStatus = _previousOrderStatuses[order.orderId];

      // Only check for cancellations, don't add new order notifications here
      if ((currentStatus == 'cancelled' || currentStatus == 'red') &&
          previousStatus != null &&
          previousStatus != 'cancelled' &&
          previousStatus != 'red') {
        print(
          "MainAppWrapper: Order ${order.orderId} newly cancelled - adding cancelled notification",
        );
        _addCancelledOrderNotification(order);
      }

      _previousOrderStatuses[order.orderId] = currentStatus;
    }
  }

  // Helper function to determine if delivery charges should apply
  bool _shouldApplyDeliveryCharge(String? orderType, String? paymentType) {
    if (orderType == null) return false;

    // Check if orderType is delivery
    if (orderType.toLowerCase() == 'delivery') {
      return true;
    }

    // Check if paymentType indicates delivery (COD, Cash on delivery, etc.)
    if (paymentType != null) {
      final paymentTypeLower = paymentType.toLowerCase();
      if (paymentTypeLower.contains('cod') ||
          paymentTypeLower.contains('cash on delivery') ||
          paymentTypeLower.contains('delivery')) {
        return true;
      }
    }

    return false;
  }
}
