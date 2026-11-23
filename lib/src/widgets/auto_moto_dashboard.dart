import 'package:material_ui/material_ui.dart';

import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/dash_units.dart';
import '../models/dash_view_mode.dart';
import 'view_builders.dart';
import '../models/gear.dart';
import '../models/particle_effect.dart';
import '../models/vehicle_type.dart';
import '../models/weather_type.dart';
import '../weather/weather_layer.dart';
import 'digital/digital_hud_body.dart';
import 'production/production_cluster_body.dart';
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
    this.style = DashStyle.classic,
    this.weather,
    this.particleEffect,
    this.vehicleType = VehicleType.car,
    this.lightSpeedThresholdKmh = 80,
    this.showGearSelector = true,
    this.showVehicleOutline = true,
    this.rainbowSpeed = false,
    this.backgroundColor = Colors.black,
    this.onGearSelected,
    this.onGearPointerDown,
    this.units = DashUnits.metric,
    this.brandBadgeBuilder,
    this.semanticsLabel,
    this.viewMode = DashViewMode.cluster,
    this.cockpitBuilder,
    this.roadViewBuilder,
  });

  /// Cluster only, or first-person cockpit (needs [cockpitBuilder]).
  final DashViewMode viewMode;

  /// Builds the first-person cockpit, e.g. `AutoMotoDash3D.cockpitBuilder`
  /// from `auto_moto_dash_3d.dart`. Without it [viewMode] falls back to cluster.
  final DashCockpitBuilder? cockpitBuilder;

  /// Fills the road area of road-view themes (Tesla / NIO / Li / virtual
  /// cockpit / EV split), e.g. `AutoMotoDash3D.roadViewBuilder`.
  final DashRoadViewBuilder? roadViewBuilder;

  /// Display units (telemetry itself stays metric). Defaults to metric.
  final DashUnits units;

  /// Optional badge for brand themes, e.g. a licensed logo. When set, the
  /// text wordmark is hidden and the widget is placed at the theme's badge
  /// position. Ignored by the digital HUD themes.
  final Widget Function(BuildContext context, DashStyle style)?
  brandBadgeBuilder;

  /// Overrides the generated (Chinese) accessibility label of analog /
  /// brand clusters, e.g. for localisation.
  final String? semanticsLabel;

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

  double get _flowThreshold =>
      lightSpeedThresholdKmh.isFinite && lightSpeedThresholdKmh > 0
      ? lightSpeedThresholdKmh
      : 80;

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
    _ => style.spec?.accent ?? const Color(0xFF00E5FF),
  };

  Widget _buildClusterBody(DashTelemetry data, {bool forCockpit = false}) {
    final dimForWeather =
        !forCockpit && (weather != null || particleEffect != null);
    final gears = !forCockpit && showGearSelector;

    if (!style.isDigitalHud) {
      return ProductionClusterBody(
        telemetry: data,
        style: style,
        units: units,
        brandBadgeBuilder: brandBadgeBuilder,
        semanticsLabel: semanticsLabel,
        showGearSelector: gears,
        onGearSelected: forCockpit ? null : onGearSelected,
        onGearPointerDown: forCockpit ? null : onGearPointerDown,
        roadViewBuilder: forCockpit ? null : roadViewBuilder,
      );
    }
    return DigitalHudBody(
      telemetry: data,
      style: style,
      vehicleType: vehicleType,
      units: units,
      lightSpeedThresholdKmh: _flowThreshold,
      showGearSelector: gears,
      showVehicleOutline: showVehicleOutline,
      rainbowSpeed: rainbowSpeed,
      dimForWeather: dimForWeather,
      onGearSelected: forCockpit ? null : onGearSelected,
      onGearPointerDown: forCockpit ? null : onGearPointerDown,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = telemetry.normalized();
    if (viewMode == DashViewMode.cockpit && cockpitBuilder != null) {
      return ColoredBox(
        color: backgroundColor,
        child: cockpitBuilder!(
          context,
          DashCockpitRequest(
            telemetry: data,
            style: style,
            units: units,
            weather: weather,
            cluster: ColoredBox(
              color: Colors.black,
              child: _buildClusterBody(data, forCockpit: true),
            ),
            showGearSelector: showGearSelector,
            onGearSelected: onGearSelected,
            onGearPointerDown: onGearPointerDown,
          ),
        ),
      );
    }
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (weather != null) WeatherLayer(type: weather!, opacity: 1),
          if (particleEffect != null)
            ParticleLayer(
              effect: particleEffect!,
              speedKmh: data.speedKmh,
              lightSpeedThresholdKmh: _flowThreshold,
              accent: _particleAccent,
              opacity: style.isAnalog ? 0.85 : 1,
            ),
          _buildClusterBody(data),
        ],
      ),
    );
  }
}
