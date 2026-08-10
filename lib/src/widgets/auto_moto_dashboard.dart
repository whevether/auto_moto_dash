import 'package:flutter/material.dart';

import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/vehicle_type.dart';
import '../models/weather_type.dart';
import '../weather/weather_layer.dart';
import 'analog/analog_cluster_body.dart';
import 'digital/digital_hud_body.dart';

/// Motorcycle / car dashboard with digital HUD or analog cluster styles,
/// and optional weather background animation.
class AutoMotoDashboard extends StatelessWidget {
  const AutoMotoDashboard({
    super.key,
    required this.telemetry,
    this.style = DashStyle.hud,
    this.weather,
    this.vehicleType = VehicleType.car,
    this.lightSpeedThresholdKmh = 80,
    this.showGearSelector = true,
    this.showVehicleOutline = true,
    this.rainbowSpeed = false,
    this.backgroundColor = Colors.black,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final WeatherType? weather;
  final VehicleType vehicleType;
  final double lightSpeedThresholdKmh;
  final bool showGearSelector;
  final bool showVehicleOutline;
  final bool rainbowSpeed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final weatherOpacity = style.isAnalog ? 0.45 : 0.85;

    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (weather != null)
            WeatherLayer(
              type: weather!,
              opacity: weatherOpacity,
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
            )
          else
            AnalogClusterBody(
              telemetry: telemetry,
              style: style,
            ),
        ],
      ),
    );
  }
}