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

  /// Horizontal bias -1..1 (wider FOV on sides).
  final double u;
  final double v;
  double depth;
  final double length;
  final double thickness;
  final int layer; // 0 far, 1 mid, 2 near
  final int seed;
}

/// Car-exterior wind: wide FOV vanishing point, mostly forward streaks.
class WindRushPainter extends CustomPainter {
  WindRushPainter({
    required this.progress,
    required this.speedNorm,
    required this.accelNorm,
    required this.accent,
    this.count = 120,
  }) : _streaks = _build(count);

  final double progress;
  final double speedNorm;
  final double accelNorm;
  final Color accent;
  final int count;
  final List<_Streak> _streaks;

  static List<_Streak> _build(int n) {
    return List.generate(n, (i) {
      final r = math.Random(i * 7919 + 3);
      // Bias samples toward horizontal sides (side-window wind).
      final side = (r.nextDouble() * 2 - 1);
      final u = side * (0.35 + r.nextDouble() * 0.75);
      final v = (r.nextDouble() - 0.5) * (0.55 + r.nextDouble() * 0.55);
      return _Streak(
        u: u,
        v: v,
        depth: r.nextDouble(),
        length: 0.04 + r.nextDouble() * 0.14,
        thickness: 0.5 + r.nextDouble() * 1.8,
        layer: r.nextInt(3),
        seed: i,
      );
    });
  }

  static double _wind(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Vanishing point slightly below center — road / hood sightline.
    final vp = Offset(size.width * 0.5, size.height * 0.52);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wind = _wind(speedNorm.clamp(0.0, 1.2));
    final accel = accelNorm.clamp(-0.2, 1.2);
    final rush = (wind + math.max(0.0, accel) * 0.5).clamp(0.0, 1.7);
    if (rush < 0.02) return;

    final flow = 0.01 + wind * 0.18 + wind * wind * 1.05 + math.max(0, accel) * 0.4;
    final density = (0.1 + rush * 0.9).clamp(0.0, 1.0);
    final active = math.max(6, (_streaks.length * density).round());

    // Layer speed multipliers (wind shear).
    const layerMul = [0.55, 1.0, 1.55];

    for (var i = 0; i < active; i++) {
      final s = _streaks[i];
      final mul = layerMul[s.layer];
      var d = (s.depth + progress * flow * mul) % 1.0;
      if (d < 0.03) d = 0.03;

      // Perspective: expand from VP with horizontal FOV stretch.
      final fovX = 1.35;
      final fovY = 0.85;
      final scale = math.pow(d, 1.05).toDouble();
      final x = vp.dx + s.u * size.width * 0.5 * fovX * scale;
      final y = vp.dy + s.v * size.height * 0.5 * fovY * scale;

      // Streak points roughly away from VP (forward rush).
      final dir = Offset(x - vp.dx, y - vp.dy);
      final len = dir.distance;
      if (len < 1) continue;
      final nd = dir / len;

      final stretch =
          s.length * size.shortestSide * (0.4 + rush * 2.6) * (0.5 + d);
      // Braking shortens trails.
      final brake = accel < 0 ? (1 + accel * 0.7).clamp(0.35, 1.0) : 1.0;
      final half = stretch * brake;

      final p1 = Offset(x - nd.dx * half * 0.15, y - nd.dy * half * 0.15);
      final p2 = Offset(x + nd.dx * half, y + nd.dy * half);

      final alpha = (0.05 +
              (1 - (d - 0.5).abs() * 1.5).clamp(0.0, 1.0) *
                  (0.2 + rush * 0.65) *
                  (0.55 + s.layer * 0.2))
          .clamp(0.03, 0.92);

      paint
        ..strokeWidth = s.thickness * (0.5 + rush * 1.2) * (0.7 + d)
        ..color = Color.lerp(Colors.white, accent, rush * 0.25)!
            .withValues(alpha: alpha);
      canvas.drawLine(p1, p2, paint);

      // Soft tip dust
      if (s.seed % 5 == 0 && rush > 0.25) {
        canvas.drawCircle(
          p2,
          1.2 + rush,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.5),
        );
      }
    }

    // Subtle center pressure haze
    final gR = size.shortestSide * (0.18 + rush * 0.12);
    canvas.drawCircle(
      vp,
      gR,
      Paint()
        ..shader = ui.Gradient.radial(
          vp,
          gR,
          [
            Colors.white.withValues(alpha: 0.04 + rush * 0.1),
            Colors.transparent,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant WindRushPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm ||
        oldDelegate.accent != accent;
  }
}