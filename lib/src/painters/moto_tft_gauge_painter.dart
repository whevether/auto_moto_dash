import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Arc gauge for motorcycle TFT (RPM, fuel, etc.).
class MotoTftGaugePainter extends CustomPainter {
  MotoTftGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    this.startAngle = math.pi * 1.15,
    this.sweepAngle = math.pi * 0.7,
    this.majorTicks = 8,
    this.labelBuilder,
    this.activeColor = Colors.white,
    this.trackColor,
    this.redlineFrom,
    this.segmented = false,
    this.segmentCount = 18,
  });

  final double value;
  final double min;
  final double max;
  final double startAngle;
  final double sweepAngle;
  final int majorTicks;
  final String Function(double)? labelBuilder;
  final Color activeColor;
  final Color? trackColor;
  final double? redlineFrom;
  final bool segmented;
  final int segmentCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final track = trackColor ?? Colors.white.withValues(alpha: 0.12);
    final norm = ((value - min) / (max - min)).clamp(0.0, 1.0);

    if (segmented) {
      _paintSegmented(canvas, center, radius, norm, track);
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = track,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * norm,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = activeColor,
      );
    }

    for (var i = 0; i <= majorTicks; i++) {
      final t = i / majorTicks;
      final angle = startAngle + sweepAngle * t;
      final tickVal = min + (max - min) * t;
      final inRed = redlineFrom != null && tickVal >= redlineFrom!;
      final tickColor = inRed ? const Color(0xFFFF5252) : activeColor;
      final inner = radius - 8;
      final outer = radius - (i % (majorTicks ~/ 2) == 0 ? 2 : 5);
      final p1 = center +
          Offset(math.cos(angle) * inner, math.sin(angle) * inner);
      final p2 = center +
          Offset(math.cos(angle) * outer, math.sin(angle) * outer);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = i % (majorTicks ~/ 2) == 0 ? 2 : 1
          ..color = tickColor.withValues(alpha: 0.85),
      );
      if (labelBuilder != null && i % (majorTicks ~/ 2) == 0) {
        final label = labelBuilder!(tickVal);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: tickColor.withValues(alpha: 0.7),
              fontSize: 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lp = center +
            Offset(
              math.cos(angle) * (radius - 18),
              math.sin(angle) * (radius - 18),
            );
        tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _paintSegmented(
    Canvas canvas,
    Offset center,
    double radius,
    double norm,
    Color track,
  ) {
    final segSweep = sweepAngle / segmentCount;
    final lit = (norm * segmentCount).ceil();
    for (var i = 0; i < segmentCount; i++) {
      final angle = startAngle + segSweep * i + segSweep * 0.15;
      final segLen = segSweep * 0.7;
      final color = i < lit ? activeColor : track;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segLen,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MotoTftGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max;
  }
}

/// Vertical fuel gauge on left side of moto TFT.
class MotoVerticalGaugePainter extends CustomPainter {
  MotoVerticalGaugePainter({
    required this.value,
    this.topLabel = 'F',
    this.bottomLabel = 'E',
    this.color = const Color(0xFFFF9800),
  });

  final double value;
  final String topLabel;
  final String bottomLabel;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.35, 8, size.width * 0.3, size.height - 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      trackRect,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    final fillH = (size.height - 16) * value.clamp(0.0, 1.0);
    if (fillH > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.35,
            size.height - 8 - fillH,
            size.width * 0.3,
            fillH,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );
    }
    _label(canvas, topLabel, Offset(size.width / 2, 2));
    _label(canvas, bottomLabel, Offset(size.width / 2, size.height - 12));
  }

  void _label(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant MotoVerticalGaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

/// Wide top RPM segmented bar (reference TFT image 1).
class MotoTopRpmBarPainter extends CustomPainter {
  MotoTopRpmBarPainter({
    required this.rpm,
    this.maxRpm = 18000,
    this.redlineFrom = 14000,
    this.segments = 18,
  });

  final double rpm;
  final double maxRpm;
  final double redlineFrom;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 1.08;
    const sweep = math.pi * 0.84;
    // Arc center sits below the paint area so only the top bow is visible.
    final radius = size.width * 0.52;
    final center = Offset(size.width * 0.5, size.height + radius * 0.28);
    final norm = (rpm / maxRpm).clamp(0.0, 1.0);
    final lit = (norm * segments).ceil();

    final segSweep = sweep / segments;
    for (var i = 0; i < segments; i++) {
      final rpmAt = maxRpm * (i + 1) / segments;
      final inRed = rpmAt >= redlineFrom;
      final active = i < lit;
      final base = inRed ? const Color(0xFFFF5252) : Colors.white;
      final color = active ? base : base.withValues(alpha: 0.15);
      final angle = startAngle + segSweep * i + segSweep * 0.12;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segSweep * 0.72,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    for (var i = 1; i <= segments; i++) {
      if (i % 2 != 0 && i != segments) continue;
      final angle = startAngle + sweep * (i / segments);
      final rpmVal = (maxRpm / 1000 * i).round();
      final inRed = i * 1000 >= redlineFrom;
      final lp = center +
          Offset(
            math.cos(angle) * (radius + 10),
            math.sin(angle) * (radius + 10),
          );
      // Skip labels that would draw above the visible area.
      if (lp.dy < 2) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: '$rpmVal',
          style: TextStyle(
            color: (inRed ? const Color(0xFFFF5252) : Colors.white)
                .withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }

    final unit = TextPainter(
      text: TextSpan(
        text: '×1000/min',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unit.paint(canvas, Offset(size.width * 0.36, size.height * 0.08));
  }

  @override
  bool shouldRepaint(covariant MotoTopRpmBarPainter oldDelegate) {
    return oldDelegate.rpm != rpm;
  }
}

/// Segmented vertical fuel column (reference TFT image 1).
class MotoFuelSegmentPainter extends CustomPainter {
  MotoFuelSegmentPainter({
    required this.percent,
    this.segments = 8,
  });

  final double percent;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    final filled = (percent / 100 * segments).ceil().clamp(0, segments);
    final segH = (size.height - (segments - 1) * 2) / segments;
    for (var i = 0; i < segments; i++) {
      final idx = segments - 1 - i;
      final y = i * (segH + 2);
      final active = idx < filled;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y, size.width, segH),
          const Radius.circular(2),
        ),
        Paint()..color = active
            ? const Color(0xFFFF9800)
            : Colors.white.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MotoFuelSegmentPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}
