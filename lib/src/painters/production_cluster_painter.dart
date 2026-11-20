import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../models/cluster_spec.dart';
import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/dash_units.dart';
import '../models/gear.dart';

part 'cluster_templates.dart';

/// Colors of a round gauge.
class _DialLook {
  const _DialLook({
    required this.faceA,
    required this.faceB,
    required this.ink,
    required this.needle,
    this.rim = const Color(0xFF73777B),
  });

  final Color faceA;
  final Color faceB;
  final Color ink;
  final Color needle;
  final Color rim;
}

const _darkLook = _DialLook(
  faceA: Color(0xFF202327),
  faceB: Color(0xFF090B0D),
  ink: Color(0xFFF0F2F3),
  needle: Color(0xFFF3483C),
);
const _yellowLook = _DialLook(
  faceA: Color(0xFFFFE55B),
  faceB: Color(0xFFE0AD22),
  ink: Color(0xFF171A1C),
  needle: Color(0xFFB71F23),
);

/// Canvas dimensions are design coordinates; all features scale uniformly.
class ProductionClusterPainter extends CustomPainter {
  ProductionClusterPainter({
    required this.telemetry,
    required this.style,
    required this.speed,
    required this.rpm,
    this.units = DashUnits.metric,
    this.showBrandWordmark = true,
    this.roadPhase = 0,
  });

  /// Scroll phase (0..1 cycles) of the road lane dividers.
  final double roadPhase;

  final DashTelemetry telemetry;
  final DashStyle style;
  final double speed;
  final double rpm;
  final DashUnits units;

  /// Draws the text wordmark; disabled when the host supplies its own badge.
  final bool showBrandWordmark;

  String _dist(double km, {int decimals = 0}) =>
      '${units.distanceValue(km).toStringAsFixed(decimals)} '
      '${units.distanceLabel}';

