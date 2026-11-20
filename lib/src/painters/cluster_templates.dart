part of 'production_cluster_painter.dart';

const _white = ProductionClusterPainter.white;
const _muted = ProductionClusterPainter.muted;
const _red = ProductionClusterPainter.red;
const _green = ProductionClusterPainter.green;
const _amber = ProductionClusterPainter.amber;

/// Data-driven templates used by the brand themes ([ClusterSpecs]).
extension _SpecTemplates on ProductionClusterPainter {
  void _paintSpec(ClusterSpec spec) {
    _specScreen(spec);
    switch (spec.layout) {
      case ClusterLayout.twinDial:
        _twinDial(spec);
      case ClusterLayout.centerDial:
        _centerDial(spec);
      case ClusterLayout.virtualCockpit:
        _virtualCockpit(spec);
      case ClusterLayout.evSplit:
        _evSplit(spec);
      case ClusterLayout.evStrip:
        _evStrip(spec);
      case ClusterLayout.motoTft:
        _motoTft(spec);
      case ClusterLayout.motoSpeedo:
        _motoSpeedo(spec);
      case ClusterLayout.motoEvTft:
        _motoEvTft(spec);
    }
  }

  _DialLook _look(ClusterSpec s) => _DialLook(
    faceA: s.faceDark,
    faceB: s.faceLight,
    ink: s.ink,
    needle: s.needle,
    rim: s.rim,
  );

