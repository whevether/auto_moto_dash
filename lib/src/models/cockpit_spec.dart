import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'cluster_spec.dart';
import 'dash_style.dart';
import 'ego_vehicle_model.dart';

/// Steering control drawn in the first-person cockpit.
enum SteeringControl { round, flatBottom, yoke, handlebar }

/// Where the instrument cluster sits in the cockpit.
enum ClusterPlacement {
  /// Cluster behind the wheel under a hooded binnacle.
  binnacle,

  /// Thin free-standing strip display behind the wheel.
  slimStrip,

  /// No driver display; instruments live on the centre screen.
  centerDisplay,

  /// One wide glass panel spanning driver and centre displays.
  widePanel,

  /// Motorcycle TFT / LCD on the top yoke.
  motoTft,
}

/// Centre (infotainment) screen layout.
enum CenterScreen { none, landscape, portrait, floating }

/// Geometry and trim of the first-person cockpit for a theme.
///
/// Dimensions are metres in the ego frame (x right, y up, z forward, origin
/// on the ground under the vehicle centre). Interiors are generic layouts,
/// not replicas of any manufacturer's design.
@immutable
class CockpitSpec {
  const CockpitSpec({
    this.steering = SteeringControl.round,
    this.cluster = ClusterPlacement.binnacle,
    this.centerScreen = CenterScreen.floating,
    this.hud = false,
    this.eyeHeightM = 1.18,
    this.eyeLateralM = -0.37,
    this.eyeZM = -0.15,
    this.fovDeg = 52,
    this.clusterWidthM = 0.34,
    this.centerScreenWidthM = 0.30,
    this.dashColor = const Color(0xFF1B1D20),
    this.dashTopColor = const Color(0xFF111214),
    this.trimColor = const Color(0xFF8A9096),
    this.pillarColor = const Color(0xFF2A2C2F),
    this.headlinerColor = const Color(0xFF3A3B3D),
    this.ambientColor = const Color(0xFF4FC3F7),
    this.wheelColor = const Color(0xFF1A1A1B),
    this.motorcycle = false,
  });

  final SteeringControl steering;
  final ClusterPlacement cluster;
  final CenterScreen centerScreen;

  /// Draws a head-up display projected onto the windscreen.
  final bool hud;

  /// Driver eye point.
  final double eyeHeightM;
  final double eyeLateralM;
  final double eyeZM;

  /// Vertical field of view in degrees.
  final double fovDeg;

  /// Physical width of the driver display.
  final double clusterWidthM;
  final double centerScreenWidthM;

  final Color dashColor;
  final Color dashTopColor;
  final Color trimColor;
  final Color pillarColor;
  final Color headlinerColor;
  final Color ambientColor;
  final Color wheelColor;

  /// Rider view: handlebar, windscreen and tank instead of a cabin.
  final bool motorcycle;

