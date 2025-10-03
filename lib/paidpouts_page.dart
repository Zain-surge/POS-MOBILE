// lib/pages/paidouts_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/paidout_models.dart';
import '../providers/paidout_provider.dart';
import '../services/custom_popup_service.dart';
import 'package:epos/services/uk_time_service.dart';

class PaidOutsPage extends StatefulWidget {
  const PaidOutsPage({super.key});

  @override
  State<PaidOutsPage> createState() => _PaidOutsPageState();
}

class _PaidOutsPageState extends State<PaidOutsPage> {
  static const List<String> _defaultPaidOutOptions = [
    'Shopping',
    'Bills',
    'Supplier Payment',
    'Staff Wages',
    'Rent',
    'Utilities',
    'Insurance',
    'Equipment Purchase',
    'Maintenance',
    'Transportation',
    'Marketing',
    'Office Supplies',
    'Cleaning Supplies',
    'Bank Charges',
    'Professional Services',
    'Other',
  ];

  List<PaidOut> _paidOuts = [PaidOut(label: '', amount: 0.0)];
  bool _isSubmitting = false;
  List<TextEditingController> _labelControllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    // Fetch today's paid outs when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PaidOutProvider>(
        context,
        listen: false,
      ).fetchTodaysPaidOuts();
    });
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _labelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPaidOut() {
    setState(() {
      _paidOuts.add(PaidOut(label: '', amount: 0.0));
      _labelControllers.add(TextEditingController());
    });
  }

  void _removePaidOut(int index) {
    if (_paidOuts.length > 1) {
      setState(() {
        _paidOuts.removeAt(index);
        _labelControllers[index].dispose();
        _labelControllers.removeAt(index);
      });
    }
  }

  void _updateLabel(int index, String value) {
    setState(() {
      _paidOuts[index].label = value;
    });
  }

  void _selectPredefinedLabel(int index, String label) {
    setState(() {
      _paidOuts[index].label = label;
      _labelControllers[index].text = label;
    });
  }

  void _updateAmount(int index, String value) {
    setState(() {
      _paidOuts[index].amount = double.tryParse(value) ?? 0.0;
    });
  }

  double get _totalAmount {
    return _paidOuts.fold(0.0, (sum, paidOut) => sum + paidOut.amount);
  }

  bool get _canSubmit {
    return _paidOuts.every(
      (paidOut) => paidOut.label.trim().isNotEmpty && paidOut.amount > 0,
    );
  }

  Future<void> _submitPaidOuts() async {
    if (!_canSubmit) {
      CustomPopupService.show(
        context,
        '❌ Please fill all fields with valid data',
        type: PopupType.failure,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Provider.of<PaidOutProvider>(
        context,
        listen: false,
      ).submitPaidOuts(_paidOuts);

      if (mounted) {
        CustomPopupService.show(
          context,
          '✅ Paid outs submitted successfully',
          type: PopupType.success,
        );

        // Reset form
        setState(() {
          _paidOuts = [PaidOut(label: '', amount: 0.0)];
          // Clear all controllers and reset to single controller
          for (var controller in _labelControllers) {
            controller.dispose();
          }
          _labelControllers = [TextEditingController()];
        });
      }
    } catch (e) {
      print('Error submitting paid outs: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          '❌ Failed to submit paid outs: ${e.toString()}',
          type: PopupType.failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            _buildHeader(),

            // Main content
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Paid Outs title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.money_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Paid Outs Management",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Empty space to balance the layout
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Form for adding new paid outs
          Expanded(flex: 1, child: _buildFormSection()),
          const SizedBox(width: 20),
          // Right side - Today's paid outs list
          Expanded(flex: 1, child: _buildTodaysSection()),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Record New Paid Outs',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Form description
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.money_off_rounded,
                size: 40,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 10),
              Text(
                'Add Payment Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Record payments made from cash register',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Paid Outs List
        Container(
          height: 400,
          child: ListView.builder(
            itemCount: _paidOuts.length,
            itemBuilder: (context, index) => _buildPaidOutItem(index),
          ),
        ),

        const SizedBox(height: 15),

        // Add button
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addPaidOut,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Add Another Entry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Total and Submit section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '£${_totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _canSubmit && !_isSubmitting ? _submitPaidOuts : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canSubmit && !_isSubmitting
                            ? Colors.black
                            : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Submit Paid Outs',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaidOutItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Number badge
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Label field
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _labelControllers[index],
                  onChanged: (value) => _updateLabel(index, value),
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., Supplier Payment',
                    labelStyle: GoogleFonts.poppins(fontSize: 10),
                    hintStyle: GoogleFonts.poppins(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Amount field
              Expanded(
                flex: 1,
                child: TextField(
                  onChanged: (value) => _updateAmount(index, value),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '£',
                    labelStyle: GoogleFonts.poppins(fontSize: 10),
                    hintStyle: GoogleFonts.poppins(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Remove button
              if (_paidOuts.length > 1)
                IconButton(
                  onPressed: () => _removePaidOut(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                  tooltip: 'Remove',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick select buttons for predefined options
          Container(
            width: double.infinity,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  _defaultPaidOutOptions.map((option) {
                    final isSelected = _paidOuts[index].label == option;
                    return GestureDetector(
                      onTap: () => _selectPredefinedLabel(index, option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's section header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "Today's Paid Outs",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Summary section
        Consumer<PaidOutProvider>(
          builder: (context, provider, child) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total Today',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '£${provider.totalTodaysAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('dd/MM/yyyy').format(UKTimeService.now()),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 15),

        // Refresh button
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Provider.of<PaidOutProvider>(
                context,
                listen: false,
              ).fetchTodaysPaidOuts();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'Refresh',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Today's paid outs table
        Container(
          height: 400,
          child: Consumer<PaidOutProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => provider.fetchTodaysPaidOuts(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (provider.todaysPaidOuts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No paid outs today',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Sort paid outs by creation time (oldest first)
              final sortedPaidOuts = [...provider.todaysPaidOuts]
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

              return _buildPaidOutsTable(sortedPaidOuts);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaidOutsTable(List<PaidOutRecord> paidOuts) {
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
                  flex: 1,
                  child: Text(
                    '#',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
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
                  flex: 2,
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
                  flex: 2,
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
          Expanded(
            child: ListView.builder(
              itemCount: paidOuts.length,
              itemBuilder: (context, index) {
                final paidOut = paidOuts[index];
                final isEven = index % 2 == 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : Colors.grey.shade50,
                    border: Border(
                      bottom:
                          index == paidOuts.length - 1
                              ? BorderSide.none
                              : BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          paidOut.label.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '£${paidOut.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatTime(paidOut.createdAt),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
