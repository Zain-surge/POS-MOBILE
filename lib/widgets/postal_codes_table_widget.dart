// lib/widgets/postal_codes_table_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostalCodesTableWidget extends StatelessWidget {
  final Map<String, dynamic>? report;

  const PostalCodesTableWidget({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (report == null) return const SizedBox.shrink();

    // Extract postal codes data from deliveries_by_postal_code field
    final postalCodes = _extractPostalCodes(report!);

    if (postalCodes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No postal codes data available',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
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
              color: Colors.blue.shade50,
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
                    'Postal Code',
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
                    'Deliveries',
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
              ],
            ),
          ),

          // Table Rows
          ...postalCodes.asMap().entries.map((entry) {
            final index = entry.key;
            final postalCodeData = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven ? Colors.white : Colors.grey.shade50,
                border: Border(
                  bottom: index == postalCodes.length - 1
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      postalCodeData['postal_code']?.toString() ?? 'Unknown',
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
                      postalCodeData['delivery_count']?.toString() ?? '0',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '£${_formatAmount(postalCodeData['total_delivery_sales'] ?? 0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // Total row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'TOTAL DELIVERIES',
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
                    _calculateTotalDeliveries(postalCodes).toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '£${_formatAmount(_calculateTotalSales(postalCodes))}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _extractPostalCodes(Map<String, dynamic> report) {
    // Extract from deliveries_by_postal_code field
    if (report['deliveries_by_postal_code'] is List) {
      return report['deliveries_by_postal_code'] as List<dynamic>;
    }
    
    // Try other possible keys for postal codes data (fallback)
    if (report['postal_codes'] is List) {
      return report['postal_codes'] as List<dynamic>;
    }
    if (report['delivery_areas'] is List) {
      return report['delivery_areas'] as List<dynamic>;
    }
    
    return [];
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    if (amount is String) {
      final parsed = double.tryParse(amount) ?? 0.0;
      return parsed.toStringAsFixed(2);
    }
    if (amount is num) {
      return amount.toStringAsFixed(2);
    }
    return '0.00';
  }

  int _calculateTotalDeliveries(List<dynamic> postalCodes) {
    int total = 0;
    for (final postalCode in postalCodes) {
      final deliveryCount = postalCode['delivery_count'] ?? 0;
      if (deliveryCount is String) {
        total += int.tryParse(deliveryCount) ?? 0;
      } else if (deliveryCount is num) {
        total += deliveryCount.toInt();
      }
    }
    return total;
  }

  double _calculateTotalSales(List<dynamic> postalCodes) {
    double total = 0.0;
    for (final postalCode in postalCodes) {
      final sales = postalCode['total_delivery_sales'] ?? 0;
      if (sales is String) {
        total += double.tryParse(sales) ?? 0.0;
      } else if (sales is num) {
        total += sales.toDouble();
      }
    }
    return total;
  }
}