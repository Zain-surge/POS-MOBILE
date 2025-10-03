import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/order.dart';

class LiveUpdatingPill extends StatefulWidget {
  final String text;
  final Order order;
  final VoidCallback onTap;

  const LiveUpdatingPill({
    Key? key,
    required this.text,
    required this.order,
    required this.onTap,
  }) : super(key: key);

  @override
  State<LiveUpdatingPill> createState() => _LiveUpdatingPillState();
}

class _LiveUpdatingPillState extends State<LiveUpdatingPill>
    with SingleTickerProviderStateMixin {
  late Timer _updateTimer;
  late AnimationController _animationController;
  Color? _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.order.statusColor;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Update color every minute for live changes
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateColor();
    });
  }

  @override
  void didUpdateWidget(LiveUpdatingPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update color if order changes
    if (oldWidget.order.orderId != widget.order.orderId ||
        oldWidget.order.status != widget.order.status ||
        oldWidget.order.driverId != widget.order.driverId) {
      _updateColor();
    }
  }

  void _updateColor() {
    final newColor = widget.order.statusColor;
    if (newColor != _currentColor) {
      setState(() {
        _currentColor = newColor;
      });
      _animationController.forward(from: 0);
      print(
        '🎨 Pill updated: Order ${widget.order.orderId} color changed to $newColor',
      );
    }
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Helper method to determine text color based on background
  Color _getTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 800),
        tween: ColorTween(begin: Colors.grey.shade300, end: _currentColor),
        curve: Curves.easeInOut,
        builder: (context, color, child) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: (color ?? Colors.grey.shade300).withOpacity(0.3),
                      blurRadius: 8 + (_animationController.value * 4),
                      offset: const Offset(0, 2),
                      spreadRadius: _animationController.value * 2,
                    ),
                  ],
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(color ?? Colors.grey.shade300),
                  ),
                  child: Text(widget.text, textAlign: TextAlign.center),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
