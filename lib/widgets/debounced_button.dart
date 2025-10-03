import 'dart:async';
import 'package:flutter/material.dart';

class DebouncedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Duration debounceDuration;
  final bool isLoading;

  const DebouncedButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.debounceDuration = const Duration(milliseconds: 1000),
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _isEnabled = true;
  bool _isProcessing = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!_isEnabled || _isProcessing || widget.onPressed == null) return;

    setState(() {
      _isEnabled = false;
      _isProcessing = true;
    });

    // Execute the callback immediately
    widget.onPressed!();

    // Start debounce timer
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        setState(() {
          _isEnabled = true;
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled =
        !_isEnabled ||
        _isProcessing ||
        widget.isLoading ||
        widget.onPressed == null;

    return AbsorbPointer(
      absorbing: isDisabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height ?? 50,
        child: ElevatedButton(
          onPressed: isDisabled ? null : _handleTap,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDisabled
                    ? Colors.grey
                    : (widget.backgroundColor ?? const Color(0xFFCB6CE6)),
            padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
            ),
            elevation: isDisabled ? 2 : 5,
          ),
          child:
              _isProcessing || widget.isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.textColor ?? Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
        ),
      ),
    );
  }
}
