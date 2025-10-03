import 'package:flutter/material.dart';
import 'package:epos/services/custom_popup_service.dart';

// Enum to define the two modes for the dialer page.
enum DialerMode { discount, payment }

// The callback function signature for when a discount is applied.
typedef OnDiscountApplied =
    Function(double finalTotal, double discountPercentage);

// The callback function signature for when a custom payment amount is entered.
typedef OnPaymentEntered = Function(double amount);

class DialerPage extends StatefulWidget {
  final double subtotal;
  final DialerMode mode;
  final OnDiscountApplied? onDiscountApplied;
  final OnPaymentEntered? onPaymentEntered;
  final VoidCallback? onBack;
  final String currentOrderType;
  final Function(String) onOrderTypeChanged;

  const DialerPage({
    super.key,
    required this.subtotal,
    required this.mode,
    this.onDiscountApplied,
    this.onPaymentEntered,
    this.onBack,
    required this.currentOrderType,
    required this.onOrderTypeChanged,
  });

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  // State variables for managing the selected discount/payment.
  double _selectedDiscountPercentage = 0.0;
  double _discountedTotal = 0.0;
  double _discountAmount = 0.0;
  String _displayValue = '0';

  // State variables for service selection (kept from original code)
  String _actualOrderType = 'collection';
  bool _hasProcessedFirstStep = false;

  // New variable to hold the entered payment amount.
  double _paymentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _actualOrderType = widget.currentOrderType;
  }

  Widget _buildServiceHighlight(String type, String imageName) {
    bool isSelected =
        _actualOrderType.toLowerCase() == type.toLowerCase() ||
        (type.toLowerCase() == 'takeaway' &&
            _actualOrderType.toLowerCase() == 'collection');

    String displayImage =
        isSelected && !imageName.contains('white.png')
            ? imageName.replaceAll('.png', 'white.png')
            : imageName;

    String baseImageNameForSizing = imageName.replaceAll('white.png', '.png');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (type.toLowerCase() == 'takeaway') {
              _actualOrderType = 'collection';
            } else {
              _actualOrderType = type;
            }
          });
          widget.onOrderTypeChanged(_actualOrderType);
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          // Adjusted size for service highlight icons
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border:
                _hasProcessedFirstStep && !isSelected
                    ? Border.all(color: Colors.grey.withOpacity(0.5), width: 1)
                    : null,
          ),
          child: Center(
            child: Image.asset(
              'assets/images/$displayImage',
              width: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
              height: baseImageNameForSizing == 'Delivery.png' ? 80 : 50,
              fit: BoxFit.contain,
              color:
                  _hasProcessedFirstStep && !isSelected
                      ? Colors.grey.withOpacity(0.5)
                      : (isSelected ? Colors.white : const Color(0xFF616161)),
            ),
          ),
        ),
      ),
    );
  }

  // --- Dynamic Logic for Dialer ---

  void _onNumberPressed(String value) {
    setState(() {
      String newDisplayValue = _displayValue;

      if (value == '.') {
        // Only add a decimal if one doesn't exist already.
        if (!newDisplayValue.contains('.')) {
          newDisplayValue =
              newDisplayValue == '0' ? '0.' : newDisplayValue + '.';
        }
      } else {
        // Handle number input
        if (newDisplayValue == '0') {
          newDisplayValue = value;
        } else {
          newDisplayValue += value;
        }

        // Check for max two decimal places
        if (newDisplayValue.contains('.')) {
          final parts = newDisplayValue.split('.');
          if (parts[1].length > 2) {
            return; // Don't allow more than two decimal places.
          }
        }
      }

      // Special handling for discount mode to not exceed 100
      if (widget.mode == DialerMode.discount) {
        double newPercentage = double.tryParse(newDisplayValue) ?? 0.0;
        if (newPercentage > 100.0) {
          CustomPopupService.show(
            context,
            'Discount % cannot exceed 100%',
            type: PopupType.failure,
          );
          return;
        }
      }

      _displayValue = newDisplayValue;
      _updateCalculations();
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_displayValue.length > 1) {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
        if (_displayValue.endsWith('.')) {
          _displayValue = _displayValue.substring(0, _displayValue.length - 1);
        }
      } else {
        _displayValue = '0';
      }
      _updateCalculations();
    });
  }

  void _updateCalculations() {
    double value = double.tryParse(_displayValue) ?? 0.0;

    if (widget.mode == DialerMode.discount) {
      _selectedDiscountPercentage = value;
      _discountAmount = (widget.subtotal * _selectedDiscountPercentage) / 100;
      _discountedTotal = widget.subtotal - _discountAmount;
    } else if (widget.mode == DialerMode.payment) {
      _paymentAmount = value;
    }
  }

  // Helper to format the display value based on the current mode
  String _formatDisplayValue() {
    String formattedValue = _displayValue;
    if (formattedValue.endsWith('.')) {
      // If the user has just entered a decimal, we want to show it.
      return formattedValue;
    }

    double value = double.tryParse(formattedValue) ?? 0.0;

    // For payments, always show a leading currency symbol.
    if (widget.mode == DialerMode.payment) {
      return value.toStringAsFixed(2);
    }

    // For discounts, just show the number.
    return value.toStringAsFixed(2);
  }

  Widget _buildNumberButton(String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ElevatedButton(
          onPressed: () => _onNumberPressed(value),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(
              18,
            ), // Increased padding for larger buttons
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ElevatedButton(
          onPressed: _onBackspacePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(
              18,
            ), // Increased padding for a larger icon
          ),
          child: const Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const Spacer(flex: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.only(right: 0),
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: SizedBox(
                      width: 26,
                      height: 26,
                      child: Image.asset(
                        'assets/images/bArrow.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              _buildServiceHighlight('takeaway', 'TakeAway.png'),
              _buildServiceHighlight('dinein', 'DineIn.png'),
              _buildServiceHighlight('delivery', 'Delivery.png'),
            ],
          ),
          const Spacer(flex: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Divider(
              height: 0,
              thickness: 3,
              color: const Color(0xFFB2B2B2),
            ),
          ),
          const Spacer(flex: 1),

          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 25),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '£' + _formatDisplayValue(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('1'),
                    _buildNumberButton('2'),
                    _buildNumberButton('3'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('4'),
                    _buildNumberButton('5'),
                    _buildNumberButton('6'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('7'),
                    _buildNumberButton('8'),
                    _buildNumberButton('9'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('.'),
                    _buildNumberButton('0'),
                    _buildBackspaceButton(),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),

          // Updated summary section with a single, thicker vertical divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sub Total',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (widget.mode == DialerMode.discount)
                        const Text(
                          'Discount',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        )
                      else
                        const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 3, // Increased width of the vertical divider
                  height: 60, // The height of the vertical divider
                  color: Colors.grey[400],
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '£${widget.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (widget.mode == DialerMode.discount)
                        Text(
                          '£${_discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        )
                      else
                        Text(
                          '£${(_paymentAmount - widget.subtotal).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (widget.mode == DialerMode.discount) {
                          widget.onDiscountApplied?.call(
                            _discountedTotal,
                            _selectedDiscountPercentage,
                          );
                        } else {
                          widget.onPaymentEntered?.call(_paymentAmount);
                        }
                        widget.onBack?.call();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}