  String _temp(double c, {int decimals = 0}) =>
      '${units.temperatureValue(c).toStringAsFixed(decimals)} '
      '${units.temperatureLabel}';
  static const white = Color(0xFFF0F2F3);
  static const muted = Color(0xFF8A929A);
  static const red = Color(0xFFF3483C);
  static const green = Color(0xFF68DCA0);
  static const amber = Color(0xFFF5B34D);
  static const blue = Color(0xFF78BDF4);
  late Canvas _c;
  bool get _moto => style.isMotorcycle;
  double get _width => _moto ? 900 : 1200;
  double get _height => _moto ? 520 : 480;
  String get _gear =>
      telemetry.gear == Gear.drive &&
          (style == DashStyle.racing ||
              style == DashStyle.motoFuelTft ||
              style == DashStyle.motoFuelHybrid ||
              (style.isBrand && !style.isElectric)) &&
          telemetry.gearNumber != null
      ? '${telemetry.gearNumber}'
      : telemetry.gear.label;
  double get _maxRpm => math.max(1000, telemetry.maxRpm);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _c = canvas;
    _c.save();
    _c.scale(size.width / _width, size.height / _height);
    _shell();
    switch (style) {
      case DashStyle.classic:
        _classic();
      case DashStyle.racing:
        _racing();
      case DashStyle.carEvTesla:
        _tesla();
      case DashStyle.carEvNio:
        _nio();
      case DashStyle.carEvLi:
        _li();
      case DashStyle.motoFuelTft:
        _tft();
      case DashStyle.motoFuelHybrid:
        _hybrid();
      case DashStyle.motoEvNiu:
        _scooter(false);
      case DashStyle.motoEvYadea:
        _scooter(true);
      default:
        final spec = style.spec;
        if (spec != null) _paintSpec(spec);
    }
    _c.restore();
  }

  void _shell() {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _width, _height),
      Radius.circular(_moto ? 48 : 30),
    );
    _c.drawRRect(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, _height),
          const [Color(0xFF43464A), Color(0xFF121416), Color(0xFF292C30)],
          const [0, 0.12, 1],
        ),
    );
    final inner = outer.deflate(_moto ? 14 : 9);
    _c.drawRRect(inner, Paint()..color = const Color(0xFF080A0C));
    _c.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF505257),
    );
  }

  void _text(
    String value,
    double x,
    double y,
    double size, {
    Color color = white,
    FontWeight weight = FontWeight.w400,
    bool center = false,
    double spacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontFeatures: const [ui.FontFeature.tabularFigures()],
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.05,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(_c, Offset(x - (center ? painter.width / 2 : 0), y));
    painter.dispose();
  }

  void _line(
    double x1,
    double y1,
    double x2,
    double y2,
    Color color, [
    double width = 1,
  ]) {
    _c.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _box(
    double x,
    double y,
    double w,
    double h,
    Color color, {
    double radius = 0,
  }) {
    _c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
  }

  Offset _polar(Offset c, double radius, double angle) =>
      c + Offset(math.cos(angle), math.sin(angle)) * radius;

  void _arc(
    Offset c,
    double radius,
    double start,
    double sweep,
    Color color,
    double width,
  ) {
    _c.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _dial(
    Offset center,
    double radius, {
    required double value,
    required double max,
    required int divisions,
    required String unit,
    double labelScale = 1,
    bool yellow = false,
    double? redline,
    _DialLook? look,
  }) {
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final face = look ?? (yellow ? _yellowLook : _darkLook);
    _c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-radius * 0.2, -radius * 0.3),
          radius * 1.4,
          [face.faceA, face.faceB],
        ),
    );
    _c.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = face.rim,
    );
    _c.drawCircle(
      center,
      radius - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF303439),
    );
    final ink = face.ink;
    if (redline != null && redline < max) {
      final fraction = (redline / max).clamp(0.0, 1.0);
      _arc(
        center,
        radius * 0.9,
        start + sweep * fraction,
        sweep * (1 - fraction),
        red,
        radius * 0.07,
      );
    }
    for (var i = 0; i <= divisions * 5; i++) {
      final major = i % 5 == 0;
      final fraction = i / (divisions * 5);
      final angle = start + sweep * fraction;
      final a = _polar(center, radius * 0.9, angle);
      final b = _polar(center, radius * (major ? 0.78 : 0.85), angle);
      final color = redline != null && fraction * max >= redline ? red : ink;
      _line(a.dx, a.dy, b.dx, b.dy, color, major ? 2.8 : 1.1);
      if (major) {
        final p = _polar(center, radius * 0.65, angle);
        _text(
          (fraction * max / labelScale).round().toString(),
          p.dx,
          p.dy - radius * 0.065,
          radius * (divisions > 10 ? 0.105 : 0.13),
          center: true,
          color: color,
          weight: FontWeight.w500,
        );
      }
    }
    _text(
      unit,
      center.dx,
      center.dy - radius * 0.35,
      radius * 0.075,
      center: true,
      color: ink,
    );
    final angle = start + sweep * (value / max).clamp(0.0, 1.0);
    _c.save();
    _c.translate(center.dx, center.dy);
    _c.rotate(angle);
    final needle = Path()
      ..moveTo(radius * 0.82, 0)
      ..lineTo(-radius * 0.16, -3)
      ..lineTo(-radius * 0.16, 3)
      ..close();
    _c.drawPath(
      needle.shift(const Offset(1, 3)),
      Paint()..color = const Color(0x66000000),
    );
    _c.drawPath(needle, Paint()..color = face.needle);
    _c.restore();
    _c.drawCircle(
      center,
      radius * 0.09,
      Paint()
        ..shader = ui.Gradient.linear(
          center.translate(0, -15),
          center.translate(0, 15),
          const [Color(0xFF53575B), Color(0xFF141619)],
        ),
    );
    _c.drawCircle(
      center,
      radius * 0.065,
      Paint()..color = const Color(0xFF101214),
    );
  }

  void _status(double y, {double width = 1200}) {
    if (telemetry.leftIndicator) {
      _icon(Icons.arrow_back, 70, y, green, 24);
    }
    if (telemetry.rightIndicator) {
      _icon(Icons.arrow_forward, width - 90, y, green, 24);
    }
    if (telemetry.highBeam) _headlamp(width / 2 - 65, y);
    if (telemetry.parkingBrake) _text('(P)', width / 2 - 20, y, 21, color: red);
    if (telemetry.engineWarning) {
      final x = width / 2 + 45;
      final engine = Path()
        ..moveTo(x, y + 6)
        ..lineTo(x + 7, y + 6)
        ..lineTo(x + 7, y + 2)
        ..lineTo(x + 17, y + 2)
        ..lineTo(x + 17, y + 6)
        ..lineTo(x + 24, y + 6)
        ..lineTo(x + 24, y + 20)
        ..lineTo(x + 4, y + 20)
        ..lineTo(x, y + 15)
        ..close();
      _c.drawPath(
        engine,
        Paint()
          ..color = amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _line(x - 4, y + 7, x - 4, y + 17, amber, 2);
    }
    _telltales(y, width);
  }

  void _headlamp(double x, double y) {
    final lamp = Path()
      ..moveTo(x + 15, y + 2)
      ..quadraticBezierTo(x + 34, y + 12, x + 15, y + 22)
      ..close();
    _c.drawPath(
      lamp,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 4; i++) {
      _line(x, y + 3 + i * 6, x + 10, y + 3 + i * 6, blue, 2);
    }
  }

  void _icon(IconData icon, double x, double y, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(_c, Offset(x, y));
    tp.dispose();
  }

  void _footer({Color color = muted, double y = 435}) {
    _line(55, y - 14, _width - 55, y - 14, const Color(0xFF30353A));
    _text(
      'ODO  ${_dist(telemetry.odometerKm, decimals: 1)}',
      60,
      y,
      17,
      color: color,
    );
    _text(
      _temp(telemetry.outsideTempC, decimals: 1),
      _width / 2,
      y,
      17,
      center: true,
      color: color,
    );
    _text(
      'RANGE  ${_dist(telemetry.rangeKm)}',
      _width - 255,
      y,
      17,
      color: color,
    );
  }

  void _level(
    double x,
    double y,
    double width,
    double percent, {
    Color color = white,
    bool battery = false,
    Color track = const Color(0xFF30363B),
  }) {
    if (battery) {
      _box(x, y - 2, width, 14, track, radius: 2);
      _box(
        x + 3,
        y + 1,
        (width - 6) * (percent / 100).clamp(0, 1),
        8,
        percent <= 15 ? amber : color,
        radius: 1,
      );
      _box(x + width, y + 2, 3, 6, track);
    } else {
      for (var i = 0; i < 12; i++) {
        _box(
          x + i * width / 12,
          y,
          width / 12 - 4,
          9,
          i / 12 < (percent / 100).clamp(0, 1)
              ? (percent <= 15 ? amber : color)
              : track,
        );
      }
    }
  }

  void _speed(double x, double y, {double size = 98, Color color = white}) {
    final over = telemetry.speedLimitKmh > 0 && speed > telemetry.speedLimitKmh;
    _text(
      units.speedValue(speed.abs()).round().toString(),
      x,
      y,
      size,
      center: true,
      color: over ? red : color,
      weight: FontWeight.w500,
    );
    _text(units.speedLabel, x, y + size + 3, 19, center: true, color: muted);
  }

  void _classic() {
    _status(32);
    final mph = units.speed == SpeedUnit.mph;
    _dial(
      const Offset(276, 231),
      180,
      value: units.speedValue(speed),
      max: mph ? 160 : 260,
      divisions: mph ? 16 : 13,
      unit: units.speedLabel,
    );
    _dial(
      const Offset(924, 231),
      180,
      value: rpm,
      max: _maxRpm,
      divisions: 8,
      unit: '1/min × 1000',
      labelScale: 1000,
      redline: telemetry.redlineRpm,
    );
    _text(
      telemetry.driveMode ?? 'COMFORT',
      600,
      80,
      18,
      center: true,
      spacing: 2,
    );
    _speed(600, 146, size: 68);
    _text(_gear, 600, 268, 40, center: true);
    _line(500, 329, 700, 329, const Color(0xFF41464B));
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      600,
      345,
      18,
      center: true,
      color: muted,
    );
    _text('E', 155, 363, 13, color: muted);
    _level(177, 369, 195, telemetry.fuelPercent);
    _text('F', 382, 363, 13, color: muted);
    _text(
      _temp(telemetry.coolantTempC),
      924,
      365,
      18,
      center: true,
      color: muted,
    );
    _footer();
  }

  void _racing() {
    _status(28);
    _dial(
      const Offset(600, 232),
      184,
      value: rpm,
      max: _maxRpm,
      divisions: 8,
      unit: 'RPM × 1000',
      labelScale: 1000,
      yellow: true,
      redline: telemetry.redlineRpm,
    );
    _text(
      _gear,
      600,
      298,
      56,
      center: true,
      color: const Color(0xFF16191C),
      weight: FontWeight.w600,
    );
    _text(
      telemetry.driveMode ?? 'SPORT',
      160,
      85,
      22,
      color: amber,
      spacing: 3,
    );
    _text('ENGINE', 160, 145, 15, color: muted);
    _text(_temp(telemetry.coolantTempC), 160, 175, 37);
    _text('FUEL', 160, 256, 15, color: muted);
    _level(160, 292, 180, telemetry.fuelPercent, color: amber);
    _text('${telemetry.fuelPercent.round()} %', 160, 318, 24);
    _speed(966, 143, size: 100);
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      966,
      324,
      18,
      center: true,
      color: muted,
    );
    for (var i = 0; i < 9; i++) {
      final lit = rpm / math.max(1, telemetry.redlineRpm) > 0.65 + i * 0.04;
      _box(
        482 + i * 27,
        28,
        20,
        6,
        lit ? (i > 5 ? red : green) : const Color(0xFF292C30),
        radius: 2,
      );
    }
    _footer();
  }

  void _road(
    double x,
    double y,
    double width,
    double height, {
    Color lane = muted,
  }) {
    final road = Path()
      ..moveTo(x + width * 0.43, y)
      ..lineTo(x + width * 0.57, y)
      ..lineTo(x + width, y + height)
      ..lineTo(x, y + height)
      ..close();
    _c.drawPath(
      road,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x, y + height),
          const [Color(0xFF10151A), Color(0xFF242C33)],
        ),
    );
    _line(x + width * 0.43, y, x, y + height, lane, 2);
    _line(x + width * 0.57, y, x + width, y + height, lane, 2);
    final cx = x + width / 2;
    // Scrolling lane dividers (perspective) driven by [roadPhase].
    _c.save();
    _c.clipPath(road);
    const dashes = 7;
    for (var i = 0; i < dashes; i++) {
      final s0 = ((roadPhase + i / dashes) % 1.0);
      final s1 = s0 + 0.045;
      final f0 = s0 * s0;
      final f1 = math.min(1.0, s1 * s1);
      if (f1 <= f0) continue;
      for (final u in const [-1 / 3, 1 / 3]) {
        final hw0 = width * (0.07 + 0.43 * f0);
        final hw1 = width * (0.07 + 0.43 * f1);
        _line(
          cx + u * hw0,
          y + height * f0,
          cx + u * hw1,
          y + height * f1,
          lane.withValues(alpha: 0.25 + 0.6 * f1),
          0.8 + 3.2 * f1,
        );
      }
    }
    _c.restore();
    final cy = y + height * 0.71;
    final braking = telemetry.powerPercent < -20;
    // Soft ground glow under the ego vehicle.
    _c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: 96, height: 120),
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy + 4), 60, [
          lane.withValues(alpha: 0.22),
          lane.withValues(alpha: 0),
        ]),
    );
    final car = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 52, height: 91),
      const Radius.circular(14),
    );
    _c.drawShadow(Path()..addRRect(car), Colors.black, 8, true);
    _c.drawRRect(
      car,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 26, cy),
          Offset(cx + 26, cy),
          const [Color(0xFF7F8A95), Color(0xFFE0E5E8), Color(0xFF66727D)],
          const [0, 0.5, 1],
        ),
    );
    _box(cx - 19, cy - 26, 38, 23, const Color(0xFF263441), radius: 5);
    _box(cx - 18, cy + 19, 36, 13, const Color(0xFF263441), radius: 4);
    _box(cx - 22, cy + 35, 11, braking ? 5 : 3, red, radius: 1);
    _box(cx + 11, cy + 35, 11, braking ? 5 : 3, red, radius: 1);
    if (braking) {
      _c.drawRect(
        Rect.fromLTWH(cx - 28, cy + 36, 56, 14),
        Paint()
          ..color = red.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _energy(double x, double y, {Color accent = green}) {
    _level(
      x,
      y + 5,
      80,
      telemetry.batteryPercent,
      color: accent,
      battery: true,
    );
    _text('${telemetry.batteryPercent.round()}%', x + 96, y, 18, color: accent);
    _text(_dist(telemetry.rangeKm), x, y + 38, 27);
  }

  void _tesla() {
    _status(30);
    _text('P   R   N   D', 145, 69, 18, color: muted, spacing: 3);
    _text(_gear, 145, 108, 26);
    _speed(262, 156, size: 108);
    _energy(180, 335);
    _road(465, 123, 345, 267);
    _text('MODEL S', 636, 71, 17, center: true, spacing: 4, color: muted);
    _text('TRIP', 928, 132, 16, color: muted, spacing: 2);
    _text(
      units.distanceValue(telemetry.tripKm).toStringAsFixed(1),
      928,
      166,
      43,
    );
    _text(units.distanceLabel, 928, 219, 17, color: muted);
    _text('TIRE PRESSURE · ${units.pressureLabel}', 928, 285, 14, color: muted);
    final p = telemetry.tirePressures;
    _text(
      '${units.pressureText(p.frontLeft)}     '
      '${units.pressureText(p.frontRight)}',
      935,
      317,
      22,
    );
    _text(
      '${units.pressureText(p.rearLeft)}     '
      '${units.pressureText(p.rearRight)}',
      935,
      355,
      22,
    );
    _footer();
  }

  void _nio() {
    _status(28);
    _text('ET7  /  DRIVE', 80, 72, 16, color: muted, spacing: 2);
    _speed(262, 147, size: 108);
    _text(_gear, 410, 214, 32);
    _road(498, 134, 260, 250, lane: const Color(0xFF566675));
    _text('TRIP DISTANCE', 874, 114, 16, color: muted, spacing: 2);
    _text(_dist(telemetry.tripKm, decimals: 1), 874, 149, 38);
    _text('REMAINING RANGE', 874, 236, 16, color: muted, spacing: 2);
    _text('${telemetry.rangeKm.round()}', 874, 268, 53);
    _text(units.distanceLabel, 1027, 302, 18, color: muted);
    _level(93, 361, 270, telemetry.batteryPercent, color: blue);
    _text('${telemetry.batteryPercent.round()}%', 380, 351, 22, color: blue);
    _footer();
  }

  void _li() {
    _status(27);
    _text('L9', 70, 74, 19, color: muted, spacing: 3);
    _speed(220, 158, size: 100);
    _text(_gear, 365, 220, 30);
    _line(442, 95, 442, 385, const Color(0xFF30363B));
    _road(500, 132, 260, 249);
    _text('VEHICLE', 900, 105, 16, color: muted, spacing: 3);
    _energy(900, 163, accent: const Color(0xFFB9D6CF));
    _text('TRIP', 900, 286, 15, color: muted);
    _text(_dist(telemetry.tripKm, decimals: 1), 900, 317, 32);
    _footer();
  }

  void _tft() {
    _text('TOTAL  ${_dist(telemetry.odometerKm)}', 62, 43, 18, color: muted);
    _text('ROAD', 780, 43, 21, center: true, spacing: 2);
    _status(84, width: 900);
    final path = Path()
      ..moveTo(65, 240)
      ..lineTo(155, 150)
      ..lineTo(735, 150);
    _c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF30363C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24,
    );
    final fraction = (rpm / _maxRpm).clamp(0.0, 1.0);
    final metric = path.computeMetrics().first;
    _c.drawPath(
      metric.extractPath(0, metric.length * fraction),
      Paint()
        ..color = rpm >= telemetry.redlineRpm ? red : white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24,
    );
    for (var i = 0; i <= 8; i++) {
      final x = 155 + i * 72.5;
      _line(
        x,
        130,
        x,
        160,
        i * _maxRpm / 8 >= telemetry.redlineRpm ? red : muted,
        2,
      );
      _text((i * _maxRpm / 8000).round().toString(), x, 106, 18, center: true);
    }
    _text('RPM × 1000', 160, 184, 14, color: muted);
    _speed(380, 226, size: 132);
    _text('GEAR', 733, 235, 16, center: true, color: muted);
    _text(
      _gear,
      733,
      269,
      100,
      center: true,
      color: telemetry.gear == Gear.neutral ? green : white,
    );
    _level(82, 418, 180, telemetry.fuelPercent);
    _text('FUEL', 82, 438, 13, color: muted);
    _text(_temp(telemetry.coolantTempC), 733, 418, 24, center: true);
    _footer(y: 479);
  }

  void _hybrid() {
    _dial(
      const Offset(260, 258),
      204,
      value: rpm,
      max: _maxRpm,
      divisions: 8,
      unit: 'RPM × 1000',
      labelScale: 1000,
      redline: telemetry.redlineRpm,
    );
    _box(491, 115, 342, 290, const Color(0xFFB7C5AD), radius: 9);
    const ink = Color(0xFF26342B);
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      518,
      139,
      18,
      color: ink,
    );
    _segments(
      units.speedValue(speed.abs()).round().toString().padLeft(3, ' '),
      529,
      191,
      58,
      ink,
      const Color(0xFFADBEA6),
    );
    _text(units.speedLabel, 745, 274, 16, color: ink);
    _line(516, 311, 811, 311, ink);
    _text('GEAR', 516, 335, 14, color: ink);
    _text(_gear, 583, 326, 40, color: ink);
    _level(
      655,
      346,
      140,
      telemetry.fuelPercent,
      color: ink,
      track: const Color(0xFF9DAF98),
    );
    _status(59, width: 900);
    _footer(y: 479);
  }

  // Seven-segment numerals have consistent physical segment geometry.
  void _segments(
    String value,
    double x,
    double y,
    double width,
    Color ink,
    Color off,
  ) {
    const patterns = [
      0x3f,
      0x06,
      0x5b,
      0x4f,
      0x66,
      0x6d,
      0x7d,
      0x07,
      0x7f,
      0x6f,
    ];
    final h = width * 1.78;
    final thick = width * 0.12;
    for (var n = 0; n < value.length; n++) {
      final digit = int.tryParse(value[n]);
      final mask = digit == null ? 0 : patterns[digit];
      final dx = x + n * width * 1.19;
      final bars = [
        Rect.fromLTWH(dx + thick, y, width - thick * 2, thick),
        Rect.fromLTWH(
          dx + width - thick,
          y + thick,
          thick,
          h / 2 - thick * 1.5,
        ),
        Rect.fromLTWH(
          dx + width - thick,
          y + h / 2 + thick / 2,
          thick,
          h / 2 - thick * 1.5,
        ),
        Rect.fromLTWH(dx + thick, y + h - thick, width - thick * 2, thick),
        Rect.fromLTWH(dx, y + h / 2 + thick / 2, thick, h / 2 - thick * 1.5),
        Rect.fromLTWH(dx, y + thick, thick, h / 2 - thick * 1.5),
        Rect.fromLTWH(
          dx + thick,
          y + h / 2 - thick / 2,
          width - thick * 2,
          thick,
        ),
      ];
      for (var i = 0; i < bars.length; i++) {
        _c.drawRRect(
          RRect.fromRectAndRadius(bars[i], Radius.circular(thick * 0.18)),
          Paint()..color = mask & (1 << i) != 0 ? ink : off,
        );
      }
    }
  }

  void _scooter(bool yadea) {
    final ink = yadea ? const Color(0xFF222F29) : const Color(0xFFE6F2EE);
    final dim = yadea ? const Color(0xFF718474) : const Color(0xFF6C8580);
    final screen = yadea ? const Color(0xFFB6C6AC) : const Color(0xFF0B1717);
    _box(37, 36, 826, 448, screen, radius: yadea ? 65 : 28);
    _text(
      yadea ? 'YADEA' : 'NIU',
      95,
      66,
      27,
      color: ink,
      weight: FontWeight.w600,
      spacing: 3,
    );
    _text('ELECTRIC', 775, 77, 14, center: true, color: dim, spacing: 2);
    _text(
      telemetry.gear == Gear.park ? 'P' : _gear,
      150,
      174,
      56,
      center: true,
      color: ink,
    );
    _segments(
      units.speedValue(speed.abs()).round().toString().padLeft(3, ' '),
      271,
      139,
      92,
      ink,
      yadea ? const Color(0xFFA9BBA1) : const Color(0xFF122423),
    );
    _text(units.speedLabel, 686, 280, 20, color: ink);
    _line(94, 346, 806, 346, dim);
    _level(
      105,
      378,
      190,
      telemetry.batteryPercent,
      color: ink,
      battery: true,
      track: yadea ? const Color(0xFF94A68E) : const Color(0xFF2A403C),
    );
    _text('${telemetry.batteryPercent.round()}%', 315, 371, 27, color: ink);
    _text(_dist(telemetry.rangeKm), 680, 371, 27, color: ink, center: true);
    _text(
      'ODO  ${_dist(telemetry.odometerKm, decimals: 1)}',
      105,
      436,
      19,
      color: ink,
    );
    _text(
      _temp(telemetry.outsideTempC, decimals: 1),
      735,
      436,
      19,
      color: ink,
      center: true,
    );
    if (telemetry.leftIndicator) _icon(Icons.arrow_back, 208, 72, green, 24);
    if (telemetry.rightIndicator) {
      _icon(Icons.arrow_forward, 645, 72, green, 24);
    }
    if (telemetry.highBeam) _headlamp(442, 73);
    _telltales(100, 900);
  }

  @override
  bool shouldRepaint(covariant ProductionClusterPainter oldDelegate) =>
      telemetry != oldDelegate.telemetry ||
      style != oldDelegate.style ||
      speed != oldDelegate.speed ||
      rpm != oldDelegate.rpm ||
      units != oldDelegate.units ||
      roadPhase != oldDelegate.roadPhase ||
      showBrandWordmark != oldDelegate.showBrandWordmark;
}
