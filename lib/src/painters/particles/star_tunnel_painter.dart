import 'dart:math' as math;

import 'package:flutter/material.dart';

class StarTunnelPainter extends CustomPainter {
  StarTunnelPainter({
    required this.distance,
    required this.flowSpeed,
    required this.accent,
  }) : _stars = List.generate(48, (i) {
          final r = math.Random(i * 4243 + 11);
          return _Star(
            r.nextDouble() * math.pi * 2,
            r.nextDouble(),
            0.7 + r.nextDouble() * 2.0,
          );
        });

  final double distance;
  final double flowSpeed;
  final Color accent;
  final List<_Star> _stars;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 0.95;
    final rush = flowSpeed.clamp(0.0, 1.4);
    if (rush < 0.02) return;

    final paint = Paint();
    final active = math.max(8, (_stars.length * (0.4 + rush * 0.5)).round());

    for (var i = 0; i < active; i++) {
      final s = _stars[i];
      final d = (s.depth + distance * 0.9) % 1.0;
      final rad = math.pow(d, 1.2).toDouble() * maxR;
      final p = c + Offset(math.cos(s.angle) * rad, math.sin(s.angle) * rad);
      if (rush > 0.3) {
        final back = rad * (1 - 0.07 * rush);
        final p0 =
            c + Offset(math.cos(s.angle) * back, math.sin(s.angle) * back);
        canvas.drawLine(
          p0,
          p,
          Paint()
            ..strokeWidth = s.size * 0.45
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.12 + d * 0.4 * rush),
        );
      }
      paint.color = Color.lerp(Colors.white, accent, rush * 0.25)!
          .withValues(alpha: 0.18 + d * 0.6);
      canvas.drawCircle(p, s.size * (0.4 + d * 0.85), paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarTunnelPainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.flowSpeed != flowSpeed;
  }
}

class _Star {
  _Star(this.angle, this.depth, this.size);
  final double angle;
  final double depth;
  final double size;
}