import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

class BlackHolePainter extends CustomPainter {
  BlackHolePainter({
    required this.distance,
    required this.flowSpeed,
    required this.accent,
  });

  final double distance;
  final double flowSpeed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 0.55;
    final rush = flowSpeed.clamp(0.0, 1.3);
    if (rush < 0.02) return;

    final spin = distance * (0.9 + rush * 0.8);

    canvas.drawCircle(
      c,
      maxR * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          maxR * 0.55,
          [
            accent.withValues(alpha: 0.28 + rush * 0.2),
            const Color(0xFF7C4DFF).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    final armPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var arm = 0; arm < 2; arm++) {
      final path = Path();
      var started = false;
      for (var i = 0; i < 56; i++) {
        final t = i / 55;
        final ang = spin + arm * math.pi + t * math.pi * 2.8;
        final rad = maxR * (0.1 + t * 0.92);
        final p = c + Offset(math.cos(ang) * rad, math.sin(ang) * rad * 0.72);
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      armPaint
        ..strokeWidth = 1.4 + rush * 1.6
        ..color = Color.lerp(accent, Colors.white, 0.3)!
            .withValues(alpha: 0.22 + rush * 0.35);
      canvas.drawPath(path, armPaint);
    }

    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final n = (18 + rush * 22).round();
    for (var i = 0; i < n; i++) {
      final r = math.Random(i * 131 + 7);
      final baseAng = r.nextDouble() * math.pi * 2 + spin * 0.25;
      final d = (r.nextDouble() + distance * 0.7) % 1.0;
      final inner = maxR * (0.14 + d * 0.12);
      final outer = maxR * (0.22 + d * 0.9);
      final p1 =
          c + Offset(math.cos(baseAng) * inner, math.sin(baseAng) * inner);
      final p2 =
          c + Offset(math.cos(baseAng) * outer, math.sin(baseAng) * outer);
      streak
        ..strokeWidth = 0.7 + d * 1.6
        ..color = Colors.white
            .withValues(alpha: (0.08 + (1 - d) * 0.4) * (0.35 + rush * 0.5));
      canvas.drawLine(p1, p2, streak);
    }

    final horizon = maxR * (0.14 + rush * 0.015);
    canvas.drawCircle(c, horizon, Paint()..color = Colors.black);
    canvas.drawCircle(
      c,
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = accent.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant BlackHolePainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.flowSpeed != flowSpeed;
  }
}