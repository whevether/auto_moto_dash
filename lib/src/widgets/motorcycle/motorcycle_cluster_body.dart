import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/gear.dart';
import '../../painters/analog_gauge_painter.dart';
import '../../painters/battery_bar_painter.dart';
import '../../painters/moto_tft_gauge_painter.dart';
import '../../painters/segmented_arc_painter.dart';
import '../shared/cluster_surface.dart';
import '../shared/mileage_range_strip.dart';

/// Motorcycle-specific cluster layouts matching reference dashboard screens.
class MotorcycleClusterBody extends StatefulWidget {
  const MotorcycleClusterBody({
    super.key,
    required this.telemetry,
    required this.style,
    this.dimForWeather = false,
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final bool dimForWeather;
  final ValueChanged<Gear>? onGearSelected;
  final VoidCallback? onGearPointerDown;

  @override
  State<MotorcycleClusterBody> createState() => _MotorcycleClusterBodyState();
}

class _MotorcycleClusterBodyState extends State<MotorcycleClusterBody>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SmoothedValue _speed;
  late final SmoothedValue _rpm;
  Duration _last = Duration.zero;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _speed = SmoothedValue(widget.telemetry.speedKmh, responsiveness: 12);
    _rpm = SmoothedValue(widget.telemetry.rpm, responsiveness: 14);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _phase = elapsed.inMilliseconds / 1000.0;
    _speed.tick(widget.telemetry.speedKmh, dt.clamp(0.0, 0.05));
    _rpm.tick(widget.telemetry.rpm, dt.clamp(0.0, 0.05));
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String get _gearLabel {
    final t = widget.telemetry;
    if (t.gearNumber != null) return '${t.gearNumber}';
    return t.gear == Gear.neutral ? 'N' : t.gear.label;
  }

  @override
  Widget build(BuildContext context) {
    return ClusterSurface(
      dimForWeather: widget.dimForWeather,
      baseColor: const Color(0xFF050505),
      child: SafeArea(
        child: switch (widget.style) {
          DashStyle.motoFuelTft => _buildFuelTft(),
          DashStyle.motoFuelHybrid => _buildFuelHybrid(),
          DashStyle.motoEvNiu => _buildEvNiu(),
          DashStyle.motoEvYadea => _buildEvYadea(),
          _ => _buildFuelTft(),
        },
      ),
    );
  }

  /// Image 1: full TFT — top RPM arc, speed right, fuel left, ODO/battery bottom.
  Widget _buildFuelTft() {
    final t = widget.telemetry;
    final speed = _speed.value.round();
    const maxRpm = 18000.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GEAR',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _gearLabel,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              CustomPaint(
                size: const Size(28, 44),
                painter: _GreenSlashPainter(),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'RAIN',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: CustomPaint(
                    painter: MotoTopRpmBarPainter(
                      rpm: _rpm.value.clamp(0, maxRpm),
                      maxRpm: maxRpm,
                      redlineFrom: 14000,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$speed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      Text(
                        'km/h',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 108,
                  child: Container(
                    height: 2,
                    color: const Color(0xFF00E676),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 120,
                  bottom: 0,
                  width: 28,
                  child: Column(
                    children: [
                      Text(
                        'F',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8,
                        ),
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: MotoFuelSegmentPainter(percent: t.fuelPercent),
                        ),
                      ),
                      Icon(
                        Icons.local_gas_station,
                        size: 14,
                        color: const Color(0xFFFF9800).withValues(alpha: 0.9),
                      ),
                      Text(
                        'E',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 40,
                  right: 8,
                  bottom: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ODO ${t.odometerKm.round()} km  ·  续航 ${t.rangeKm.round()} km',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'BATTERY ${(t.batteryPercent * 0.12 + 11).toStringAsFixed(1)} v',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${t.coolantTempC.round()}°C',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatClock(_phase),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Image 2: analog tach left + Kawasaki-style TFT right.
  Widget _buildFuelHybrid() {
    final t = widget.telemetry;
    final speed = _speed.value.round();
    const maxRpm = 16000.0;
    const gaugeStyle = AnalogGaugeStyle(theme: AnalogGaugeTheme.ferrari);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: AnalogGaugePainter(
                  value: _rpm.value.clamp(0, maxRpm),
                  min: 0,
                  max: maxRpm,
                  majorTickEvery: 2000,
                  labelBuilder: (v) => (v / 1000).round().toString(),
                  redlineFrom: 14000,
                  title: '',
                  unit: '×1000r/min',
                  style: gaugeStyle,
                  pulsePhase: _phase * 0.25,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: Container(
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TRIP A',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 8,
                          ),
                        ),
                        Text(
                          '${t.tripKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 28,
                    child: Text(
                      _gearLabel,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$speed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                        Text(
                          'km/h',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: CustomPaint(
                      size: const Size(36, 56),
                      painter: _MotoLeanGraphicPainter(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hybridTag('KEBC'),
                        const SizedBox(height: 2),
                        _hybridTag('KQS'),
                        const SizedBox(height: 2),
                        Text(
                          'KTRC 1',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '${t.coolantTempC.round()}°C',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 9,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      _formatClock(_phase),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: CustomPaint(
                      painter: _HybridRedAccentPainter(phase: _phase),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 12,
                    bottom: 14,
                    child: MileageRangeStrip(
                      telemetry: t,
                      compact: true,
                      fontSize: 8,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Image 3: NIU NXT — wide HUD, green V frame, top status bar.
  Widget _buildEvNiu() {
    final t = widget.telemetry;
    final speed = _speed.value.round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.arrow_back_ios, size: 14, color: const Color(0xFF00E676).withValues(alpha: 0.8)),
              const Spacer(),
              _niuStatusIcon(Icons.bluetooth, active: true),
              _niuStatusIcon(Icons.light_mode),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00E676)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'READY',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _niuStatusIcon(Icons.settings_input_antenna),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: const Color(0xFF00E676).withValues(alpha: 0.8)),
            ],
          ),
          const Spacer(),
          CustomPaint(
            foregroundPainter: _NiuVFramePainter(),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$speed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                      shadows: [
                        Shadow(color: Color(0xAA00E676), blurRadius: 20),
                      ],
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 14,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(t.batteryPercent * 0.88).round()} v',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 72,
                    height: 16,
                    child: CustomPaint(
                      painter: BatteryBarPainter(
                        percent: t.batteryPercent,
                        segments: 5,
                        activeColor: const Color(0xFF00E676),
                      ),
                    ),
                  ),
                  Text(
                    '${t.batteryPercent.round()}%',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatClock(_phase),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.odometerKm.round().toString().padLeft(5, '0')} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '续航 ${t.rangeKm.round()} km',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Image 4: Yadea E9 — READY top, dual power arc, TTFAR SPORT.
  Widget _buildEvYadea() {
    final t = widget.telemetry;
    final speed = _speed.value.round();
    final powerNorm = (_rpm.value / t.maxRpm).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.arrow_left, size: 18, color: const Color(0xFF00E676).withValues(alpha: 0.85)),
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  const Text(
                    'READY',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_right, size: 18, color: const Color(0xFF00E676).withValues(alpha: 0.85)),
            ],
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        'TTFAR',
                        style: TextStyle(
                          color: Color(0xFF00BCD4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'SPORT',
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 110,
                  child: CustomPaint(
                    painter: SegmentedArcPainter(
                      powerNorm: powerNorm,
                      regenNorm: 0.35,
                      segments: 28,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$speed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 88,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'km/h',
                      style: TextStyle(
                        color: Color(0xFF00BCD4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 56,
                height: 22,
                child: CustomPaint(
                  painter: BatteryIconPainter(
                    percent: t.batteryPercent,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatClock(_phase),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ODO ${t.odometerKm.round()}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    'TRIP ${t.tripKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '续航 ${t.rangeKm.round()} km · ${t.batteryPercent.round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'YADEA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _niuStatusIcon(IconData icon, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        icon,
        size: 14,
        color: active ? const Color(0xFF00E676) : Colors.white38,
      ),
    );
  }

  Widget _hybridTag(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 8,
        letterSpacing: 0.5,
      ),
    );
  }

  String _formatClock(double phase) {
    final totalSec = phase.floor();
    final h = (totalSec ~/ 3600) % 24;
    final m = (totalSec ~/ 60) % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _GreenSlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.2, size.height), Offset(size.width * 0.8, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NiuVFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(24, size.height * 0.12)
      ..lineTo(cx - 50, size.height * 0.62)
      ..lineTo(cx, size.height * 0.38)
      ..lineTo(cx + 50, size.height * 0.62)
      ..lineTo(size.width - 24, size.height * 0.12);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF00E676),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0x4400E676)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MotoLeanGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, size.height * 0.5), width: 8, height: 28),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white24,
    );
    canvas.drawCircle(Offset(cx, size.height * 0.22), 5, Paint()..color = Colors.white38);
    canvas.drawCircle(Offset(cx, size.height * 0.78), 5, Paint()..color = Colors.white38);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HybridRedAccentPainter extends CustomPainter {
  _HybridRedAccentPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.45,
        size.width * 0.5,
        size.height * 0.85,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.75 + 0.15 * math.sin(phase * 3)),
    );
  }

  @override
  bool shouldRepaint(covariant _HybridRedAccentPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
