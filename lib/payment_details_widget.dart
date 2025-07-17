import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart';
import 'package:epos/services/thermal_printer_service.dart';

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
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  double _discountedTotal = 0.0;
  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _amountReceivedController.addListener(_calculateChange);
    _discountPercentageController.addListener(_calculateDiscountedTotal);
    _checkPrinterStatus();
  }

  @override
  void dispose() {
    _amountReceivedController.removeListener(_calculateChange);
    _discountPercentageController.removeListener(_calculateDiscountedTotal);
    _amountReceivedController.dispose();
    _discountPercentageController.dispose();
    super.dispose();
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
          child: Divider(
            thickness: 2,
            color: Colors.grey,
          ),
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
                  // Payment Type Selection
                  const Text(
                    'Payment Type:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedPaymentType = 'Cash';
                                _calculateChange();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPaymentType == 'Cash'
                                  ? Colors.black
                                  : Colors.grey[200],
                              foregroundColor: _selectedPaymentType == 'Cash'
                                  ? Colors.white
                                  : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: _selectedPaymentType == 'Cash'
                                      ? Colors.black
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              elevation: _selectedPaymentType == 'Cash' ? 6 : 2,
                            ),
                            child: const Text(
                              'Cash',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
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
                                  ? Colors.black
                                  : Colors.grey[200],
                              foregroundColor: _selectedPaymentType == 'Card'
                                  ? Colors.white
                                  : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: _selectedPaymentType == 'Card'
                                      ? Colors.black
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              elevation: _selectedPaymentType == 'Card' ? 6 : 2,
                            ),
                            child: const Text(
                              'Card',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Amount Received (for Cash only)
                  if (_selectedPaymentType == 'Cash') ...[
                    TextFormField(
                      controller: _amountReceivedController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount Received (£)',
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
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$'))],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _change < 0 ? Colors.red[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _change < 0 ? Colors.red : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Change: £${_change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: _change < 0 ? Colors.red : Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

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

                  // Discounted Total
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
                ],
              ),
            ),
          ),
        ),

        // Bottom section with divider, subtotal and confirm button
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 42.0),
          child: Divider(thickness: 2, color: Colors.grey),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '£${widget.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
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

                          await _checkPrinterStatus();

                          final paymentDetails = PaymentDetails(
                            paymentType: _selectedPaymentType,
                            amountReceived: _selectedPaymentType == 'Cash'
                                ? (double.tryParse(_amountReceivedController.text) ?? 0.0)
                                : null,
                            discountPercentage: double.tryParse(_discountPercentageController.text) ?? 0.0,
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
                                  'Confirm Payment £${_discountedTotal.toStringAsFixed(2)}',
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

                        await _checkPrinterStatus();

                        final paymentDetails = PaymentDetails(
                          paymentType: _selectedPaymentType,
                          amountReceived: _selectedPaymentType == 'Cash'
                              ? (double.tryParse(_amountReceivedController.text) ?? 0.0)
                              : null,
                          discountPercentage: double.tryParse(_discountPercentageController.text) ?? 0.0,
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