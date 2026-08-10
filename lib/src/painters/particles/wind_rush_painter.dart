import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class _Streak {
  _Streak({
    required this.u,
    required this.v,
    required this.depth,
    required this.length,
    required this.thickness,
    required this.layer,
    required this.seed,
  });

  final double u;
  final double v;
  final double depth;
  final double length;
  final double thickness;
  final int layer;
  final int seed;
}

/// Sparse wind streaks; motion from [distance] / [flowSpeed].
class WindRushPainter extends CustomPainter {
  WindRushPainter({
    required this.distance,
    required this.flowSpeed,
    required this.accent,
    this.count = 52,
  }) : _streaks = _build(count);

  final double distance;
  final double flowSpeed;
  final Color accent;
  final int count;
  final List<_Streak> _streaks;

  static List<_Streak> _build(int n) {
    return List.generate(n, (i) {
      final r = math.Random(i * 7919 + 3);
      final side = (r.nextDouble() * 2 - 1);
      return _Streak(
        u: side * (0.45 + r.nextDouble() * 0.7),
        v: (r.nextDouble() - 0.5) * (0.4 + r.nextDouble() * 0.5),
        depth: r.nextDouble(),
        length: 0.05 + r.nextDouble() * 0.12,
        thickness: 0.6 + r.nextDouble() * 1.6,
        layer: r.nextInt(3),
        seed: i,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vp = Offset(size.width * 0.5, size.height * 0.52);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rush = flowSpeed.clamp(0.0, 1.4);
    if (rush < 0.02) return;

    final density = (0.35 + rush * 0.55).clamp(0.0, 0.9);
    final active = math.max(4, (_streaks.length * density).round());
    const layerMul = [0.55, 1.0, 1.45];

    for (var i = 0; i < active; i++) {
      final s = _streaks[i];
      var d = (s.depth + distance * 0.85 * layerMul[s.layer]) % 1.0;
      if (d < 0.04) d = 0.04;

      final scale = math.pow(d, 1.05).toDouble();
      final x = vp.dx + s.u * size.width * 0.5 * 1.35 * scale;
      final y = vp.dy + s.v * size.height * 0.5 * 0.85 * scale;
      final dir = Offset(x - vp.dx, y - vp.dy);
      final len = dir.distance;
      if (len < 1) continue;
      final nd = dir / len;

      final stretch =
          s.length * size.shortestSide * (0.35 + rush * 2.2) * (0.5 + d);
      final p1 = Offset(x - nd.dx * stretch * 0.12, y - nd.dy * stretch * 0.12);
      final p2 = Offset(x + nd.dx * stretch, y + nd.dy * stretch);

      final alpha = (0.06 +
              (1 - (d - 0.5).abs() * 1.4).clamp(0.0, 1.0) *
                  (0.18 + rush * 0.55))
          .clamp(0.04, 0.85);

      paint
        ..strokeWidth = s.thickness * (0.45 + rush) * (0.7 + d)
        ..color = Color.lerp(Colors.white, accent, rush * 0.22)!
            .withValues(alpha: alpha);
      canvas.drawLine(p1, p2, paint);
    }

    final gR = size.shortestSide * (0.16 + rush * 0.1);
    canvas.drawCircle(
      vp,
      gR,
      Paint()
        ..shader = ui.Gradient.radial(
          vp,
          gR,
          [
            Colors.white.withValues(alpha: 0.03 + rush * 0.08),
            Colors.transparent,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant WindRushPainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.flowSpeed != flowSpeed ||
        oldDelegate.accent != accent;
  }
}