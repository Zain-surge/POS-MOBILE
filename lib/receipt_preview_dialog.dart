// lib/receipt_preview_dialog.dart
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart'; // Ensure this path is correct

class ReceiptPreviewDialog extends StatefulWidget {
  final Order order;
  final String printerStatus;
  final bool isPrinting;
  final VoidCallback onPrintPressed;

  const ReceiptPreviewDialog({
    Key? key,
    required this.order,
    required this.printerStatus,
    required this.isPrinting,
    required this.onPrintPressed,
  }) : super(key: key);

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400, // Adjust size as needed
        padding: const EdgeInsets.all(20),
        child: Material( // Wrap in Material to provide Directionality and other inherited widgets
          color: Colors.transparent, // Transparent to show parent dialog's shape
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Receipt Preview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              // Display some order details as a "preview"
              // Note: This is NOT a visual representation of the thermal receipt.
              // It's just displaying order info in the dialog.
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${widget.order.orderId}', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Customer: ${widget.order.customerName}'),
                    Text('Total: £${widget.order.orderTotalPrice.toStringAsFixed(2)}'),
                    Text('Payment: ${widget.order.paymentType.toUpperCase()}'),
                    Text('Type: ${widget.order.orderType.toUpperCase()}'),
                    const Divider(),
                    const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...widget.order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text('${item.quantity}x ${item.itemName} (£${item.totalPrice.toStringAsFixed(2)})'),
                    )),
                    const Divider(),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text('Printer Status: ${widget.printerStatus}', style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: widget.isPrinting ? null : widget.onPrintPressed,
                child: Text(widget.isPrinting ? 'Printing...' : 'Print Receipt'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}