import 'package:material_ui/material_ui.dart';

/// Horizontal segmented battery bar.
class BatteryBarPainter extends CustomPainter {
  BatteryBarPainter({
    required this.percent,
    this.segments = 5,
    this.activeColor = const Color(0xFF00E676),
    this.inactiveColor,
    this.gap = 3,
    this.radius = 2,
  });

  final double percent;
  final int segments;
  final Color activeColor;
  final Color? inactiveColor;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final inactive = inactiveColor ?? Colors.white.withValues(alpha: 0.12);
    final filled = (percent / 100 * segments).ceil().clamp(0, segments);
    final segW = (size.width - gap * (segments - 1)) / segments;

    for (var i = 0; i < segments; i++) {
      final x = i * (segW + gap);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, segW, size.height),
        Radius.circular(radius),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = i < filled ? activeColor : inactive,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BatteryBarPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.segments != segments ||
        oldDelegate.activeColor != activeColor;
  }
}

/// Battery icon outline with fill level.
class BatteryIconPainter extends CustomPainter {
  BatteryIconPainter({
    required this.percent,
    this.color = const Color(0xFF00E676),
    this.outlineColor,
  });

  final double percent;
  final Color color;
  final Color? outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = outlineColor ?? Colors.white.withValues(alpha: 0.6);
    final bodyW = size.width * 0.88;
    final bodyH = size.height * 0.55;
    final top = (size.height - bodyH) / 2;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, bodyW, bodyH),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = outline,
    );
    final tipW = size.width - bodyW;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyW, top + bodyH * 0.25, tipW, bodyH * 0.5),
        const Radius.circular(1),
      ),
      Paint()..color = outline,
    );
    final fillW = (bodyW - 4) * (percent / 100).clamp(0.0, 1.0);
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, top + 2, fillW, bodyH - 4),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BatteryIconPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}
