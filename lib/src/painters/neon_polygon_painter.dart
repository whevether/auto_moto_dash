import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class NeonPolygonPainter extends CustomPainter {
  NeonPolygonPainter({
    required this.sides,
    required this.rotation,
    required this.color,
    required this.intensity,
  });

  final int sides;
  final double rotation;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final radius = size.shortestSide * 0.28;

    Path poly(double r) {
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final a = rotation + (i / sides) * math.pi * 2 - math.pi / 2;
        final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      return path;
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color.withValues(alpha: 0.25 + intensity * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(poly(radius), glow);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.55 + intensity * 0.35);
    canvas.drawPath(poly(radius), edge);
    canvas.drawPath(poly(radius * 0.78), edge..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant NeonPolygonPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.color != color ||
        oldDelegate.intensity != intensity ||
        oldDelegate.sides != sides;
  }
}