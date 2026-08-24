import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class PulseRingPainter extends CustomPainter {
  PulseRingPainter({
    required this.phase,
    required this.intensity,
    required this.color,
  });

  final double phase;
  final double intensity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final base = size.shortestSide * 0.22;
    final breath = (math.sin(phase * math.pi * 2) * 0.5 + 0.5);
    final radius = base * (1 + breath * 0.18 * (0.4 + intensity));
    final alpha = 0.18 + breath * 0.35 * (0.4 + intensity);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + breath * 3
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, paint);

    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: alpha * 0.7);
    canvas.drawCircle(center, radius * 0.86, paint2);
  }

  @override
  bool shouldRepaint(covariant PulseRingPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color;
  }
}