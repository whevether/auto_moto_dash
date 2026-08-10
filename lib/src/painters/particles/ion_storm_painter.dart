import 'dart:math' as math;

import 'package:flutter/material.dart';

class IonStormPainter extends CustomPainter {
  IonStormPainter({
    required this.progress,
    required this.speedNorm,
    required this.accelNorm,
    required this.accent,
  }) : _ions = List.generate(100, (i) {
          final r = math.Random(i * 3331 + 5);
          return _Ion(
            r.nextDouble(),
            r.nextDouble(),
            r.nextDouble() * math.pi * 2,
            0.4 + r.nextDouble() * 1.8,
            HSVColor.fromAHSV(1, r.nextDouble() * 360, 0.7, 1).toColor(),
          );
        });

  final double progress;
  final double speedNorm;
  final double accelNorm;
  final Color accent;
  final List<_Ion> _ions;

  @override
  void paint(Canvas canvas, Size size) {
    final rush = speedNorm.clamp(0.0, 1.3);
    final flow = 0.08 + rush * 1.1 + math.max(0, accelNorm) * 0.4;

    for (final ion in _ions) {
      final x = ((ion.x + progress * flow * math.cos(ion.dir) * 0.15) % 1.0);
      final y = ((ion.y + progress * flow * (0.4 + 0.6 * math.sin(ion.dir))) %
          1.0);
      final p = Offset(x * size.width, y * size.height);
      final trail = Offset(
        p.dx - math.cos(ion.dir) * (6 + rush * 22),
        p.dy - math.sin(ion.dir) * (6 + rush * 22),
      );
      canvas.drawLine(
        trail,
        p,
        Paint()
          ..strokeWidth = ion.size
          ..strokeCap = StrokeCap.round
          ..color = ion.color.withValues(alpha: 0.25 + rush * 0.45),
      );
      canvas.drawCircle(
        p,
        ion.size * 0.8,
        Paint()
          ..color = ion.color.withValues(alpha: 0.5 + rush * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Occasional arc flashes
    if (rush > 0.4 && math.sin(progress * 17) > 0.92) {
      final r = math.Random((progress * 10).floor());
      final a = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final b = a + Offset((r.nextDouble() - 0.5) * 120, (r.nextDouble() - 0.5) * 80);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = accent.withValues(alpha: 0.7)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant IonStormPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm;
  }
}

class _Ion {
  _Ion(this.x, this.y, this.dir, this.size, this.color);
  final double x;
  final double y;
  final double dir;
  final double size;
  final Color color;
}