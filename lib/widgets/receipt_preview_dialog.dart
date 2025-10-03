// lib/widgets/receipt_preview_dialog.dart

import 'package:flutter/material.dart';
import 'package:epos/models/cart_item.dart';
import 'package:intl/intl.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final String transactionId;
  final String orderType;
  final List<CartItem> cartItems;
  final double subtotal;
  final double totalCharge;
  final String? extraNotes;
  final double changeDue;
  final String? customerName;
  final String? customerEmail;
  final String? phoneNumber;
  final String? streetAddress;
  final String? city;
  final String? postalCode;
  final String? paymentType;
  final bool? paidStatus;
  final int? orderId;
  final double? deliveryCharge;
  final DateTime? orderDateTime;

  const ReceiptPreviewDialog({
    Key? key,
    required this.transactionId,
    required this.orderType,
    required this.cartItems,
    required this.subtotal,
    required this.totalCharge,
    this.extraNotes,
    required this.changeDue,
    this.customerName,
    this.customerEmail,
    this.phoneNumber,
    this.streetAddress,
    this.city,
    this.postalCode,
    this.paymentType,
    this.paidStatus,
    this.orderId,
    this.deliveryCharge,
    this.orderDateTime,
  }) : super(key: key);

  // Helper method to check if a field should be excluded from receipt (same as thermal printer)
  bool _shouldExcludeField(String? value) {
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

  static Future<void> show(
    BuildContext context, {
    required String transactionId,
    required String orderType,
    required List<CartItem> cartItems,
    required double subtotal,
    required double totalCharge,
    String? extraNotes,
    required double changeDue,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? paymentType,
    bool? paidStatus,
    int? orderId,
    double? deliveryCharge,
    DateTime? orderDateTime,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReceiptPreviewDialog(
          transactionId: transactionId,
          orderType: orderType,
          cartItems: cartItems,
          subtotal: subtotal,
          totalCharge: totalCharge,
          extraNotes: extraNotes,
          changeDue: changeDue,
          customerName: customerName,
          customerEmail: customerEmail,
          phoneNumber: phoneNumber,
          streetAddress: streetAddress,
          city: city,
          postalCode: postalCode,
          paymentType: paymentType,
          paidStatus: paidStatus,
          orderId: orderId,
          deliveryCharge: deliveryCharge,
          orderDateTime: orderDateTime,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String receiptContent = _generateThermalPrinterContent();

    return Dialog(
      child: Container(
        width: 400,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Receipt Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    receiptContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateThermalPrinterContent() {
    // This is the EXACT same logic as ThermalPrinterService._generateReceiptContent
    StringBuffer receipt = StringBuffer();

    // Use full 80mm paper width (48 characters)
    receipt.writeln('================================================');
    receipt.writeln('                    **Dallas**'); // Bold restaurant name
    receipt.writeln('================================================');
    DateTime displayDateTime = orderDateTime ?? DateTime.now();
    receipt.writeln(
      'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(displayDateTime)}',
    );
    if (orderId != null) {
      receipt.writeln('**Order #: $orderId**'); // Bold order number
    }
    receipt.writeln(
      '**Order Type: ${orderType.toUpperCase()}**',
    ); // Bold order type
    receipt.writeln('================================================');
    receipt.writeln();

    // Customer Details Section
    if (customerName?.isNotEmpty == true) {
      receipt.writeln('CUSTOMER DETAILS:');
      receipt.writeln('------------------------------------------------');
      receipt.writeln('Name: $customerName');

      if (phoneNumber?.isNotEmpty == true) {
        receipt.writeln('Phone: $phoneNumber');
      }

      // Address details for delivery orders
      if (orderType.toLowerCase() == 'delivery') {
        if (streetAddress?.isNotEmpty == true) {
          receipt.writeln('Address: $streetAddress');
        }
        if (city?.isNotEmpty == true) {
          receipt.writeln('City: $city');
        }
        if (postalCode?.isNotEmpty == true) {
          receipt.writeln('Postcode: $postalCode');
        }
      }

      receipt.writeln('================================================');
      receipt.writeln();
    }

    receipt.writeln('ITEMS:');
    receipt.writeln('------------------------------------------------');

    for (CartItem item in cartItems) {
      // Use the calculated pricePerUnit from CartItem (includes toppings, crusts, etc.)
      double itemTotal = item.pricePerUnit * item.quantity;

      receipt.writeln(
        '${item.quantity}x **${item.foodItem.name}**',
      ); // Bold item name only

      if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) {
        for (String option in item.selectedOptions!) {
          if (!_shouldExcludeField(option)) {
            receipt.writeln('  + $option');
          }
        }
      }

      if (item.comment?.isNotEmpty == true) {
        receipt.writeln('  Note: ${item.comment}');
      }

      receipt.writeln('  £${itemTotal.toStringAsFixed(2)}');
      receipt.writeln();
    }

    receipt.writeln('------------------------------------------------');

    // Show delivery charges for delivery orders before subtotal
    if (orderType.toLowerCase() == 'delivery' &&
        deliveryCharge != null &&
        deliveryCharge! > 0) {
      String label = 'Delivery Charges:';
      String amount = '${deliveryCharge!.toStringAsFixed(2)}';
      int padding = 48 - label.length - amount.length;
      if (padding < 1) padding = 1;
      receipt.writeln('$label${' ' * padding}$amount');
    }

    // Subtotal - left aligned label, right aligned amount
    String subtotalLabel = 'Subtotal:';
    String subtotalAmount = '${subtotal.toStringAsFixed(2)}';
    int subtotalPadding = 48 - subtotalLabel.length - subtotalAmount.length;
    if (subtotalPadding < 1) subtotalPadding = 1;
    receipt.writeln('$subtotalLabel${' ' * subtotalPadding}$subtotalAmount');

    receipt.writeln('================================================');

    // Total - left aligned label, right aligned amount
    String totalLabel = '**TOTAL:**';
    String totalAmount = '**GBP ${totalCharge.toStringAsFixed(2)}**';
    int totalPadding = 48 - 'TOTAL:'.length - 'GBP ${totalCharge.toStringAsFixed(2)}'.length;
    if (totalPadding < 1) totalPadding = 1;
    receipt.writeln('$totalLabel${' ' * totalPadding}$totalAmount');

    receipt.writeln('================================================');

    // Payment Status Section
    receipt.writeln();
    receipt.writeln('PAYMENT STATUS:');
    receipt.writeln('------------------------------------------------');
    if (paymentType?.isNotEmpty == true) {
      receipt.writeln('**Payment Method: $paymentType**'); // Bold payment type
    }

    // Determine payment status - use paidStatus for most orders, but override for COD
    String paymentStatus = (paidStatus == true) ? 'PAID' : 'UNPAID';

    // Override: Cash on Delivery orders are always UNPAID regardless of paidStatus
    if (paymentType != null &&
        paymentType!.toLowerCase().contains('cash on delivery')) {
      paymentStatus = 'UNPAID';
    }

    // Show payment details based on payment type and status
    if (paidStatus == true) {
      if (paymentType != null &&
          paymentType!.toLowerCase() == 'cash' &&
          changeDue > 0) {
        receipt.writeln(
          'Amount Received:  £${(totalCharge + changeDue).toStringAsFixed(2)}',
        );
        receipt.writeln('Change Due:       £${changeDue.toStringAsFixed(2)}');
      }
    }

    receipt.writeln(
      'Status: **$paymentStatus**',
    ); // Bold payment status (PAID/UNPAID)
    receipt.writeln('================================================');

    receipt.writeln();
    receipt.writeln('Thank you for your order!');
    receipt.writeln('================================================');

    return receipt.toString();
  }
}
