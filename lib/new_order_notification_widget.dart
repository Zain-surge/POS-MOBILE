// lib/new_order_notification_widget.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart'; // Ensure your Order model is correctly imported

class NewOrderNotificationWidget extends StatelessWidget {
  final Order order; // Now handles a single order
  final Function(Order) onAccept;
  final Function(Order) onDecline;
  final VoidCallback onDismiss; // To signal removal of this specific widget

  const NewOrderNotificationWidget({
    Key? key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double cardWidth = 450.0;
    final double cardHeight = 520.0;
    final double cardPadding = 16.0;

    return Positioned(
      top: 50,
      left: (MediaQuery.of(context).size.width - cardWidth) / 2,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF2D9F9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Header (Order ID) ---
              Container(
                padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: cardPadding),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Center( // Center the order ID
                  child: Text(
                    'Order ${order.orderId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // --- Body Content ---
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Order Items (Scrollable) ---
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...order.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.itemName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black87,
                                              fontFamily: 'Poppins',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '£${item.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.normal,
                                            color: Colors.black87,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Qty: ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black54,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                              if (order.items.isEmpty)
                                const Text(
                                  'No Items',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // --- Horizontal Separator Line ---
                      const Divider(
                        color: Colors.black,
                        thickness: 1,
                      ),
                      const SizedBox(height: 15),

                      // --- Total Section ---
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB6CE6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              '£${order.orderTotalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Customer Info ---
                      Text(
                        'Customer: ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty)
                        Text(
                          'Phone: ${order.phoneNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      Text(
                        'Type: ${order.orderType}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Action Buttons ---
                      Row(
                        children: [
                          // DECLINE Button
                          // Expanded(
                          //   child: ElevatedButton(
                          //     onPressed: () {
                          //       onDecline(order);
                          //       onDismiss(); // Dismiss this specific notification
                          //     },
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: Colors.red,
                          //       padding: const EdgeInsets.symmetric(vertical: 16),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(10),
                          //       ),
                          //       elevation: 5,
                          //     ),
                          //     child: const Text(
                          //       'DECLINE',
                          //       style: TextStyle(
                          //         color: Colors.white,
                          //         fontSize: 18,
                          //         fontWeight: FontWeight.normal,
                          //         fontFamily: 'Poppins',
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(width: 16),
                          // ACCEPT Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                onAccept(order);
                                onDismiss(); // Dismiss this specific notification
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCB6CE6),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 5,
                              ),
                              child: const Text(
                                'ACCEPT',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}