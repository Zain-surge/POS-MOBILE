// lib/website_orders_screen.dart

import 'dart:async';
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/services/order_api_service.dart';
//import 'package:epos/widgets/receipt_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/providers/website_orders_provider.dart';
import 'package:provider/provider.dart';
import 'package:epos/providers/order_counts_provider.dart';
import 'package:epos/custom_bottom_nav_bar.dart';
import 'package:epos/circular_timer_widget.dart';
import 'models/cart_item.dart';
import 'models/food_item.dart';
import 'package:epos/services/uk_time_service.dart';
import 'package:epos/services/custom_popup_service.dart';
import 'package:intl/intl.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class WebsiteOrdersScreen extends StatefulWidget {
  final int initialBottomNavItemIndex;

  const WebsiteOrdersScreen({
    super.key,
    required this.initialBottomNavItemIndex,
  });

  @override
  State<WebsiteOrdersScreen> createState() => _WebsiteOrdersScreenState();
}

class _WebsiteOrdersScreenState extends State<WebsiteOrdersScreen> {
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

  List<Order> activeOrders = [];
  List<Order> completedOrders = [];
  Order? _selectedOrder;
  late int _selectedBottomNavItem;
  String _selectedOrderType = 'delivery';
  final ScrollController _driversScrollController = ScrollController();
  final ScrollController _ordersScrollController = ScrollController();
  final ScrollController _orderDetailsScrollController = ScrollController();
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  Timer? _printerStatusTimer;
  Timer? _colorUpdateTimer;
  DateTime? _lastPrinterCheck;
  Map<String, bool>? _cachedPrinterStatus;

  // Keep reference to OrderProvider for safe disposal
  OrderProvider? _orderProvider;

  // Drivers UI state
  String? _selectedDriverName;
  List<Map<String, dynamic>> _selectedDriverOrders = [];

