import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class CustomAmountDialer extends StatefulWidget {
  final VoidCallback onClose;
  // MODIFIED: Callback now only passes amountPaid and priceAfterDiscount
  final Function(double amountPaid, double priceAfterDiscount) onAmountSelected;
  final double initialOrderPrice; // The original subtotal from PaymentWidget

  const CustomAmountDialer({
    Key? key,
    required this.onClose,
    required this.onAmountSelected,
    required this.initialOrderPrice,
  }) : super(key: key);

  @override
  State<CustomAmountDialer> createState() => _CustomAmountDialerState();
}

class _CustomAmountDialerState extends State<CustomAmountDialer> {
  String _amountToPayString = '';
  String _percentageText = '';
  final TextEditingController _percentageController = TextEditingController();

  double _discountAmount = 0.0;
  double _priceAfterDiscount = 0.0; // This is the new calculated total
  double _amountToPay = 0.0;
  // This remains internal

  @override
  void initState() {
    super.initState();
    _percentageController.addListener(() {
      _onPercentageChanged(_percentageController.text);
    });
    // Initialize with the initial order price and no discount initially
    _priceAfterDiscount = widget.initialOrderPrice;
    _calculateDerivedAmounts(); // Calculate initial state
  }

  void _calculateDerivedAmounts() {
    double percentage = double.tryParse(_percentageText) ?? 0.0;

    if (percentage < 0) percentage = 0.0;
    if (percentage > 100) percentage = 100.0;

    setState(() {
      // Keep this internal
      _discountAmount = (widget.initialOrderPrice * percentage) / 100;
      _priceAfterDiscount = widget.initialOrderPrice - _discountAmount;
      if (_priceAfterDiscount < 0) _priceAfterDiscount = 0.0;

      // Ensure amount to pay isn't less than 0 if a very high discount makes it negative
      _amountToPay = double.tryParse(_amountToPayString) ?? 0.0;
      // If amount to pay is less than discounted price, show discounted price as min
      // This logic depends on whether _amountToPay is what the customer 'gives' or what is 'due'
      // Assuming _amountToPay is what the customer provides for now.
    });
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (number == '.') {
        if (!_amountToPayString.contains('.')) {
          if (_amountToPayString.isEmpty) {
            _amountToPayString = '0.';
          } else {
            _amountToPayString += number;
          }
        }
      } else {
        if (_amountToPayString == '0' && number != '0') {
          _amountToPayString = number;
        } else if (_amountToPayString.isEmpty && number == '0') {
          _amountToPayString = '0';
        } else {
          _amountToPayString += number;
        }
      }
      // Re-calculate to update displays based on current input
      _calculateDerivedAmounts();
    });
  }

  void _onClearPressed() {
    setState(() {
      _amountToPayString = '';
      _percentageController.clear();
      _percentageText = '';
      _calculateDerivedAmounts(); // Recalculate to reset all derived values
    });
  }

  void _onDeletePressed() {
    if (_amountToPayString.isNotEmpty) {
      setState(() {
        _amountToPayString = _amountToPayString.substring(
          0,
          _amountToPayString.length - 1,
        );
        if (_amountToPayString.isEmpty) {
          _amountToPayString = ''; // Clear string if empty after deletion
        }
      });
      _calculateDerivedAmounts();
    }
  }

  void _onPercentageChanged(String value) {
    setState(() {
      _percentageText = value;
      _calculateDerivedAmounts();
    });
  }

  void _onConfirmPressed() {
    // MODIFIED: Only pass amountPaid and the new total (priceAfterDiscount)
    // The discountPercentage is not passed back, it's an internal detail of the dialer
    widget.onAmountSelected(_amountToPay, _priceAfterDiscount);
  }

  Widget _buildDialerButton(
    String text, {
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.0),
            ),
            child: Material(
              color: Colors.black,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                splashColor: Colors.grey.shade100.withOpacity(0.3),
                highlightColor: Colors.grey.shade100.withOpacity(0.1),
                child: Center(
                  child:
                      icon != null
                          ? Icon(icon, size: 28, color: Colors.white)
                          : Text(
                            text,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade100, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(
                            Icons.close,
                            size: 28,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Half: Percentage Input and Amount Displays
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Discount Percentage (remains in dialer UI)
                                    const Text(
                                      'Discount Percentage',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 0,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TextField(
                                        controller: _percentageController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        onChanged: _onPercentageChanged,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8.0,
                                              ),
                                          border: InputBorder.none,
                                          hintText: '0',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                          suffixText: '%',
                                          suffixStyle: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d*$'),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Spacer(flex: 2),

                                    // Price Before Discount (Original Order Price from PaymentWidget)
                                    const Text(
                                      'Price Before Discount',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ' ${widget.initialOrderPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Price After Discount (Calculated by Dialer)
                                    const Text(
                                      'Price After Discount',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ' ${_priceAfterDiscount.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),

                                    const Spacer(flex: 2),

                                    // Amount to Pay Text Field (Manual input by customer)
                                    const Text(
                                      'Enter Amount',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Text(
                                        ' ${_amountToPayString.isEmpty ? '0.00' : double.parse(_amountToPayString).toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 60,
                                      child: ElevatedButton(
                                        onPressed:
                                            (_amountToPayString.isNotEmpty &&
                                                    _amountToPay > 0)
                                                ? _onConfirmPressed
                                                : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.white,
                                              width: 3.0,
                                            ),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: const Text(
                                          'Confirm ',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Right Half: Numeric Dialer
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20),

                                    // Number pad
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildDialerButton(
                                                '7',
                                                onPressed:
                                                    () => _onNumberPressed('7'),
                                              ),
                                              _buildDialerButton(
                                                '8',
                                                onPressed:
                                                    () => _onNumberPressed('8'),
                                              ),
                                              _buildDialerButton(
                                                '9',
                                                onPressed:
                                                    () => _onNumberPressed('9'),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildDialerButton(
                                                '4',
                                                onPressed:
                                                    () => _onNumberPressed('4'),
                                              ),
                                              _buildDialerButton(
                                                '5',
                                                onPressed:
                                                    () => _onNumberPressed('5'),
                                              ),
                                              _buildDialerButton(
                                                '6',
                                                onPressed:
                                                    () => _onNumberPressed('6'),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildDialerButton(
                                                '1',
                                                onPressed:
                                                    () => _onNumberPressed('1'),
                                              ),
                                              _buildDialerButton(
                                                '2',
                                                onPressed:
                                                    () => _onNumberPressed('2'),
                                              ),
                                              _buildDialerButton(
                                                '3',
                                                onPressed:
                                                    () => _onNumberPressed('3'),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildDialerButton(
                                                'C',
                                                onPressed: _onClearPressed,
                                              ),
                                              _buildDialerButton(
                                                '0',
                                                onPressed:
                                                    () => _onNumberPressed('0'),
                                              ),
                                              _buildDialerButton(
                                                '.',
                                                onPressed:
                                                    () => _onNumberPressed('.'),
                                              ),
                                              _buildDialerButton(
                                                '',
                                                onPressed: _onDeletePressed,
                                                icon: Icons.backspace_outlined,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }
}
