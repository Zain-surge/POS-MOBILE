import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart'; // Assuming PaymentDetails is here
import 'package:epos/services/thermal_printer_service.dart';
import 'package:epos/custom_amount_dialer.dart';
import 'dart:async';
import 'dart:ui';

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
  final CustomerDetails customerDetails;
  final String paymentType;
  final Function(PaymentDetails) onPaymentConfirmed;
  final VoidCallback? onBack;

  const PaymentWidget({
    super.key,
    required this.subtotal,
    required this.customerDetails,
    required this.paymentType,
    required this.onPaymentConfirmed,
    this.onBack,
  });

  @override
  State<PaymentWidget> createState() => _PaymentWidgetState();
}

class _PaymentWidgetState extends State<PaymentWidget> {
  // REMOVED: _discountPercentageController as per your instruction.
  final TextEditingController _amountPaidController = TextEditingController();
  final FocusNode _amountPaidFocusNode = FocusNode();
  bool _isPrinterConnected = false;
  bool _isCheckingPrinter = false;
  bool _isCustomAmountMode = false; // True if 'Other' dialer was used
  double _discountedTotal = 0.0; // This will hold the "Price After Discount" from dialer or initial subtotal
  double _selectedAmount = 0.0; // This is the amount paid by the customer
  double _changeDue = 0.0;
  List<double> _presetAmounts = [];
  bool _isCustomAmountDialerOpen = false;

  // This will store the discount percentage only if the dialer was used
  // and we need to pass it to PaymentDetails.
  // It's not for UI or internal calculations within PaymentWidget.
  double _currentDiscountPercentageForPaymentDetails = 0.0;

  OverlayEntry? _changeOverlayEntry;

  @override
  void initState() {
    super.initState();
    // Initially, the total to charge is the full subtotal
    _discountedTotal = widget.subtotal;
    // For card, amount paid is usually the total. For cash, it starts at 0.
    _selectedAmount = widget.paymentType.toLowerCase() == 'card' ? _discountedTotal : 0.0;

    if (widget.paymentType.toLowerCase() == 'card') {
      _isCustomAmountMode = false; // Card is not "custom" in terms of discount dialer
      _amountPaidController.text = _discountedTotal.toStringAsFixed(2);
    } else {
      _isCustomAmountMode = false;
      _amountPaidController.clear();
    }

    // REMOVED: _discountPercentageController.addListener(_calculateDiscountedTotal);
    _amountPaidController.addListener(_onAmountPaidChanged);
    _calculatePresetAmounts(); // Calculate initial presets based on subtotal
    _checkPrinterStatus();
  }

  void _enableCustomAmountMode() {
    setState(() {
      _isCustomAmountDialerOpen = true;
    });
  }

  // MODIFIED: Now only receives amountPaid and priceAfterDiscount
  void _onCustomAmountSelected(double amountPaidFromDialer, double priceAfterDiscountFromDialer) {
    setState(() {
      _selectedAmount = amountPaidFromDialer; // The amount user paid
      _discountedTotal = priceAfterDiscountFromDialer; // The new total after dialer's discount

      // INFER the discount percentage for PaymentDetails
      if (widget.subtotal > 0 && priceAfterDiscountFromDialer < widget.subtotal) {
        _currentDiscountPercentageForPaymentDetails = ((widget.subtotal - priceAfterDiscountFromDialer) / widget.subtotal) * 100;
      } else {
        _currentDiscountPercentageForPaymentDetails = 0.0;
      }

      _amountPaidController.text = _selectedAmount.toStringAsFixed(2); // Update the Amount Paid field
      _isCustomAmountMode = true; // Flag that amount is from custom input (via dialer)
      _isCustomAmountDialerOpen = false; // Close the dialer
    });
    _calculateChange(); // Recalculate change with new values
    _calculatePresetAmounts(); // Recalculate presets as _discountedTotal has changed
  }

  void _onDialerClose() {
    setState(() {
      _isCustomAmountDialerOpen = false;
    });
    // If dialer was closed without confirming, ensure _isCustomAmountMode is reset
    // if the payment type is cash and no specific amount was chosen.
    if (widget.paymentType.toLowerCase() == 'cash' && _selectedAmount == 0.0) {
      _isCustomAmountMode = false;
    }
  }

  @override
  void dispose() {
    // REMOVED: _discountPercentageController.removeListener(_calculateDiscountedTotal);
    _amountPaidController.removeListener(_onAmountPaidChanged);
    // REMOVED: _discountPercentageController.dispose();
    _amountPaidController.dispose();
    _amountPaidFocusNode.dispose();
    _changeOverlayEntry?.remove();
    super.dispose();
  }

