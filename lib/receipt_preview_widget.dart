
import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final Order order;
  const ReceiptPreviewWidget({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  'RESTAURANT RECEIPT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.black,
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Order Details
          _buildReceiptLine('Order #:', order.orderId.toString()),
          _buildReceiptLine('Customer:', order.customerName),
          _buildReceiptLine('Type:', order.orderType.toUpperCase()),

          if (order.phoneNumber?.isNotEmpty == true)
            _buildReceiptLine('Phone:', order.phoneNumber!),

          if (order.streetAddress?.isNotEmpty == true) ...[
            _buildReceiptLine('Address:', order.streetAddress!),
            if (order.city?.isNotEmpty == true)
              _buildReceiptLine('', '${order.city}, ${order.postalCode ?? ''}'),
          ],

          _buildReceiptLine('Status:', order.status),
          _buildReceiptLine('Payment:', order.paymentType),

          if (order.createdAt != null)
            _buildReceiptLine('Time:', order.createdAt.toString().substring(0, 19)),

          SizedBox(height: 12),

          // Items Header
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.black,
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'ITEMS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.black,
          ),
          SizedBox(height: 8),

          // Items List
          ...order.items.map((item) => _buildItemSection(item)),

          SizedBox(height: 12),

          // Total Section
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.black,
          ),
          SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                '€${order.orderTotalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          if (order.changeDue != null && order.changeDue! > 0) ...[
            SizedBox(height: 4),
            _buildReceiptLine('Change Due:', '€${order.changeDue!.toStringAsFixed(2)}'),
          ],

          SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.black,
          ),
          SizedBox(height: 8),

          // Footer
          Center(
            child: Text(
              'Thank you for your order!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),

          if (order.transactionId?.isNotEmpty == true) ...[
            SizedBox(height: 4),
            Center(
              child: Text(
                'Transaction ID: ${order.transactionId}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ] else ...[
            SizedBox(width: 80),
          ],
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSection(OrderItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                '${item.quantity}x ${item.itemName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '€${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),

        if (item.description.isNotEmpty && item.description != item.itemName) ...[
          SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              item.description,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],

        if (item.comment?.isNotEmpty == true) ...[
          SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Note: ${item.comment}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],

        SizedBox(height: 8),
      ],
    );
  }
}