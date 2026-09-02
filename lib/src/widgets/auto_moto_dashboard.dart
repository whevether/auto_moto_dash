import 'package:material_ui/material_ui.dart';

import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/gear.dart';
import '../models/particle_effect.dart';
import '../models/vehicle_type.dart';
import '../models/weather_type.dart';
import '../weather/weather_layer.dart';
import 'analog/analog_cluster_body.dart';
import 'car/car_ev_body.dart';
import 'digital/digital_hud_body.dart';
import 'motorcycle/motorcycle_cluster_body.dart';
import 'particle/particle_layer.dart';

/// Motorcycle / car dashboard with digital HUD or analog cluster styles,
/// and optional weather / particle background animation.
///
/// Layer order bottom → top: [backgroundColor] → [weather] → [particleEffect]
/// → cluster body. Pass `null` for [weather] / [particleEffect] to disable.
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

  /// Host-provided speed, RPM, gear, battery, etc.
  final DashTelemetry telemetry;

  /// Mutually exclusive visual theme.
  final DashStyle style;

  /// Animated weather; `null` disables the weather layer.
  final WeatherType? weather;

  /// Motion particle effect; pass `null` to disable.
  final ParticleEffect? particleEffect;

  /// Car vs motorcycle silhouette (digital car HUD themes).
  final VehicleType vehicleType;

  /// Speed (km/h) at which particle flow is considered “full”.
  final double lightSpeedThresholdKmh;

  /// Whether to show the P/R/N/D strip.
  final bool showGearSelector;

  /// Whether to draw the vehicle outline (digital car HUD themes).
  final bool showVehicleOutline;

  /// Rainbow-colored speed digits when true.
  final bool rainbowSpeed;

  /// Bottom fill behind weather / particles.
  final Color backgroundColor;

  /// Called when the user taps a gear position.
  final ValueChanged<Gear>? onGearSelected;

  /// Called on gear strip pointer-down (e.g. to claim gestures).
  final VoidCallback? onGearPointerDown;

  VehicleType get _effectiveVehicleType {
    if (style.isMotorcycle) return VehicleType.motorcycle;
    return VehicleType.car;
  }

  Color get _particleAccent => switch (style) {
        DashStyle.techNeon => const Color(0xFF7C4DFF),
        DashStyle.hud => const Color(0xFF4FC3F7),
        DashStyle.performance => const Color(0xFF69F0AE),
        DashStyle.pulseBreath => const Color(0xFFFF80AB),
        DashStyle.classic => const Color(0xFF00E5FF),
        DashStyle.racing => const Color(0xFFFF1744),
        DashStyle.carEvTesla => Colors.white,
        DashStyle.carEvNio => const Color(0xFF4FC3F7),
        DashStyle.carEvLi => const Color(0xFFFF9800),
        DashStyle.motoFuelTft => Colors.white,
        DashStyle.motoFuelHybrid => const Color(0xFF00E5FF),
        DashStyle.motoEvNiu => const Color(0xFF00E676),
        DashStyle.motoEvYadea => const Color(0xFF00BCD4),
      };

  Widget _buildClusterBody() {
    final dimForWeather = weather != null || particleEffect != null;

    if (style.isMotorcycle) {
      return MotorcycleClusterBody(
        telemetry: telemetry,
        style: style,
        dimForWeather: dimForWeather,
        onGearSelected: onGearSelected,
        onGearPointerDown: onGearPointerDown,
      );
    }
    if (style.isCarEv) {
      return CarEvBody(
        telemetry: telemetry,
        style: style,
        dimForWeather: dimForWeather,
        onGearSelected: onGearSelected,
        onGearPointerDown: onGearPointerDown,
      );
    }
    if (style.isDigitalHud) {
      return DigitalHudBody(
        telemetry: telemetry,
        style: style,
        vehicleType: _effectiveVehicleType,
        lightSpeedThresholdKmh: lightSpeedThresholdKmh,
        showGearSelector: showGearSelector,
        showVehicleOutline: showVehicleOutline && !style.isMotorcycle,
        rainbowSpeed: rainbowSpeed,
        dimForWeather: dimForWeather,
        onGearSelected: onGearSelected,
        onGearPointerDown: onGearPointerDown,
      );
    }
    return AnalogClusterBody(
      telemetry: telemetry,
      style: style,
      dimForWeather: weather != null || particleEffect != null,
      onGearSelected: onGearSelected,
      onGearPointerDown: onGearPointerDown,
    );
  }

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
          _buildClusterBody(),
        ],
      ),
    );
  }
}
