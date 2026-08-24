import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class IonStormPainter extends CustomPainter {
  IonStormPainter({
    required this.distance,
    required this.flowSpeed,
    required this.accent,
  }) : _ions = List.generate(32, (i) {
          final r = math.Random(i * 3331 + 5);
          return _Ion(
            r.nextDouble(),
            r.nextDouble(),
            r.nextDouble() * math.pi * 2,
            0.5 + r.nextDouble() * 1.5,
            HSVColor.fromAHSV(1, r.nextDouble() * 360, 0.7, 1).toColor(),
          );
        });

  final double distance;
  final double flowSpeed;
  final Color accent;
  final List<_Ion> _ions;

  @override
  void paint(Canvas canvas, Size size) {
    final rush = flowSpeed.clamp(0.0, 1.3);
    if (rush < 0.02) return;

    final active =
        (_ions.length * (0.4 + rush * 0.5)).round().clamp(6, _ions.length);

    for (var i = 0; i < active; i++) {
      final ion = _ions[i];
      var x = (ion.x + distance * 0.12 * math.cos(ion.dir)) % 1.0;
      var y = (ion.y + distance * 0.35 * (0.5 + 0.5 * math.sin(ion.dir))) % 1.0;
      if (x < 0) x += 1;
      if (y < 0) y += 1;
      final p = Offset(x * size.width, y * size.height);
      final trailLen = 8 + rush * 18;
      final trail = Offset(
        p.dx - math.cos(ion.dir) * trailLen,
        p.dy - math.sin(ion.dir) * trailLen,
      );
      canvas.drawLine(
        trail,
        p,
        Paint()
          ..strokeWidth = ion.size
          ..strokeCap = StrokeCap.round
          ..color = ion.color.withValues(alpha: 0.22 + rush * 0.4),
      );
      canvas.drawCircle(
        p,
        ion.size * 0.75,
        Paint()
          ..color = ion.color.withValues(alpha: 0.45 + rush * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    if (rush > 0.5 && math.sin(distance * 9) > 0.96) {
      final r = math.Random((distance * 8).floor());
      final a =
          Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final b = a +
          Offset((r.nextDouble() - 0.5) * 100, (r.nextDouble() - 0.5) * 70);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 1.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant IonStormPainter oldDelegate) {
    return oldDelegate.distance != distance ||
        oldDelegate.flowSpeed != flowSpeed;
  }
}

class _Ion {
  _Ion(this.x, this.y, this.dir, this.size, this.color);
  final double x;
  final double y;
  final double dir;
  final double size;
  final Color color;
}