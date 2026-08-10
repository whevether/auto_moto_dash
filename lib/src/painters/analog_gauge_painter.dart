import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum AnalogGaugeTheme {
  /// BMW-inspired: chrome bezel, white ticks, red needle, black face.
  bmw,

  /// Ferrari-inspired: yellow numerals, black face, red needle & redline.
  ferrari,
}

class AnalogGaugeStyle {
  const AnalogGaugeStyle({
    required this.theme,
    this.startAngle = math.pi * 0.75,
    this.sweepAngle = math.pi * 1.5,
  });

  final AnalogGaugeTheme theme;
  final double startAngle;
  final double sweepAngle;

  Color get faceColor => switch (theme) {
        AnalogGaugeTheme.bmw => const Color(0xFF0A0B0D),
        AnalogGaugeTheme.ferrari => const Color(0xFF080808),
      };

  Color get tickColor => switch (theme) {
        AnalogGaugeTheme.bmw => const Color(0xFFF2F2F2),
        AnalogGaugeTheme.ferrari => const Color(0xFFFFD54F),
      };

  Color get labelColor => switch (theme) {
        AnalogGaugeTheme.bmw => const Color(0xFFECECEC),
        AnalogGaugeTheme.ferrari => const Color(0xFFFFC107),
      };

  Color get needleColor => switch (theme) {
        AnalogGaugeTheme.bmw => const Color(0xFFE53935),
        AnalogGaugeTheme.ferrari => const Color(0xFFFF1744),
      };

  Color get redlineColor => const Color(0xFFD32F2F);

  Color get accentColor => switch (theme) {
        AnalogGaugeTheme.bmw => const Color(0xFF90CAF9),
        AnalogGaugeTheme.ferrari => const Color(0xFFFFD54F),
      };
}

/// Realistic circular automotive gauge (BMW / Ferrari inspired).
class AnalogGaugePainter extends CustomPainter {
  AnalogGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.style,
    this.majorTickEvery = 1,
    this.minorTicks = 5,
    this.labelBuilder,
    this.redlineFrom,
    this.title,
    this.unit,
    this.centerReadout,
    this.centerReadoutUnit,
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
  final String? centerReadout;
  final String? centerReadoutUnit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final ferrari = style.theme == AnalogGaugeTheme.ferrari;

