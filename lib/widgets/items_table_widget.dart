// lib/widgets/items_table_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ItemsTableWidget extends StatelessWidget {
  final Map<String, dynamic>? report;

  const ItemsTableWidget({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (report == null) return const SizedBox.shrink();

    final items = report!['all_items_sold'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No items sold',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Item Name',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Type',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty Sold',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total Sales',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Orders',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven ? Colors.white : Colors.grey.shade50,
                border: Border(
                  bottom:
                      index == items.length - 1
                          ? BorderSide.none
                          : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['item_name']?.toString().toUpperCase() ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _formatType(item['type']?.toString() ?? ''),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      item['total_quantity_sold']?.toString() ?? '0',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _formatCurrency(item['total_item_sales']),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      item['orders_containing_item']?.toString() ?? '0',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatType(String type) {
    if (type.isEmpty) return 'N/A';
    return type.substring(0, 1).toUpperCase() + type.substring(1).toLowerCase();
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '£0.00';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '£${value.toStringAsFixed(2)}';
  }
}
