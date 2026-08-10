import 'dart:math' as math;

import 'package:flutter/material.dart';

class StarTunnelPainter extends CustomPainter {
  StarTunnelPainter({
    required this.progress,
    required this.speedNorm,
    required this.accelNorm,
    required this.accent,
  }) : _stars = List.generate(160, (i) {
          final r = math.Random(i * 4243 + 11);
          return _Star(
            r.nextDouble() * math.pi * 2,
            r.nextDouble(),
            0.6 + r.nextDouble() * 2.2,
          );
        });

  final double progress;
  final double speedNorm;
  final double accelNorm;
  final Color accent;
  final List<_Star> _stars;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final maxR = size.shortestSide * 0.95;
    final rush = speedNorm.clamp(0.0, 1.4);
    final flow = 0.05 + rush * rush * 1.4 + math.max(0, accelNorm) * 0.5;
    final paint = Paint();

    for (final s in _stars) {
      final d = (s.depth + progress * flow) % 1.0;
      final rad = math.pow(d, 1.2).toDouble() * maxR;
      final p = c + Offset(math.cos(s.angle) * rad, math.sin(s.angle) * rad);
      // Motion streak at high speed
      if (rush > 0.35) {
        final back = rad * (1 - 0.08 * rush);
        final p0 =
            c + Offset(math.cos(s.angle) * back, math.sin(s.angle) * back);
        canvas.drawLine(
          p0,
          p,
          Paint()
            ..strokeWidth = s.size * 0.5
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.15 + d * 0.5 * rush),
        );
      }
      paint.color = Color.lerp(Colors.white, accent, rush * 0.3)!
          .withValues(alpha: 0.2 + d * 0.7);
      canvas.drawCircle(p, s.size * (0.4 + d * 0.9), paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarTunnelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm;
  }
}

class _Star {
  _Star(this.angle, this.depth, this.size);
  final double angle;
  final double depth;
  final double size;
}