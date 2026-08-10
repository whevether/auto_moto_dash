import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Wormhole / black-hole transit: event horizon + spiral accretion + stretch.
class BlackHolePainter extends CustomPainter {
  BlackHolePainter({
    required this.progress,
    required this.speedNorm,
    required this.accelNorm,
    required this.accent,
  });

  final double progress;
  final double speedNorm;
  final double accelNorm;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 0.55;
    final rush = speedNorm.clamp(0.0, 1.3);
    final spin = progress * (0.4 + rush * 2.8 + math.max(0, accelNorm) * 1.2);

    // Accretion disk glow
    canvas.drawCircle(
      c,
      maxR * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          maxR * 0.55,
          [
            accent.withValues(alpha: 0.35 + rush * 0.25),
            const Color(0xFF7C4DFF).withValues(alpha: 0.15),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Spiral arms
    final armPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var arm = 0; arm < 3; arm++) {
      final path = Path();
      var started = false;
      for (var i = 0; i < 80; i++) {
        final t = i / 79;
        final ang = spin + arm * (math.pi * 2 / 3) + t * math.pi * 3.2;
        final rad = maxR * (0.08 + t * 0.95);
        final p = c + Offset(math.cos(ang) * rad, math.sin(ang) * rad * 0.72);
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      armPaint
        ..strokeWidth = 1.5 + rush * 2
        ..color = Color.lerp(accent, Colors.white, 0.3)!
            .withValues(alpha: 0.25 + rush * 0.4);
      canvas.drawPath(path, armPaint);
    }

    // Infalling stretch streaks
    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final n = (40 + rush * 80).round();
    for (var i = 0; i < n; i++) {
      final r = math.Random(i * 131 + 7);
      final baseAng = r.nextDouble() * math.pi * 2 + spin * 0.3;
      final d = (r.nextDouble() + progress * (0.3 + rush * 1.4)) % 1.0;
      final inner = maxR * (0.12 + d * 0.15);
      final outer = maxR * (0.2 + d * 0.95);
      final p1 = c + Offset(math.cos(baseAng) * inner, math.sin(baseAng) * inner);
      final p2 = c + Offset(math.cos(baseAng) * outer, math.sin(baseAng) * outer);
      streak
        ..strokeWidth = 0.8 + d * 2
        ..color = Colors.white.withValues(alpha: (0.1 + (1 - d) * 0.55) * (0.3 + rush));
      canvas.drawLine(p1, p2, streak);
    }

    // Event horizon
    final horizon = maxR * (0.14 + rush * 0.02);
    canvas.drawCircle(c, horizon, Paint()..color = Colors.black);
    canvas.drawCircle(
      c,
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      horizon * 1.08,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant BlackHolePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm;
  }
}