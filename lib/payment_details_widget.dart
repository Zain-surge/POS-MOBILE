// lib/widgets/payment_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart'; // Make sure this path is correct
import 'package:epos/services/thermal_printer_service.dart';

class PaymentWidget extends StatefulWidget {
  final double subtotal;
  final CustomerDetails customerDetails;
  final String paymentType; // Add payment type parameter
  final Function(PaymentDetails) onPaymentConfirmed;
  final VoidCallback? onBack;

  const PaymentWidget({
    super.key,
    required this.subtotal,
    required this.customerDetails,
    required this.paymentType, // Add payment type parameter
    required this.onPaymentConfirmed,
    this.onBack,
  });

  @override
  State<PaymentWidget> createState() => _PaymentWidgetState();
}

class _PaymentWidgetState extends State<PaymentWidget> {
  final TextEditingController _discountPercentageController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final FocusNode _amountPaidFocusNode = FocusNode();
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  bool _isCustomAmountMode = false;
  double _discountedTotal = 0.0;
  double _selectedAmount = 0.0;
  double _changeDue = 0.0;
  List<double> _presetAmounts = [];

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _selectedAmount = widget.subtotal;
    _discountPercentageController.addListener(_calculateDiscountedTotal);
    _amountPaidController.addListener(_onAmountPaidChanged);
    _calculatePresetAmounts();
    _checkPrinterStatus();
  }

  @override
  void dispose() {
    _discountPercentageController.removeListener(_calculateDiscountedTotal);
    _amountPaidController.removeListener(_onAmountPaidChanged);
    _discountPercentageController.dispose();
    _amountPaidController.dispose();
    _amountPaidFocusNode.dispose();
    super.dispose();
  }

  void _onAmountPaidChanged() {
    if (_isCustomAmountMode) {
      String text = _amountPaidController.text;
      double amount = double.tryParse(text) ?? 0.0;
      if (amount == 0.0 && text.isNotEmpty) {
        amount = _discountedTotal;
      }
      setState(() {
        _selectedAmount = amount;
      });
      _calculateChange();
    }
  }

  void _calculatePresetAmounts() {
    double exactAmount = _discountedTotal;

    // Find the next round number (5, 10, 15, 20, etc.)
    double nextRoundFive = (exactAmount / 5).ceil() * 5.0;
    double nextRoundTen = (exactAmount / 10).ceil() * 10.0;

    // Ensure we have three different amounts
    List<double> amounts = [exactAmount];

    // Add next round five if it's different from exact amount
    if (nextRoundFive > exactAmount && !amounts.contains(nextRoundFive)) {
      amounts.add(nextRoundFive);
    }

    // Add next round ten if it's different and we need more options
    if (nextRoundTen > exactAmount && !amounts.contains(nextRoundTen) && amounts.length < 3) {
      amounts.add(nextRoundTen);
    }

    // If we still need more options, add incremental amounts
    while (amounts.length < 3) {
      double lastAmount = amounts.last;
      double nextAmount;

      if (lastAmount < 10) {
        nextAmount = lastAmount + 1.0; // Add £1 for amounts under £10
      } else if (lastAmount < 20) {
        nextAmount = lastAmount + 2.0; // Add £2 for amounts £10-£20
      } else {
        nextAmount = lastAmount + 5.0; // Add £5 for amounts over £20
      }

      if (!amounts.contains(nextAmount)) {
        amounts.add(nextAmount);
      } else {
        break;
      }
    }

    _presetAmounts = amounts.take(3).toList();
  }

  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter) return;

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus = await ThermalPrinterService().testAllConnections();
      bool isConnected = connectionStatus['usb'] == true || connectionStatus['bluetooth'] == true;

      if (mounted) {
        setState(() {
          _isPrinterConnected = isConnected;
          _isCheckingPrinter = false;
        });
      }
    } catch (e) {
      print('Error checking printer status: $e');
      if (mounted) {
        setState(() {
          _isPrinterConnected = false;
          _isCheckingPrinter = false;
        });
      }
    }
  }

  void _calculateDiscountedTotal() {
    setState(() {
      double discount = double.tryParse(_discountPercentageController.text) ?? 0.0;
      if (discount < 0) discount = 0.0;
      if (discount > 100) discount = 100.0;

      _discountedTotal = widget.subtotal * (1 - (discount / 100));
      _calculatePresetAmounts();

      // Reset selected amount to exact amount after discount change
      _selectedAmount = _discountedTotal;
      _isCustomAmountMode = false;
      _amountPaidController.clear();
      _calculateChange();
    });
  }

  void _calculateChange() {
    setState(() {
      _changeDue = (_selectedAmount - _discountedTotal).clamp(0.0, double.infinity);
    });
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _isCustomAmountMode = false;
      _amountPaidController.clear();
      _calculateChange();
    });
  }

  void _enableCustomAmountMode() {
    setState(() {
      _isCustomAmountMode = true;
      _amountPaidController.text = _discountedTotal.toStringAsFixed(2);
      _selectedAmount = _discountedTotal;
      _calculateChange();
    });
    // Focus on the amount paid field after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _amountPaidFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(top: 20.0, bottom: 16.0),
          child: Row(
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.only(right: 3.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: 26,
                    onPressed: widget.onBack,
                  ),
                ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3D9FF),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Text(
                      'Payment & Discount',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
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

        const SizedBox(height: 9),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 42.0),
          child: Divider(thickness: 2, color: Colors.grey),
        ),

        const SizedBox(height: 16),

        // Payment content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Discount Field
                  TextFormField(
                    controller: _discountPercentageController,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage (%)',
                      hintText: 'e.g., 10 for 10%',
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                  ),

                  const SizedBox(height: 16),

                  // Final Total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3D9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCB6CE6), width: 2),
                    ),
                    child: Text(
                      'Final Total: £${_discountedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color(0xFFCB6CE6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preset Amount Buttons
                  Column(
                    children: [
                      for (int i = 0; i < _presetAmounts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => _selectAmount(_presetAmounts[i]),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedAmount == _presetAmounts[i] && !_isCustomAmountMode
                                    ? Colors.black
                                    : Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                '£${_presetAmounts[i].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Other button with keyboard icon
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _enableCustomAmountMode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCustomAmountMode ? Colors.grey[800] : Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Other',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.dialpad,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom section
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 42.0),
          child: Divider(thickness: 2, color: Colors.grey),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Payment summary - Show Amount Paid section when in custom mode or when there's change
              if (_isCustomAmountMode || _selectedAmount >= _discountedTotal) ...[
                // Amount Paid Row - Editable when in custom mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount Paid',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (_isCustomAmountMode)
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _amountPaidController,
                          focusNode: _amountPaidFocusNode,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          decoration: const InputDecoration(
                            prefixText: '£',
                            border: UnderlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                        ),
                      )
                    else
                      Text(
                        '£${_selectedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                  ],
                ),
                if (_selectedAmount > _discountedTotal) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Due',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '£${_changeDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      '£${widget.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Charge Button
              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          // Validation
                          if (_selectedAmount < _discountedTotal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Amount must be greater than or equal to the final total.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          await _checkPrinterStatus();

                          final paymentDetails = PaymentDetails(
                            paymentType: widget.paymentType, // Use the passed payment type
                            amountReceived: _selectedAmount,
                            discountPercentage: double.tryParse(_discountPercentageController.text) ?? 0.0,
                            totalCharge: _discountedTotal,
                          );
                          widget.onPaymentConfirmed(paymentDetails);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Charge    £${_discountedTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_isCheckingPrinter)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.print,
                                    color: _isPrinterConnected ? Colors.green : Colors.red,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        if (_selectedAmount < _discountedTotal) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Amount must be greater than or equal to the final total.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await _checkPrinterStatus();

                        final paymentDetails = PaymentDetails(
                          paymentType: widget.paymentType, // Use the passed payment type
                          amountReceived: _selectedAmount,
                          discountPercentage: double.tryParse(_discountPercentageController.text) ?? 0.0,
                          totalCharge: _discountedTotal,
                        );
                        widget.onPaymentConfirmed(paymentDetails);
                      },
                      child: Image.asset('assets/images/men.png', width: 40, height: 40),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}