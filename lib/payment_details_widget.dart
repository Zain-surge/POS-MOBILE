import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epos/models/order_models.dart';
import 'package:epos/services/thermal_printer_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:epos/services/custom_popup_service.dart';
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
  final double subtotal;
  final CustomerDetails? customerDetails;
  final String paymentType;
  final Function(PaymentDetails)? onPaymentConfirmed;
  final VoidCallback? onBack;
  final Function(String)? onPaymentTypeChanged;
  final bool isProcessing;

  const PaymentWidget({
    super.key,
    required this.subtotal,
    this.customerDetails,
    required this.paymentType,
    this.onPaymentConfirmed,
    this.onBack,
    this.onPaymentTypeChanged,
    this.isProcessing = false,
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
  Timer? _printerStatusTimer;
  double _currentDiscountPercentageForPaymentDetails = 0.0;

  OverlayEntry? _changeOverlayEntry;

  bool _canOpenDrawer = false;
  bool _isDrawerOpening = false;

  bool get _isPaid => widget.paymentType.toLowerCase() != 'unpaid';

  bool _isCardForRemainingPressed = false;
  double _cashAmountPaid = 0.0;
  double _cardAmountPaid = 0.0;
  double _remainingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _discountedTotal = widget.subtotal;
    _selectedAmount =
        (widget.paymentType.toLowerCase() == 'card' ||
                widget.paymentType.toLowerCase() == 'card_through_link')
            ? _discountedTotal
            : 0.0;

    if (widget.paymentType.toLowerCase() == 'card' ||
        widget.paymentType.toLowerCase() == 'card_through_link') {
      _isCustomAmountMode = false;
      _amountPaidController.text = _discountedTotal.toStringAsFixed(2);
    } else {
      _isCustomAmountMode = false;
      _amountPaidController.clear();
    }

    _amountPaidController.addListener(_onAmountPaidChanged);
    _calculatePresetAmounts();
    _startPrinterStatusChecking();
    _checkDrawerAvailability();
  }

  void _startPrinterStatusChecking() {
    _checkPrinterStatus();
    _printerStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkPrinterStatus();
    });
  }

  void _onPaymentDialerConfirmed(double amount) {
    setState(() {
      _selectedAmount = amount;
      _isCustomAmountMode = true;
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

      if (nextRoundTen > exactAmount &&
          !amounts.contains(nextRoundTen) &&
          amounts.length < 4) {
        amounts.add(nextRoundTen);
      }

      while (amounts.length < 4) {
        double lastAmount = amounts.last;
        double nextAmount;

        if (lastAmount < 10) {
          nextAmount = lastAmount + 1.0;
        } else if (lastAmount < 20) {
          nextAmount = lastAmount + 2.0;
        } else {
          nextAmount = lastAmount + 5.0;
        }

        if (!amounts.contains(nextAmount) &&
            (nextAmount - exactAmount).abs() > 0.001) {
          amounts.add(nextAmount);
        } else {
          break;
        }
      }
      _presetAmounts = amounts.take(4).toList();
    } else {
      _presetAmounts = [];
    }
  }

  Future<void> _checkPrinterStatus() async {
    if (_isCheckingPrinter || !mounted) return;

    setState(() {
      _isCheckingPrinter = true;
    });

    try {
      Map<String, bool> connectionStatus =
          await ThermalPrinterService().checkConnectionStatusOnly();
      bool isConnected =
          connectionStatus['usb'] == true ||
          connectionStatus['bluetooth'] == true;

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

  Future<void> _checkDrawerAvailability() async {
    try {
      bool canOpen = await ThermalPrinterService().canOpenDrawer();
      if (mounted) {
        setState(() {
          _canOpenDrawer = canOpen;
        });
      }
    } catch (e) {
      print('Error checking drawer availability: $e');
    }
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
      builder:
          (context) => Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 450.0,
                    vertical: 300.0,
                  ),
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
                        child: ElevatedButton(
                          onPressed: widget.onBack,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(45, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22.5),
                            ),
                            elevation: 0,
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
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

              const SizedBox(height: 16),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        if (widget.paymentType.toLowerCase() == 'cash' ||
                            widget.paymentType.toLowerCase() == 'card & cash')
                          Column(
                            children: [
                              // Preset amount buttons
                              for (int i = 0; i < _presetAmounts.length; i++)
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
                                          () =>
                                              _selectAmount(_presetAmounts[i]),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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

                              // Other amount button
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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

                              // Card for remaining button
                              if (_remainingAmount > 0)
                                const SizedBox(height: 12),
                              if (_remainingAmount > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 65,
                                    child: ElevatedButton(
                                      onPressed: _handleCardForRemaining,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.credit_card, size: 20),
                                          SizedBox(width: 12),
                                          Text(
                                            'Card',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Poppins',
                                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
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
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 0,
                                      ),
                                      isDense: true,
                                      prefixText: '£',
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}$'),
                                      ),
                                    ],
                                    readOnly: false,
                                    onTap: () {},
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (widget.paymentType.toLowerCase() == 'unpaid')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Order will be marked as UNPAID',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                      color: Colors.orange,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '£${_discountedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (widget.paymentType.toLowerCase() == 'cash' &&
                        _remainingAmount > 0 &&
                        !_isCardForRemainingPressed)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Remaining Amount',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                '£${_remainingAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),

                    if (_isCardForRemainingPressed &&
                        _cashAmountPaid > 0 &&
                        _cardAmountPaid > 0)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cash Paid',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '£${_cashAmountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Card Paid',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '£${_cardAmountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '£${_changeDue.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Main payment button and cash drawer button row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                (widget.isProcessing ||
                                        widget.onPaymentConfirmed == null)
                                    ? null
                                    : () async {
                                      if (widget.paymentType.toLowerCase() ==
                                          'unpaid') {
                                        final paymentDetails = PaymentDetails(
                                          paymentType: widget.paymentType,
                                          amountReceived: 0.0,
                                          discountPercentage:
                                              _currentDiscountPercentageForPaymentDetails,
                                          totalCharge: _discountedTotal,
                                          paidStatus: _isPaid,
                                        );

                                        print("🔍 UNPAID ORDER DEBUG:");
                                        print(
                                          "Payment Type: ${paymentDetails.paymentType}",
                                        );
                                        print(
                                          "Paid Status: ${paymentDetails.paidStatus}",
                                        );
                                        print(
                                          "Total Amount: £${paymentDetails.totalCharge}",
                                        );

                                        // Open cash drawer when charge button is pressed
                                        await _openCashDrawer();

                                        widget.onPaymentConfirmed?.call(
                                          paymentDetails,
                                        );
                                        return;
                                      }

                                      if ((widget.paymentType.toLowerCase() ==
                                                  'card' ||
                                              widget.paymentType
                                                      .toLowerCase() ==
                                                  'card_through_link') &&
                                          (_amountPaidController.text.isEmpty ||
                                              double.tryParse(
                                                    _amountPaidController.text,
                                                  ) ==
                                                  null ||
                                              double.parse(
                                                    _amountPaidController.text,
                                                  ) <=
                                                  0)) {
                                        CustomPopupService.show(
                                          context,
                                          'Please enter a valid amount for card payment!',
                                          type: PopupType.failure,
                                        );
                                        return;
                                      }

                                      if (widget.paymentType.toLowerCase() ==
                                              'cash' &&
                                          _selectedAmount <= 0) {
                                        CustomPopupService.show(
                                          context,
                                          'Please select an amount to pay!',
                                          type: PopupType.failure,
                                        );
                                        return;
                                      }

                                      // NEW: Validate email for card_through_link payment
                                      if (widget.paymentType.toLowerCase() ==
                                          'card_through_link') {
                                        if (widget.customerDetails == null ||
                                            widget.customerDetails!.email ==
                                                null ||
                                            widget.customerDetails!.email!
                                                .trim()
                                                .isEmpty) {
                                          CustomPopupService.show(
                                            context,
                                            'Customer email is required for Card Through Link payment!',
                                            type: PopupType.failure,
                                          );
                                          return;
                                        }

                                        // Validate email format
                                        final emailRegex = RegExp(
                                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                        );
                                        if (!emailRegex.hasMatch(
                                          widget.customerDetails!.email!.trim(),
                                        )) {
                                          CustomPopupService.show(
                                            context,
                                            'Please enter a valid email address!',
                                            type: PopupType.failure,
                                          );
                                          return;
                                        }
                                      }

                                      if (_selectedAmount < _discountedTotal) {
                                        CustomPopupService.show(
                                          context,
                                          'Amount paid cannot be less than order total!',
                                          type: PopupType.failure,
                                        );
                                        return;
                                      }

                                      if (_changeDue > 0) {
                                        _showChangeOverlay(_changeDue);
                                      }

                                      final paymentDetails = PaymentDetails(
                                        paymentType: _getPaymentType(),
                                        amountReceived: _selectedAmount,
                                        discountPercentage:
                                            _currentDiscountPercentageForPaymentDetails,
                                        totalCharge: _discountedTotal,
                                        paidStatus: _isPaid,
                                      );

                                      print("🔍 PAYMENT DEBUG:");
                                      print(
                                        "Payment Type: ${paymentDetails.paymentType}",
                                      );
                                      print(
                                        "Paid Status: ${paymentDetails.paidStatus}",
                                      );
                                      print(
                                        "Total Amount: £${paymentDetails.amountReceived}",
                                      );
                                      print(
                                        "Change Due: £${paymentDetails.changeDue}",
                                      );

                                      // Open cash drawer when charge button is pressed
                                      await _openCashDrawer();

                                      widget.onPaymentConfirmed?.call(
                                        paymentDetails,
                                      );
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.isProcessing
                                      ? Colors.grey
                                      : Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child:
                                widget.isProcessing
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Processing Order...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Charge    £${_discountedTotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
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

                        // Cash drawer button
                        if (widget.paymentType.toLowerCase() == 'cash' &&
                            _canOpenDrawer)
                          const SizedBox(width: 8),
                        if (widget.paymentType.toLowerCase() == 'cash' &&
                            _canOpenDrawer)
                          ElevatedButton(
                            onPressed:
                                _isDrawerOpening ? null : _openCashDrawer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isDrawerOpening
                                      ? Colors.grey
                                      : const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(70, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color:
                                    _isDrawerOpening
                                        ? Colors.grey
                                        : const Color(0xFF2E7D2E),
                                width: 2,
                              ),
                              elevation: 2,
                            ),
                            child:
                                _isDrawerOpening
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.money, size: 28),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

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
                  color: (_isPrinterConnected ? Colors.green : Colors.red)
                      .withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),

        if (_isCustomAmountDialerOpen)
          Positioned.fill(
            child: DialerPage(
              mode: DialerMode.payment,
              subtotal: widget.subtotal,
              onPaymentEntered: (amount) {
                _onPaymentDialerConfirmed(amount);
              },
              onBack: _onDialerClose,
              currentOrderType: 'takeaway',
              onOrderTypeChanged: (type) {},
            ),
          ),
      ],
    );
  }

  void _handleCardForRemaining() {
    if (_selectedAmount >= _discountedTotal) {
      return;
    }

    setState(() {
      _isCardForRemainingPressed = true;
      _cashAmountPaid = _selectedAmount;
      _remainingAmount = _discountedTotal - _selectedAmount;
      _cardAmountPaid = _remainingAmount;
      _selectedAmount = _discountedTotal;
    });
    if (widget.onPaymentTypeChanged != null) {
      widget.onPaymentTypeChanged!('Card & Cash');
    }

    print("🔍 SPLIT PAYMENT DEBUG:");
    print("Card for remaining pressed: $_isCardForRemainingPressed");
    print("Cash amount paid: $_cashAmountPaid");
    print("Card amount paid: $_cardAmountPaid");
    print("Payment type will be: ${_getPaymentType()}");

    _calculateChange();
  }

  void _calculateChange() {
    setState(() {
      if (_isCardForRemainingPressed) {
        _changeDue = 0.0;
        _remainingAmount = 0.0;
      } else {
        _remainingAmount = (_discountedTotal - _selectedAmount).clamp(
          0.0,
          double.infinity,
        );
        _changeDue = (_selectedAmount - _discountedTotal).clamp(
          0.0,
          double.infinity,
        );
      }
    });
  }

  String _getPaymentType() {
    print("🔍 GET PAYMENT TYPE DEBUG:");
    print("widget.paymentType: ${widget.paymentType}");
    print("_isCardForRemainingPressed: $_isCardForRemainingPressed");
    print("Returning: ${widget.paymentType}");
    return widget.paymentType;
  }

  /// Opens the cash drawer when charge button is pressed
  Future<void> _openCashDrawer() async {
    if (_isDrawerOpening || !_canOpenDrawer) return;

    setState(() {
      _isDrawerOpening = true;
    });

    try {
      bool success = await ThermalPrinterService().openCashDrawer();

      if (mounted) {
        CustomPopupService.show(
          context,
          success
              ? '💰 Cash drawer opened successfully'
              : '❌ Failed to open cash drawer',
          type: success ? PopupType.success : PopupType.failure,
        );
      }
    } catch (e) {
      print('Error opening cash drawer: $e');
      if (mounted) {
        CustomPopupService.show(
          context,
          '❌ Cash drawer error: $e',
          type: PopupType.failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDrawerOpening = false;
        });
      }
    }
  }
}
