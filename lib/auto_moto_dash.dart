/// Motorcycle / car dashboard Flutter package.
///
/// Main entry: [AutoMotoDashboard]. Also exports telemetry models,
/// [DashStyle], [WeatherType], [ParticleEffect], and [DriveSimulation].
/// The first-person 3D cockpit lives in `package:auto_moto_dash/auto_moto_dash_3d.dart`
/// (same package), which plugs in through [DashCockpitBuilder] /
/// [DashRoadViewBuilder].
library;

export 'src/models/cluster_spec.dart'
    show ClusterLayout, ClusterSpec, ClusterSpecs;
export 'src/models/cockpit_spec.dart';
export 'src/models/dash_style.dart' show DashCategory, DashStyle, DashStyleX;
export 'src/models/dash_telemetry.dart';
export 'src/models/dash_units.dart';
export 'src/models/dash_view_mode.dart';
export 'src/models/ego_vehicle_model.dart';
export 'src/models/gear.dart';
export 'src/models/particle_effect.dart';
export 'src/models/traffic_vehicle.dart';
export 'src/models/vehicle_trajectory.dart';
export 'src/models/vehicle_type.dart';
export 'src/models/weather_type.dart';
export 'src/painters/production_cluster_painter.dart'
    show ProductionClusterPainter;
export 'src/simulation/drive_simulation.dart';
export 'src/simulation/road_profile.dart';
export 'src/widgets/auto_moto_dashboard.dart';
export 'src/widgets/shared/gear_selector.dart';
export 'src/widgets/shared/overspeed_warning.dart';
export 'src/widgets/view_builders.dart';
