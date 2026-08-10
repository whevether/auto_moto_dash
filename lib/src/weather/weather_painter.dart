import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/weather_type.dart';

class _Particle {
  _Particle(this.x, this.y, this.z, this.size, this.vx, this.vy);

  double x;
  double y;
  double z;
  double size;
  double vx;
  double vy;
}

/// Single CustomPainter covering all [WeatherType] backgrounds.
class WeatherPainter extends CustomPainter {
  WeatherPainter({
    required this.type,
    required this.progress,
    this.opacity = 1,
  }) : _particles = _seed(type);

  final WeatherType type;
  final double progress;
  final double opacity;
  final List<_Particle> _particles;

  static List<_Particle> _seed(WeatherType type) {
    final count = switch (type) {
      WeatherType.sunny => 12,
      WeatherType.cloudy || WeatherType.overcast => 10,
      WeatherType.lightRain => 60,
      WeatherType.mediumRain => 110,
      WeatherType.heavyRain || WeatherType.thunderstorm => 180,
      WeatherType.lightSnow => 50,
      WeatherType.mediumSnow => 90,
      WeatherType.heavySnow || WeatherType.sunnySnow => 140,
      WeatherType.fog || WeatherType.haze => 8,
      WeatherType.dust => 70,
    };
    final r = math.Random(type.index * 1337 + 7);
    return List.generate(count, (_) {
      return _Particle(
        r.nextDouble(),
        r.nextDouble(),
        r.nextDouble(),
        0.4 + r.nextDouble() * 1.6,
        -0.05 + r.nextDouble() * 0.1,
        0.2 + r.nextDouble() * 0.8,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );

    switch (type) {
      case WeatherType.sunny:
        _paintSunny(canvas, size);
      case WeatherType.cloudy:
        _paintClouds(canvas, size, dense: false);
      case WeatherType.overcast:
        _paintClouds(canvas, size, dense: true);
      case WeatherType.lightRain:
      case WeatherType.mediumRain:
      case WeatherType.heavyRain:
        _paintRain(canvas, size, slant: 0.25);
      case WeatherType.thunderstorm:
        _paintRain(canvas, size, slant: 0.35);
        _paintLightning(canvas, size);
      case WeatherType.lightSnow:
      case WeatherType.mediumSnow:
      case WeatherType.heavySnow:
        _paintSnow(canvas, size, warm: false);
      case WeatherType.sunnySnow:
        _paintSunny(canvas, size, soft: true);
        _paintSnow(canvas, size, warm: true);
      case WeatherType.fog:
        _paintHaze(canvas, size, color: const Color(0xFFB0B8C0));
      case WeatherType.haze:
        _paintHaze(canvas, size, color: const Color(0xFFC4A882));
      case WeatherType.dust:
        _paintDust(canvas, size);
    }

    canvas.restore();
  }

  void _paintSunny(Canvas canvas, Size size, {bool soft = false}) {
    final center = Offset(size.width * 0.78, size.height * 0.18);
    final r = size.shortestSide * (soft ? 0.12 : 0.16);
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        r * 2.2,
        [
          const Color(0xFFFFE08A).withValues(alpha: soft ? 0.35 : 0.55),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, r * 2.2, glow);
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFFFFF1B0).withValues(alpha: 0.85),
    );
  }

  void _paintClouds(Canvas canvas, Size size, {required bool dense}) {
    final base = dense ? const Color(0xFF6B7280) : const Color(0xFF9AA3B2);
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final drift = (p.x + progress * (0.02 + p.z * 0.03)) % 1.2 - 0.1;
      final cx = drift * size.width;
      final cy = (0.12 + p.y * 0.35) * size.height;
      final s = size.shortestSide * (0.08 + p.size * 0.05);
      final paint = Paint()
        ..color = base.withValues(alpha: dense ? 0.28 : 0.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: s * 2.4, height: s),
        paint,
      );
      canvas.drawCircle(Offset(cx - s * 0.5, cy), s * 0.55, paint);
      canvas.drawCircle(Offset(cx + s * 0.45, cy - s * 0.1), s * 0.5, paint);
    }
    if (dense) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF1A1D22).withValues(alpha: 0.35),
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, {required double slant}) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    for (final p in _particles) {
      final y = (p.y + progress * (0.55 + p.vy)) % 1.0;
      final x = (p.x + y * slant + progress * p.vx) % 1.0;
      final start = Offset(x * size.width, y * size.height);
      final end = start + Offset(slant * 18, 16 + p.size * 10);
      paint.color = Colors.white.withValues(alpha: 0.18 + p.z * 0.35);
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintLightning(Canvas canvas, Size size) {
    final flash = (math.sin(progress * math.pi * 14) > 0.92);
    if (!flash) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final path = Path()
      ..moveTo(size.width * 0.62, size.height * 0.08)
      ..lineTo(size.width * 0.55, size.height * 0.28)
      ..lineTo(size.width * 0.6, size.height * 0.28)
      ..lineTo(size.width * 0.5, size.height * 0.55);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _paintSnow(Canvas canvas, Size size, {required bool warm}) {
    final paint = Paint();
    for (final p in _particles) {
      final y = (p.y + progress * (0.12 + p.vy * 0.25)) % 1.0;
      final x = (p.x + math.sin((y + p.z) * math.pi * 2) * 0.03 + progress * p.vx) %
          1.0;
      paint.color = (warm ? const Color(0xFFFFF8E7) : Colors.white)
          .withValues(alpha: 0.35 + p.z * 0.45);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        1.2 + p.size * 1.8,
        paint,
      );
    }
  }

  void _paintHaze(Canvas canvas, Size size, {required Color color}) {
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final cy = ((p.y + progress * 0.03) % 1.0) * size.height;
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, cy - 40),
          Offset(0, cy + 40),
          [
            Colors.transparent,
            color.withValues(alpha: 0.18 + p.z * 0.12),
            Colors.transparent,
          ],
        );
      canvas.drawRect(Rect.fromLTWH(0, cy - 50, size.width, 100), paint);
    }
  }

  void _paintDust(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF8B6914).withValues(alpha: 0.12),
    );
    final paint = Paint();
    for (final p in _particles) {
      final x = (p.x + progress * (0.08 + p.vx)) % 1.0;
      final y = (p.y + math.sin(progress * 4 + p.z * 8) * 0.02) % 1.0;
      paint.color = const Color(0xFFD2B48C).withValues(alpha: 0.25 + p.z * 0.35);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        0.8 + p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeatherPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity;
  }
}