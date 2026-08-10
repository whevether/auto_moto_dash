import 'package:flutter/material.dart';

import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/gear.dart';
import '../models/particle_effect.dart';
import '../models/vehicle_type.dart';
import '../models/weather_type.dart';
import '../weather/weather_layer.dart';
import 'analog/analog_cluster_body.dart';
import 'digital/digital_hud_body.dart';
import 'particle/particle_layer.dart';

/// Motorcycle / car dashboard with digital HUD or analog cluster styles,
/// and optional weather / particle background animation.
class AutoMotoDashboard extends StatelessWidget {
  const AutoMotoDashboard({
    super.key,
    required this.telemetry,
    this.style = DashStyle.hud,
    this.weather,
    this.particleEffect = ParticleEffect.windRush,
    this.vehicleType = VehicleType.car,
    this.lightSpeedThresholdKmh = 80,
    this.showGearSelector = true,
    this.showVehicleOutline = true,
    this.rainbowSpeed = false,
    this.backgroundColor = Colors.black,
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final WeatherType? weather;

  /// Motion particle effect; pass `null` to disable.
  final ParticleEffect? particleEffect;
  final VehicleType vehicleType;
  final double lightSpeedThresholdKmh;
  final bool showGearSelector;
  final bool showVehicleOutline;
  final bool rainbowSpeed;
  final Color backgroundColor;

  final ValueChanged<Gear>? onGearSelected;
  final VoidCallback? onGearPointerDown;

  Color get _particleAccent => switch (style) {
        DashStyle.techNeon => const Color(0xFF7C4DFF),
        DashStyle.hud => const Color(0xFF4FC3F7),
        DashStyle.performance => const Color(0xFF69F0AE),
        DashStyle.pulseBreath => const Color(0xFFFF80AB),
        DashStyle.classic => const Color(0xFF00E5FF),
        DashStyle.racing => const Color(0xFFFF1744),
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (weather != null)
            WeatherLayer(
              type: weather!,
              opacity: 1,
            ),
          if (particleEffect != null)
            ParticleLayer(
              effect: particleEffect!,
              speedKmh: telemetry.speedKmh,
              lightSpeedThresholdKmh: lightSpeedThresholdKmh,
              accent: _particleAccent,
              opacity: style.isAnalog ? 0.85 : 1,
            ),
          if (style.isDigital)
            DigitalHudBody(
              telemetry: telemetry,
              style: style,
              vehicleType: vehicleType,
              lightSpeedThresholdKmh: lightSpeedThresholdKmh,
              showGearSelector: showGearSelector,
              showVehicleOutline: showVehicleOutline,
              rainbowSpeed: rainbowSpeed,
              onGearSelected: onGearSelected,
              onGearPointerDown: onGearPointerDown,
            )
          else
            AnalogClusterBody(
              telemetry: telemetry,
              style: style,
              dimForWeather: weather != null || particleEffect != null,
              onGearSelected: onGearSelected,
              onGearPointerDown: onGearPointerDown,
            ),
        ],
      ),
    );
  }
}