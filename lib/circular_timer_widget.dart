// circular_timer_widget.dart (FIXED)

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:epos/services/uk_time_service.dart';

class CircularTimer extends StatefulWidget {
  final DateTime startTime;
  final double size;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final int
  maxMinutes; // Maximum minutes for full circle (default 60 minutes = 1 hour)

  const CircularTimer({
    Key? key,
    required this.startTime,
    this.size = 80.0,
    this.progressColor = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.strokeWidth = 6.0,
    this.maxMinutes = 60, // 1 hour for full circle
  }) : super(key: key);

  @override
  State<CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends State<CircularTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsedTime();

    // Update every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateElapsedTime();
      }
    });
  }

  void _updateElapsedTime() {
    setState(() {
      // WORKAROUND: Backend sends UK time with Z suffix (should be UTC but isn't)
      // So we need to compare UK times, not UTC times
      final DateTime currentUKTime = UKTimeService.now();

      // The backend incorrectly stores UK local time as UTC
      // So we need to treat widget.startTime as UK time, not UTC
      // Extract the time components and create a UK DateTime
      final DateTime startTimeAsUK = DateTime(
        widget.startTime.year,
        widget.startTime.month,
        widget.startTime.day,
        widget.startTime.hour,
        widget.startTime.minute,
        widget.startTime.second,
        widget.startTime.millisecond,
        widget.startTime.microsecond,
      );

      // Calculate difference using UK timestamps
      _elapsed = currentUKTime.difference(startTimeAsUK);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress (0.0 to 1.0) - always start from 0 and go to 60 minutes
    // Ensure non-negative minutes (in case of timezone issues)
    final elapsedMinutes = math.max(0, _elapsed.inMinutes);
    final totalMinutes = math.min(elapsedMinutes, widget.maxMinutes);
    final progress =
        widget.maxMinutes > 0 ? totalMinutes / widget.maxMinutes : 0.0;

    // Determine color based on time elapsed
    Color currentColor = Colors.green; // Default green for 0-30 minutes
    if (totalMinutes >= 45) {
      currentColor = Colors.red; // Red after 45 minutes
    } else if (totalMinutes >= 30) {
      currentColor =
          Colors
              .yellow; // Orange from 30-45 minutes (changed from yellow for better visibility)
    }

    // Show elapsed minutes only (ensure non-negative)
    final minutesText = '$totalMinutes';

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle with hour markers
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: BackgroundCirclePainter(
              backgroundColor: widget.backgroundColor.withOpacity(0.3),
              strokeWidth: widget.strokeWidth,
              size: widget.size,
            ),
          ),
          // Progress circle (always starts from 12 o'clock)
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: CircleProgressPainter(
              progress: progress,
              color: currentColor,
              strokeWidth: widget.strokeWidth,
            ),
          ),
          // Minutes display in center
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                minutesText,
                style: TextStyle(
                  fontSize: widget.size * 0.24,
                  fontWeight: FontWeight.bold,
                  color: currentColor,
                ),
              ),
              Text(
                'min',
                style: TextStyle(
                  fontSize: widget.size * 0.20,
                  color: currentColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ... rest of the CustomPainter classes remain the same ...

class BackgroundCirclePainter extends CustomPainter {
  final Color backgroundColor;
  final double strokeWidth;
  final double size;

  BackgroundCirclePainter({
    required this.backgroundColor,
    required this.strokeWidth,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = (canvasSize.width - strokeWidth) / 2;

    // Draw background circle
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw hour markers (every 15 minutes: 0, 15, 30, 45)
    final markerPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle =
          (i * 15 / 60) * 2 * math.pi - math.pi / 2; // Every 15 minutes
      final markerStart = Offset(
        center.dx + math.cos(angle) * (radius - 8),
        center.dy + math.sin(angle) * (radius - 8),
      );
      final markerEnd = Offset(
        center.dx + math.cos(angle) * (radius - 2),
        center.dy + math.sin(angle) * (radius - 2),
      );
      canvas.drawLine(markerStart, markerEnd, markerPaint);
    }

    // Draw minute markers (every 5 minutes) - smaller
    final smallMarkerPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      if (i % 3 != 0) {
        // Skip the main hour markers
        final angle =
            (i * 5 / 60) * 2 * math.pi - math.pi / 2; // Every 5 minutes
        final markerStart = Offset(
          center.dx + math.cos(angle) * (radius - 5),
          center.dy + math.sin(angle) * (radius - 5),
        );
        final markerEnd = Offset(
          center.dx + math.cos(angle) * (radius - 2),
          center.dy + math.sin(angle) * (radius - 2),
        );
        canvas.drawLine(markerStart, markerEnd, smallMarkerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(BackgroundCirclePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // Draw arc from top (12 o'clock position)
    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
