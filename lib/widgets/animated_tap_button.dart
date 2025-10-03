import 'package:flutter/material.dart';

class AnimatedTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? baseColor;
  final Duration animationDuration;
  final double brightnessChange;
  final BorderRadius? borderRadius;

  const AnimatedTapButton({
    super.key,
    required this.child,
    this.onTap,
    this.baseColor,
    this.animationDuration = const Duration(milliseconds: 150),
    this.brightnessChange = 0.2,
    this.borderRadius,
  });

  @override
  State<AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

class _AnimatedTapButtonState extends State<AnimatedTapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {});
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _onTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    setState(() {});
    _animationController.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  Color _getAnimatedColor() {
    if (widget.baseColor == null) {
      return Colors.transparent;
    }

    final baseColor = widget.baseColor!;
    final brightness = baseColor.computeLuminance();

    // For dark colors, make them lighter on tap
    // For light colors, make them darker on tap
    final shouldLighten = brightness < 0.5;

    final animationValue = _animation.value * widget.brightnessChange;

    if (shouldLighten) {
      // Lighten the color
      return Color.lerp(baseColor, Colors.white, animationValue) ?? baseColor;
    } else {
      // Darken the color
      return Color.lerp(baseColor, Colors.black, animationValue) ?? baseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration:
                widget.baseColor != null
                    ? BoxDecoration(
                      color: _getAnimatedColor(),
                      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                    )
                    : null,
            child: widget.child,
          );
        },
      ),
    );
  }
}

// Convenience wrapper for common button patterns
class AnimatedColorButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final double brightnessChange;

  const AnimatedColorButton({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 150),
    this.brightnessChange = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      baseColor: backgroundColor,
      borderRadius: borderRadius,
      animationDuration: animationDuration,
      brightnessChange: brightnessChange,
      child: Container(
        padding: padding,
        child: child,
      ),
    );
  }
}

// Extension to easily wrap any widget with tap animation
extension AnimatedTapExtension on Widget {
  Widget withTapAnimation({
    VoidCallback? onTap,
    Color? baseColor,
    Duration animationDuration = const Duration(milliseconds: 150),
    double brightnessChange = 0.2,
  }) {
    return AnimatedTapButton(
      onTap: onTap,
      baseColor: baseColor,
      animationDuration: animationDuration,
      brightnessChange: brightnessChange,
      child: this,
    );
  }
}
