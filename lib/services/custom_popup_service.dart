// lib/services/custom_popup_service.dart

import 'package:flutter/material.dart';
import 'dart:async';

enum PopupType { success, failure }

class CustomPopupService {
  static OverlayEntry? _overlayEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.black,
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
    PopupType type = PopupType.failure,
  }) {
    _dismiss();

    IconData iconData;
    if (type == PopupType.success) {
      iconData = Icons.check_circle_outline;
      backgroundColor = Colors.green[700]!;
    } else {
      iconData = Icons.close;
      backgroundColor = Colors.red[700]!;
    }

    try {
      _overlayEntry = OverlayEntry(
        builder:
            (overlayContext) => _PopupWidget(
              message: message,
              iconData: iconData,
              backgroundColor: backgroundColor,
              textColor: textColor,
              overlayContext: overlayContext,
            ),
      );

      final overlay = Overlay.of(context);
      if (overlay.mounted) {
        overlay.insert(_overlayEntry!);
        _dismissTimer = Timer(duration, _dismiss);
      } else {
        print('CustomPopupService: Overlay not mounted, skipping popup display');
        _overlayEntry = null;
      }
    } catch (e) {
      print('CustomPopupService: Error showing popup: $e');
      _overlayEntry = null;
    }
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    try {
      _overlayEntry?.remove();
    } catch (e) {
      // Handle overlay removal errors gracefully
      print('CustomPopupService: Error removing overlay: $e');
    }
    _overlayEntry = null;
  }
}

class _PopupWidget extends StatefulWidget {
  final String message;
  final IconData iconData;
  final Color backgroundColor;
  final Color textColor;
  final BuildContext overlayContext;

  const _PopupWidget({
    required this.message,
    required this.iconData,
    required this.backgroundColor,
    required this.textColor,
    required this.overlayContext,
  });

  @override
  State<_PopupWidget> createState() => _PopupWidgetState();
}

class _PopupWidgetState extends State<_PopupWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(widget.overlayContext).padding.top + 10.0,
      left: 10.0,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.iconData, color: widget.textColor),
                const SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
