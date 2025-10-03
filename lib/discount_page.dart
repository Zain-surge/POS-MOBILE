import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/dialer.dart';
import 'package:epos/models/order_models.dart';

typedef OnDiscountApplied =
    Function(double finalTotal, double discountPercentage);

class DiscountPage extends StatefulWidget {
  final double subtotal;
  final OnDiscountApplied onDiscountApplied;
  final VoidCallback? onBack;
  final String currentOrderType;
  final Function(String) onOrderTypeChanged;
  final CustomerDetails? customerDetails;
  // Removed paymentType and onPaymentConfirmed parameters as they are no longer needed here.

  const DiscountPage({
    super.key,
    required this.subtotal,
    required this.onDiscountApplied,
    this.onBack,
    required this.currentOrderType,
    required this.onOrderTypeChanged,
    this.customerDetails,
  });

  @override
  State<DiscountPage> createState() => _DiscountPageState();
}

class _DiscountPageState extends State<DiscountPage> {
  // State variables for managing the selected discount.
  double _selectedDiscountPercentage = 0.0;
  double _discountedTotal = 0.0;
  double _discountAmount = 0.0;
  bool _isCustomDiscountMode = false;
  bool _showDialerPage = false;
  final TextEditingController _customDiscountController =
      TextEditingController();

  // Add these state variables for service selection
  String _actualOrderType = 'collection';
  bool _hasProcessedFirstStep = false;
  // Removed _cartItems, _customerDetails, _showPayment, _selectedBottomNavItem as they are not used in this widget.

  @override
  void initState() {
    super.initState();
    // Initially, the discounted total is the same as the subtotal.
    _discountedTotal = widget.subtotal;
    // Set the current order type from the passed parameter
    _actualOrderType = widget.currentOrderType;
  }

  @override
  void dispose() {
    _customDiscountController.dispose();
    super.dispose();
  }

  // A helper function to apply the selected discount percentage.
  void _applyDiscount(double percentage) {
    setState(() {
      _selectedDiscountPercentage = percentage;
      _discountAmount = (widget.subtotal * percentage) / 100;
      _discountedTotal = widget.subtotal - _discountAmount;
      _isCustomDiscountMode = false;
      _showDialerPage = false; // Hide dialer when applying preset discount
      _customDiscountController.clear();
    });
  }

  // Function to apply custom discount
  // void _applyCustomDiscount() {
  //   if (_customDiscountController.text.isNotEmpty) {
  //     double customPercentage = double.tryParse(_customDiscountController.text) ?? 0.0;
  //     if (customPercentage >= 0 && customPercentage <= 100) {
  //       _applyDiscount(customPercentage);
  //     } else {

  //     }
  //   }
  // }

  // Function to enable custom discount input
  // void _enableCustomDiscountMode() {
  //   setState(() {
  //     _isCustomDiscountMode = true;
  //     _showDialerPage = false; // Hide dialer when enabling custom mode
  //     _selectedDiscountPercentage = 0.0;
  //     _discountAmount = 0.0;
  //     _discountedTotal = widget.subtotal;
  //   });
  // }

  // Function to show dialer page
  void _showDialer() {
    setState(() {
      _showDialerPage = true;
      _isCustomDiscountMode = false;
    });
  }

  // Helper function for getting bottom nav item index
  // int _getBottomNavItemIndexForOrderType(String type) {
  //   switch (type.toLowerCase()) {
  //     case 'takeaway':
  //       return 0;
  //     case 'dinein':
  //     case 'collection':
  //       return 1;
  //     case 'delivery':
  //       return 2;
  //     default:
  //       return 0;
  //   }
  // }

  // Service highlight widget
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
              _actualOrderType = 'takeaway';
            } else {
              _actualOrderType = type;
            }
            //_selectedBottomNavItem = _getBottomNavItemIndexForOrderType(type); // Removed unused variable
          });
          widget.onOrderTypeChanged(_actualOrderType);
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
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

  // A helper widget to build a discount button with a dynamic style.
  Widget _buildDiscountButton(double percentage) {
    bool isSelected =
        _selectedDiscountPercentage == percentage &&
        !_isCustomDiscountMode &&
        !_showDialerPage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: () => _applyDiscount(percentage),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.grey[300] : Colors.black,
            foregroundColor: isSelected ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            side: isSelected ? const BorderSide(color: Colors.grey) : null,
          ),
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 29,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _showDialerPage
              ? DialerPage(
                mode: DialerMode.discount,
                subtotal: widget.subtotal,
                currentOrderType: _actualOrderType,
                onDiscountApplied: (finalTotal, discountPercentage) {
                  // Apply the discount from dialer and hide dialer
                  setState(() {
                    _discountedTotal = finalTotal;
                    _selectedDiscountPercentage = discountPercentage;
                    _discountAmount = widget.subtotal - finalTotal;
                    _isCustomDiscountMode = false;
                    _showDialerPage = false; // Hide dialer after applying
                  });
                },
                onOrderTypeChanged: (newOrderType) {
                  // Update order type
                  setState(() {
                    _actualOrderType = newOrderType;
                  });
                  widget.onOrderTypeChanged(newOrderType);
                },
                onBack: () {
                  setState(() {
                    _showDialerPage = false; // Hide dialer on back
                  });
                },
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // --- Service Selection Row ---
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60.0),
                      child: Divider(
                        height: 0,
                        thickness: 3,
                        color: const Color(0xFFB2B2B2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Discount Buttons in Column ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Preset discount buttons
                          _buildDiscountButton(10.0),
                          _buildDiscountButton(15.0),
                          _buildDiscountButton(20.0),

                          // Other button with dialpad icon
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12.0,
                              left: 16.0,
                              right: 16.0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton(
                                onPressed:
                                    _showDialer, // Show dialer instead of navigating
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _showDialerPage
                                          ? Colors.grey[300]
                                          : Colors.black,
                                  foregroundColor:
                                      _showDialerPage
                                          ? Colors.black
                                          : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                  side:
                                      _showDialerPage
                                          ? const BorderSide(color: Colors.grey)
                                          : null,
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
                                    Icon(Icons.dialpad, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Custom discount input field (shown when Other is selected)
                          if (_isCustomDiscountMode)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Custom Discount %',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: _customDiscountController,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                      decoration: const InputDecoration(
                                        suffixText: '%',
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 0,
                                        ),
                                        isDense: true,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          double customPercentage =
                                              double.tryParse(value) ?? 0.0;
                                          if (customPercentage >= 0 &&
                                              customPercentage <= 100) {
                                            setState(() {
                                              _selectedDiscountPercentage =
                                                  customPercentage;
                                              _discountAmount =
                                                  (widget.subtotal *
                                                      customPercentage) /
                                                  100;
                                              _discountedTotal =
                                                  widget.subtotal -
                                                  _discountAmount;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            _selectedDiscountPercentage = 0.0;
                                            _discountAmount = 0.0;
                                            _discountedTotal = widget.subtotal;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- Summary Section ---
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
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '£${widget.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Discount (${_selectedDiscountPercentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '- £${_discountAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Final Total',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '£${_discountedTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // --- Action Button ---
                          Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Instead of navigating, call the callback and go back.
                                      widget.onDiscountApplied(
                                        _discountedTotal,
                                        _selectedDiscountPercentage,
                                      );
                                      widget.onBack?.call();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 22,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Apply Discount',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