  @override
  void initState() {
    super.initState();
    _selectedBottomNavItem = widget.initialBottomNavItemIndex;
    print("WebsiteOrdersScreen: initState called.");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      _separateOrders(orderProvider.websiteOrders);
      _updateWebsiteOrderCountsInProvider();
      if (!orderProvider.isPolling) {
        orderProvider.startPolling();
      }

      _startPrinterStatusChecking();
      _startColorUpdateTimer();
    });
  }

  void _startPrinterStatusChecking() {
    _checkPrinterStatus();

    // Check every 2 minutes instead of 30 seconds to reduce printer communication
    _printerStatusTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkPrinterStatus();
    });
  }

  void _startColorUpdateTimer() {
    _colorUpdateTimer?.cancel();
    _colorUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild so time-based colors stay aligned with timers
        });
      }
    });
  }

  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter || !mounted) return; // Add mounted check

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus = {'usb': false, 'bluetooth': false};

      // Only do a real check every 5 minutes, otherwise use cached status
      final now = DateTime.now();
      if (_lastPrinterCheck == null ||
          now.difference(_lastPrinterCheck!).inMinutes >= 5) {
        connectionStatus =
            await ThermalPrinterService().checkConnectionStatusOnly();
        _lastPrinterCheck = now;
        _cachedPrinterStatus = connectionStatus;
      } else {
        // Use cached status to avoid frequent printer communication
        connectionStatus =
            _cachedPrinterStatus ?? {'usb': false, 'bluetooth': false};
      }

      bool isConnected =
          connectionStatus['usb'] == true ||
          connectionStatus['bluetooth'] == true;

      if (mounted) {
        setState(() {
          _isPrinterConnected = isConnected;
          _isCheckingPrinter = false;
        });
      }
    } catch (e) {
      print('Error checking printer status: $e');
      if (mounted) {
        setState(() {
          _isPrinterConnected = false;
          _isCheckingPrinter = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Cancel the timer before disposing
    _printerStatusTimer?.cancel();
    _colorUpdateTimer?.cancel();

    // Use saved provider reference instead of context lookup
    try {
      _orderProvider?.removeListener(_onOrderProviderChange);
      debugPrint(
        '✅ WebsiteOrdersScreen: Successfully removed OrderProvider listener',
      );
    } catch (e) {
      debugPrint('⚠️ WebsiteOrdersScreen: Error removing listener: $e');
    }

    _driversScrollController.dispose();
    _ordersScrollController.dispose();
    _orderDetailsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // Save reference for safe disposal later
    _orderProvider = orderProvider;

    try {
      orderProvider.removeListener(_onOrderProviderChange);
    } catch (e) {
      // Listener might not exist yet
    }
    orderProvider.addListener(_onOrderProviderChange);
    // Re-separate orders whenever dependencies change or provider updates
    _separateOrders(orderProvider.websiteOrders);
  }

  void _onOrderProviderChange() {
    // Check if widget is still mounted before accessing context
    if (!mounted) return;

    try {
      print(
        "WebsiteOrdersScreen: OrderProvider data changed, updating UI. Current orders in provider: ${Provider.of<OrderProvider>(context, listen: false).websiteOrders.length}",
      );
      final allWebsiteOrders =
          Provider.of<OrderProvider>(context, listen: false).websiteOrders;
      _separateOrders(allWebsiteOrders);
      _updateWebsiteOrderCountsInProvider(); // Update counts whenever provider changes

      // If we have a selected order, try to update it with more complete data
      if (_selectedOrder != null && _selectedOrderType == 'drivers') {
        try {
          final updatedOrder = allWebsiteOrders.firstWhere(
            (order) => order.orderId == _selectedOrder!.orderId,
          );
          // Check if the updated order has more complete data
          if ((updatedOrder.phoneNumber != null &&
                  _selectedOrder!.phoneNumber == null) ||
              (updatedOrder.customerEmail != null &&
                  _selectedOrder!.customerEmail == null)) {
            print('DEBUG: Updating selected order with more complete data');
            if (mounted) {
              setState(() {
                _selectedOrder = updatedOrder;
              });
            }
          }
        } catch (e) {
          // Order not found in provider, keep current selection
        }
      }
    } catch (e) {
      // Context may be invalid during disposal - this is expected
      print(
        '⚠️ WebsiteOrdersScreen: Could not update from provider during disposal: $e',
      );
    }
  }

  void _updateWebsiteOrderCountsInProvider() {
    // Check if widget is still mounted before accessing context
    if (!mounted) return;

    try {
      final orderCountsProvider = Provider.of<OrderCountsProvider>(
        context,
        listen: false,
      );
      int newWebsiteActiveCount = 0;
      for (var order
          in Provider.of<OrderProvider>(context, listen: false).websiteOrders) {
        if (!(order.status.toLowerCase() == 'completed' ||
            order.status.toLowerCase() == 'delivered' ||
            order.status.toLowerCase() == 'blue' ||
            order.status.toLowerCase() == 'cancelled' ||
            order.status.toLowerCase() == 'red')) {
          newWebsiteActiveCount++;
        }
      }
      orderCountsProvider.setOrderCount('website', newWebsiteActiveCount);
    } catch (e) {
      // Context may be invalid during disposal - this is expected
      print(
        '⚠️ WebsiteOrdersScreen: Could not update order counts during disposal: $e',
      );
    }
  }

  // Helper method to define status priority for sorting
  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'yellow':
      case 'accepted':
        return 1; // Highest priority (shows first)
      case 'ready':
      case 'green':
      case 'preparing':
        return 2; // Second priority
      default:
        return 3; // Lowest priority for other statuses
    }
  }

  // Helper method to group orders by status for divider placement
  String _getStatusGroup(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'yellow':
      case 'accepted':
        return 'pending';
      case 'ready':
      case 'green':
      case 'preparing':
        return 'ready';
      default:
        return 'other';
    }
  }

  Future<void> _handlePrintingOrderReceipt() async {
    if (_selectedOrder == null) {
      CustomPopupService.show(
        context,
        "No order selected for printing",
        type: PopupType.failure,
      );
      return;
    }

    try {
      // Convert Order items to CartItem format for the printer service
      List<CartItem> cartItems =
          _selectedOrder!.items.map((orderItem) {
            // Calculate price per unit from total price and quantity
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
              selectedOptions:
                  selectedOptions.isNotEmpty ? selectedOptions : null,
              comment: finalComment,
              pricePerUnit: pricePerUnit,
            );
          }).toList();

      // Calculate subtotal
      double subtotal = _selectedOrder!.orderTotalPrice;

      // // Show test dialog with receipt content
      // await _showReceiptDialog(_selectedOrder!, cartItems, subtotal);

      // Calculate delivery charge for delivery orders
      double? deliveryChargeAmount;
      if (_shouldApplyDeliveryCharge(
        _selectedOrder!.orderType,
        _selectedOrder!.paymentType,
      )) {
        deliveryChargeAmount = 1.50; // Delivery charge amount
      }

      // // Show receipt preview dialog before printing
      // await ReceiptPreviewDialog.show(
      //   context,
      //   transactionId:
      //       _selectedOrder!.transactionId.isNotEmpty
      //           ? _selectedOrder!.transactionId
      //           : _selectedOrder!.orderId.toString(),
      //   orderType: _selectedOrder!.orderType,
      //   cartItems: cartItems,
      //   subtotal: subtotal,
      //   totalCharge: _selectedOrder!.orderTotalPrice,
      //   changeDue: _selectedOrder!.changeDue,
      //   extraNotes: _selectedOrder!.orderExtraNotes,
      //   customerName: _selectedOrder!.customerName,
      //   customerEmail: _selectedOrder!.customerEmail,
      //   phoneNumber: _selectedOrder!.phoneNumber,
      //   streetAddress: _selectedOrder!.streetAddress,
      //   city: _selectedOrder!.city,
      //   postalCode: _selectedOrder!.postalCode,
      //   deliveryCharge: deliveryChargeAmount,
      //   paymentType: _selectedOrder!.paymentType,
      //   paidStatus: _selectedOrder!.paidStatus,
      //   orderId: _selectedOrder!.orderId,
      //   orderDateTime: UKTimeService.now(),
      // );

      // Use the thermal printer service to print
      bool
      success = await ThermalPrinterService().printReceiptWithUserInteraction(
        transactionId:
            _selectedOrder!.transactionId.isNotEmpty
                ? _selectedOrder!.transactionId
                : _selectedOrder!.orderId.toString(),
        orderType: _selectedOrder!.orderType,
        cartItems: cartItems,
        subtotal: subtotal,
        totalCharge: _selectedOrder!.orderTotalPrice,
        changeDue: _selectedOrder!.changeDue,
        extraNotes: _selectedOrder!.orderExtraNotes,
        customerName: _selectedOrder!.customerName,
        customerEmail: _selectedOrder!.customerEmail,
        phoneNumber: _selectedOrder!.phoneNumber,
        streetAddress: _selectedOrder!.streetAddress,
        city: _selectedOrder!.city,
        postalCode: _selectedOrder!.postalCode,
        deliveryCharge: deliveryChargeAmount,
        paymentType: _selectedOrder!.paymentType,
        paidStatus:
            _selectedOrder!
                .paidStatus, // Pass the actual paid status from order
        orderDateTime: UKTimeService.now(), // Always use UK time for printing
        onShowMethodSelection: (availableMethods) {
          CustomPopupService.show(
            context,
            "Available printing methods: ${availableMethods.join(', ')}. Please check printer connections.",
            type: PopupType.success,
          );
        },
      );

      if (success) {
        CustomPopupService.show(
          context,
          "Receipt printed successfully",
          type: PopupType.success,
        );
      } else {
        CustomPopupService.show(
          context,
          "Failed to print receipt. Check printer connection.",
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Error printing receipt: $e');
      CustomPopupService.show(
        context,
        "Error printing Receipt.",
        type: PopupType.failure,
      );
    }
  }

  // Updated _separateOrders method with proper sorting
  void _separateOrders(List<Order> allOrdersFromProvider) {
    setState(() {
      int? selectedOrderId = _selectedOrder?.orderId;

      List<Order> typeFilteredOrders;
      if (_selectedOrderType == 'pickup') {
        typeFilteredOrders =
            allOrdersFromProvider
                .where((order) => order.orderType.toLowerCase() == 'pickup')
                .toList();
      } else if (_selectedOrderType == 'delivery') {
        typeFilteredOrders =
            allOrdersFromProvider
                .where((order) => order.orderType.toLowerCase() == 'delivery')
                .toList();
      } else {
        typeFilteredOrders = List.from(allOrdersFromProvider);
      }

      List<Order> tempActive = [];
      List<Order> tempCompleted = [];

      for (var order in typeFilteredOrders) {
        if (order.status.toLowerCase() == 'completed' ||
            order.status.toLowerCase() == 'delivered' ||
            order.status.toLowerCase() == 'blue' ||
            order.status.toLowerCase() == 'cancelled' ||
            order.status.toLowerCase() == 'red') {
          tempCompleted.add(order);
        } else {
          tempActive.add(order);
        }
      }
      // Sort active orders: Pending first, then others, then by creation time within each group
      tempActive.sort((a, b) {
        int statusPriorityA = _getStatusPriority(a.status);
        int statusPriorityB = _getStatusPriority(b.status);

        if (statusPriorityA != statusPriorityB) {
          return statusPriorityA.compareTo(
            statusPriorityB,
          ); // Lower number = higher priority
        }
        // If same status priority, sort by creation time (LATEST first - newest orders on top)
        return b.createdAt.compareTo(a.createdAt);
      });
      // Completed orders: Latest first (newest completed orders on top)
      tempCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      activeOrders = tempActive;
      completedOrders = tempCompleted;
      print(
        "WebsiteOrdersScreen: Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length} for type '$_selectedOrderType'",
      );
      if (selectedOrderId != null) {
        Order? foundOrder;
        try {
          foundOrder = activeOrders.firstWhere(
            (o) => o.orderId == selectedOrderId,
          );
          print(
            "WebsiteOrdersScreen: Found selected order ${selectedOrderId} in active orders",
          );
        } catch (e) {
          try {
            foundOrder = completedOrders.firstWhere(
              (o) => o.orderId == selectedOrderId,
            );
            print(
              "WebsiteOrdersScreen: Found selected order ${selectedOrderId} in completed orders",
            );
          } catch (e) {
            foundOrder = null;
            print(
              "WebsiteOrdersScreen: Selected order ${selectedOrderId} not found in any list",
            );
          }
        }

        if (foundOrder != null) {
          _selectedOrder = foundOrder;
          print(
            "WebsiteOrdersScreen: Maintained selection for order: ${_selectedOrder?.orderId}",
          );
        } else {
          _selectedOrder =
              activeOrders.isNotEmpty
                  ? activeOrders.first
                  : completedOrders.isNotEmpty
                  ? completedOrders.first
                  : null;
          print(
            "WebsiteOrdersScreen: Selected order disappeared, new selected: ${_selectedOrder?.orderId}",
          );
        }
      } else {
        _selectedOrder =
            activeOrders.isNotEmpty
                ? activeOrders.first
                : completedOrders.isNotEmpty
                ? completedOrders.first
                : null;
        if (_selectedOrder != null) {
          print(
            "WebsiteOrdersScreen: No order selected, setting default: ${_selectedOrder?.orderId}",
          );
        }
      }
    });
  }

  String get _screenHeading {
    return 'Website';
  }

  String get _screenImage {
    return 'webwhite.png';
  }

  String _getEmptyStateMessage() {
    if (_selectedOrderType == 'pickup') {
      return 'No pickup orders found.';
    } else if (_selectedOrderType == 'delivery') {
      return 'No delivery orders found.';
    } else if (_selectedOrderType == 'drivers') {
      return 'No drivers with ready orders found.';
    }
    return 'No website orders found.';
  }

  Widget _buildDriversView(bool isLargeScreen) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (_selectedDriverName != null) {
          // Show selected driver's orders
          return _buildDriverOrdersList(isLargeScreen);
        }

        if (orderProvider.driversData.isEmpty) {
          return Center(
            child: Text(
              'No drivers with ready orders found.',
              style: TextStyle(
                fontSize: isLargeScreen ? 20 : 18,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        // Show drivers list - removed loading check to use polling
        return _buildDriversList(isLargeScreen, orderProvider.driversData);
      },
    );
  }

  // New method to handle tab changes and prevent cross-tab contamination
  void _handleTabChange(String newOrderType) {
    setState(() {
      _selectedOrderType = newOrderType;

      if (newOrderType != 'drivers') {
        // Clear driver-specific state when switching away from drivers tab
        _selectedDriverName = null;
        _selectedDriverOrders = [];

        // Separate orders based on the new tab selection
        _separateOrders(
          Provider.of<OrderProvider>(context, listen: false).websiteOrders,
        );

        // Reset to first order if we have orders, otherwise clear selection
        if (activeOrders.isNotEmpty) {
          _selectedOrder = activeOrders.first;
        } else if (completedOrders.isNotEmpty) {
          _selectedOrder = completedOrders.first;
        } else {
          _selectedOrder = null;
        }
      } else {
        // When switching to drivers tab, clear the selected order to prevent cross-contamination
        _selectedOrder = null;
        _selectedDriverName = null;
        _selectedDriverOrders = [];
      }
    });
  }

  Widget _buildDriversList(
    bool isLargeScreen,
    List<Map<String, dynamic>> driversData,
  ) {
    // Flatten all driver-order pairs into individual rows
    List<Map<String, dynamic>> activeRows = [];
    List<Map<String, dynamic>> completedRows = [];

    for (var driverData in driversData) {
      final driverName = driverData['driver_name'] ?? 'Unknown Driver';
      final orders = driverData['orders'] as List<dynamic>? ?? [];

      for (var orderData in orders) {
        final status = orderData['status']?.toString().toLowerCase() ?? '';
        bool isCompleted = [
          'completed',
          'delivered',
          'blue',
          'cancelled',
          'red',
        ].contains(status);

        Map<String, dynamic> row = {
          'driver_name': driverName,
          'order_data': orderData,
          'is_completed': isCompleted,
        };

        if (isCompleted) {
          completedRows.add(row);
        } else {
          activeRows.add(row);
        }
      }
    }

    // Combine with divider if both exist
    List<Map<String, dynamic>> allRowsForDisplay = [];
    allRowsForDisplay.addAll(activeRows);

    if (activeRows.isNotEmpty && completedRows.isNotEmpty) {
      // Add divider
      allRowsForDisplay.add({
        'driver_name': '__divider__',
        'order_data': null,
        'is_completed': false,
      });
    }

    allRowsForDisplay.addAll(completedRows);

    return ListView.builder(
      controller: _driversScrollController,
      itemCount: allRowsForDisplay.length,
      itemBuilder: (context, index) {
        final rowData = allRowsForDisplay[index];

        // Handle divider
        if (rowData['driver_name'] == '__divider__') {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: isLargeScreen ? 12.0 : 10.0,
              horizontal: isLargeScreen ? 70 : 60,
            ),
            child: const Divider(color: Color(0xFFB2B2B2), thickness: 2),
          );
        }

        final driverName = rowData['driver_name'];
        final orderData = rowData['order_data'];
        final isCompleted = rowData['is_completed'];
        final postalCode = orderData['postal_code'] ?? 'N/A';

        // Use green for active, grey for completed
        Color cardColor =
            isCompleted
                ? HexColor.fromHex('D6D6D6')
                : HexColor.fromHex('DEF5D4');

        return Container(
          margin: EdgeInsets.symmetric(
            vertical: 1,
            horizontal: isLargeScreen ? 70 : 60,
          ),
          padding: EdgeInsets.all(isLargeScreen ? 10 : 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.transparent, width: 3),
          ),
          child: Row(
            children: [
              // Driver name card (left) - clickable to show driver's order history
              Expanded(
                flex:
                    isCompleted
                        ? 6
                        : 3, // Full width for completed, half width for active
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDriverName = driverName;
                      // Get all orders for this driver
                      List<Map<String, dynamic>> driverOrders = [];
                      for (var driverData in driversData) {
                        if (driverData['driver_name'] == driverName) {
                          driverOrders =
                              (driverData['orders'] as List<dynamic>)
                                  .cast<Map<String, dynamic>>();
                          break;
                        }
                      }
                      _selectedDriverOrders = driverOrders;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 35 : 30,
                      vertical: isLargeScreen ? 25 : 20,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      driverName,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 32 : 29,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // Only show postal code card for active deliveries (not completed)
              if (!isCompleted) ...[
                SizedBox(width: isLargeScreen ? 12 : 10),

                // Postal code card (right) - clickable to show complete order details
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => _showOrderDetails(orderData),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 35 : 30,
                        vertical: isLargeScreen ? 25 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        postalCode,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 32 : 29,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverOrdersList(bool isLargeScreen) {
    // Separate active and completed orders for the selected driver
    List<Map<String, dynamic>> activeOrders = [];
    List<Map<String, dynamic>> completedOrders = [];

    for (var orderData in _selectedDriverOrders) {
      final status = orderData['status']?.toString().toLowerCase() ?? '';
      if ([
        'completed',
        'delivered',
        'blue',
        'cancelled',
        'red',
      ].contains(status)) {
        completedOrders.add(orderData);
      } else {
        activeOrders.add(orderData);
      }
    }

    // Combine with divider if both exist
    List<Map<String, dynamic>> allOrdersForDisplay = [];
    allOrdersForDisplay.addAll(activeOrders);

    if (activeOrders.isNotEmpty && completedOrders.isNotEmpty) {
      // Add divider
      allOrdersForDisplay.add({'order_id': '__divider__', 'status': 'divider'});
    }

    allOrdersForDisplay.addAll(completedOrders);

    return Column(
      children: [
        // Back button and driver name
        Container(
          padding: EdgeInsets.all(isLargeScreen ? 16 : 12),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDriverName = null;
                      _selectedDriverOrders = [];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.grey[700]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '$_selectedDriverName\'s Orders',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: ListView.builder(
            controller: _ordersScrollController,
            itemCount: allOrdersForDisplay.length,
            itemBuilder: (context, index) {
              final orderData = allOrdersForDisplay[index];

              // Handle divider
              if (orderData['order_id'] == '__divider__' &&
                  orderData['status'] == 'divider') {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isLargeScreen ? 12.0 : 10.0,
                    horizontal: isLargeScreen ? 70 : 60,
                  ),
                  child: const Divider(color: Color(0xFFB2B2B2), thickness: 2),
                );
              }

              return _buildDriverOrderCard(orderData, isLargeScreen);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDriverOrderCard(
    Map<String, dynamic> orderData,
    bool isLargeScreen,
  ) {
    final postalCode = orderData['postal_code'] ?? 'N/A';
    final status = orderData['status']?.toString().toLowerCase() ?? '';

    // Determine colors based on completion status
    bool isCompleted = [
      'completed',
      'delivered',
      'blue',
      'cancelled',
      'red',
    ].contains(status);
    Color addressCardColor =
        isCompleted ? HexColor.fromHex('D6D6D6') : HexColor.fromHex('DEF5D4');
    Color statusCardColor =
        isCompleted ? HexColor.fromHex('D6D6D6') : HexColor.fromHex('DEF5D4');

    // Get display status - showing "On Its Way" for active delivery orders
    String displayStatus = isCompleted ? 'Completed' : 'On Its Way';

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 1,
        horizontal: isLargeScreen ? 70 : 60,
      ),
      padding: EdgeInsets.all(isLargeScreen ? 10 : 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.transparent, width: 3),
      ),
      child: Row(
        children: [
          // Address card (clickable to show order details)
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _showOrderDetails(orderData),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 35 : 30,
                  vertical: isLargeScreen ? 25 : 20,
                ),
                decoration: BoxDecoration(
                  color: addressCardColor,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  postalCode,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 32 : 29,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          SizedBox(width: isLargeScreen ? 12 : 10),

          // Status card (non-clickable, display only)
          Container(
            width: isLargeScreen ? 220 : 200,
            height: isLargeScreen ? 90 : 80,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 16 : 14,
              vertical: isLargeScreen ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: statusCardColor,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              displayStatus, // This now shows "On Its Way" or "Completed"
              style: TextStyle(
                fontSize: isLargeScreen ? 28 : 25,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> orderData) {
    print(
      'DEBUG: _showOrderDetails called with orderData keys: ${orderData.keys.toList()}',
    );
    print('DEBUG: Raw customer_phone: ${orderData['customer_phone']}');
    print('DEBUG: Raw customer_email: ${orderData['customer_email']}');

    // Try to find complete order data from provider first
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final orderId = int.tryParse(orderData['order_id'].toString()) ?? 0;

    // Look for complete order in provider's website orders
    Order? completeOrder;
    try {
      completeOrder = orderProvider.websiteOrders.firstWhere(
        (order) => order.orderId == orderId,
      );
      print(
        'DEBUG: Found complete order in provider - Phone: ${completeOrder.phoneNumber}, Email: ${completeOrder.customerEmail}',
      );

      // If we found a complete order with phone/email data, use it directly
      if (completeOrder.phoneNumber != null ||
          completeOrder.customerEmail != null) {
        setState(() {
          _selectedOrder = completeOrder;
        });
        return;
      }
    } catch (e) {
      print(
        'DEBUG: Complete order not found in provider, creating from raw data',
      );
    }

    try {
      DateTime createdAtDateTime;
      try {
        final createdAtString = orderData['created_at']?.toString() ?? '';
        if (createdAtString.isEmpty) {
          createdAtDateTime = DateTime.now();
        } else {
          createdAtDateTime = DateTime.parse(createdAtString);
        }
      } catch (e) {
        print('Error parsing created_at date: $e');
        createdAtDateTime = DateTime.now();
      }
      // Parse items from orderData - handle different possible item data structures
      List<OrderItem> orderItems = [];
      final itemsData = orderData['items'] as List<dynamic>? ?? [];

      print(
        'DEBUG: Processing ${itemsData.length} items for order ${orderData['order_id']}',
      );

      for (var itemData in itemsData) {
        try {
          // Handle different possible field names from the API
          final itemName =
              itemData['item_name']?.toString() ??
              itemData['name']?.toString() ??
              'Unknown Item';
          final itemCategory =
              itemData['item_category']?.toString() ??
              itemData['category']?.toString() ??
              'GENERAL';
          final itemDescription =
              itemData['item_description']?.toString() ??
              itemData['description']?.toString() ??
              itemName;

          // Calculate price per unit
          double totalPrice =
              double.tryParse(
                itemData['total_price']?.toString() ??
                    itemData['price']?.toString() ??
                    '0',
              ) ??
              0.0;
          int quantity =
              int.tryParse(itemData['quantity']?.toString() ?? '1') ?? 1;
          double pricePerUnit = quantity > 0 ? (totalPrice / quantity) : 0.0;

          // Create proper FoodItem object for category icon support
          FoodItem foodItem = FoodItem(
            id:
                int.tryParse(
                  itemData['item_id']?.toString() ??
                      itemData['id']?.toString() ??
                      '0',
                ) ??
                0,
            name: itemName,
            category: itemCategory,
            price: {'default': pricePerUnit},
            image:
                itemData['item_image_url']?.toString() ??
                itemData['image_url']?.toString() ??
                '',
            availability: true,
          );

          final orderItem = OrderItem(
            itemId: foodItem.id,
            itemName: itemName,
            itemType: itemCategory,
            quantity: quantity,
            totalPrice: totalPrice,
            description: itemDescription,
            comment:
                itemData['item_comment']?.toString() ??
                itemData['comment']?.toString(),
            imageUrl: foodItem.image,
            foodItem: foodItem, // Now properly set instead of null
          );
          orderItems.add(orderItem);
          print(
            'DEBUG: Added item: ${orderItem.itemName} x${orderItem.quantity}',
          );
        } catch (e) {
          print('Error parsing order item: $e');
        }
      }

      print('DEBUG: Total items parsed: ${orderItems.length}');

      final order = Order(
        orderId: int.tryParse(orderData['order_id'].toString()) ?? 0,
        paymentType: orderData['payment_type']?.toString() ?? 'card',
        transactionId: orderData['transaction_id']?.toString() ?? '',
        orderType: 'delivery',
        status: orderData['status']?.toString() ?? 'ready',
        createdAt: createdAtDateTime,
        changeDue: double.tryParse(orderData['change_due'].toString()) ?? 0.0,
        orderSource: orderData['source']?.toString() ?? 'website',
        customerName: orderData['customer_name']?.toString() ?? 'N/A',
        customerEmail: orderData['customer_email']?.toString(),
        phoneNumber: orderData['customer_phone']?.toString(),
        streetAddress: orderData['customer_address']?.toString(),
        city: orderData['customer_city']?.toString(),
        county: orderData['customer_county']?.toString(),
        postalCode: orderData['postal_code']?.toString(),
        orderTotalPrice: double.tryParse(orderData['total'].toString()) ?? 0.0,
        orderExtraNotes: orderData['comments']?.toString(),
        items: orderItems,
        driverId: int.tryParse(orderData['driver_id'].toString()),
        paidStatus:
            orderData['paid_status'] == true || orderData['paid_status'] == '1',
      );

      print(
        'DEBUG: Driver order created - Phone: ${order.phoneNumber}, Email: ${order.customerEmail}',
      );

      setState(() {
        _selectedOrder = order;
      });
    } catch (e) {
      print('Error creating Order from driver data: $e');
      CustomPopupService.show(
        context,
        'Error displaying order details',
        type: PopupType.failure,
      );
    }
  }

  String _nextStatus(Order order) {
    print(
      "WebsiteOrdersScreen: nextStatus: Current status is '${order.status}'. Order Type: ${order.orderType}, Driver ID: ${order.driverId}",
    );

    final String currentStatusLower = order.status.toLowerCase();
    final String orderTypeLower = order.orderType.toLowerCase();
    // final bool hasDriver =
    //     order.driverId != null &&
    //     order.driverId != 0; // Fixed: use != 0 instead of isNotEmpty

    final bool isWebsiteDeliveryOrder = orderTypeLower == 'delivery';

    if (isWebsiteDeliveryOrder) {
      switch (currentStatusLower) {
        case 'pending':
        case 'accepted':
        case 'yellow':
          return 'Ready'; // Allow PENDING delivery to go to READY
        case 'ready':
        case 'preparing':
        case 'green':
          // ORIGINAL DRIVER RESTRICTION LOGIC (COMMENTED OUT):
          // If it's ready but no driver assigned yet, keep it as ready
          // If driver is assigned, it should show "On Its Way" in display but status stays 'green'
          /*
          if (hasDriver) {
            return 'Ready'; // Don't change status, just display changes
          }
          return 'Ready'; // Stays 'ready' (frontend enforcement)
          */

          // NEW LOGIC: Allow progression to completed regardless of driver assignment
          return 'Completed';
        case 'completed':
        case 'delivered':
        case 'blue':
          return 'Completed'; // Stays completed
        case 'cancelled':
        case 'red':
          return 'Completed'; // Stays cancelled
        default:
          return 'Ready'; // Fallback
      }
    } else {
      // For all other website order types (e.g., 'pickup')
      switch (currentStatusLower) {
        case 'pending':
        case 'accepted':
        case 'yellow':
          return 'Ready';
        case 'ready':
        case 'preparing':
        case 'green':
          return 'Completed';
        case 'completed':
        case 'delivered':
        case 'blue':
          return 'Completed';
        case 'cancelled':
        case 'red':
          return 'Completed';
        default:
          return 'Ready';
      }
    }
  }

  String _getCategoryIcon(String categoryName) {
    print(
      'DEBUG: Getting icon for category: "$categoryName" (uppercase: "${categoryName.toUpperCase()}")',
    );

    // Clean and normalize the category name
    String cleanCategory = categoryName.toUpperCase().trim();

    // Handle variations and partial matches
    if (cleanCategory.contains('PIZZA')) {
      return 'assets/images/PizzasS.png';
    } else if (cleanCategory.contains('SHAWARMA')) {
      return 'assets/images/ShawarmaS.png';
    } else if (cleanCategory.contains('BURGER')) {
      return 'assets/images/BurgersS.png';
    } else if (cleanCategory.contains('CALZONE')) {
      return 'assets/images/CalzonesS.png';
    } else if (cleanCategory.contains('GARLIC') ||
        cleanCategory.contains('BREAD')) {
      return 'assets/images/GarlicBreadS.png';
    } else if (cleanCategory.contains('WRAP')) {
      return 'assets/images/WrapsS.png';
    } else if (cleanCategory.contains('KIDS') ||
        cleanCategory.contains('MEAL')) {
      return 'assets/images/KidsMealS.png';
    } else if (cleanCategory.contains('SIDE')) {
      return 'assets/images/SidesS.png';
    } else if (cleanCategory.contains('DRINK') &&
        !cleanCategory.contains('MILKSHAKE')) {
      return 'assets/images/DrinksS.png';
    } else if (cleanCategory.contains('MILKSHAKE') ||
        cleanCategory.contains('SHAKE')) {
      return 'assets/images/MilkshakeS.png';
    } else if (cleanCategory.contains('DIP') ||
        cleanCategory.contains('SAUCE')) {
      return 'assets/images/DipsS.png';
    } else if (cleanCategory.contains('DESSERT')) {
      return 'assets/images/Desserts.png';
    } else if (cleanCategory.contains('CHICKEN')) {
      return 'assets/images/Chicken.png';
    } else if (cleanCategory.contains('KEBAB')) {
      return 'assets/images/Kebabs.png';
    } else if (cleanCategory.contains('WING')) {
      return 'assets/images/Wings.png';
    } else if (cleanCategory.contains('DEAL')) {
      return 'assets/images/DealsS.png';
    }

    // Exact matches as fallback
    switch (cleanCategory) {
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMA':
      case 'SHAWARMAS':
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
      case 'DESSERTS':
        return 'assets/images/Desserts.png';
      case 'CHICKEN':
        return 'assets/images/Chicken.png';
      case 'KEBABS':
        return 'assets/images/Kebabs.png';
      case 'WINGS':
        return 'assets/images/Wings.png';
      case 'DEALS':
        return 'assets/images/DealsS.png';
      case 'GENERAL':
      default:
        print(
          'DEBUG: No match found for category "$categoryName", using SIDES as fallback',
        );
        return 'assets/images/SidesS.png';
    }
  }

  String _getNextStepLabel(Order order) {
    // Check if this is an offline order first
    if (order.status.toLowerCase() == 'offline' ||
        order.orderSource == 'epos_offline') {
      return 'Sync Order';
    }

    // Check if this is a delivery order
    final isDeliveryOrder =
        ((order.orderSource.toLowerCase() == 'epos' ||
                order.orderSource.toLowerCase() == 'epos_offline') &&
            order.orderType.toLowerCase() == 'delivery') ||
        (order.orderSource.toLowerCase() == 'website' &&
            order.orderType.toLowerCase() == 'delivery');

    // For cancelled orders, always show "Cancelled"
    if (order.status.toLowerCase() == 'cancelled' ||
        order.status.toLowerCase() == 'red') {
      return 'Cancelled';
    }

    // For completed orders, always show "Completed"
    if (order.status.toLowerCase() == 'blue' ||
        order.status.toLowerCase() == 'completed' ||
        order.status.toLowerCase() == 'delivered') {
      return 'Completed';
    }

    // Handle different order types and their next steps
    if (isDeliveryOrder) {
      switch (order.status.toLowerCase()) {
        case 'pending':
        case 'yellow':
          return 'Ready'; // Show Mark Ready for pending delivery orders
        case 'ready':
        case 'green':
          // ORIGINAL DRIVER RESTRICTION LOGIC (COMMENTED OUT):
          // For delivery orders that are ready
          /*
          if (order.driverId != null && order.driverId! > 0) {
            return 'Complete'; // Driver assigned, can mark complete
          } else {
            return 'On Its Way'; // Waiting for driver assignment, show next visual step
          }
          */

          // NEW LOGIC: Always allow completion regardless of driver assignment
          return 'Complete';
        default:
          return 'Ready';
      }
    } else {
      // For dine-in, takeaway, collection orders
      switch (order.status.toLowerCase()) {
        case 'pending':
        case 'yellow':
          return 'Ready'; // Next step for pending orders
        case 'ready':
        case 'green':
          return 'Complete'; // Next step for ready orders
        default:
          return 'Ready';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "WebsiteOrdersScreen: build method called. Active orders: ${activeOrders.length}, Completed orders: ${completedOrders.length}",
    );

    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions based on 10.5" screen
    final isLargeScreen = screenWidth > 1200;
    final headerImageSize = 60.0;
    final headerFontSize = 46.0;
    final buttonWidth = isLargeScreen ? 220.0 : 200.0;
    final buttonHeight = isLargeScreen ? 65.0 : 55.0;
    final buttonFontSize = isLargeScreen ? 32.0 : 28.0;

    // Group active orders by status and add dividers between different statuses
    final allOrdersForDisplay = <Order>[];
    if (activeOrders.isNotEmpty) {
      String? currentStatus;
      for (int i = 0; i < activeOrders.length; i++) {
        final order = activeOrders[i];
        final orderStatus = _getStatusGroup(order.status);

        // Add divider if status changes (except for the first order)
        if (currentStatus != null && currentStatus != orderStatus) {
          allOrdersForDisplay.add(
            Order(
              orderId: -2, // Different ID for status dividers
              customerName: '',
              items: [],
              orderTotalPrice: 0.0,
              createdAt: UKTimeService.now(),
              status: 'status_divider',
              orderType: 'status_divider',
              changeDue: 0.0,
              orderSource: 'internal',
              paymentType: '',
              transactionId: '',
            ),
          );
        }

        currentStatus = orderStatus;
        allOrdersForDisplay.add(order);
      }
    }

    if (activeOrders.isNotEmpty && completedOrders.isNotEmpty) {
      allOrdersForDisplay.add(
        Order(
          orderId: -1,
          customerName: '',
          items: [],
          orderTotalPrice: 0.0,
          createdAt: UKTimeService.now(),
          status: 'divider',
          orderType: 'divider',
          changeDue: 0.0,
          orderSource: 'internal',
          paymentType: '',
          transactionId: '',
        ),
      );
    }

    allOrdersForDisplay.addAll(completedOrders);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                // --- Left Panel (Order List) ---
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(
                                17,
                              ), // Fixed padding like dynamic order screen
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(
                                  23,
                                ), // Fixed border radius like dynamic order screen
                              ),
                              child: Image.asset(
                                'assets/images/${_screenImage}',
                                width: headerImageSize,
                                height: headerImageSize,
                              ),
                            ),
                            const SizedBox(
                              width: 20,
                            ), // Fixed spacing like dynamic order screen
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    18, // Fixed padding like dynamic order screen
                                vertical:
                                    14, // Fixed padding like dynamic order screen
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(
                                  23,
                                ), // Fixed border radius like dynamic order screen
                              ),
                              child: Text(
                                _screenHeading,
                                style: TextStyle(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isLargeScreen ? 25 : 20),
                        // Pickup/Delivery Filter Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _handleTabChange('pickup'),
                                child: Container(
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 10 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedOrderType == 'pickup'
                                            ? Colors.grey[100]
                                            : Colors.black,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Pickup',
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _selectedOrderType == 'pickup'
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _handleTabChange('delivery'),
                                child: Container(
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 10 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedOrderType == 'delivery'
                                            ? Colors.grey[100]
                                            : Colors.black,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Delivery',
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _selectedOrderType == 'delivery'
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _handleTabChange('drivers'),
                                child: Container(
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 10 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedOrderType == 'drivers'
                                            ? Colors.grey[100]
                                            : Colors.black,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Drivers',
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _selectedOrderType == 'drivers'
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isLargeScreen ? 25 : 20),

                        Expanded(
                          child:
                              _selectedOrderType == 'drivers'
                                  ? _buildDriversView(isLargeScreen)
                                  : allOrdersForDisplay.isEmpty
                                  ? Center(
                                    child: Text(
                                      _getEmptyStateMessage(),
                                      style: TextStyle(
                                        fontSize: isLargeScreen ? 20 : 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: allOrdersForDisplay.length,
                                    itemBuilder: (context, index) {
                                      final order = allOrdersForDisplay[index];

                                      // Handle divider placeholders
                                      if ((order.orderId == -1 &&
                                              order.status == 'divider' &&
                                              order.orderType == 'divider') ||
                                          (order.orderId == -2 &&
                                              order.status ==
                                                  'status_divider' &&
                                              order.orderType ==
                                                  'status_divider')) {
                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical:
                                                isLargeScreen ? 12.0 : 10.0,
                                            horizontal: isLargeScreen ? 70 : 60,
                                          ),
                                          child: const Divider(
                                            color: Color(0xFFB2B2B2),
                                            thickness: 2,
                                          ),
                                        );
                                      }

                                      bool isActiveOrder = activeOrders
                                          .contains(order);
                                      int? serialNumber;
                                      if (isActiveOrder) {
                                        serialNumber =
                                            1; // Just set to 1, won't display the number
                                      }

                                      Color finalDisplayColor;

                                      // Helper function for time-based colors - NOW TAKES THE SPECIFIC ORDER
                                      Color getTimeBasedColor(
                                        String status,
                                        DateTime orderCreatedAt,
                                      ) {
                                        final DateTime now =
                                            UKTimeService.now();

                                        // CRITICAL FIX: Use same approach as CircularTimer
                                        // Backend stores UK local time with Z suffix (incorrectly marked as UTC)
                                        // Strip timezone and treat as UK local time
                                        final DateTime orderStart = DateTime(
                                          orderCreatedAt.year,
                                          orderCreatedAt.month,
                                          orderCreatedAt.day,
                                          orderCreatedAt.hour,
                                          orderCreatedAt.minute,
                                          orderCreatedAt.second,
                                          orderCreatedAt.millisecond,
                                          orderCreatedAt.microsecond,
                                        );

                                        final Duration orderAge = now
                                            .difference(orderStart);
                                        final int minutesPassed =
                                            orderAge.inMinutes < 0
                                                ? 0
                                                : orderAge.inMinutes;

                                        // Completed orders are always grey regardless of time
                                        if (status.toLowerCase() == 'blue' ||
                                            status.toLowerCase() ==
                                                'completed' ||
                                            status.toLowerCase() ==
                                                'delivered') {
                                          return HexColor.fromHex('D6D6D6');
                                        }

                                        // Cancelled orders keep their red color
                                        if (status.toLowerCase() == 'red' ||
                                            status.toLowerCase() ==
                                                'cancelled') {
                                          return Colors.red[100]!;
                                        }

                                        // Time-based colors for active orders
                                        if (minutesPassed < 30) {
                                          return HexColor.fromHex(
                                            'DEF5D4',
                                          ); // Green - 0-30 minutes
                                        } else if (minutesPassed >= 30 &&
                                            minutesPassed < 45) {
                                          return HexColor.fromHex(
                                            'FFF6D4',
                                          ); // Yellow - 30-45 minutes
                                        } else {
                                          return HexColor.fromHex(
                                            'ffcaca',
                                          ); // Red - 45+ minutes
                                        }
                                      }

                                      Provider.of<OrderProvider>(
                                        context,
                                        listen: false,
                                      );
                                      finalDisplayColor = getTimeBasedColor(
                                        order.status.toLowerCase(),
                                        order.createdAt,
                                      );

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedOrder = order;
                                          });
                                        },
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                            vertical: 1,
                                            horizontal: isLargeScreen ? 70 : 60,
                                          ),
                                          padding: EdgeInsets.all(
                                            isLargeScreen ? 10 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            border: Border.all(
                                              color: Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Order Number Box (similar to active orders list)
                                              Container(
                                                width: 80,
                                                height: isLargeScreen ? 80 : 70,
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(35),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '#${order.orderId}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(width: 15),

                                              Expanded(
                                                flex: 3,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedOrder = order;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              isLargeScreen
                                                                  ? 35
                                                                  : 30,
                                                          vertical:
                                                              isLargeScreen
                                                                  ? 25
                                                                  : 20,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: finalDisplayColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            50,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      order
                                                          .displayAddressSummary,
                                                      style: TextStyle(
                                                        fontSize:
                                                            isLargeScreen
                                                                ? 32
                                                                : 29,
                                                        color: Colors.black,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: isLargeScreen ? 12 : 10,
                                              ),
                                              // Circular Timer - only show for active orders
                                              if (serialNumber != null) ...[
                                                CircularTimer(
                                                  startTime: order.createdAt,
                                                  size:
                                                      isLargeScreen
                                                          ? 80.0
                                                          : 70.0,
                                                  progressColor: Colors.black,
                                                  backgroundColor: Colors.grey,
                                                  strokeWidth:
                                                      isLargeScreen ? 6.0 : 5.0,
                                                  maxMinutes: 60,
                                                ),
                                              ],
                                              SizedBox(
                                                width: isLargeScreen ? 12 : 10,
                                              ),

                                              SizedBox(
                                                width:
                                                    isLargeScreen ? 220 : 200,
                                                height: isLargeScreen ? 90 : 80,
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    // First, check if the order is already in a final state (completed, delivered, cancelled)
                                                    final bool isFinalState =
                                                        order.status
                                                                .toLowerCase() ==
                                                            'completed' ||
                                                        order.status
                                                                .toLowerCase() ==
                                                            'delivered' ||
                                                        order.status
                                                                .toLowerCase() ==
                                                            'blue' ||
                                                        order.status
                                                                .toLowerCase() ==
                                                            'cancelled' ||
                                                        order.status
                                                                .toLowerCase() ==
                                                            'red';

                                                    if (isFinalState) {
                                                      if (mounted) {
                                                        CustomPopupService.show(
                                                          context,
                                                          'Order ${order.orderId} is already ${order.statusLabel}.',
                                                          //type: PopupType.failure,
                                                        );
                                                      }
                                                      return; // Do nothing if it's already in a final state
                                                    }

                                                    // Determine the next intended status using the intelligent function
                                                    final String
                                                    nextIntendedStatus =
                                                        _nextStatus(
                                                          order,
                                                        ); // Pass the full order object

                                                    // ORIGINAL RESTRICTION LOGIC (COMMENTED OUT):
                                                    // Specific rule for Website Delivery Orders:
                                                    // If it's a delivery order and currently 'ready', AND the _nextStatus function also says 'ready'
                                                    // (meaning it cannot progress further from this app), then show a message and stop.
                                                    /* 
                                                    final bool
                                                    isWebsiteDeliveryOrder =
                                                        order.orderType
                                                            .toLowerCase() ==
                                                        'delivery';

                                                    if (isWebsiteDeliveryOrder &&
                                                        order.status
                                                                .toLowerCase() ==
                                                            'ready' &&
                                                        nextIntendedStatus
                                                                .toLowerCase() ==
                                                            'ready') {
                                                      if (mounted) {
                                                        CustomPopupService.show(
                                                          context,
                                                          "Website Delivery orders cannot be updated beyond 'Ready' from this screen.",
                                                          type:
                                                              PopupType.failure,
                                                        );
                                                      }
                                                      return; // Prevent update
                                                    }
                                                    */

                                                    // NEW LOGIC: Allow status updates regardless of driver assignment
                                                    // final bool
                                                    // // isWebsiteDeliveryOrder =
                                                    // //     order.orderType
                                                    // //         .toLowerCase() ==
                                                    // //     'delivery';

                                                    // Allow status progression for delivery orders

                                                    final orderProvider =
                                                        Provider.of<
                                                          OrderProvider
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    Provider.of<
                                                      OrderCountsProvider
                                                    >(context, listen: false);

                                                    bool
                                                    success = await orderProvider
                                                        .updateAndRefreshOrder(
                                                          order.orderId,
                                                          nextIntendedStatus,
                                                        );

                                                    if (success) {
                                                      if (mounted) {
                                                        CustomPopupService.show(
                                                          context,
                                                          'Order ${order.orderId} status updated to ${nextIntendedStatus.toUpperCase()}.',
                                                          type:
                                                              PopupType.success,
                                                        );
                                                      }
                                                    } else {
                                                      if (mounted) {
                                                        CustomPopupService.show(
                                                          context,
                                                          'Order ${order.orderId} status updated to ${nextIntendedStatus.toUpperCase()}.',
                                                          type:
                                                              PopupType.success,
                                                        );

                                                        CustomPopupService.show(
                                                          context,
                                                          'Failed to update status for order ${order.orderId}. Please try again.',
                                                          type:
                                                              PopupType.failure,
                                                        );
                                                      }
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        finalDisplayColor,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              isLargeScreen
                                                                  ? 16
                                                                  : 14,
                                                          vertical:
                                                              isLargeScreen
                                                                  ? 12
                                                                  : 10,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            50,
                                                          ),
                                                    ),
                                                    elevation: 4.0,
                                                  ),
                                                  child: Text(
                                                    // Dynamic text for the button - use the same logic as display label
                                                    _getNextStepLabel(order),
                                                    style: TextStyle(
                                                      fontSize:
                                                          isLargeScreen
                                                              ? 28
                                                              : 25,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isLargeScreen ? 25.0 : 20.0,
                  ),
                  child: const VerticalDivider(
                    width: 3,
                    thickness: 3,
                    color: Colors.grey,
                  ),
                ),

                //RIGHT PANEL
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(isLargeScreen ? 12.0 : 9.0),
                    child:
                        _selectedOrder == null
                            ? Center(
                              child: Text(
                                'Select an order to see details',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 20 : 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order Number and Header
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 25.0 : 20.0,
                                    vertical: isLargeScreen ? 8 : 5,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _selectedOrder!.orderType
                                                            .toLowerCase() ==
                                                        "delivery" &&
                                                    _selectedOrder!
                                                            .postalCode !=
                                                        null &&
                                                    _selectedOrder!
                                                        .postalCode!
                                                        .isNotEmpty
                                                ? '${_selectedOrder!.postalCode} '
                                                : '',
                                            style: TextStyle(
                                              fontSize: isLargeScreen ? 19 : 17,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          // Display Order Number
                                          Text(
                                            'Order no. ${_selectedOrder!.orderId}',
                                            style: TextStyle(
                                              fontSize: isLargeScreen ? 19 : 17,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          // UNPAID Indicator
                                          if (_selectedOrder!.paidStatus ==
                                              false)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'UNPAID',
                                                style: TextStyle(
                                                  fontSize:
                                                      isLargeScreen ? 14 : 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      if (_selectedOrder!.orderType
                                                  .toLowerCase() ==
                                              "delivery" &&
                                          _selectedOrder!.streetAddress !=
                                              null &&
                                          _selectedOrder!
                                              .streetAddress!
                                              .isNotEmpty)
                                        Text(
                                          _selectedOrder!.streetAddress!,
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                          ),
                                        ),
                                      if (_selectedOrder!.orderType
                                                  .toLowerCase() ==
                                              "delivery" &&
                                          _selectedOrder!.city != null &&
                                          _selectedOrder!.city!.isNotEmpty)
                                        Text(
                                          '${_selectedOrder!.city}, ${_selectedOrder!.postalCode ?? ''}',
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                          ),
                                        ),
                                      if (_selectedOrder!.phoneNumber != null &&
                                          _selectedOrder!
                                              .phoneNumber!
                                              .isNotEmpty) ...[
                                        Text(
                                          _selectedOrder!.phoneNumber!,
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          'DEBUG: Phone is ${_selectedOrder!.phoneNumber == null ? "null" : "empty"}',
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 16 : 14,
                                            color: Colors.red,
                                          ),
                                        ),
                                      Text(
                                        _selectedOrder!.customerName,
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 19 : 17,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),

                                      if (_selectedOrder!.customerEmail !=
                                              null &&
                                          _selectedOrder!
                                              .customerEmail!
                                              .isNotEmpty) ...[
                                        Text(
                                          _selectedOrder!.customerEmail!,
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          'DEBUG: Email is ${_selectedOrder!.customerEmail == null ? "null" : "empty"}',
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 16 : 14,
                                            color: Colors.red,
                                          ),
                                        ),

                                      // Display order date and time from created_at
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy   HH:mm',
                                        ).format(_selectedOrder!.createdAt),
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 18 : 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),

                                      // Display order-level extra notes
                                      if (_selectedOrder!.orderExtraNotes !=
                                              null &&
                                          _selectedOrder!
                                              .orderExtraNotes!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12.0,
                                            horizontal: 16.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E8),
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF4CAF50),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Order Notes:',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2E7D2E),
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _selectedOrder!
                                                    .orderExtraNotes!,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF2E7D2E),
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 25 : 20),
                                // Horizontal Divider
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 65.0 : 55.0,
                                  ),
                                  child: const Divider(
                                    height: 0,
                                    thickness: 3,
                                    color: Color(0xFFB2B2B2),
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 15 : 10),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _orderDetailsScrollController,
                                    thumbVisibility: true,
                                    trackVisibility: false,
                                    thickness: isLargeScreen ? 12.0 : 10.0,
                                    radius: const Radius.circular(30),
                                    interactive: true,
                                    thumbColor: const Color(0xFFF2D9F9),
                                    child: ListView.builder(
                                      controller: _orderDetailsScrollController,
                                      itemCount: _selectedOrder!.items.length,
                                      itemBuilder: (context, itemIndex) {
                                        final item =
                                            _selectedOrder!.items[itemIndex];

                                        // FIXED: Use direct description approach (same as receipt printing)
                                        List<String> directOptions = [];

                                        if (item.description.isNotEmpty &&
                                            item.description != item.itemName) {
                                          // Split description by newlines and use each line directly
                                          List<String> descriptionLines =
                                              item.description
                                                  .split('\n')
                                                  .map((line) => line.trim())
                                                  .where(
                                                    (line) =>
                                                        line.isNotEmpty &&
                                                        line != item.itemName &&
                                                        !_shouldExcludeOption(
                                                          line,
                                                        ),
                                                  )
                                                  .toList();

                                          directOptions.addAll(
                                            descriptionLines,
                                          );
                                        }

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: isLargeScreen ? 15.0 : 12.0,
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      isLargeScreen ? 12 : 10,
                                                  horizontal:
                                                      isLargeScreen ? 45 : 40,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 6,
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${item.quantity}',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize:
                                                                  isLargeScreen
                                                                      ? 38
                                                                      : 34,
                                                              fontFamily:
                                                                  'Poppins',
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Padding(
                                                              padding: EdgeInsets.only(
                                                                left:
                                                                    isLargeScreen
                                                                        ? 35
                                                                        : 30,
                                                                right:
                                                                    isLargeScreen
                                                                        ? 12
                                                                        : 10,
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // FIXED: Use direct description approach (same as receipt printing) to avoid duplication and show complete information
                                                                  ...directOptions
                                                                      .map(
                                                                        (
                                                                          option,
                                                                        ) => Text(
                                                                          option,
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                isLargeScreen
                                                                                    ? 17
                                                                                    : 15,
                                                                            fontFamily:
                                                                                'Poppins',
                                                                            color:
                                                                                Colors.black,
                                                                            fontWeight:
                                                                                FontWeight.normal,
                                                                          ),
                                                                          maxLines:
                                                                              option.contains(
                                                                                        'Selected Pizzas',
                                                                                      ) ||
                                                                                      option.contains(
                                                                                        'Selected Shawarmas',
                                                                                      ) ||
                                                                                      option.contains(
                                                                                        'Deal',
                                                                                      )
                                                                                  ? null
                                                                                  : 3,
                                                                          overflow:
                                                                              option.contains(
                                                                                        'Selected Pizzas',
                                                                                      ) ||
                                                                                      option.contains(
                                                                                        'Selected Shawarmas',
                                                                                      ) ||
                                                                                      option.contains(
                                                                                        'Deal',
                                                                                      )
                                                                                  ? TextOverflow.visible
                                                                                  : TextOverflow.ellipsis,
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    Container(
                                                      width: 3,
                                                      height:
                                                          isLargeScreen
                                                              ? 120
                                                              : 110,
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 0,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              30,
                                                            ),
                                                        color: const Color(
                                                          0xFFB2B2B2,
                                                        ),
                                                      ),
                                                    ),

                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          if (_selectedOrderType !=
                                                              'drivers')
                                                            Container(
                                                              width:
                                                                  isLargeScreen
                                                                      ? 100
                                                                      : 90,
                                                              height:
                                                                  isLargeScreen
                                                                      ? 74
                                                                      : 64,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                  ),
                                                              clipBehavior:
                                                                  Clip.hardEdge,
                                                              child: Image.asset(
                                                                _getCategoryIcon(
                                                                  item.itemType,
                                                                ),
                                                                fit:
                                                                    BoxFit
                                                                        .contain,
                                                              ),
                                                            ),
                                                          SizedBox(
                                                            height:
                                                                isLargeScreen
                                                                    ? 10
                                                                    : 8,
                                                          ),
                                                          Text(
                                                            item.itemName,
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  isLargeScreen
                                                                      ? 18
                                                                      : 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              fontFamily:
                                                                  'Poppins',
                                                            ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              if (item.comment != null &&
                                                  item.comment!.isNotEmpty)
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    top:
                                                        isLargeScreen
                                                            ? 10.0
                                                            : 8.0,
                                                  ),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              isLargeScreen
                                                                  ? 10.0
                                                                  : 8.0,
                                                          horizontal:
                                                              isLargeScreen
                                                                  ? 15.0
                                                                  : 12.0,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Horizontal Divider
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 65.0 : 55.0,
                                  ),
                                  child: const Divider(
                                    height: 0,
                                    thickness: 3,
                                    color: Color(0xFFB2B2B2),
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 15 : 10),

                                Column(
                                  children: [
                                    // Payment Type Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Payment Type:',
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                          ),
                                        ),
                                        Text(
                                          _selectedOrder!.paymentType,
                                          style: TextStyle(
                                            fontSize: isLargeScreen ? 20 : 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isLargeScreen ? 18 : 13),

                                    // Total and Change Due Box with Printer Icon
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: EdgeInsets.all(
                                              isLargeScreen ? 40 : 30,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isLargeScreen
                                                                ? 22
                                                                : 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          isLargeScreen
                                                              ? 80
                                                              : 60,
                                                    ),
                                                    Text(
                                                      '£${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isLargeScreen
                                                                ? 22
                                                                : 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_selectedOrder!.changeDue >
                                                    0) ...[
                                                  SizedBox(
                                                    height:
                                                        isLargeScreen ? 12 : 10,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Change Due',
                                                        style: TextStyle(
                                                          fontSize:
                                                              isLargeScreen
                                                                  ? 22
                                                                  : 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            isLargeScreen
                                                                ? 30
                                                                : 20,
                                                      ),
                                                      Text(
                                                        '£${_selectedOrder!.changeDue.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize:
                                                              isLargeScreen
                                                                  ? 22
                                                                  : 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: isLargeScreen ? 10 : 8),

                                        if (_selectedOrderType != 'drivers')
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () async {
                                                await _handlePrintingOrderReceipt();
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(
                                                  isLargeScreen ? 10 : 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Image.asset(
                                                      'assets/images/printer.png',
                                                      width:
                                                          isLargeScreen
                                                              ? 55
                                                              : 50,
                                                      height:
                                                          isLargeScreen
                                                              ? 55
                                                              : 50,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          isLargeScreen ? 6 : 4,
                                                    ),
                                                    Text(
                                                      'Print',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isLargeScreen
                                                                ? 15
                                                                : 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        SizedBox(width: isLargeScreen ? 10 : 8),

                                        // Cancel button
                                        if (_selectedOrderType != 'drivers')
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () async {
                                                await _handleCancelOrder();
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(
                                                  isLargeScreen ? 10 : 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[700],
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.cancel_outlined,
                                                      size:
                                                          isLargeScreen
                                                              ? 55
                                                              : 50,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          isLargeScreen ? 6 : 4,
                                                    ),
                                                    Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isLargeScreen
                                                                ? 15
                                                                : 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
            // Printer status indicator - positioned at top left
            Positioned(
              top: isLargeScreen ? 20 : 16,
              left: isLargeScreen ? 20 : 16,
              child: Container(
                width: isLargeScreen ? 15 : 12,
                height: isLargeScreen ? 15 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPrinterConnected ? Colors.green : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPrinterConnected ? Colors.green : Colors.red)
                          .withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedBottomNavItem,
        showDivider: true,
        onItemSelected: (index) {
          if (index == 3) {
            setState(() {
              _selectedBottomNavItem = index;
            });
          }
        },
      ),
    );
  }

  Future<void> _handleCancelOrder() async {
    if (_selectedOrder == null) {
      CustomPopupService.show(
        context,
        "No order selected for cancellation",
        type: PopupType.failure,
      );
      return;
    }

    final String normalizedStatus = _selectedOrder!.status.toLowerCase();
    String? statusMessage;
    if (normalizedStatus == 'cancelled' || normalizedStatus == 'red') {
      statusMessage = 'Order ${_selectedOrder!.orderId} is already cancelled.';
    } else if (normalizedStatus == 'completed' ||
        normalizedStatus == 'delivered' ||
        normalizedStatus == 'blue') {
      statusMessage =
          'Order ${_selectedOrder!.orderId} has already been completed and cannot be cancelled.';
    }

    if (statusMessage != null) {
      CustomPopupService.show(context, statusMessage, type: PopupType.failure);
      return;
    }

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Text(
            'Are you sure you want to cancel order #${_selectedOrder!.orderId}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel Order'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final success = await OrderApiService.updateOrderStatus(
        _selectedOrder!.orderId,
        'red',
      );

      if (!mounted) return;

      if (success) {
        CustomPopupService.show(
          context,
          'Order ${_selectedOrder!.orderId} has been cancelled',
          type: PopupType.success,
        );

        // Refresh orders to show updated status
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        await orderProvider.fetchWebsiteOrders();
      } else {
        CustomPopupService.show(
          context,
          'Failed to cancel order ${_selectedOrder!.orderId}',
          type: PopupType.failure,
        );
      }
    } catch (e) {
      print('Error cancelling order: $e');
      if (!mounted) return;
      CustomPopupService.show(
        context,
        'Error cancelling order',
        type: PopupType.failure,
      );
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
