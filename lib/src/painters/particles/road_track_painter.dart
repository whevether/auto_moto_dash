import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Perspective asphalt road / race track rushing forward.
class RoadTrackPainter extends CustomPainter {
  RoadTrackPainter({
    required this.distance,
    required this.flowSpeed,
    required this.accent,
  });

  final double distance;
  final double flowSpeed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rush = flowSpeed.clamp(0.0, 1.4);
    if (rush < 0.015) return;

    final vp = Offset(size.width * 0.5, size.height * 0.38);
    final groundTop = vp.dy;
    final groundBottom = size.height;

    // No opaque sky fill — weather behind this layer must remain visible
    // above the horizon. Soften only the road trapezoid into transparency
    // near the vanishing point so it blends with weather.
    final road = Path()
      ..moveTo(vp.dx - 8, groundTop)
      ..lineTo(vp.dx + 8, groundTop)
      ..lineTo(size.width * 1.05, groundBottom)
      ..lineTo(-size.width * 0.05, groundBottom)
      ..close();

    canvas.drawPath(
      road,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, groundTop),
          Offset(0, groundBottom),
          [
            const Color(0xFF2A2A2E).withValues(alpha: 0.15),
            const Color(0xFF1A1A1C).withValues(alpha: 0.72),
            const Color(0xFF121214).withValues(alpha: 0.88),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );

    final grain = Paint()..color = Colors.white.withValues(alpha: 0.03);
    final rng = math.Random(42);
    for (var i = 0; i < 36; i++) {
      final t = rng.nextDouble();
      final y = groundTop + math.pow(t, 1.35) * (groundBottom - groundTop);
      final halfW = _roadHalfWidth(size, vp, y);
      final x = vp.dx + (rng.nextDouble() * 2 - 1) * halfW * 0.9;
      canvas.drawCircle(Offset(x, y), 0.8 + rng.nextDouble(), grain);
    }

    final curb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFE8E8E8).withValues(alpha: 0.55 + rush * 0.25);
    canvas.drawLine(
      Offset(vp.dx - 6, groundTop),
      Offset(-size.width * 0.02, groundBottom),
      curb,
    );
    canvas.drawLine(
      Offset(vp.dx + 6, groundTop),
      Offset(size.width * 1.02, groundBottom),
      curb,
    );

    _paintKerb(canvas, size, vp, left: true, rush: rush);
    _paintKerb(canvas, size, vp, left: false, rush: rush);

    final dashPaint = Paint()
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFFFF59D).withValues(alpha: 0.75);
    const segments = 8;
    final scroll = distance * 0.55;
    for (var i = 0; i < segments; i++) {
      final t0 = ((i / segments) + scroll) % 1.0;
      final t1 = (t0 + 0.045).clamp(0.0, 1.0);
      if (t1 <= t0) continue;
      final y0 = groundTop + math.pow(t0, 1.55) * (groundBottom - groundTop);
      final y1 = groundTop + math.pow(t1, 1.55) * (groundBottom - groundTop);
      dashPaint.strokeWidth = 1.5 + t0 * 4;
      canvas.drawLine(Offset(vp.dx, y0), Offset(vp.dx, y1), dashPaint);
    }

    final postPaint =
        Paint()..color = accent.withValues(alpha: 0.35 + rush * 0.25);
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 5; i++) {
        final t = ((i / 5) + scroll * 0.7) % 1.0;
        if (t < 0.08) continue;
        final y = groundTop + math.pow(t, 1.5) * (groundBottom - groundTop);
        final half = _roadHalfWidth(size, vp, y);
        final x = vp.dx + side * (half + 6 + t * 10);
        final h = 6 + t * 18;
        canvas.drawRect(Rect.fromLTWH(x - 1.2, y - h, 2.4, h), postPaint);
      }
    }

    canvas.drawCircle(
      vp,
      28 + rush * 20,
      Paint()
        ..shader = ui.Gradient.radial(
          vp,
          40 + rush * 24,
          [
            Colors.white.withValues(alpha: 0.06 + rush * 0.08),
            Colors.transparent,
          ],
        ),
    );
  }

  double _roadHalfWidth(Size size, Offset vp, double y) {
    final t = ((y - vp.dy) / (size.height - vp.dy)).clamp(0.0, 1.0);
    return 8 + t * size.width * 0.52;
  }

  void _paintKerb(
    Canvas canvas,
    Size size,
    Offset vp, {
    required bool left,
    required double rush,
  }) {
    final scroll = distance * 0.4;
    for (var i = 0; i < 10; i++) {
      final t = ((i / 10) + scroll) % 1.0;
      if (t < 0.05 || t > 0.95) continue;
      final y = vp.dy + math.pow(t, 1.5) * (size.height - vp.dy);
      final half = _roadHalfWidth(size, vp, y);
      final x = vp.dx + (left ? -1 : 1) * (half - 2);
      final stripeH = 4 + t * 10;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 3 + t * 5,
          height: stripeH,
        ),
        Paint()
          ..color = (i.isEven ? const Color(0xFFE53935) : Colors.white)
              .withValues(alpha: 0.4 + rush * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RoadTrackPainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.flowSpeed != flowSpeed ||
        oldDelegate.accent != accent;
  }
}