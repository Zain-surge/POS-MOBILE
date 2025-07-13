// lib/active_orders_list.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:epos/new_order_notification_widget.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class ActiveOrdersList extends StatefulWidget {
  const ActiveOrdersList({super.key});

  @override
  State<ActiveOrdersList> createState() => _ActiveOrdersListState();
}

class _ActiveOrdersListState extends State<ActiveOrdersList> {
  List<Order> _activeOrders = [];
  bool _isLoadingOrders = true;
  String? _errorLoadingOrders;
  late StreamSubscription _newOrderSocketSubscription;
  late StreamSubscription _acceptedOrderStreamSubscription;
  Order? _selectedOrder;

  // This Set expects Strings, so we'll add String representations of orderId
  final Set<String> _pendingWebsiteOrderIds = {};

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
    _listenForNewOrdersFromSocket();
    _listenForAcceptedOrders();
  }

  @override
  void dispose() {
    _newOrderSocketSubscription.cancel();
    _acceptedOrderStreamSubscription.cancel();
    super.dispose();
  }

  void _listenForNewOrdersFromSocket() {
    _newOrderSocketSubscription = OrderApiService().newOrderStream.listen((newOrder) {
      print('ActiveOrdersList: Received new order from socket: ${newOrder.orderId} (Source: ${newOrder.orderSource})');

      final nonActiveStatuses = ['completed', 'delivered'];

      if (newOrder.orderSource.toLowerCase() == 'website' && newOrder.status.toLowerCase() == 'pending') {
        setState(() {
          // Fix: Convert newOrder.orderId (int) to String for the Set
          if (!_pendingWebsiteOrderIds.contains(newOrder.orderId.toString())) {
            _pendingWebsiteOrderIds.add(newOrder.orderId.toString()); // <-- FIX
            _showNewOrderNotification(newOrder);
          }
        });
      } else if (!nonActiveStatuses.contains(newOrder.status.toLowerCase())) {
        setState(() {
          int existingIndex = _activeOrders.indexWhere((o) => o.orderId == newOrder.orderId);
          if (existingIndex != -1) {
            _activeOrders[existingIndex] = newOrder;
            if (_selectedOrder != null && _selectedOrder!.orderId == newOrder.orderId) {
              _selectedOrder = newOrder;
            }
          } else {
            _activeOrders.add(newOrder);
          }
          _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } else {
        setState(() {
          if (_selectedOrder != null && _selectedOrder!.orderId == newOrder.orderId) {
            _selectedOrder = null;
          }
          _activeOrders.removeWhere((o) => o.orderId == newOrder.orderId);
          _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    });
  }

  void _listenForAcceptedOrders() {
    _acceptedOrderStreamSubscription = OrderApiService().acceptedOrderStream.listen((acceptedOrder) {
      print('ActiveOrdersList: Received accepted order via stream: ${acceptedOrder.orderId}');
      setState(() {
        // Fix: Convert acceptedOrder.orderId (int) to String for the Set
        _pendingWebsiteOrderIds.remove(acceptedOrder.orderId.toString()); // <-- FIX

        int existingIndex = _activeOrders.indexWhere((o) => o.orderId == acceptedOrder.orderId);
        if (existingIndex != -1) {
          _activeOrders[existingIndex] = acceptedOrder;
        } else {
          _activeOrders.add(acceptedOrder);
        }
        _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    });
  }

  void _showNewOrderNotification(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(0),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: NewOrderNotificationWidget(
            order: order,
            onAccept: () async {
              print('Order ${order.orderId} ACCEPTED!');
              // Fix: order.orderId is already int, no need for replaceAll or tryParse here if API expects int
              final orderIdForApi = order.orderId; // This is already an int

              final success = await OrderApiService.updateOrderStatus(
                  orderIdForApi, // Pass the int directly
                  'Accepted');

              if (success) {
                OrderApiService().addAcceptedOrder(order.copyWith(status: 'Accepted'));
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Failed to accept order on server.')),
                );
              }
              Navigator.of(dialogContext).pop();
            },
            onDecline: () async {
              print('Order ${order.orderId} DECLINED!');
              // Fix: order.orderId is already int, no need for replaceAll or tryParse here if API expects int
              final orderIdForApi = order.orderId; // This is already an int

              final success = await OrderApiService.updateOrderStatus(
                  orderIdForApi, // Pass the int directly
                  'Declined');

              if (success) {
                setState(() {
                  // Fix: Convert order.orderId (int) to String for the Set
                  _pendingWebsiteOrderIds.remove(order.orderId.toString()); // <-- FIX
                });
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Failed to decline order on server.')),
                );
              }
              Navigator.of(dialogContext).pop();
            },
            onDismiss: () {
              print('Order ${order.orderId} DISMISSED!');
              setState(() {
                // Fix: Convert order.orderId (int) to String for the Set
                _pendingWebsiteOrderIds.remove(order.orderId.toString()); // <-- FIX
              });
              Navigator.of(dialogContext).pop();
            },
          ),
        );
      },
    );
  }

  Future<void> _fetchActiveOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _errorLoadingOrders = null;
    });
    try {
      final allOrders = await OrderApiService.fetchTodayOrders();
      print('ActiveOrdersList: Fetched ${allOrders.length} orders from backend.');

      final List<Order> currentlyActive = [];
      final List<Order> initiallyPendingWebOrders = [];

      for (var order in allOrders) {
        final nonActiveStatuses = ['completed', 'delivered', 'declined'];

        if (order.orderSource.toLowerCase() == 'website' && order.status.toLowerCase() == 'pending') {
          initiallyPendingWebOrders.add(order);
        } else if (!nonActiveStatuses.contains(order.status.toLowerCase())) {
          currentlyActive.add(order);
        }
      }

      currentlyActive.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _activeOrders = currentlyActive;
        _isLoadingOrders = false;
        if (_selectedOrder != null && !_activeOrders.any((o) => o.orderId == _selectedOrder!.orderId)) {
          _selectedOrder = null;
        }

        for (var order in initiallyPendingWebOrders) {
          // Fix: Convert order.orderId (int) to String for the Set
          if (!_pendingWebsiteOrderIds.contains(order.orderId.toString())) {
            _pendingWebsiteOrderIds.add(order.orderId.toString()); // <-- FIX
            _showNewOrderNotification(order);
          }
        }
      });
      print('ActiveOrdersList: Displaying ${_activeOrders.length} active orders (excluding pending website orders).');
      print('ActiveOrdersList: ${_pendingWebsiteOrderIds.length} pending website orders found on initial fetch.');

    } catch (e) {
      print('Error fetching active orders: $e');
      setState(() {
        _errorLoadingOrders = 'Failed to load active orders: $e';
        _isLoadingOrders = false;
      });
    }
  }

  void refreshOrders() {
    _fetchActiveOrders();
  }

  Widget _buildOrderSummaryContent(Order order) {
    final textStyle = const TextStyle(fontSize: 22, color: Colors.black87, fontFamily: 'Poppins');

    if (order.orderSource.toLowerCase() == 'epos') {
      final itemNames = order.items.map((item) => ' ${item.itemName}').join(', ');
      return Center(
        child: Text(
          itemNames.isNotEmpty ? itemNames : 'No items',
          style: textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    } else if (order.orderSource.toLowerCase() == 'website') {
      return Center(
        child: Text(
          order.displayAddressSummary,
          style: textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Center(
      child: Text(
        order.displaySummary,
        style: textStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getDisplayOrderType(Order order) {
    String source = order.orderSource.toLowerCase();
    String type = order.orderType.toLowerCase();

    if (source == 'website') {
      return 'Web ${type == 'delivery' ? 'Delivery' : 'Pickup'}';
    } else if (source == 'epos') {
      return 'EPOS ${type == 'delivery' ? 'Delivery' : type == 'dinein' ? 'Dine-In' : 'Take-Out'}';
    }
    return '${source.toUpperCase()} ${type.toUpperCase()}';
  }

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'PIZZA':
        return 'assets/images/PizzasS.png';
      case 'SHAWARMAS':
        return 'assets/images/ShawarmaS.png';
      case 'BURGERS':
        return 'assets/images/BurgersS.png';
      case 'CALZONES':
        return 'assets/images/CalzonesS.png';
      case 'GARLIC BREAD':
        return 'assets/images/GarlicBreadS.png';
      case 'WRAPS':
        return 'assets/images/WrapsS.png';
      case 'KIDS MEAL':
        return 'assets/images/KidsMealS.png';
      case 'SIDES':
        return 'assets/images/SidesS.png';
      case 'DRINKS':
        return 'assets/images/DrinksS.png';
      default:
        return 'assets/images/default.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLoadingOrders != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorLoadingOrders!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchActiveOrders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedOrder != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                iconSize: 30,
                onPressed: () {
                  setState(() {
                    _selectedOrder = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order no. ${_selectedOrder!.orderId}', // orderId (int) will be automatically converted to String for display
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              _selectedOrder!.customerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_selectedOrder!.phoneNumber != null && _selectedOrder!.phoneNumber!.isNotEmpty)
              Text(
                _selectedOrder!.phoneNumber!,
                style: const TextStyle(fontSize: 16),
              ),
            if (_selectedOrder!.streetAddress != null && _selectedOrder!.streetAddress!.isNotEmpty)
              Text(
                _selectedOrder!.streetAddress!,
                style: const TextStyle(fontSize: 16),
              ),
            if (_selectedOrder!.city != null && _selectedOrder!.city!.isNotEmpty)
              Text(
                '${_selectedOrder!.city}, ${_selectedOrder!.postalCode ?? ''}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: _selectedOrder!.items.length,
                itemBuilder: (context, itemIndex) {
                  final item = _selectedOrder!.items[itemIndex];

                  String? selectedSize;
                  String? selectedCrust;
                  String baseItemName = item.itemName;

                  final optionMatch = RegExp(r'\((.*?)\)').firstMatch(item.description);
                  if (optionMatch != null && optionMatch.group(1) != null) {
                    String optionsString = optionMatch.group(1)!;
                    List<String> optionsList = optionsString.split(', ').map((s) => s.trim()).toList();

                    for (var option in optionsList) {
                      if (option.toLowerCase().startsWith('size:')) {
                        selectedSize = option.substring('size:'.length).trim();
                      } else if (option.toLowerCase().startsWith('crust:')) {
                        selectedCrust = option.substring('crust:'.length).trim();
                      }
                    }
                    baseItemName = item.description.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
                  }

                  String sizeDisplay = selectedSize != null ? 'Size: $selectedSize' : 'Size: Default';
                  String? crustDisplay = selectedCrust != null ? 'Crust: $selectedCrust' : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 30,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 30),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sizeDisplay,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontFamily: 'Poppins',
                                              color: Colors.black,
                                            ),
                                          ),
                                          if (crustDisplay != null)
                                            Text(
                                              crustDisplay,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontFamily: 'Poppins',
                                                color: Colors.black,
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),

                              Container(
                                width: 1.2,
                                height: 180,
                                color: Colors.black,
                                margin: const EdgeInsets.symmetric(horizontal: 0),
                              ),

                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.asset(
                                        _getCategoryIcon(item.itemType),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      baseItemName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Poppins',
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.comment != null && item.comment!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFDF1C7),
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Comment: ${item.comment!}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text('Total amount:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '€ ${_selectedOrder!.orderTotalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    } else if (_activeOrders.isEmpty && _pendingWebsiteOrderIds.isEmpty) {
      return const Center(
        child: Text(
          'No active orders found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    } else {
      const double fixedBoxHeight = 70.0;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30.0, bottom: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3D9FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Active Orders',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _activeOrders.length,
              itemBuilder: (context, index) {
                final order = _activeOrders[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOrder = order;
                      });
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 0,
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    height: fixedBoxHeight,
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: HexColor.fromHex('FFF6D4'),
                                      borderRadius: BorderRadius.circular(35),
                                    ),
                                    child: _buildOrderSummaryContent(order),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: fixedBoxHeight,
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: HexColor.fromHex('FFF6D4'),
                                      borderRadius: BorderRadius.circular(35),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _getDisplayOrderType(order),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // if (order.orderExtraNotes != null && order.orderExtraNotes!.isNotEmpty)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0),
                            //     child: Text('Notes: ${order.orderExtraNotes!}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Poppins')),
                            //   ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}