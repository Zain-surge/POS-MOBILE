// lib/widgets/paidouts_table_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaidOutsTableWidget extends StatelessWidget {
  final Map<String, dynamic>? report;

  const PaidOutsTableWidget({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (report == null) return const SizedBox.shrink();

    // Extract paidouts data - could be a list or individual fields
    final paidOuts = _extractPaidOuts(report!);

    if (paidOuts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No paid outs for today',
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
              color: Colors.orange.shade50,
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
                    'Description',
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
                    'Amount',
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
                    'Time',
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
          ...paidOuts.asMap().entries.map((entry) {
            final index = entry.key;
            final paidOut = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven ? Colors.white : Colors.grey.shade50,
                border: Border(
                  bottom: index == paidOuts.length - 1
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      paidOut['label']?.toString() ?? 
                      paidOut['description']?.toString() ?? 
                      paidOut['reason']?.toString() ?? 
                      'Paid Out',
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
                      '£${_formatAmount(paidOut['amount'] ?? paidOut['value'] ?? 0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _formatTime(paidOut['payout_date'] ?? paidOut['time'] ?? paidOut['created_at'] ?? ''),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
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
              color: Colors.orange.shade100,
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
                    'TOTAL PAID OUTS',
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
                    '£${_formatAmount(_calculateTotalPaidOuts(paidOuts))}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _extractPaidOuts(Map<String, dynamic> report) {
    // The API returns paidouts as a list with structure: {id, payout_date, label, amount}
    if (report['paidouts'] is List) {
      return report['paidouts'] as List<dynamic>;
    }
    
    // Try other possible keys for paid outs data (fallback)
    if (report['paidouts_details'] is List) {
      return report['paidouts_details'] as List<dynamic>;
    }
    if (report['paid_outs'] is List) {
      return report['paid_outs'] as List<dynamic>;
    }
    if (report['paidouts_list'] is List) {
      return report['paidouts_list'] as List<dynamic>;
    }
    
    // If we have a total paidouts value but no details, create a single entry
    final paidOutsTotal = report['paidouts'];
    if (paidOutsTotal != null && paidOutsTotal is! List) {
      final amount = double.tryParse(paidOutsTotal.toString()) ?? 0.0;
      if (amount > 0) {
        return [
          {
            'description': 'Total Paid Outs',
            'amount': amount,
            'time': '',
          }
        ];
      }
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

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    
    try {
      // Try to parse different time formats
      DateTime? dateTime;
      
      if (timeStr.contains('T')) {
        dateTime = DateTime.tryParse(timeStr);
      } else if (timeStr.contains(':')) {
        // Assume it's just a time string like "14:30"
        return timeStr;
      }
      
      if (dateTime != null) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // If parsing fails, return the original string
    }
    
    return timeStr;
  }

  double _calculateTotalPaidOuts(List<dynamic> paidOuts) {
    double total = 0.0;
    for (final paidOut in paidOuts) {
      // API structure uses 'amount' field
      final amount = paidOut['amount'] ?? paidOut['value'] ?? 0;
      if (amount is String) {
        total += double.tryParse(amount) ?? 0.0;
      } else if (amount is num) {
        total += amount.toDouble();
      }
    }
    return total;
  }
}