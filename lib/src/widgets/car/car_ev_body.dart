import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/gear.dart';
import '../../painters/battery_bar_painter.dart';
import '../shared/cluster_surface.dart';
import '../shared/gear_selector.dart';
import '../shared/mileage_range_strip.dart';
import '../shared/overspeed_warning.dart';

/// Tesla / NIO / Li Auto EV car cluster layouts (reference-accurate).
class CarEvBody extends StatefulWidget {
  const CarEvBody({
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
  State<CarEvBody> createState() => _CarEvBodyState();
}

class _CarEvBodyState extends State<CarEvBody> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SmoothedValue _speed;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _speed = SmoothedValue(widget.telemetry.speedKmh, responsiveness: 14);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _speed.tick(widget.telemetry.speedKmh, dt.clamp(0.0, 0.05));
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ClusterSurface(
      dimForWeather: widget.dimForWeather,
      baseColor: const Color(0xFF000000),
      weatherScrimAlpha: 0.18,
      solidAlpha: 0.72,
      child: switch (widget.style) {
        DashStyle.carEvTesla => _buildTesla(),
        DashStyle.carEvNio => _buildNio(),
        DashStyle.carEvLi => _buildLi(),
        _ => _buildTesla(),
      },
    );

    return OverspeedWarningLayer(
      speedKmh: _speed.value,
      speedLimitKmh: widget.telemetry.speedLimitKmh,
      child: child,
    );
  }

  /// Model 3/Y: left regen/power line, huge speed, SOC + range bottom-left.
  Widget _buildTesla() {
    final t = widget.telemetry;
    final speed = _speed.value.round();
    final powerNorm = (t.rpm / t.maxRpm).clamp(0.0, 1.0);

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 28,
            top: 80,
            bottom: 120,
            width: 4,
            child: CustomPaint(
              painter: _TeslaPowerLinePainter(powerNorm: powerNorm),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$speed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 120,
                        fontWeight: FontWeight.w300,
                        height: 0.9,
                        letterSpacing: -4,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 18),
                      child: Text(
                        'km/h',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 3),
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 14,
                      child: CustomPaint(
                        painter: BatteryIconPainter(
                          percent: t.batteryPercent,
                          color: _teslaSocColor(t.batteryPercent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${t.batteryPercent.round()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${t.rangeKm.round()} km',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MileageRangeStrip(
                  telemetry: t,
                  compact: true,
                  fontSize: 11,
                  color: Colors.white38,
                ),
                const SizedBox(height: 12),
                if (widget.onGearSelected != null)
                  GearSelector(
                    gear: t.gear,
                    accent: Colors.white38,
                    onGearSelected: widget.onGearSelected,
                    onGearPointerDown: widget.onGearPointerDown,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// NIO NT2: left SOC pillar, center speed, range below.
  Widget _buildNio() {
    final t = widget.telemetry;
    final speed = _speed.value.round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            _NioSocPillar(percent: t.batteryPercent),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    '$speed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 108,
                      fontWeight: FontWeight.w200,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    'km/h',
                    style: TextStyle(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
                      fontSize: 15,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${t.rangeKm.round()} km',
                    style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MileageRangeStrip(
                    telemetry: t,
                    showTrip: true,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const Spacer(),
                  if (widget.onGearSelected != null)
                    GearSelector(
                      gear: t.gear,
                      accent: const Color(0xFF4FC3F7),
                      onGearSelected: widget.onGearSelected,
                      onGearPointerDown: widget.onGearPointerDown,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Li Auto L-series: top energy strip, speed center, orange power arc.
  Widget _buildLi() {
    final t = widget.telemetry;
    final speed = _speed.value.round();
    final powerNorm = (t.rpm / t.maxRpm).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.battery_charging_full,
                    size: 20,
                    color: const Color(0xFFFF9800).withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${t.batteryPercent.round()}%',
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '续航 ${t.rangeKm.round()} km',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '纯电',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 100,
                  child: CustomPaint(
                    painter: _LiEnergyArcPainter(powerNorm: powerNorm),
                  ),
                ),
                Text(
                  '$speed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
              ],
            ),
            Text(
              'km/h',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            MileageRangeStrip(
              telemetry: t,
              showTrip: true,
              fontSize: 12,
            ),
            const SizedBox(height: 12),
            if (widget.onGearSelected != null)
              GearSelector(
                gear: t.gear,
                accent: const Color(0xFFFF9800),
                onGearSelected: widget.onGearSelected,
                onGearPointerDown: widget.onGearPointerDown,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _teslaSocColor(double percent) {
    if (percent <= 20) return const Color(0xFFFF5252);
    return const Color(0xFF4CAF50);
  }
}

class _TeslaPowerLinePainter extends CustomPainter {
  _TeslaPowerLinePainter({required this.powerNorm});

  final double powerNorm;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height * 0.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = Colors.white12
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final regenH = mid * 0.3;
    canvas.drawLine(
      Offset(size.width / 2, mid - regenH),
      Offset(size.width / 2, mid),
      Paint()
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final powerH = mid * powerNorm;
    canvas.drawLine(
      Offset(size.width / 2, mid),
      Offset(size.width / 2, mid + powerH),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TeslaPowerLinePainter oldDelegate) {
    return oldDelegate.powerNorm != powerNorm;
  }
}

class _NioSocPillar extends StatelessWidget {
  const _NioSocPillar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 160,
      child: CustomPaint(
        painter: _NioSocPillarPainter(percent: percent / 100),
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              '${percent.round()}',
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NioSocPillarPainter extends CustomPainter {
  _NioSocPillarPainter({required this.percent});

  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    final fillH = (size.height - 8) * percent.clamp(0.0, 1.0);
    if (fillH > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4, size.height - 4 - fillH, size.width - 8, fillH),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NioSocPillarPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}

class _LiEnergyArcPainter extends CustomPainter {
  _LiEnergyArcPainter({required this.powerNorm});

  final double powerNorm;

  @override
  void paint(Canvas canvas, Size size) {
    const start = math.pi * 0.15;
    const sweep = math.pi * 0.7;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white10,
    );
    canvas.drawArc(
      rect,
      start + sweep * 0.5,
      sweep * 0.5 * powerNorm,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF9800),
    );
    canvas.drawArc(
      rect,
      start,
      sweep * 0.5 * 0.25,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4CAF50),
    );
  }

  @override
  bool shouldRepaint(covariant _LiEnergyArcPainter oldDelegate) {
    return oldDelegate.powerNorm != powerNorm;
  }
}
