import 'package:material_ui/material_ui.dart';

import '../models/dash_style.dart';
import '../models/dash_telemetry.dart';
import '../models/dash_units.dart';
import '../models/gear.dart';
import '../models/weather_type.dart';

/// Inputs for a host-supplied road view drawn inside a cluster's road area.
@immutable
class DashRoadViewRequest {
  const DashRoadViewRequest({
    required this.telemetry,
    required this.style,
    required this.units,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final DashUnits units;
}

/// Builds the road area of road-view themes (see
/// `ProductionClusterPainter.roadRectFor`), e.g. a live 3D scene.
typedef DashRoadViewBuilder =
    Widget Function(BuildContext context, DashRoadViewRequest request);

/// Inputs for a host-supplied first-person cockpit view.
@immutable
class DashCockpitRequest {
  const DashCockpitRequest({
    required this.telemetry,
    required this.style,
    required this.units,
    required this.cluster,
    this.weather,
    this.showGearSelector = true,
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final DashUnits units;

  /// The theme's instrument cluster (no background layers or gear strip),
  /// ready to be captured as a texture for the in-cabin display.
  final Widget cluster;

  /// Weather outside the windscreen.
  final WeatherType? weather;
  final bool showGearSelector;
  final ValueChanged<Gear>? onGearSelected;
  final VoidCallback? onGearPointerDown;
}

/// Builds the first-person cockpit for `DashViewMode.cockpit`.
typedef DashCockpitBuilder =
    Widget Function(BuildContext context, DashCockpitRequest request);
