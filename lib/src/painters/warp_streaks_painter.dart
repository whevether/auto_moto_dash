import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class _Streak {
  _Streak({
    required this.angle,
    required this.depth,
    required this.baseLength,
    required this.thickness,
    required this.drift,
    required this.seed,
  });

  double angle;
  double depth;
  final double baseLength;
  final double thickness;
  final double drift;
  final int seed;
}

/// Radial wind / light-speed streaks.
///
/// Motion is intentionally non-linear: slow crawl at low speed, then ramps
/// hard as speed (and acceleration) rise — closer to perceived wind rush.
class WarpStreaksPainter extends CustomPainter {
  WarpStreaksPainter({
    required this.progress,
    required this.speedNorm,
    required this.accelNorm,
    required this.accent,
    this.streakCount = 90,
  }) : _streaks = _build(streakCount);

  /// Monotonic time in seconds (for subtle shimmer only).
  final double progress;

  /// 0..1 speed / lightSpeedThreshold (raw, before easing).
  final double speedNorm;

  /// Roughly -0.2..1 from longitudinal acceleration.
  final double accelNorm;

  final Color accent;
  final int streakCount;
  final List<_Streak> _streaks;

  static List<_Streak> _build(int count) {
    return List.generate(count, (i) {
      final r = math.Random(i * 9973 + 17);
      return _Streak(
        angle: r.nextDouble() * math.pi * 2,
        depth: r.nextDouble(),
        baseLength: 0.05 + r.nextDouble() * 0.16,
        thickness: 0.5 + r.nextDouble() * 2.0,
        drift: (r.nextDouble() - 0.5) * 0.35,
        seed: i,
      );
    });
  }

  /// Ease-in cubic: stays soft early, surges later.
  static double _windCurve(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 1.05;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final raw = speedNorm.clamp(0.0, 1.2);
    final wind = _windCurve(raw); // slow start → fast later
    final accelBoost = accelNorm.clamp(-0.15, 1.2);
    // Forward accel stretches & speeds streaks; braking slightly calms them.
    final rush = (wind + math.max(0.0, accelBoost) * 0.45).clamp(0.0, 1.6);

    // Radial advance rate (depth units / normalized progress second).
    // Quadratic-cubic blend: barely moves when crawling, howls at speed.
    final flow = 0.015 + wind * 0.22 + wind * wind * 0.95 + math.max(0, accelBoost) * 0.35;

    // How many streaks are alive — sparse breeze → dense gale.
    final density = (0.08 + rush * 0.92).clamp(0.0, 1.0);
    final active = math.max(4, (_streaks.length * density).round());

    for (var i = 0; i < active; i++) {
      final s = _streaks[i];
      // Perspective: outer (near) layers travel faster — wind shear feel.
      final layer = 0.55 + s.depth * 0.9;
      var d = (s.depth + progress * flow * layer) % 1.0;
      // Soft respawn bias toward center so new streaks “appear” ahead.
      if (d < 0.02) {
        d = 0.02 + (s.seed % 7) * 0.01;
      }

      // Motion blur length grows with wind; near-camera streaks longer.
      final stretch =
          s.baseLength * (0.35 + rush * 2.4) * (0.55 + d * 1.35);
      final inner = math.pow(d, 1.15).toDouble() * maxR;
      final outer = (d + stretch).clamp(0.0, 1.35) * maxR;

      // Slight angular sway = crosswind / road vibration.
      final sway = s.drift * (0.04 + rush * 0.1) * math.sin(progress * 3.2 + s.seed);
      final a = s.angle + sway;

      final p1 = center + Offset(math.cos(a) * inner, math.sin(a) * inner);
      final p2 = center + Offset(math.cos(a) * outer, math.sin(a) * outer);

      // Fade in near center, peak mid-field, ease out at rim.
      final mid = 1 - (d - 0.45).abs() * 1.6;
      final alpha =
          (0.04 + mid.clamp(0.0, 1.0) * (0.25 + rush * 0.65)).clamp(0.03, 0.95);

      paint
        ..strokeWidth = s.thickness * (0.55 + rush * 1.35) * (0.7 + d)
        ..color = Color.lerp(
          Colors.white,
          accent,
          (rush * 0.4).clamp(0.0, 0.7),
        )!
            .withValues(alpha: alpha);

      canvas.drawLine(p1, p2, paint);
    }

    // Central pressure glow intensifies with rush.
    final glowR = maxR * (0.22 + rush * 0.16);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          glowR,
          [
            Colors.white.withValues(alpha: 0.05 + rush * 0.16),
            Colors.transparent,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant WarpStreaksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm ||
        oldDelegate.accent != accent;
  }
}