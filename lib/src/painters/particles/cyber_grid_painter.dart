import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Perspective cyber grid rushing forward.
class CyberGridPainter extends CustomPainter {
  CyberGridPainter({
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
    final vp = Offset(size.width / 2, size.height * 0.42);
    final rush = speedNorm.clamp(0.0, 1.3);
    final scroll = (progress * (0.2 + rush * 2.2 + math.max(0, accelNorm))) % 1.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.2 + rush * 0.45);

    // Horizon line
    canvas.drawLine(
      Offset(0, vp.dy),
      Offset(size.width, vp.dy),
      Paint()..color = accent.withValues(alpha: 0.25),
    );

    // Ground grid — horizontal lines (depth)
    for (var i = 0; i < 18; i++) {
      final t = ((i / 18) + scroll) % 1.0;
      final y = vp.dy + math.pow(t, 1.6) * (size.height - vp.dy);
      final spread = t * size.width * 0.55;
      canvas.drawLine(
        Offset(vp.dx - spread - size.width * 0.1, y),
        Offset(vp.dx + spread + size.width * 0.1, y),
        paint..color = accent.withValues(alpha: 0.08 + t * 0.4),
      );
    }

    // Vertical converging lines
    for (var i = -10; i <= 10; i++) {
      if (i == 0) continue;
      final edgeX = vp.dx + i * size.width * 0.12;
      canvas.drawLine(
        vp,
        Offset(edgeX, size.height + 20),
        paint..color = accent.withValues(alpha: 0.12 + rush * 0.2),
      );
    }

    // Sky grid (lighter)
    for (var i = 0; i < 8; i++) {
      final t = ((i / 8) + scroll * 0.5) % 1.0;
      final y = vp.dy - math.pow(t, 1.4) * vp.dy * 0.85;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = accent.withValues(alpha: 0.04 + t * 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedNorm != speedNorm ||
        oldDelegate.accelNorm != accelNorm;
  }
}