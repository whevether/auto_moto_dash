import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/gear.dart';
import '../../painters/analog_gauge_painter.dart';
import '../shared/gear_selector.dart';
import '../shared/mileage_range_strip.dart';
import '../shared/overspeed_warning.dart';

class AnalogClusterBody extends StatefulWidget {
  const AnalogClusterBody({
    super.key,
    required this.telemetry,
    required this.style,
    this.dimForWeather = false,
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final DashTelemetry telemetry;
  final DashStyle style;

  /// When true, cluster hood stays translucent so weather shows through.
  final bool dimForWeather;
  final ValueChanged<Gear>? onGearSelected;
  final VoidCallback? onGearPointerDown;

  @override
  State<AnalogClusterBody> createState() => _AnalogClusterBodyState();
}

class _AnalogClusterBodyState extends State<AnalogClusterBody>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SmoothedValue _speed;
  late final SmoothedValue _rpm;
  Duration _last = Duration.zero;
  double _phase = 0;

  bool get _racing => widget.style == DashStyle.racing;

  @override
  void initState() {
    super.initState();
    _speed = SmoothedValue(
      widget.telemetry.speedKmh,
      responsiveness: _racing ? 16 : 9,
    );
    _rpm = SmoothedValue(
      widget.telemetry.rpm,
      responsiveness: _racing ? 18 : 10,
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant AnalogClusterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _speed.responsiveness = _racing ? 16 : 9;
    _rpm.responsiveness = _racing ? 18 : 10;
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _phase = elapsed.inMilliseconds / 1000.0;
    _speed.tick(widget.telemetry.speedKmh, dt.clamp(0, 0.05));
    _rpm.tick(widget.telemetry.rpm, dt.clamp(0, 0.05));
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final redPulse = _racing && _rpm.value >= t.redlineRpm;
    final pulse = ((_phase * 8) % 1.0 - 0.5).abs() * 2;

    return OverspeedWarningLayer(
      speedKmh: _speed.value,
      speedLimitKmh: t.speedLimitKmh,
      child: CustomPaint(
        painter: _ClusterHoodPainter(
          racing: _racing,
          redPulse: redPulse ? 0.25 + 0.35 * pulse : 0,
          showWeather: widget.dimForWeather,
        ),
        child: SafeArea(
          child: _racing ? _buildFerrari(t) : _buildBmw(t),
        ),
      ),
    );
  }

  /// BMW-style: equal dual gauges, chrome bezels, center info bridge.
  Widget _buildBmw(DashTelemetry t) {
    final style = const AnalogGaugeStyle(theme: AnalogGaugeTheme.bmw);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= constraints.maxHeight * 0.85;
        final gauges = [
          Expanded(
            child: _Gauge(
              child: CustomPaint(
                painter: AnalogGaugePainter(
                  value: _rpm.value,
                  min: 0,
                  max: t.maxRpm,
                  majorTickEvery: (t.maxRpm / 8).round().clamp(500, 2000),
                  labelBuilder: (v) => (v / 1000).round().toString(),
                  redlineFrom: t.redlineRpm,
                  title: 'RPM',
                  unit: '×1000/min',
                  style: style,
                  pulsePhase: _phase * 0.35,
                ),
              ),
            ),
          ),
          Expanded(
            child: _Gauge(
              child: CustomPaint(
                painter: AnalogGaugePainter(
                  value: _speed.value,
                  min: 0,
                  max: 260,
                  majorTickEvery: 20,
                  title: 'km/h',
                  style: style,
                  centerReadout: _speed.value.round().toString(),
                  centerReadoutUnit: 'HUD',
                  pulsePhase: _phase * 0.35,
                ),
              ),
            ),
          ),
        ];

        return Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        gauges[0],
                        _BmwCenterBridge(
                          telemetry: t,
                          speed: _speed.value,
                          rpm: _rpm.value,
                        ),
                        gauges[1],
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Row(children: gauges),
                        ),
                        _BmwCenterBridge(
                          telemetry: t,
                          speed: _speed.value,
                          rpm: _rpm.value,
                          horizontal: true,
                        ),
                      ],
                    ),
            ),
            if (widget.onGearSelected != null) ...[
              GearSelector(
                gear: t.gear,
                accent: const Color(0xFF00E5FF),
                onGearSelected: widget.onGearSelected,
                onGearPointerDown: widget.onGearPointerDown,
              ),
              const SizedBox(height: 4),
            ],
            _BmwFooter(telemetry: t),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  /// Ferrari-style: dominant tach, yellow ticks, digital speed, shift LEDs.
  Widget _buildFerrari(DashTelemetry t) {
    final style = const AnalogGaugeStyle(theme: AnalogGaugeTheme.ferrari);
    final gearText = t.gearNumber != null ? '${t.gearNumber}' : t.gear.label;

    return Column(
      children: [
        const SizedBox(height: 6),
        _FerrariShiftLights(
          rpm: _rpm.value,
          redline: t.redlineRpm,
          maxRpm: t.maxRpm,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth * 0.92,
                constraints.maxHeight * 0.95,
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: AnalogGaugePainter(
                        value: _rpm.value,
                        min: 0,
                        max: t.maxRpm,
                        majorTickEvery:
                            (t.maxRpm / 8).round().clamp(500, 2000),
                        labelBuilder: (v) => (v / 1000).round().toString(),
                        redlineFrom: t.redlineRpm,
                        title: 'RACE',
                        unit: '×1000 rpm',
                        style: style,
                        pulsePhase: _phase * (0.4 + (_rpm.value / t.maxRpm) * 0.8),
                      ),
                    ),
                  ),
                  // Digital speed + gear overlay in lower half of tach
                  Positioned(
                    bottom: constraints.maxHeight * 0.14,
                    child: Column(
                      children: [
                        Text(
                          _speed.value.round().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w200,
                            height: 1,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(color: Color(0x66FFFFFF), blurRadius: 18),
                            ],
                          ),
                        ),
                        Text(
                          'km/h',
                          style: TextStyle(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                            fontSize: 11,
                            letterSpacing: 3,
                            shadows: const [
                              Shadow(color: Color(0x66FFD54F), blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gearText,
                          style: const TextStyle(
                            color: Color(0xFFFF1744),
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: Color(0xCCFF1744),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.onGearSelected != null) ...[
          GearSelector(
            gear: t.gear,
            accent: const Color(0xFFFFD54F),
            onGearSelected: widget.onGearSelected,
            onGearPointerDown: widget.onGearPointerDown,
          ),
          const SizedBox(height: 4),
        ],
        _FerrariFooter(telemetry: t, rpm: _rpm.value),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: AspectRatio(aspectRatio: 1, child: child),
    );
  }
}

class _ClusterHoodPainter extends CustomPainter {
  _ClusterHoodPainter({
    required this.racing,
    required this.redPulse,
    required this.showWeather,
  });

  final bool racing;
  final double redPulse;
  final bool showWeather;

  @override
  void paint(Canvas canvas, Size size) {
    if (showWeather) {
      // Light scrim so gauges stay readable over animated weather.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
    } else {
      final base = racing ? const Color(0xFF050505) : const Color(0xFF0B0C10);
      canvas.drawRect(Offset.zero & size, Paint()..color = base);
    }

    // Binnacle / hood shadow like a real cluster cove
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height * 0.35),
          [
            Colors.black.withValues(alpha: showWeather ? 0.45 : 0.75),
            Colors.transparent,
          ],
        ),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.48),
          size.shortestSide * 0.75,
          [
            (racing ? const Color(0xFF1A0A0A) : const Color(0xFF152033))
                .withValues(alpha: showWeather ? 0.18 : 0.35),
            Colors.transparent,
          ],
        ),
    );

    if (redPulse > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFF0000).withValues(alpha: redPulse * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClusterHoodPainter oldDelegate) {
    return oldDelegate.racing != racing ||
        oldDelegate.redPulse != redPulse ||
        oldDelegate.showWeather != showWeather;
  }
}

