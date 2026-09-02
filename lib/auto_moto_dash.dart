/// Motorcycle / car dashboard Flutter package.
///
/// Main entry: [AutoMotoDashboard]. Also exports telemetry models,
/// [DashStyle], [WeatherType], [ParticleEffect], and [DriveSimulation].
library;

export 'src/models/dash_style.dart' show DashCategory, DashStyle, DashStyleX;
export 'src/models/dash_telemetry.dart';
export 'src/models/gear.dart';
export 'src/models/particle_effect.dart';
export 'src/models/vehicle_type.dart';
export 'src/models/weather_type.dart';
export 'src/simulation/drive_simulation.dart';
export 'src/widgets/auto_moto_dashboard.dart';
export 'src/widgets/shared/overspeed_warning.dart';