  CockpitSpec copyWith({
    SteeringControl? steering,
    ClusterPlacement? cluster,
    CenterScreen? centerScreen,
    bool? hud,
    double? eyeHeightM,
    double? eyeLateralM,
    double? eyeZM,
    double? fovDeg,
    double? clusterWidthM,
    double? centerScreenWidthM,
    Color? dashColor,
    Color? dashTopColor,
    Color? trimColor,
    Color? pillarColor,
    Color? headlinerColor,
    Color? ambientColor,
    Color? wheelColor,
    bool? motorcycle,
  }) {
    return CockpitSpec(
      steering: steering ?? this.steering,
      cluster: cluster ?? this.cluster,
      centerScreen: centerScreen ?? this.centerScreen,
      hud: hud ?? this.hud,
      eyeHeightM: eyeHeightM ?? this.eyeHeightM,
      eyeLateralM: eyeLateralM ?? this.eyeLateralM,
      eyeZM: eyeZM ?? this.eyeZM,
      fovDeg: fovDeg ?? this.fovDeg,
      clusterWidthM: clusterWidthM ?? this.clusterWidthM,
      centerScreenWidthM: centerScreenWidthM ?? this.centerScreenWidthM,
      dashColor: dashColor ?? this.dashColor,
      dashTopColor: dashTopColor ?? this.dashTopColor,
      trimColor: trimColor ?? this.trimColor,
      pillarColor: pillarColor ?? this.pillarColor,
      headlinerColor: headlinerColor ?? this.headlinerColor,
      ambientColor: ambientColor ?? this.ambientColor,
      wheelColor: wheelColor ?? this.wheelColor,
      motorcycle: motorcycle ?? this.motorcycle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CockpitSpec &&
          steering == other.steering &&
          cluster == other.cluster &&
          centerScreen == other.centerScreen &&
          hud == other.hud &&
          eyeHeightM == other.eyeHeightM &&
          eyeLateralM == other.eyeLateralM &&
          eyeZM == other.eyeZM &&
          fovDeg == other.fovDeg &&
          clusterWidthM == other.clusterWidthM &&
          centerScreenWidthM == other.centerScreenWidthM &&
          dashColor == other.dashColor &&
          dashTopColor == other.dashTopColor &&
          trimColor == other.trimColor &&
          pillarColor == other.pillarColor &&
          headlinerColor == other.headlinerColor &&
          ambientColor == other.ambientColor &&
          wheelColor == other.wheelColor &&
          motorcycle == other.motorcycle;

  @override
  int get hashCode => Object.hash(
    steering,
    cluster,
    centerScreen,
    hud,
    eyeHeightM,
    eyeLateralM,
    eyeZM,
    fovDeg,
    clusterWidthM,
    centerScreenWidthM,
    dashColor,
    dashTopColor,
    trimColor,
    pillarColor,
    headlinerColor,
    ambientColor,
    wheelColor,
    motorcycle,
  );
}

double _eyeHeight(EgoVehicleModel model) => switch (model) {
  EgoVehicleModel.sportCoupe => 1.04,
  EgoVehicleModel.fastback => 1.13,
  EgoVehicleModel.suv => 1.45,
  EgoVehicleModel.pickup => 1.55,
  EgoVehicleModel.shootingBrake => 1.18,
  _ => 1.17,
};

/// Theme → cockpit mapping.
extension DashStyleCockpit on DashStyle {
  CockpitSpec get cockpit {
    final override = spec?.cockpit;
    if (override != null) return override;
    final model = egoVehicle;
    if (isMotorcycle) {
      return CockpitSpec(
        steering: SteeringControl.handlebar,
        cluster: ClusterPlacement.motoTft,
        centerScreen: CenterScreen.none,
        motorcycle: true,
        eyeLateralM: 0,
        eyeZM: -0.35,
        eyeHeightM: switch (model) {
          EgoVehicleModel.adventureBike => 1.55,
          EgoVehicleModel.cruiserBike => 1.3,
          EgoVehicleModel.scooter => 1.4,
          _ => 1.45,
        },
        fovDeg: 60,
        clusterWidthM: switch (model) {
          EgoVehicleModel.scooter => 0.2,
          EgoVehicleModel.cruiserBike => 0.16,
          _ => 0.18,
        },
        dashColor: const Color(0xFF141516),
        trimColor: spec?.accent ?? const Color(0xFF9AA0A6),
        wheelColor: const Color(0xFF1C1C1D),
      );
    }
    final base = CockpitSpec(
      eyeHeightM: _eyeHeight(model),
      trimColor: spec?.accent ?? const Color(0xFF8A9096),
      ambientColor: spec?.accent ?? const Color(0xFF4FC3F7),
    );
    return switch (this) {
      DashStyle.carEvTesla => base.copyWith(
        steering: SteeringControl.yoke,
        cluster: ClusterPlacement.centerDisplay,
        centerScreen: CenterScreen.landscape,
        centerScreenWidthM: 0.42,
        dashColor: const Color(0xFF16171A),
        trimColor: const Color(0xFFD9D4CA),
        ambientColor: const Color(0xFFFFFFFF),
      ),
      DashStyle.carEvNio => base.copyWith(
        cluster: ClusterPlacement.slimStrip,
        clusterWidthM: 0.27,
        centerScreen: CenterScreen.floating,
        dashColor: const Color(0xFF2A2725),
        trimColor: const Color(0xFFB8A58C),
        ambientColor: const Color(0xFF4FC3F7),
      ),
      DashStyle.carEvLi => base.copyWith(
        cluster: ClusterPlacement.slimStrip,
        clusterWidthM: 0.22,
        hud: true,
        centerScreen: CenterScreen.landscape,
        centerScreenWidthM: 0.38,
        dashColor: const Color(0xFF3B3A37),
        trimColor: const Color(0xFFC9BBA2),
        ambientColor: const Color(0xFFFF9800),
      ),
      DashStyle.carMercedes => base.copyWith(
        cluster: ClusterPlacement.widePanel,
        clusterWidthM: 0.34,
        centerScreen: CenterScreen.landscape,
        centerScreenWidthM: 0.36,
        trimColor: const Color(0xFFC0C4C8),
        ambientColor: const Color(0xFFE040FB),
      ),
      DashStyle.racing => base.copyWith(
        steering: SteeringControl.flatBottom,
        centerScreen: CenterScreen.none,
        fovDeg: 50,
        dashColor: const Color(0xFF121212),
        trimColor: const Color(0xFFFFD600),
        ambientColor: const Color(0xFFFF1744),
      ),
      DashStyle.carEvXiaomi || DashStyle.carEvTaycan => base.copyWith(
        steering: SteeringControl.flatBottom,
        cluster: ClusterPlacement.slimStrip,
        clusterWidthM: 0.3,
      ),
      DashStyle.carPorsche => base.copyWith(
        centerScreen: CenterScreen.landscape,
        trimColor: const Color(0xFFB0B4B8),
      ),
      DashStyle.hud => base.copyWith(
        hud: true,
        cluster: ClusterPlacement.slimStrip,
        clusterWidthM: 0.26,
      ),
      _ => base.copyWith(
        cluster: ClusterPlacement.binnacle,
        centerScreen: spec?.layout == ClusterLayout.evStrip
            ? CenterScreen.portrait
            : CenterScreen.floating,
      ),
    };
  }
}