class _BmwCenterBridge extends StatelessWidget {
  const _BmwCenterBridge({
    required this.telemetry,
    required this.speed,
    required this.rpm,
    this.horizontal = false,
  });

  final DashTelemetry telemetry;
  final double speed;
  final double rpm;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final gear = telemetry.gear.label;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gear,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 40,
            fontWeight: FontWeight.w300,
            height: 1,
            shadows: [Shadow(color: Color(0x8800E5FF), blurRadius: 14)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${speed.round()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        Text(
          'km/h',
          style: TextStyle(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${(rpm / 1000).toStringAsFixed(1)}k',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      ],
    );

    final card = Container(
      width: horizontal ? null : 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x990A1520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x6600E5FF)),
        boxShadow: const [
          BoxShadow(color: Color(0x3300E5FF), blurRadius: 16),
        ],
      ),
      child: content,
    );

    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: card,
      );
    }
    return card;
  }
}

class _BmwFooter extends StatelessWidget {
  const _BmwFooter({required this.telemetry});

  final DashTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          _AuxGauge(
            label: 'E',
            endLabel: 'F',
            value: telemetry.fuelPercent / 100,
            color: const Color(0xFFFFB74D),
            icon: Icons.local_gas_station,
          ),
          Expanded(
            child: MileageRangeStrip(
              telemetry: telemetry,
              showTrip: true,
              fontSize: 11,
              secondaryFontSize: 10,
            ),
          ),
          _AuxGauge(
            label: 'C',
            endLabel: 'H',
            value: (telemetry.coolantTempC / 120).clamp(0.0, 1.0),
            color: const Color(0xFF64B5F6),
            icon: Icons.thermostat,
          ),
        ],
      ),
    );
  }
}

