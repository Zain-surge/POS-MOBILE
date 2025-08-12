import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart'; // Assuming PaymentDetails is here
import 'package:epos/services/thermal_printer_service.dart';
import 'dart:async';
import 'dart:ui';

// Assume the DialerPage is in a file named 'dialer_page.dart'
import 'package:epos/dialer.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class PaymentWidget extends StatefulWidget {
  final double subtotal; // This is the original, undiscounted subtotal
  final CustomerDetails? customerDetails;
  final String paymentType;
  final Function(PaymentDetails) onPaymentConfirmed;
  final VoidCallback? onBack;

  const PaymentWidget({
    super.key,
    required this.subtotal,
    this.customerDetails,
    required this.paymentType,
    required this.onPaymentConfirmed,
    this.onBack,
  });

  @override
  State<PaymentWidget> createState() => _PaymentWidgetState();
}

class _PaymentWidgetState extends State<PaymentWidget> {
  final TextEditingController _amountPaidController = TextEditingController();
  final FocusNode _amountPaidFocusNode = FocusNode();
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  bool _isCustomAmountMode = false;
  double _discountedTotal = 0.0;
  double _selectedAmount = 0.0;
  double _changeDue = 0.0;
  List<double> _presetAmounts = [];
  bool _isCustomAmountDialerOpen = false;
  Timer? _printerStatusTimer; // Added for periodic printer status checking

  double _currentDiscountPercentageForPaymentDetails = 0.0;

  OverlayEntry? _changeOverlayEntry;

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _selectedAmount = widget.paymentType.toLowerCase() == 'card' ? _discountedTotal : 0.0;

    if (widget.paymentType.toLowerCase() == 'card') {
      _isCustomAmountMode = false;
      _amountPaidController.text = _discountedTotal.toStringAsFixed(2);
    } else {
      _isCustomAmountMode = false;
      _amountPaidController.clear();
    }

    _amountPaidController.addListener(_onAmountPaidChanged);
    _calculatePresetAmounts();