    _paintBezel(canvas, center, radius, ferrari);
    _paintFace(canvas, center, radius);
    _paintRedline(canvas, center, radius);
    _paintTicksAndLabels(canvas, center, radius, ferrari);
    _paintCenterText(canvas, center, radius, ferrari);
    _paintNeedle(canvas, center, radius);
    _paintHub(canvas, center, radius, ferrari);
    _paintGlass(canvas, center, radius);
  }

  void _paintBezel(Canvas canvas, Offset c, double r, bool ferrari) {
    // Outer dark housing
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            const Color(0xFF2A2A2E),
            const Color(0xFF121214),
            const Color(0xFF050506),
          ],
          const [0.75, 0.9, 1.0],
        ),
    );

    // Chrome / carbon ring
    final ringR = r * 0.935;
    final ringW = r * 0.055;
    if (ferrari) {
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW
          ..color = const Color(0xFF1A1A1A),
      );
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW * 0.35
          ..color = const Color(0xFF3A3A3A),
      );
    } else {
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW
          ..shader = ui.Gradient.linear(
            Offset(c.dx - ringR, c.dy - ringR),
            Offset(c.dx + ringR, c.dy + ringR),
            const [
              Color(0xFF9E9E9E),
              Color(0xFFE8E8E8),
              Color(0xFF757575),
              Color(0xFFBDBDBD),
              Color(0xFF616161),
            ],
            const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
      );
    }

    // Inner black lip
    canvas.drawCircle(
      c,
      r * 0.895,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.018
        ..color = const Color(0xFF0D0D0F),
    );
  }

  void _paintFace(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-r * 0.12, -r * 0.15),
          r * 1.1,
          [
            Color.lerp(style.faceColor, Colors.white, 0.06)!,
            style.faceColor,
            Colors.black,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Subtle inner track ring
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = style.tickColor.withValues(alpha: 0.12),
    );
  }

  void _paintRedline(Canvas canvas, Offset c, double r) {
    if (redlineFrom == null || redlineFrom! >= max) return;
    final span = max - min;
    final t0 = ((redlineFrom! - min) / span).clamp(0.0, 1.0);
    final a0 = style.startAngle + style.sweepAngle * t0;
    final sweep = style.sweepAngle * (1 - t0);
    final rect = Rect.fromCircle(center: c, radius: r * 0.845);

    canvas.drawArc(
      rect,
      a0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.butt
        ..color = style.redlineColor.withValues(alpha: 0.9),
    );

    // Hash marks in redline (Ferrari style)
    if (style.theme == AnalogGaugeTheme.ferrari) {
      final steps = 8;
      for (var i = 0; i <= steps; i++) {
        final a = a0 + sweep * (i / steps);
        final p1 = c + Offset(math.cos(a) * r * 0.818, math.sin(a) * r * 0.818);
        final p2 = c + Offset(math.cos(a) * r * 0.872, math.sin(a) * r * 0.872);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _paintTicksAndLabels(
    Canvas canvas,
    Offset c,
    double r,
    bool ferrari,
  ) {
    final span = (max - min).clamp(1e-6, double.infinity);
    final majorCount = ((max - min) / majorTickEvery).round().clamp(1, 40);

    for (var i = 0; i <= majorCount; i++) {
      final v = min + i * majorTickEvery;
      final t = ((v - min) / span).clamp(0.0, 1.0);
      final angle = style.startAngle + style.sweepAngle * t;
      final inRed =
          redlineFrom != null && v >= redlineFrom! - 1e-6;

      _tick(
        canvas,
        c,
        r,
        angle,
        length: r * (ferrari ? 0.11 : 0.10),
        width: r * 0.018,
        color: inRed ? style.redlineColor : style.tickColor,
        outer: r * 0.87,
      );

      final label = labelBuilder?.call(v) ?? v.toStringAsFixed(0);
      final lp = c +
          Offset(
            math.cos(angle) * r * 0.66,
            math.sin(angle) * r * 0.66,
          );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: inRed ? style.redlineColor : style.labelColor,
            fontSize: r * (ferrari ? 0.125 : 0.105),
            fontWeight: ferrari ? FontWeight.w700 : FontWeight.w600,
            fontFamily: ferrari ? 'serif' : null,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));

      if (i >= majorCount) continue;
      for (var m = 1; m < minorTicks; m++) {
        final mt = t + (1 / majorCount) * (m / minorTicks);
        final ma = style.startAngle + style.sweepAngle * mt;
        final mid = m == minorTicks ~/ 2;
        _tick(
          canvas,
          c,
          r,
          ma,
          length: r * (mid ? 0.07 : 0.045),
          width: r * (mid ? 0.01 : 0.006),
          color: style.tickColor.withValues(alpha: mid ? 0.75 : 0.4),
          outer: r * 0.87,
        );
      }
    }
  }

  void _paintCenterText(
    Canvas canvas,
    Offset c,
    double r,
    bool ferrari,
  ) {
    if (title != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: style.labelColor.withValues(alpha: 0.55),
            fontSize: r * 0.07,
            letterSpacing: ferrari ? 2.5 : 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, r * 0.12));
    }

    if (unit != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: unit,
          style: TextStyle(
            color: style.labelColor.withValues(alpha: 0.45),
            fontSize: r * 0.055,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, r * 0.22));
    }

    if (centerReadout != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: centerReadout,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: r * 0.2,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, -r * 0.08 - tp.height / 2));
      if (centerReadoutUnit != null) {
        final up = TextPainter(
          text: TextSpan(
            text: centerReadoutUnit,
            style: TextStyle(
              color: style.accentColor.withValues(alpha: 0.8),
              fontSize: r * 0.05,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        up.paint(canvas, c + Offset(-up.width / 2, r * 0.02));
      }
    }
  }

  void _paintNeedle(Canvas canvas, Offset c, double r) {
    final span = (max - min).clamp(1e-6, double.infinity);
    final vt = ((value - min) / span).clamp(0.0, 1.0);
    final angle = style.startAngle + style.sweepAngle * vt;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);

    // Soft shadow under needle
    final shadow = Path()
      ..moveTo(r * 0.12, 0)
      ..lineTo(-r * 0.018, -r * 0.028)
      ..lineTo(-r * 0.72, 0)
      ..lineTo(-r * 0.018, r * 0.028)
      ..close();
    canvas.drawPath(
      shadow.shift(const Offset(2, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Tapered needle body (point toward -X because start is left-bottom arc)
    // Needle tip points along +X after we rotate to angle from center along cos/sin.
    // Our angle convention: 0 = east. Tip should be at outer tick → use +X direction
    // after rotate(angle), tip at (needleLen, 0).
    final tipLen = r * 0.78;
    final backLen = r * 0.16;
    final needle = Path()
      ..moveTo(tipLen, 0)
      ..lineTo(-backLen * 0.15, -r * 0.022)
      ..lineTo(-backLen, -r * 0.012)
      ..lineTo(-backLen, r * 0.012)
      ..lineTo(-backLen * 0.15, r * 0.022)
      ..close();

    canvas.drawPath(
      needle,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-backLen, 0),
          Offset(tipLen, 0),
          [
            Color.lerp(style.needleColor, Colors.black, 0.25)!,
            style.needleColor,
            Color.lerp(style.needleColor, Colors.white, 0.25)!,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // White tip accent (BMW)
    if (style.theme == AnalogGaugeTheme.bmw) {
      canvas.drawLine(
        Offset(tipLen * 0.82, 0),
        Offset(tipLen, 0),
        Paint()
          ..color = Colors.white
          ..strokeWidth = r * 0.012
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  void _paintHub(Canvas canvas, Offset c, double r, bool ferrari) {
    canvas.drawCircle(
      c,
      r * 0.11,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-r * 0.02, -r * 0.02),
          r * 0.12,
          const [
            Color(0xFF4A4A4E),
            Color(0xFF1A1A1C),
            Color(0xFF0A0A0B),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      c,
      r * 0.11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ferrari
            ? const Color(0xFFFFD54F).withValues(alpha: 0.35)
            : const Color(0xFFBDBDBD).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      c,
      r * 0.045,
      Paint()..color = style.needleColor,
    );
    canvas.drawCircle(
      c,
      r * 0.02,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  void _paintGlass(Canvas canvas, Offset c, double r) {
    final highlight = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: r * 0.86),
        -math.pi * 0.95,
        math.pi * 0.55,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.07)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.02),
    );
  }

  void _tick(
    Canvas canvas,
    Offset c,
    double r,
    double angle, {
    required double length,
    required double width,
    required Color color,
    required double outer,
  }) {
    final p1 = c + Offset(math.cos(angle) * outer, math.sin(angle) * outer);
    final p2 = c +
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
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant AnalogGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.redlineFrom != redlineFrom ||
        oldDelegate.centerReadout != centerReadout ||
        oldDelegate.style.theme != style.theme;
  }
}