class _FerrariShiftLights extends StatelessWidget {
  const _FerrariShiftLights({
    required this.rpm,
    required this.redline,
    required this.maxRpm,
  });

  final double rpm;
  final double redline;
  final double maxRpm;

  @override
  Widget build(BuildContext context) {
    const count = 10;
    final start = redline * 0.72;
    final lit = rpm <= start
        ? 0
        : (((rpm - start) / (maxRpm - start)) * count).ceil().clamp(0, count);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i < lit;
        final color = i < 5
            ? const Color(0xFF00E676)
            : i < 8
                ? const Color(0xFFFFD54F)
                : const Color(0xFFFF1744);
        return Container(
          width: 16,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(1),
            border: Border.all(
              color: color.withValues(alpha: active ? 0.9 : 0.25),
              width: 0.8,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.9),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _FerrariFooter extends StatelessWidget {
  const _FerrariFooter({
    required this.telemetry,
    required this.rpm,
  });

  final DashTelemetry telemetry;
  final double rpm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _AuxGauge(
            label: 'E',
            endLabel: 'F',
            value: telemetry.fuelPercent / 100,
            color: const Color(0xFFFFD54F),
            icon: Icons.local_gas_station,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${(rpm / 1000).toStringAsFixed(2)} ×1000',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                MileageRangeStrip(
                  telemetry: telemetry,
                  fontSize: 10,
                  secondaryFontSize: 9,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
          _AuxGauge(
            label: 'C',
            endLabel: 'H',
            value: (telemetry.coolantTempC / 120).clamp(0.0, 1.0),
            color: const Color(0xFFFF5252),
            icon: Icons.thermostat,
          ),
        ],
      ),
    );
  }
}

class _AuxGauge extends StatelessWidget {
  const _AuxGauge({
    required this.label,
    required this.endLabel,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String endLabel;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 40,
      child: CustomPaint(
        painter: _AuxArcPainter(value: value, color: color),
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 9,
                ),
              ),
              Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
              Text(
                endLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuxArcPainter extends CustomPainter {
  _AuxArcPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height * 1.4);
    const start = math.pi * 1.15;
    const sweep = math.pi * 0.7;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white12,
    );
    canvas.drawArc(
      rect,
      start,
      sweep * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AuxArcPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
