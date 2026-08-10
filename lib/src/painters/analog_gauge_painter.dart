import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnalogGaugeStyle {
  const AnalogGaugeStyle({
    this.ringColor = const Color(0xFF3A3F48),
    this.tickColor = const Color(0xFFE8E8E8),
    this.labelColor = const Color(0xFFCFCFCF),
    this.needleColor = const Color(0xFFFFB84D),
    this.capColor = const Color(0xFF222222),
    this.redlineColor = const Color(0xFFE53935),
    this.faceColor = const Color(0xFF0E0F12),
    this.glowColor = const Color(0x33FFFFFF),
    this.startAngle = math.pi * 0.75,
    this.sweepAngle = math.pi * 1.5,
  });

  final Color ringColor;
  final Color tickColor;
  final Color labelColor;
  final Color needleColor;
  final Color capColor;
  final Color redlineColor;
  final Color faceColor;
  final Color glowColor;
  final double startAngle;
  final double sweepAngle;
}

/// Circular analog gauge with ticks, labels, optional redline and needle.
class AnalogGaugePainter extends CustomPainter {
  AnalogGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.style,
    this.majorTickEvery = 1,
    this.minorTicks = 4,
    this.labelBuilder,
    this.redlineFrom,
    this.title,
    this.unit,
  });

  final double value;
  final double min;
  final double max;
  final AnalogGaugeStyle style;
  final int majorTickEvery;
  final int minorTicks;
  final String Function(double value)? labelBuilder;
  final double? redlineFrom;
  final String? title;
  final String? unit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final face = Paint()..color = style.faceColor;
    canvas.drawCircle(center, radius * 0.98, face);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06
      ..color = style.ringColor;
    canvas.drawCircle(center, radius * 0.94, ring);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..color = style.glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04);
    canvas.drawCircle(center, radius * 0.9, glow);

    if (redlineFrom != null && redlineFrom! < max) {
      final t0 = ((redlineFrom! - min) / (max - min)).clamp(0.0, 1.0);
      final a0 = style.startAngle + style.sweepAngle * t0;
      final a1 = style.startAngle + style.sweepAngle;
      final red = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07
        ..strokeCap = StrokeCap.butt
        ..color = style.redlineColor.withValues(alpha: 0.85);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.88),
        a0,
        a1 - a0,
        false,
        red,
      );
    }

    final span = (max - min).clamp(1e-6, double.infinity);
    final majorCount = ((max - min) / majorTickEvery).round();
    for (var i = 0; i <= majorCount; i++) {
      final v = min + i * majorTickEvery;
      final t = ((v - min) / span).clamp(0.0, 1.0);
      final angle = style.startAngle + style.sweepAngle * t;
      _tick(canvas, center, radius, angle, radius * 0.12, 2.2, style.tickColor);

      final label = labelBuilder?.call(v) ?? v.toStringAsFixed(0);
      final lp = center +
          Offset(
            math.cos(angle) * radius * 0.68,
            math.sin(angle) * radius * 0.68,
          );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: style.labelColor,
            fontSize: radius * 0.11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));

      if (i < majorCount) {
        for (var m = 1; m < minorTicks; m++) {
          final mt = t + (1 / majorCount) * (m / minorTicks);
          final ma = style.startAngle + style.sweepAngle * mt;
          _tick(
            canvas,
            center,
            radius,
            ma,
            radius * 0.06,
            1.2,
            style.tickColor.withValues(alpha: 0.55),
          );
        }
      }
    }

    if (title != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: style.labelColor.withValues(alpha: 0.8),
            fontSize: radius * 0.1,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center + Offset(-tp.width / 2, radius * 0.18));
    }
    if (unit != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: unit,
          style: TextStyle(
            color: style.labelColor.withValues(alpha: 0.65),
            fontSize: radius * 0.08,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center + Offset(-tp.width / 2, radius * 0.32));
    }

    final vt = ((value - min) / span).clamp(0.0, 1.0);
    final needleAngle = style.startAngle + style.sweepAngle * vt;
    final needleLen = radius * 0.72;
    final tip = center +
        Offset(
          math.cos(needleAngle) * needleLen,
          math.sin(needleAngle) * needleLen,
        );
    final back = center +
        Offset(
          math.cos(needleAngle + math.pi) * radius * 0.14,
          math.sin(needleAngle + math.pi) * radius * 0.14,
        );
    final needle = Paint()
      ..color = style.needleColor
      ..strokeWidth = radius * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(back, tip, needle);

    canvas.drawCircle(center, radius * 0.08, Paint()..color = style.capColor);
    canvas.drawCircle(
      center,
      radius * 0.035,
      Paint()..color = style.needleColor,
    );
  }

  void _tick(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final outer = radius * 0.9;
    final p1 = center +
        Offset(math.cos(angle) * outer, math.sin(angle) * outer);
    final p2 = center +
        Offset(
          math.cos(angle) * (outer - length),
          math.sin(angle) * (outer - length),
        );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant AnalogGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.redlineFrom != redlineFrom ||
        oldDelegate.style != style;
  }
}