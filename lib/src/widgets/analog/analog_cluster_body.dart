import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../painters/analog_gauge_painter.dart';

class AnalogClusterBody extends StatefulWidget {
  const AnalogClusterBody({
    super.key,
    required this.telemetry,
    required this.style,
  });

  final DashTelemetry telemetry;
  final DashStyle style;

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

  AnalogGaugeStyle get _gaugeStyle {
    if (_racing) {
      return const AnalogGaugeStyle(
        ringColor: Color(0xFF2A2A2A),
        tickColor: Color(0xFFF5F5F5),
        labelColor: Color(0xFFE0E0E0),
        needleColor: Color(0xFFFF1744),
        capColor: Color(0xFF111111),
        redlineColor: Color(0xFFFF1744),
        faceColor: Color(0xFF050505),
        glowColor: Color(0x22FF1744),
      );
    }
    return const AnalogGaugeStyle(
      ringColor: Color(0xFF4A4F58),
      tickColor: Color(0xFFEDEDED),
      labelColor: Color(0xFFD0D0D0),
      needleColor: Color(0xFFFFB74D),
      capColor: Color(0xFF1C1C1C),
      redlineColor: Color(0xFFE53935),
      faceColor: Color(0xFF121418),
      glowColor: Color(0x33FFF3E0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final redPulse = _racing && _rpm.value >= t.redlineRpm;
    final pulse = ((_phase * 8) % 1.0 - 0.5).abs() * 2;
    final bg = redPulse
        ? Color.lerp(Colors.black, const Color(0xFF3B0000), 0.25 + 0.35 * pulse)!
        : Colors.black;

    return ColoredBox(
      color: bg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= constraints.maxHeight;
            final gauges = wide
                ? Row(
                    children: [
                      Expanded(child: _rpmGauge(t)),
                      Expanded(child: _speedGauge(t)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 5, child: _rpmGauge(t)),
                      Expanded(flex: 5, child: _speedGauge(t)),
                    ],
                  );

            return Column(
              children: [
                if (_racing) ...[
                  const SizedBox(height: 8),
                  _ShiftLights(
                    rpm: _rpm.value,
                    redline: t.redlineRpm,
                    maxRpm: t.maxRpm,
                  ),
                ],
                Expanded(child: gauges),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _FooterInfo(
                    telemetry: t,
                    racing: _racing,
                    speed: _speed.value,
                    rpm: _rpm.value,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rpmGauge(DashTelemetry t) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
        painter: AnalogGaugePainter(
          value: _rpm.value,
          min: 0,
          max: t.maxRpm,
          majorTickEvery: (t.maxRpm / 8).round().clamp(500, 2000),
          labelBuilder: (v) => (v / 1000).toStringAsFixed(0),
          redlineFrom: t.redlineRpm,
          title: 'RPM',
          unit: 'x1000',
          style: _gaugeStyle,
        ),
      ),
    );
  }

  Widget _speedGauge(DashTelemetry t) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
        painter: AnalogGaugePainter(
          value: _speed.value,
          min: 0,
          max: 260,
          majorTickEvery: 20,
          title: 'SPEED',
          unit: 'km/h',
          style: _gaugeStyle,
        ),
      ),
    );
  }
}

class _ShiftLights extends StatelessWidget {
  const _ShiftLights({
    required this.rpm,
    required this.redline,
    required this.maxRpm,
  });

  final double rpm;
  final double redline;
  final double maxRpm;

  @override
  Widget build(BuildContext context) {
    const count = 8;
    final start = redline * 0.75;
    final lit = rpm <= start
        ? 0
        : (((rpm - start) / (maxRpm - start)) * count).ceil().clamp(0, count);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i < lit;
        final color = i < count - 2
            ? const Color(0xFF69F0AE)
            : i < count - 1
                ? const Color(0xFFFFF176)
                : const Color(0xFFFF1744);
        return Container(
          width: 18,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  const _FooterInfo({
    required this.telemetry,
    required this.racing,
    required this.speed,
    required this.rpm,
  });

  final DashTelemetry telemetry;
  final bool racing;
  final double speed;
  final double rpm;

  @override
  Widget build(BuildContext context) {
    final gearText = telemetry.gearNumber != null
        ? '${telemetry.gearNumber}'
        : telemetry.gear.label;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MiniArc(
              label: 'FUEL',
              value: telemetry.fuelPercent / 100,
              color: const Color(0xFFFFB74D),
            ),
            Column(
              children: [
                Text(
                  racing ? gearText : telemetry.gear.label,
                  style: TextStyle(
                    color: racing
                        ? const Color(0xFFFF1744)
                        : const Color(0xFF4FC3F7),
                    fontSize: racing ? 42 : 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${speed.round()} km/h · ${(rpm / 1000).toStringAsFixed(1)}k',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            _MiniArc(
              label: 'TEMP',
              value: (telemetry.coolantTempC / 120).clamp(0.0, 1.0),
              color: const Color(0xFF4FC3F7),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'ODO ${telemetry.odometerKm.toStringAsFixed(1)}  ·  TRIP ${telemetry.tripKm.toStringAsFixed(1)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _MiniArc extends StatelessWidget {
  const _MiniArc({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _MiniArcPainter(value: value, color: color),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniArcPainter extends CustomPainter {
  _MiniArcPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.42);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white12;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    const start = 2.4;
    const sweep = 4.5;
    canvas.drawArc(rect, start, sweep, false, bg);
    canvas.drawArc(rect, start, sweep * value.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _MiniArcPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}