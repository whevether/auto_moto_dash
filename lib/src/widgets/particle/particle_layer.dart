import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/particle_effect.dart';
import '../../painters/particles/black_hole_painter.dart';
import '../../painters/particles/ion_storm_painter.dart';
import '../../painters/particles/road_track_painter.dart';
import '../../painters/particles/star_tunnel_painter.dart';
import '../../painters/particles/wind_rush_painter.dart';

/// Shared motion particle layer for digital and analog clusters.
///
/// Uses inertial [flowSpeed]: rises quickly when accelerating, decays slowly
/// when decelerating so particles ease down instead of snapping off.
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
  double _flowSpeed = 0;
  double _distance = 0;

  @override
  void initState() {
    super.initState();
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
    if (clamped <= 0) return;

    final threshold = widget.lightSpeedThresholdKmh <= 0
        ? 80.0
        : widget.lightSpeedThresholdKmh;
    final target = (widget.speedKmh / threshold).clamp(0.0, 1.4);

    final rate = target > _flowSpeed ? 7.0 : 2.2;
    final t = 1 - math.exp(-rate * clamped);
    _flowSpeed += (target - _flowSpeed) * t;
    _distance += clamped * (0.08 + _flowSpeed * _flowSpeed * 1.65);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final painter = switch (widget.effect) {
      ParticleEffect.windRush => WindRushPainter(
          distance: _distance,
          flowSpeed: _flowSpeed,
          accent: widget.accent,
        ),
      ParticleEffect.blackHole => BlackHolePainter(
          distance: _distance,
          flowSpeed: _flowSpeed,
          accent: widget.accent,
        ),
      ParticleEffect.starTunnel => StarTunnelPainter(
          distance: _distance,
          flowSpeed: _flowSpeed,
          accent: widget.accent,
        ),
      ParticleEffect.roadTrack => RoadTrackPainter(
          distance: _distance,
          flowSpeed: _flowSpeed,
          accent: widget.accent,
        ),
      ParticleEffect.ionStorm => IonStormPainter(
          distance: _distance,
          flowSpeed: _flowSpeed,
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