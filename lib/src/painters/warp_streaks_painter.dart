import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class _Streak {
  _Streak(this.angle, this.depth, this.length, this.thickness);

  double angle;
  double depth;
  double length;
  double thickness;
}

/// Radial hyperspace / light-speed streaks behind digital speed.
class WarpStreaksPainter extends CustomPainter {
  WarpStreaksPainter({
    required this.progress,
    required this.intensity,
    required this.accent,
    this.streakCount = 72,
  }) : _streaks = List.generate(streakCount, (i) {
          final r = math.Random(i * 9973);
          return _Streak(
            r.nextDouble() * math.pi * 2,
            r.nextDouble(),
            0.08 + r.nextDouble() * 0.22,
            0.6 + r.nextDouble() * 2.2,
          );
        });

  final double progress;
  final double intensity;
  final Color accent;
  final int streakCount;
  final List<_Streak> _streaks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 0.95;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final density = (0.25 + intensity * 0.75).clamp(0.0, 1.0);
    final speed = 0.08 + intensity * 0.55;

    for (var i = 0; i < _streaks.length; i++) {
      if (i / _streaks.length > density) continue;
      final s = _streaks[i];
      final d = (s.depth + progress * speed) % 1.0;
      final inner = d * maxR;
      final outer = (d + s.length * (0.4 + intensity)) * maxR;
      final a = s.angle;
      final p1 = center + Offset(math.cos(a) * inner, math.sin(a) * inner);
      final p2 = center + Offset(math.cos(a) * outer, math.sin(a) * outer);
      final alpha = (0.15 + (1 - d) * 0.65 * intensity).clamp(0.05, 0.9);
      paint
        ..strokeWidth = s.thickness * (0.7 + intensity)
        ..color = Color.lerp(Colors.white, accent, intensity * 0.35)!
            .withValues(alpha: alpha);
      canvas.drawLine(p1, p2, paint);
    }

    final glow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        maxR * 0.35,
        [
          Colors.white.withValues(alpha: 0.12 + intensity * 0.1),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, maxR * 0.35, glow);
  }

  @override
  bool shouldRepaint(covariant WarpStreaksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.accent != accent;
  }
}