import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/services/notification_audio_service.dart';
import 'package:epos/widgets/debounced_button.dart';

class NewOrderNotificationWidget extends StatefulWidget {
  final Order order;
  final Function(Order) onAccept;
  final Function(Order) onDecline;
  final VoidCallback onDismiss;
  final bool shouldPlaySound; // NEW: Control sound playing

  const NewOrderNotificationWidget({
    Key? key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
    this.shouldPlaySound = true,
  }) : super(key: key);

  @override
  State<NewOrderNotificationWidget> createState() =>
      _NewOrderNotificationWidgetState();
}

class _NewOrderNotificationWidgetState
    extends State<NewOrderNotificationWidget> {
  final NotificationAudioService _audioService = NotificationAudioService();
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldPlaySound) {
      // Delay sound to ensure widget is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _audioService.playNewOrderSound();
          print(
            "NewOrderNotificationWidget: Playing sound for order ${widget.order.orderId}",
          );
        }
      });
    } else {
      print(
        "NewOrderNotificationWidget: Skipping sound for order ${widget.order.orderId}",
      );
    }
  }

  @override
  void didUpdateWidget(covariant NewOrderNotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Stop sound if shouldPlaySound changed from true to false
    if (oldWidget.shouldPlaySound && !widget.shouldPlaySound) {
      _audioService.stopSound();
      print(
        "NewOrderNotificationWidget: Stopping sound for order ${widget.order.orderId}",
      );
    }
  }

  void _handleAccept() {
    if (_isDismissed) return;

    print(
      "NewOrderNotificationWidget: Accept button clicked for order ${widget.order.orderId}",
    );

    // Stop the notification sound immediately
    _audioService.stopSound();

    setState(() {
      _isDismissed = true;
    });

    // Dismiss immediately
    widget.onDismiss();

    // Handle acceptance asynchronously
    _processAcceptance();
  }

  void _processAcceptance() async {
    try {
      await widget.onAccept(widget.order);
      print(
        "NewOrderNotificationWidget: Order ${widget.order.orderId} accepted successfully",
      );
    } catch (e) {
      print(
        "NewOrderNotificationWidget: Error accepting order ${widget.order.orderId}: $e",
      );
    }
  }

  String _getPaymentStatus(String? paymentType) {
    if (paymentType == null || paymentType.isEmpty) {
      return 'UNPAID';
    }

    final type = paymentType.toLowerCase();
    if (type.contains('card') || type == 'card') {
      return 'PAID';
    } else if (type.contains('cash') ||
        type.contains('cod') ||
        type == 'cash on delivery' ||
        type == 'cash') {
      return 'UNPAID';
    }

    // Default to unpaid for unknown payment types
    return 'UNPAID';
  }

  Color _getPaymentStatusColor(String? paymentType) {
    final status = _getPaymentStatus(paymentType);
    return status == 'PAID' ? Colors.green : Colors.red;
  }

  @override
  void dispose() {
    // Stop sound when widget is disposed
    _audioService.stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = 450.0;
    final double cardHeight = 520.0;
    final double cardPadding = 16.0;

    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return Material(
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
              padding: EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: cardPadding,
              ),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Center(
                child: Text(
                  'Order ${widget.order.displayOrderNumber}',
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
                            ...widget.order.items
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                  ),
                                )
                                .toList(),
                            if (widget.order.items.isEmpty)
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
                    const Divider(color: Colors.black, thickness: 1),
                    const SizedBox(height: 15),

                    // --- Discount Section (if present) ---
                    if (widget.order.discountPercentage != null &&
                        widget.order.discountPercentage! > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB6CE6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${widget.order.discountPercentage!.toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              '- £${(widget.order.discountAmount ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --- Total Section ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 10.0,
                      ),
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
                            '£${widget.order.orderTotalPrice.toStringAsFixed(2)}',
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
                      'Customer: ${widget.order.customerName}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (widget.order.phoneNumber != null &&
                        widget.order.phoneNumber!.isNotEmpty)
                      Text(
                        'Phone: ${widget.order.phoneNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    Text(
                      'Type: ${widget.order.orderType}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      'Payment Status: ${_getPaymentStatus(widget.order.paymentType)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _getPaymentStatusColor(widget.order.paymentType),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Action Buttons ---
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        // ACCEPT Button
                        Expanded(
                          child: SizedBox(
                            height: 50.0,
                            child: DebouncedButton(
                              text: 'ACCEPT',
                              onPressed: _handleAccept,
                              backgroundColor: const Color(0xFFCB6CE6),
                              textColor: Colors.black,
                              debounceDuration: const Duration(
                                milliseconds: 1500,
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
    );
  }
}
