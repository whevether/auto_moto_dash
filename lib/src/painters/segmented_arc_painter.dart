import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Dual-layer segmented power arc (Yadea-style).
class SegmentedArcPainter extends CustomPainter {
  SegmentedArcPainter({
    required this.powerNorm,
    required this.regenNorm,
    this.segments = 24,
    this.startAngle = math.pi * 0.55,
    this.sweepAngle = math.pi * 0.9,
    this.powerColor = const Color(0xFFFF9800),
    this.regenColor = const Color(0xFF00BCD4),
    this.trackColor,
  });

  final double powerNorm;
  final double regenNorm;
  final int segments;
  final double startAngle;
  final double sweepAngle;
  final Color powerColor;
  final Color regenColor;
  final Color? trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.72);
    final radius = math.min(size.width, size.height) * 0.42;
    final track = trackColor ?? Colors.white.withValues(alpha: 0.08);
    final segSweep = sweepAngle / segments;
    final mid = segments ~/ 2;

    for (var i = 0; i < segments; i++) {
      final angle = startAngle + segSweep * i + segSweep * 0.12;
      final segLen = segSweep * 0.76;
      Color color;
      if (i < mid) {
        final lit = (regenNorm * mid).ceil();
        color = i < lit ? regenColor : track;
      } else {
        final lit = (powerNorm * (segments - mid)).ceil();
        color = i - mid < lit ? powerColor : track;
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segLen,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedArcPainter oldDelegate) {
    return oldDelegate.powerNorm != powerNorm ||
        oldDelegate.regenNorm != regenNorm;
  }
}