    // Start printer status checking when widget initializes
    _startPrinterStatusChecking();
  }

  void _startPrinterStatusChecking() {
    _checkPrinterStatus();

    // Create a periodic timer and store the reference
    _printerStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkPrinterStatus();
    });
  }

  // New method to handle the amount returned from the payment dialer.
  void _onPaymentDialerConfirmed(double amount) {
    setState(() {
      _selectedAmount = amount;
      _isCustomAmountMode = true; // Flag as custom amount from dialer
      _amountPaidController.text = _selectedAmount.toStringAsFixed(2);
      _isCustomAmountDialerOpen = false;
    });
    _calculateChange();
  }

  void _onDialerClose() {
    setState(() {
      _isCustomAmountDialerOpen = false;
    });
  }

  @override
  void dispose() {
    // Cancel the timer before disposing
    _printerStatusTimer?.cancel();

    _amountPaidController.removeListener(_onAmountPaidChanged);
    _amountPaidController.dispose();
    _amountPaidFocusNode.dispose();
    _changeOverlayEntry?.remove();
    super.dispose();
  }

  void _onAmountPaidChanged() {
    if (widget.paymentType.toLowerCase() == 'card' || _isCustomAmountMode) {
      if (_amountPaidController.text.isNotEmpty) {
        double amount = double.tryParse(_amountPaidController.text) ?? 0.0;
        setState(() {
          _selectedAmount = amount;
        });
        _calculateChange();
      }
    }
  }

  void _calculatePresetAmounts() {
    if (widget.paymentType.toLowerCase() == 'cash') {
      double exactAmount = _discountedTotal;
      double nextRoundFive = (exactAmount / 5).ceil() * 5.0;
      double nextRoundTen = (exactAmount / 10).ceil() * 10.0;

      List<double> amounts = [exactAmount];

      if (nextRoundFive > exactAmount && !amounts.contains(nextRoundFive)) {
        amounts.add(nextRoundFive);
      }

      if (nextRoundTen > exactAmount && !amounts.contains(nextRoundTen) && amounts.length < 3) {
        amounts.add(nextRoundTen);
      }

      while (amounts.length < 3) {
        double lastAmount = amounts.last;
        double nextAmount;

        if (lastAmount < 10) {
          nextAmount = lastAmount + 1.0;
        } else if (lastAmount < 20) {
          nextAmount = lastAmount + 2.0;
        } else {
          nextAmount = lastAmount + 5.0;
        }

        if (!amounts.contains(nextAmount) && (nextAmount - exactAmount).abs() > 0.001) {
          amounts.add(nextAmount);
        } else {
          break;
        }
      }
      _presetAmounts = amounts.take(3).toList();
    } else {
      _presetAmounts = [];
    }
  }

  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter || !mounted) return; // Add mounted check

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus = await ThermalPrinterService().checkConnectionStatusOnly();
      bool isConnected = connectionStatus['usb'] == true || connectionStatus['bluetooth'] == true;

      if (mounted) { // Check mounted before setState
        setState(() {
          _isPrinterConnected = isConnected;
          _isCheckingPrinter = false;
        });
      }
    } catch (e) {
      print('Error checking printer status: $e');
      if (mounted) { // Check mounted before setState
        setState(() {
          _isPrinterConnected = false;
          _isCheckingPrinter = false;
        });
      }
    }
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
      _amountPaidController.text = amount.toStringAsFixed(2);
      _currentDiscountPercentageForPaymentDetails = 0.0;
      _calculateChange();
    });
  }

  void _showChangeOverlay(double changeAmount) {
    if (_changeOverlayEntry != null && _changeOverlayEntry!.mounted) {
      _changeOverlayEntry!.remove();
      _changeOverlayEntry = null;
    }

    _changeOverlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 450.0, vertical: 300.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade100, width: 2.0),
                borderRadius: BorderRadius.circular(30),
                color: Colors.black.withOpacity(0.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.transparent,
                    child: _buildChangeDisplayContent(changeAmount),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_changeOverlayEntry!);

    Timer(const Duration(seconds: 5), () {
      if (_changeOverlayEntry != null && _changeOverlayEntry!.mounted) {
        _changeOverlayEntry!.remove();
        _changeOverlayEntry = null;
      }
    });
  }

  Widget _buildChangeDisplayContent(double changeAmount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'CHANGE   £${changeAmount.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 16.0),
                child: Row(
                  children: [
                    if (widget.onBack != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 3.0),
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: SizedBox(
                            width: 45,
                            height: 45,
                            child: Image.asset(
                              'assets/images/bArrow.png',
                              fit: BoxFit.contain,
                            ),
                          ),
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 55.0),
                child: Divider(
                  height: 0,
                  thickness: 3,
                  color: const Color(0xFFB2B2B2),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        if (widget.paymentType.toLowerCase() == 'cash')
                          Column(
                            children: [
                              for (int i = 0; i < _presetAmounts.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 65,
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
                                        ' £${_presetAmounts[i].toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 65,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isCustomAmountDialerOpen = true;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Other',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Icon(
                                          Icons.dialpad,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (widget.paymentType.toLowerCase() == 'card')


                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0), // apply horizontal padding
                            child: Row(
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
                                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                                      isDense: true,
                                      prefixText: '£',
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                                    readOnly: false,
                                    onTap: () {},
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 55.0),
                child: Divider(
                  height: 0,
                  thickness: 3,
                  color: const Color(0xFFB2B2B2),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '£${_discountedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '£${_changeDue.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: (_selectedAmount > 0 || (widget.paymentType.toLowerCase() == 'card' && _amountPaidController.text.isNotEmpty && double.tryParse(_amountPaidController.text) != null && double.parse(_amountPaidController.text) > 0))
                                  ? () async {
                                if (_selectedAmount < _discountedTotal) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Amount paid cannot be less than the discounted total.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                if (_changeDue > 0) {
                                  _showChangeOverlay(_changeDue);
                                }
                                final paymentDetails = PaymentDetails(
                                  paymentType: widget.paymentType,
                                  amountReceived: _selectedAmount,
                                  discountPercentage: _currentDiscountPercentageForPaymentDetails,
                                  totalCharge: _discountedTotal,
                                );
                                widget.onPaymentConfirmed(paymentDetails);
                              }
                                  : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter or choose an amount to pay.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                                      const SizedBox(width: 10),
                                      Image.asset(
                                        'assets/images/printer.png',
                                        width: 58,
                                        height: 58,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),

        // Printer status indicator - positioned at top right corner
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPrinterConnected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (_isPrinterConnected ? Colors.green : Colors.red).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),

        // Conditionally render the DialerPage when a custom amount is needed
        if (_isCustomAmountDialerOpen)
          Positioned.fill(
            child: DialerPage(
              mode: DialerMode.payment,
              subtotal: widget.subtotal,
              onPaymentEntered: (amount) {
                _onPaymentDialerConfirmed(amount);
              },
              onBack: _onDialerClose,
              currentOrderType: 'takeaway', // Dummy value for this context
              onOrderTypeChanged: (type) {}, // Dummy function for this context
            ),
          ),
      ],
    );
  }
}