  void _specScreen(ClusterSpec spec) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _width, _height),
      Radius.circular(_moto ? 48 : 30),
    );
    _c.drawRRect(outer.deflate(_moto ? 14 : 9), Paint()..color = spec.screen);
  }

  /// Speed gauge scale in the active unit: (full scale, major divisions).
  (double, int) _speedScale(ClusterSpec spec) {
    if (units.speed == SpeedUnit.kmh) {
      return (spec.speedMax, spec.speedDivisions);
    }
    final step = spec.speedMax <= 200 ? 10.0 : 20.0;
    final max = (spec.speedMax / 1.609344 / step).ceil() * step;
    return (max, (max / step).round());
  }

  void _brand(
    ClusterSpec spec,
    double x,
    double y, {
    double size = 20,
    Color color = _white,
  }) {
    if (!showBrandWordmark) return;
    final text = spec.model.isEmpty
        ? spec.brand
        : '${spec.brand}  ${spec.model}';
    _text(
      text,
      x,
      y,
      size,
      center: true,
      color: color,
      weight: spec.brandWeight,
      spacing: spec.brandSpacing,
    );
  }

  double _chip(String label, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 12;
    _c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 20),
        const Radius.circular(4),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    tp.paint(_c, Offset(x + 6, y + (20 - tp.height) / 2));
    tp.dispose();
    return w;
  }

  /// ABS, belt, door, traction, battery, charging and cruise telltales.
  void _telltales(double y, double width) {
    final t = telemetry;
    final left = <(String, Color)>[
      if (t.absWarning) ('ABS', _amber),
      if (t.seatbeltWarning) ('BELT', _red),
      if (t.doorOpen) ('DOOR', _red),
      if (t.tractionControlOff) ('TC OFF', _amber),
    ];
    final right = <(String, Color)>[
      if (t.batteryWarning) ('BATT', _red),
      if (t.charging) ('CHG', _green),
      if (t.cruiseActive) ('CRUISE', _green),
    ];
    var x = 110.0;
    for (final item in left) {
      x += _chip(item.$1, x, y + 2, item.$2) + 8;
    }
    x = width / 2 + 90;
    for (final item in right) {
      x += _chip(item.$1, x, y + 2, item.$2) + 8;
    }
  }

  // ---- Cars -------------------------------------------------------------

  void _twinDial(ClusterSpec spec) {
    final look = _look(spec);
    final (max, divisions) = _speedScale(spec);
    _status(32);
    _dial(
      const Offset(276, 231),
      180,
      value: units.speedValue(speed),
      max: max,
      divisions: divisions,
      unit: units.speedLabel,
      look: look,
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
      look: look,
    );
    _brand(spec, 600, 60, size: 18);
    _line(530, 86, 670, 86, spec.accent, 3);
    _text(
      telemetry.driveMode ?? 'DRIVE',
      600,
      94,
      15,
      center: true,
      color: spec.accent,
      spacing: 2,
    );
    _speed(600, 124, size: 66);
    _text(_gear, 600, 262, 40, center: true);
    _line(500, 329, 700, 329, const Color(0xFF41464B));
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      600,
      345,
      18,
      center: true,
      color: _muted,
    );
    _text('E', 155, 363, 13, color: _muted);
    _level(177, 369, 195, telemetry.fuelPercent, color: spec.accent);
    _text('F', 382, 363, 13, color: _muted);
    _text(
      _temp(telemetry.coolantTempC),
      924,
      365,
      18,
      center: true,
      color: _muted,
    );
    _footer();
  }

  void _centerDial(ClusterSpec spec) {
    final look = _look(spec);
    _status(28);
    _dial(
      const Offset(600, 232),
      184,
      value: rpm,
      max: _maxRpm,
      divisions: 8,
      unit: 'RPM × 1000',
      labelScale: 1000,
      redline: telemetry.redlineRpm,
      look: look,
    );
    _text(
      _gear,
      600,
      298,
      56,
      center: true,
      color: look.ink,
      weight: FontWeight.w600,
    );
    _brand(spec, 600, 372, size: 16);
    _text(
      telemetry.driveMode ?? 'SPORT',
      160,
      85,
      22,
      color: spec.accent,
      spacing: 3,
    );
    _text('ENGINE', 160, 145, 15, color: _muted);
    _text(_temp(telemetry.coolantTempC), 160, 175, 37);
    _text('FUEL', 160, 256, 15, color: _muted);
    _level(160, 292, 180, telemetry.fuelPercent, color: spec.accent);
    _text('${telemetry.fuelPercent.round()} %', 160, 318, 24);
    _speed(966, 143, size: 100);
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      966,
      324,
      18,
      center: true,
      color: _muted,
    );
    for (var i = 0; i < 9; i++) {
      final lit = rpm / math.max(1, telemetry.redlineRpm) > 0.65 + i * 0.04;
      _box(
        482 + i * 27,
        28,
        20,
        6,
        lit ? (i > 5 ? _red : spec.accent) : const Color(0xFF292C30),
        radius: 2,
      );
    }
    _footer();
  }

  void _ring(
    Offset c,
    double r, {
    required double fraction,
    required Color color,
    required double max,
    required int divisions,
    double labelScale = 1,
    double? redline,
  }) {
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    const track = Color(0xFF1E2328);
    _arc(c, r, start, sweep, track, 16);
    final f = fraction.clamp(0.0, 1.0);
    if (f > 0) {
      if (redline != null && redline < max) {
        final split = (redline / max).clamp(0.0, 1.0);
        _arc(c, r, start, sweep * math.min(f, split), color, 16);
        if (f > split) {
          _arc(c, r, start + sweep * split, sweep * (f - split), _red, 16);
        }
      } else {
        _arc(c, r, start, sweep * f, color, 16);
      }
    }
    for (var i = 0; i <= divisions; i++) {
      final a = start + sweep * i / divisions;
      final p1 = _polar(c, r + 14, a);
      final p2 = _polar(c, r + 22, a);
      _line(p1.dx, p1.dy, p2.dx, p2.dy, _muted, 2);
      final p = _polar(c, r + 38, a);
      _text(
        (max * i / divisions / labelScale).round().toString(),
        p.dx,
        p.dy - 8,
        14,
        center: true,
        color: _muted,
      );
    }
  }

  void _virtualCockpit(ClusterSpec spec) {
    final (max, divisions) = _speedScale(spec);
    _status(28);
    const left = Offset(250, 232);
    const right = Offset(950, 232);
    _ring(
      left,
      136,
      fraction: units.speedValue(speed) / max,
      color: spec.accent,
      max: max,
      divisions: divisions,
    );
    _ring(
      right,
      136,
      fraction: rpm / _maxRpm,
      color: spec.accent,
      max: _maxRpm,
      divisions: 8,
      labelScale: 1000,
      redline: telemetry.redlineRpm,
    );
    _speed(left.dx, 150, size: 84);
    _text(
      (rpm / 1000).toStringAsFixed(1),
      right.dx,
      168,
      60,
      center: true,
      weight: FontWeight.w500,
    );
    _text('×1000 RPM', right.dx, 236, 16, center: true, color: _muted);
    _text(_gear, right.dx, 268, 34, center: true, color: spec.accent);
    _brand(spec, 600, 52, size: 20);
    _text(
      telemetry.driveMode ?? 'COMFORT',
      600,
      82,
      14,
      center: true,
      color: spec.accent,
      spacing: 2,
    );
    _road(455, 112, 290, 268, lane: spec.accent.withValues(alpha: 0.6));
    _text('FUEL', 130, 385, 13, color: _muted);
    _level(130, 405, 160, telemetry.fuelPercent, color: spec.accent);
    _text(
      _temp(telemetry.coolantTempC),
      right.dx,
      392,
      18,
      center: true,
      color: _muted,
    );
    _footer();
  }

  void _evSplit(ClusterSpec spec) {
    _status(30);
    _text('P   R   N   D', 145, 69, 18, color: _muted, spacing: 3);
    _text(_gear, 145, 108, 26);
    _speed(262, 156, size: 108);
    _energy(180, 335, accent: spec.accent);
    if (telemetry.charging) {
      _text('CHARGING', 180, 305, 14, color: spec.accent, spacing: 2);
    }
    _road(465, 123, 345, 267, lane: spec.accent.withValues(alpha: 0.7));
    _brand(spec, 636, 71, size: 17);
    _text('TRIP', 928, 132, 16, color: _muted, spacing: 2);
    _text(
      units.distanceValue(telemetry.tripKm).toStringAsFixed(1),
      928,
      166,
      43,
    );
    _text(units.distanceLabel, 928, 219, 17, color: _muted);
    _text(
      'TIRE PRESSURE · ${units.pressureLabel}',
      928,
      285,
      14,
      color: _muted,
    );
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

  void _evStrip(ClusterSpec spec) {
    _status(30);
    _brand(spec, 600, 62, size: 18);
    // Power / regeneration bar: center is zero, regen grows to the left.
    const barX = 300.0;
    const barW = 600.0;
    _box(barX, 98, barW, 10, const Color(0xFF1E2328), radius: 5);
    final p = telemetry.powerPercent.clamp(-100.0, 100.0);
    final half = barW / 2;
    if (p >= 0) {
      _box(barX + half, 98, half * p / 100, 10, spec.accent, radius: 5);
    } else {
      final w = half * -p / 100;
      _box(barX + half - w, 98, w, 10, _green, radius: 5);
    }
    _line(barX + half, 92, barX + half, 114, _muted, 2);
    _text('REGEN', barX, 116, 12, color: _muted, spacing: 2);
    _text('POWER', barX + barW - 44, 116, 12, color: _muted, spacing: 2);
    _speed(600, 136, size: 128);
    _text(
      telemetry.driveMode ?? _gear,
      600,
      330,
      30,
      center: true,
      color: spec.accent,
      spacing: 2,
    );
    _text(_gear, 150, 140, 40);
    _energy(110, 285, accent: spec.accent);
    if (telemetry.charging) {
      _text('CHARGING', 110, 255, 14, color: spec.accent, spacing: 2);
    }
    _text('TRIP', 940, 250, 15, color: _muted, spacing: 2);
    _text(_dist(telemetry.tripKm, decimals: 1), 940, 272, 30);
    _text('TIRE · ${units.pressureLabel}', 940, 330, 14, color: _muted);
    final t = telemetry.tirePressures;
    _text(
      '${units.pressureText(t.frontLeft)}   ${units.pressureText(t.frontRight)}'
      '   ${units.pressureText(t.rearLeft)}   ${units.pressureText(t.rearRight)}',
      940,
      352,
      18,
    );
    _footer();
  }

  // ---- Motorcycles ------------------------------------------------------

  void _lean() {
    final lean = telemetry.leanAngleDeg;
    if (lean.abs() < 1) return;
    _text(
      'LEAN ${lean.abs().round()}° ${lean < 0 ? 'L' : 'R'}',
      733,
      392,
      18,
      center: true,
      color: _amber,
    );
  }

  void _motoTft(ClusterSpec spec) {
    _brand(spec, 450, 30, size: 20);
    _text('TOTAL  ${_dist(telemetry.odometerKm)}', 62, 43, 18, color: _muted);
    _text(
      telemetry.driveMode ?? 'ROAD',
      810,
      43,
      21,
      center: true,
      color: spec.accent,
      spacing: 2,
    );
    _status(66, width: 900);
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
        ..color = rpm >= telemetry.redlineRpm ? _red : spec.accent
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
        i * _maxRpm / 8 >= telemetry.redlineRpm ? _red : _muted,
        2,
      );
      _text((i * _maxRpm / 8000).round().toString(), x, 106, 18, center: true);
    }
    _text('RPM × 1000', 160, 184, 14, color: _muted);
    _speed(380, 226, size: 132);
    _text('GEAR', 733, 235, 16, center: true, color: _muted);
    _text(
      _gear,
      733,
      269,
      100,
      center: true,
      color: telemetry.gear == Gear.neutral ? _green : _white,
    );
    _lean();
    _level(82, 418, 180, telemetry.fuelPercent, color: spec.accent);
    _text('FUEL', 82, 438, 13, color: _muted);
    _text(_temp(telemetry.coolantTempC), 733, 418, 24, center: true);
    _footer(y: 479);
  }

  void _motoSpeedo(ClusterSpec spec) {
    final look = _look(spec);
    final (max, divisions) = _speedScale(spec);
    _status(24, width: 900);
    _dial(
      const Offset(290, 274),
      205,
      value: units.speedValue(speed),
      max: max,
      divisions: divisions,
      unit: units.speedLabel,
      look: look,
    );
    final over = telemetry.speedLimitKmh > 0 && speed > telemetry.speedLimitKmh;
    _text(
      units.speedValue(speed.abs()).round().toString(),
      290,
      352,
      58,
      center: true,
      color: over ? _red : look.ink,
      weight: FontWeight.w600,
    );
    const lcd = Color(0xFF12161A);
    _box(540, 104, 320, 340, lcd, radius: 14);
    _brand(spec, 700, 66, size: 18);
    _text('RPM', 565, 128, 13, color: _muted, spacing: 2);
    _box(565, 150, 270, 12, const Color(0xFF283038), radius: 4);
    final f = (rpm / _maxRpm).clamp(0.0, 1.0);
    _box(
      565,
      150,
      270 * f,
      12,
      rpm >= telemetry.redlineRpm ? _red : spec.accent,
      radius: 4,
    );
    _text('GEAR', 565, 188, 13, color: _muted, spacing: 2);
    _text(_gear, 565, 204, 84, weight: FontWeight.w600);
    _text(
      telemetry.driveMode ?? 'ROAD',
      830,
      212,
      18,
      color: spec.accent,
      spacing: 2,
    );
    _text('FUEL', 565, 318, 13, color: _muted, spacing: 2);
    _level(565, 340, 150, telemetry.fuelPercent, color: spec.accent);
    _text(_temp(telemetry.coolantTempC), 830, 330, 20);
    _text(
      'TRIP  ${_dist(telemetry.tripKm, decimals: 1)}',
      565,
      372,
      16,
      color: _muted,
    );
    _text(
      telemetry.leanAngleDeg.abs() >= 1
          ? 'LEAN ${telemetry.leanAngleDeg.abs().round()}°'
          : 'ODO  ${_dist(telemetry.odometerKm)}',
      565,
      402,
      16,
      color: telemetry.leanAngleDeg.abs() >= 1 ? _amber : _muted,
    );
  }

  void _motoEvTft(ClusterSpec spec) {
    _brand(spec, 450, 30, size: 20);
    _status(66, width: 900);
    const c = Offset(260, 290);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    _arc(c, 170, start, sweep, const Color(0xFF1E2328), 22);
    final p = telemetry.powerPercent.clamp(-100.0, 100.0);
    if (p != 0) {
      _arc(
        c,
        170,
        start,
        sweep * (p.abs() / 100),
        p >= 0 ? spec.accent : _green,
        22,
      );
    }
    _text(
      p < 0 ? 'REGEN' : 'POWER',
      c.dx,
      118,
      14,
      center: true,
      color: _muted,
    );
    _speed(c.dx, 170, size: 120);
    _text(
      'LEAN ${telemetry.leanAngleDeg.abs().round()}°',
      c.dx,
      420,
      16,
      center: true,
      color: telemetry.leanAngleDeg.abs() >= 1 ? _amber : _muted,
    );
    _text('BATTERY', 520, 110, 16, color: _muted, spacing: 2);
    _text(
      '${telemetry.batteryPercent.round()}%',
      520,
      132,
      70,
      color: telemetry.batteryPercent <= 15 ? _amber : spec.accent,
      weight: FontWeight.w600,
    );
    _box(520, 225, 320, 34, const Color(0xFF1E2328), radius: 6);
    _box(
      524,
      229,
      312 * (telemetry.batteryPercent / 100).clamp(0.0, 1.0),
      26,
      telemetry.batteryPercent <= 15 ? _amber : spec.accent,
      radius: 4,
    );
    if (telemetry.charging) {
      _text('CHARGING', 520, 266, 16, color: spec.accent, spacing: 2);
    }
    _text('RANGE', 520, 296, 16, color: _muted, spacing: 2);
    _text(_dist(telemetry.rangeKm), 520, 318, 46);
    _text(_gear, 780, 100, 56, center: true);
    _text(
      telemetry.driveMode ?? 'ECO',
      780,
      168,
      18,
      center: true,
      color: spec.accent,
      spacing: 2,
    );
    _footer(y: 479);
  }
}