  void _onAmountPaidChanged() {
    // This listener only acts if it's a card payment or if we are in custom amount mode
    // where the amount can be manually edited (e.g., after custom dialer).
    // For cash presets, _selectedAmount is set directly.
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
      double exactAmount = _discountedTotal; // Use the current total (after dialer discount)

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

  // REMOVED: _calculateDiscountedTotal method entirely as per your instructions.
  // The _discountedTotal is now set directly by CustomAmountDialer or remains widget.subtotal.

  void _calculateChange() {
    setState(() {
      _changeDue = (_selectedAmount - _discountedTotal).clamp(0.0, double.infinity);
    });
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _isCustomAmountMode = false; // Selecting a preset, not a custom amount via dialer
      _amountPaidController.text = amount.toStringAsFixed(2); // Update text field with preset
      _currentDiscountPercentageForPaymentDetails = 0.0; // Reset discount if preset chosen
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
          color: Colors.black.withOpacity(0.5), // This provides the overall dark, semi-transparent background
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

                        // NO Discount Percentage Input in this UI (per your instructions)

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
                                        '£ ${_presetAmounts[i].toStringAsFixed(2)}',
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
                                    onPressed: _enableCustomAmountMode,
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
                        // This TextFormField handles manual input for card
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
                                  // For card, it's always editable.
                                  readOnly: false, // Card payment always editable
                                  onTap: () {
                                    // For card, tapping doesn't open dialer, it allows direct input
                                  },
                                ),
                              ),
                            ],
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

              // This section displays calculated values
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // // Price Before Discount: Always shows widget.subtotal
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     const Text(
                    //       'Price Before Discount',
                    //       style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    //     ),
                    //     Text(
                    //       '£${widget.subtotal.toStringAsFixed(2)}',
                    //       style: const TextStyle(fontSize: 22),
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 10),

                    // Price After Discount: Reflects _discountedTotal from dialer or initial subtotal
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

                    // // This handles the "Amount Paid" / "Amount Due" display logic
                    // // FIXED: This uses `[]` for List of Widgets, not `{...}` for Set
                    // if (_selectedAmount >= _discountedTotal) // If enough or more is paid
                    //   ...[
                    //     Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [
                    //         const Text(
                    //           'Amount Paid',
                    //           style: TextStyle(
                    //             fontSize: 20,
                    //             fontWeight: FontWeight.bold,
                    //             fontFamily: 'Poppins',
                    //           ),
                    //         ),
                    //         Text(
                    //           '£${_selectedAmount.toStringAsFixed(2)}',
                    //           style: const TextStyle(
                    //             fontSize: 20,
                    //             fontWeight: FontWeight.bold,
                    //             fontFamily: 'Poppins',
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //     if (_changeDue > 0 && widget.paymentType.toLowerCase() == 'cash') // Only show change for cash
                    //       ...[
                    //         const SizedBox(height: 4),
                    //         Row(
                    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //           children: [
                    //             const Text(
                    //               'Change Due',
                    //               style: TextStyle(
                    //                 fontSize: 20,
                    //                 fontWeight: FontWeight.bold,
                    //                 fontFamily: 'Poppins',
                    //                 color: Colors.green,
                    //               ),
                    //             ),
                    //             Text(
                    //               '£${_changeDue.toStringAsFixed(2)}',
                    //               style: const TextStyle(
                    //                 fontSize: 20,
                    //                 fontWeight: FontWeight.bold,
                    //                 fontFamily: 'Poppins',
                    //                 color: Colors.green,
                    //               ),
                    //             ),
                    //           ],
                    //         ),
                    //       ],
                    //   ]
                    // else // If amount paid is less than discounted total (meaning still due)
                    //   Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //     children: [
                    //       const Text(
                    //         'Amount Due', // Indicates remaining amount to be paid
                    //         style: TextStyle(
                    //           fontSize: 20,
                    //           fontWeight: FontWeight.bold,
                    //           fontFamily: 'Poppins',
                    //         ),
                    //       ),
                    //       Text(
                    //         '£${_discountedTotal.toStringAsFixed(2)}',
                    //         style: const TextStyle(
                    //           fontSize: 20,
                    //           fontWeight: FontWeight.bold,
                    //           fontFamily: 'Poppins',
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    //
                    // const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: (_selectedAmount > 0 || (widget.paymentType.toLowerCase() == 'card' && _amountPaidController.text.isNotEmpty && double.tryParse(_amountPaidController.text) != null && double.parse(_amountPaidController.text) > 0))
                                  ? () async {
                                // ... existing logic ...
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

                                await _checkPrinterStatus();

                                final paymentDetails = PaymentDetails(
                                  paymentType: widget.paymentType,
                                  amountReceived: _selectedAmount,
                                  discountPercentage: _currentDiscountPercentageForPaymentDetails,
                                  totalCharge: _discountedTotal,
                                );
                                widget.onPaymentConfirmed(paymentDetails);
                              }
                                  : () {
                                // Show a message if no amount is selected/entered
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter or choose an amount to pay.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 22),
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
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_isCustomAmountDialerOpen)
          CustomAmountDialer(
            onClose: _onDialerClose,
            initialOrderPrice: widget.subtotal, // Pass the original subtotal
            // MODIFIED: Only receive amountPaid and priceAfterDiscount
            onAmountSelected: (amountPaid, priceAfterDiscount) {
              _onCustomAmountSelected(amountPaid, priceAfterDiscount);
            },
          ),
      ],
    );
  }
}