import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/vehicle_type.dart';
import '../../painters/neon_polygon_painter.dart';
import '../../painters/pulse_ring_painter.dart';
import '../../painters/warp_streaks_painter.dart';
import '../shared/gear_selector.dart';
import '../shared/vehicle_outline.dart';

class DigitalHudBody extends StatefulWidget {
  const DigitalHudBody({
    super.key,
    required this.telemetry,
    required this.style,
    required this.vehicleType,
    required this.lightSpeedThresholdKmh,
    required this.showGearSelector,
    required this.showVehicleOutline,
    this.rainbowSpeed = false,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final VehicleType vehicleType;
  final double lightSpeedThresholdKmh;
  final bool showGearSelector;
  final bool showVehicleOutline;
  final bool rainbowSpeed;

  @override
  State<DigitalHudBody> createState() => _DigitalHudBodyState();
}

class _DigitalHudBodyState extends State<DigitalHudBody>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SmoothedValue _speed;
  Duration _last = Duration.zero;
  double _elapsedSec = 0;
  double _prevSpeed = 0;
  double _accelNorm = 0;

  @override
  void initState() {
    super.initState();
    final responsiveness = widget.style == DashStyle.performance ? 18.0 : 10.0;
    _speed = SmoothedValue(widget.telemetry.speedKmh,
        responsiveness: responsiveness);
    _prevSpeed = widget.telemetry.speedKmh;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant DigitalHudBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _speed.responsiveness =
        widget.style == DashStyle.performance ? 18.0 : 10.0;
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final clampedDt = dt.clamp(0.0, 0.05);
    _elapsedSec = elapsed.inMilliseconds / 1000.0;
    _speed.tick(widget.telemetry.speedKmh, clampedDt);
    if (clampedDt > 0) {
      final accelKmhps = (_speed.value - _prevSpeed) / clampedDt;
      // ~60 km/h/s ≈ full rush boost
      final target = (accelKmhps / 60).clamp(-0.2, 1.2);
      _accelNorm += (target - _accelNorm) * (8 * clampedDt).clamp(0.0, 1.0);
      _prevSpeed = _speed.value;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Color get _accent {
    return switch (widget.style) {
      DashStyle.techNeon => const Color(0xFF7C4DFF),
      DashStyle.hud => const Color(0xFF4FC3F7),
      DashStyle.performance => const Color(0xFF69F0AE),
      DashStyle.pulseBreath => const Color(0xFFFF80AB),
      _ => const Color(0xFF4FC3F7),
    };
  }

  Color _speedColor(double speed) {
    if (!widget.rainbowSpeed && widget.style != DashStyle.techNeon) {
      return Colors.white;
    }
    final hue = (speed * 2.2) % 360;
    return HSVColor.fromAHSV(1, hue, 0.65, 1).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final threshold = widget.lightSpeedThresholdKmh <= 0
        ? 80.0
        : widget.lightSpeedThresholdKmh;
    final speedNorm = (_speed.value / threshold).clamp(0.0, 1.25);
    final intensity = speedNorm.clamp(0.0, 1.0);
    final displaySpeed = _speed.value.round().clamp(0, 999);

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: WarpStreaksPainter(
            progress: _elapsedSec,
            speedNorm: speedNorm,
            accelNorm: _accelNorm,
            accent: _accent,
            streakCount: widget.style == DashStyle.performance ? 110 : 90,
          ),
        ),
        if (widget.style == DashStyle.techNeon)
          CustomPaint(
            painter: NeonPolygonPainter(
              sides: 6,
              rotation: _elapsedSec * 0.15,
              color: _accent,
              intensity: intensity,
            ),
          ),
        if (widget.style == DashStyle.pulseBreath)
          CustomPaint(
            painter: PulseRingPainter(
              phase: _elapsedSec * (0.35 + intensity * 0.9),
              intensity: intensity,
              color: _accent,
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _TopStats(telemetry: widget.telemetry),
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displaySpeed',
                              style: TextStyle(
                                color: _speedColor(_speed.value),
                                fontSize: 96,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: -2,
                                shadows: [
                                  Shadow(
                                    color: Colors.white
                                        .withValues(alpha: 0.35 + intensity * 0.25),
                                    blurRadius: 24,
                                  ),
                                  if (widget.style == DashStyle.techNeon ||
                                      widget.rainbowSpeed)
                                    Shadow(
                                      color: _speedColor(_speed.value)
                                          .withValues(alpha: 0.55),
                                      blurRadius: 28,
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              'KM/H',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.showVehicleOutline)
                        Positioned(
                          right: 0,
                          top: 24,
                          child: VehicleOutline(
                            vehicleType: widget.vehicleType,
                            tires: widget.telemetry.tirePressures,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showGearSelector) ...[
                  GearSelector(
                    gear: widget.telemetry.gear,
                    accent: _accent,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
        if (widget.style == DashStyle.hud)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.telemetry});

  final DashTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${telemetry.batteryPercent.round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white54,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            '${telemetry.rangeKm.round()} km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}