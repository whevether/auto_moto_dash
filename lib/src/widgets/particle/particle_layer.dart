import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/particle_effect.dart';
import '../../painters/particles/black_hole_painter.dart';
import '../../painters/particles/cyber_grid_painter.dart';
import '../../painters/particles/ion_storm_painter.dart';
import '../../painters/particles/star_tunnel_painter.dart';
import '../../painters/particles/wind_rush_painter.dart';

/// Shared motion particle layer for digital and analog clusters.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({
    super.key,
    required this.effect,
    required this.speedKmh,
    required this.lightSpeedThresholdKmh,
    this.accent = const Color(0xFF4FC3F7),
    this.opacity = 1,
  });

  final ParticleEffect effect;
  final double speedKmh;
  final double lightSpeedThresholdKmh;
  final Color accent;
  final double opacity;

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _elapsed = 0;
  double _prevSpeed = 0;
  double _accelNorm = 0;

  @override
  void initState() {
    super.initState();
    _prevSpeed = widget.speedKmh;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final clamped = dt.clamp(0.0, 0.05);
    _elapsed = elapsed.inMilliseconds / 1000.0;
    if (clamped > 0) {
      final accel = (widget.speedKmh - _prevSpeed) / clamped;
      final target = (accel / 60).clamp(-0.2, 1.2);
      _accelNorm += (target - _accelNorm) * (8 * clamped).clamp(0.0, 1.0);
      _prevSpeed = widget.speedKmh;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final threshold = widget.lightSpeedThresholdKmh <= 0
        ? 80.0
        : widget.lightSpeedThresholdKmh;
    final speedNorm = (widget.speedKmh / threshold).clamp(0.0, 1.4);

    final painter = switch (widget.effect) {
      ParticleEffect.windRush => WindRushPainter(
          progress: _elapsed,
          speedNorm: speedNorm,
          accelNorm: _accelNorm,
          accent: widget.accent,
        ),
      ParticleEffect.blackHole => BlackHolePainter(
          progress: _elapsed,
          speedNorm: speedNorm,
          accelNorm: _accelNorm,
          accent: widget.accent,
        ),
      ParticleEffect.starTunnel => StarTunnelPainter(
          progress: _elapsed,
          speedNorm: speedNorm,
          accelNorm: _accelNorm,
          accent: widget.accent,
        ),
      ParticleEffect.cyberGrid => CyberGridPainter(
          progress: _elapsed,
          speedNorm: speedNorm,
          accelNorm: _accelNorm,
          accent: widget.accent,
        ),
      ParticleEffect.ionStorm => IonStormPainter(
          progress: _elapsed,
          speedNorm: speedNorm,
          accelNorm: _accelNorm,
          accent: widget.accent,
        ),
    };

    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: painter,
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}