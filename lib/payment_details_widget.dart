// lib/payment_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart';

class PaymentWidget extends StatefulWidget {
  final double subtotal;
  final CustomerDetails customerDetails;
  final Function(PaymentDetails) onPaymentConfirmed;
  final VoidCallback? onBack;

  const PaymentWidget({
    super.key,
    required this.subtotal,
    required this.customerDetails,
    required this.onPaymentConfirmed,
    this.onBack,
  });

  @override
  State<PaymentWidget> createState() => _PaymentWidgetState();
}

class _PaymentWidgetState extends State<PaymentWidget> {
  String _selectedPaymentType = 'Cash';
  final TextEditingController _amountReceivedController = TextEditingController();
  final TextEditingController _discountPercentageController = TextEditingController();

  double _discountedTotal = 0.0;
  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _amountReceivedController.addListener(_calculateChange);
    _discountPercentageController.addListener(_calculateDiscountedTotal);
  }

  @override
  void dispose() {
    _amountReceivedController.removeListener(_calculateChange);
    _discountPercentageController.removeListener(_calculateDiscountedTotal);
    _amountReceivedController.dispose();
    _discountPercentageController.dispose();
    super.dispose();
  }

  void _calculateDiscountedTotal() {
    setState(() {
      double discount = double.tryParse(_discountPercentageController.text) ?? 0.0;
      if (discount < 0) discount = 0.0;
      if (discount > 100) discount = 100.0;

      _discountedTotal = widget.subtotal * (1 - (discount / 100));
      _calculateChange();
    });
  }

  void _calculateChange() {
    setState(() {
      if (_selectedPaymentType == 'Cash') {
        if (_amountReceivedController.text.isEmpty) {
          _change = 0.0;
        } else {
          double received = double.tryParse(_amountReceivedController.text) ?? 0.0;
          _change = received - _discountedTotal;
        }
      } else {
        _change = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header similar to ActiveOrdersList
        Padding(
          padding: const EdgeInsets.only(top: 30.0, bottom: 20.0),
          child: Row(
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: 30,
                    onPressed: widget.onBack,
                  ),
                ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3D9FF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Payment & Discount',
                      style: TextStyle(
                        fontSize: 32,
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

        // Payment content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3D9FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCB6CE6), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order for: ${widget.customerDetails.name}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Phone: ${widget.customerDetails.phoneNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Subtotal: £${widget.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Color(0xFFCB6CE6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Payment Type Selection
                  const Text(
                    'Payment Type:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 80,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedPaymentType = 'Cash';
                                _calculateChange();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPaymentType == 'Cash'
                                  ? const Color(0xFFCB6CE6)
                                  : Colors.grey[200],
                              foregroundColor: _selectedPaymentType == 'Cash'
                                  ? Colors.white
                                  : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedPaymentType == 'Cash'
                                      ? const Color(0xFFCB6CE6)
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              elevation: _selectedPaymentType == 'Cash' ? 8 : 2,
                            ),
                            child: const Text(
                              'Cash',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Container(
                          height: 80,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedPaymentType = 'Card';
                                _amountReceivedController.clear();
                                _change = 0.0;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPaymentType == 'Card'
                                  ? const Color(0xFFCB6CE6)
                                  : Colors.grey[200],
                              foregroundColor: _selectedPaymentType == 'Card'
                                  ? Colors.white
                                  : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedPaymentType == 'Card'
                                      ? const Color(0xFFCB6CE6)
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              elevation: _selectedPaymentType == 'Card' ? 8 : 2,
                            ),
                            child: const Text(
                              'Card',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Amount Received (for Cash only)
                  if (_selectedPaymentType == 'Cash') ...[
                    TextFormField(
                      controller: _amountReceivedController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount Received (£)',
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$'))],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _change < 0 ? Colors.red[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _change < 0 ? Colors.red : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Change: £${_change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: _change < 0 ? Colors.red : Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Discount Field
                  TextFormField(
                    controller: _discountPercentageController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'Poppins',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage (%)',
                      hintText: 'e.g., 10 for 10%',
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                  ),

                  const SizedBox(height: 20),

                  // Discounted Total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3D9FF),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFCB6CE6), width: 2),
                    ),
                    child: Text(
                      'Final Total: £${_discountedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color(0xFFCB6CE6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Confirm Button
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedPaymentType == 'Cash' &&
                            (_amountReceivedController.text.isEmpty ||
                                (double.tryParse(_amountReceivedController.text) ?? 0.0) < _discountedTotal)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Amount received must be greater than or equal to the final total.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final paymentDetails = PaymentDetails(
                          paymentType: _selectedPaymentType,
                          amountReceived: _selectedPaymentType == 'Cash'
                              ? (double.tryParse(_amountReceivedController.text) ?? 0.0)
                              : null,
                          discountPercentage: double.tryParse(_discountPercentageController.text) ?? 0.0,
                        );
                        widget.onPaymentConfirmed(paymentDetails);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB6CE6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        'Confirm Order',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}