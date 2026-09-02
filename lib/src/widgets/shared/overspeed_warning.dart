import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

/// Ferrari-style shift lights driven by speed vs speed limit.
class OverspeedShiftLights extends StatelessWidget {
  const OverspeedShiftLights({
    super.key,
    required this.speedKmh,
    required this.speedLimitKmh,
    this.litCount = 10,
  });

  final double speedKmh;
  final double speedLimitKmh;
  final int litCount;

  static int computeLit({
    required double speedKmh,
    required double speedLimitKmh,
    int count = 10,
  }) {
    if (speedLimitKmh <= 0 || speedKmh <= 0) return 0;
    final start = speedLimitKmh * 0.72;
    if (speedKmh <= start) return 0;
    final max = speedLimitKmh * 1.15;
    return (((speedKmh - start) / (max - start)) * count).ceil().clamp(0, count);
  }

  @override
  Widget build(BuildContext context) {
    final lit = computeLit(
      speedKmh: speedKmh,
      speedLimitKmh: speedLimitKmh,
      count: litCount,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(litCount, (i) {
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

/// Red pulse overlay when speed exceeds limit.
class OverspeedPulseOverlay extends StatelessWidget {
  const OverspeedPulseOverlay({
    super.key,
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.phase,
  });

  final double speedKmh;
  final double speedLimitKmh;
  final double phase;

  bool get _active =>
      speedLimitKmh > 0 && speedKmh >= speedLimitKmh;

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    final pulse = ((phase * 8) % 1.0 - 0.5).abs() * 2;
    final alpha = (0.25 + 0.35 * pulse) * 0.35;

    return IgnorePointer(
      child: ColoredBox(
        color: const Color(0xFFFF0000).withValues(alpha: alpha),
      ),
    );
  }
}

/// Wraps car cluster bodies with overspeed shift lights + pulse overlay.
class OverspeedWarningLayer extends StatefulWidget {
  const OverspeedWarningLayer({
    super.key,
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.child,
    this.showShiftLights = true,
    this.shiftLightsOnTop = true,
  });

  final double speedKmh;
  final double speedLimitKmh;
  final Widget child;
  final bool showShiftLights;
  final bool shiftLightsOnTop;

  @override
  State<OverspeedWarningLayer> createState() => _OverspeedWarningLayerState();
}

class _OverspeedWarningLayerState extends State<OverspeedWarningLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _phase = elapsed.inMilliseconds / 1000.0);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  bool get _warns =>
      widget.speedLimitKmh > 0 &&
      OverspeedShiftLights.computeLit(
            speedKmh: widget.speedKmh,
            speedLimitKmh: widget.speedLimitKmh,
          ) >
          0;

  @override
  Widget build(BuildContext context) {
    final lights = widget.showShiftLights && _warns
        ? SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OverspeedShiftLights(
                  speedKmh: widget.speedKmh,
                  speedLimitKmh: widget.speedLimitKmh,
                ),
              ),
            ),
          )
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        OverspeedPulseOverlay(
          speedKmh: widget.speedKmh,
          speedLimitKmh: widget.speedLimitKmh,
          phase: _phase,
        ),
        if (lights != null && !widget.shiftLightsOnTop) lights,
        if (lights != null && widget.shiftLightsOnTop) lights,
      ],
    );
  }
}

/// Circular battery SOC ring used by NIO-style cluster.
class BatterySocRing extends StatelessWidget {
  const BatterySocRing({
    super.key,
    required this.percent,
    this.size = 72,
    this.strokeWidth = 5,
    this.color = const Color(0xFF4FC3F7),
  });

  final double percent;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SocRingPainter(
          percent: percent / 100,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '${percent.round()}%',
            style: TextStyle(
              color: color,
              fontSize: size * 0.22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocRingPainter extends CustomPainter {
  _SocRingPainter({
    required this.percent,
    required this.color,
    required this.strokeWidth,
  });

  final double percent;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - strokeWidth * 2,
      size.height - strokeWidth * 2,
    );
    canvas.drawArc(
      rect,
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white12,
    );
    canvas.drawArc(
      rect,
      math.pi * 0.75,
      math.pi * 1.5 * percent.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SocRingPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}
