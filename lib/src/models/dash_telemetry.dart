import 'gear.dart';

/// Tire pressures in bar.
class TirePressures {
  const TirePressures({
    this.frontLeft = 2.9,
    this.frontRight = 2.9,
    this.rearLeft = 2.9,
    this.rearRight = 2.9,
  });

  final double frontLeft;
  final double frontRight;
  final double rearLeft;
  final double rearRight;

  TirePressures copyWith({
    double? frontLeft,
    double? frontRight,
    double? rearLeft,
    double? rearRight,
  }) {
    return TirePressures(
      frontLeft: frontLeft ?? this.frontLeft,
      frontRight: frontRight ?? this.frontRight,
      rearLeft: rearLeft ?? this.rearLeft,
      rearRight: rearRight ?? this.rearRight,
    );
  }
}

/// Host-provided vehicle telemetry for the dashboard.
class DashTelemetry {
  const DashTelemetry({
    this.speedKmh = 0,
    this.rpm = 0,
    this.maxRpm = 8000,
    this.redlineRpm = 7000,
    this.batteryPercent = 100,
    this.fuelPercent = 100,
    this.coolantTempC = 90,
    this.rangeKm = 0,
    this.odometerKm = 0,
    this.tripKm = 0,
    this.outsideTempC = 20,
    this.gear = Gear.park,
    this.gearNumber,
    this.tirePressures = const TirePressures(),
  });

  /// Vehicle speed in km/h.
  final double speedKmh;

  /// Engine / motor RPM.
  final double rpm;

  /// Gauge full-scale RPM.
  final double maxRpm;

  /// Redline start RPM (racing / shift lights).
  final double redlineRpm;

  /// Traction battery SOC 0–100.
  final double batteryPercent;

  /// Fuel level 0–100 (analog themes).
  final double fuelPercent;

  /// Coolant temperature in °C.
  final double coolantTempC;

  /// Estimated remaining range in km.
  final double rangeKm;

  /// Total odometer in km.
  final double odometerKm;

  /// Trip meter in km.
  final double tripKm;

  /// Outside ambient temperature in °C.
  final double outsideTempC;

  /// Automatic PRND position.
  final Gear gear;

  /// Manual gear number (1–6). When set, racing cluster prefers this over [gear].
  final int? gearNumber;
  final TirePressures tirePressures;

  DashTelemetry copyWith({
    double? speedKmh,
    double? rpm,
    double? maxRpm,
    double? redlineRpm,
    double? batteryPercent,
    double? fuelPercent,
    double? coolantTempC,
    double? rangeKm,
    double? odometerKm,
    double? tripKm,
    double? outsideTempC,
    Gear? gear,
    int? gearNumber,
    TirePressures? tirePressures,
  }) {
    return DashTelemetry(
      speedKmh: speedKmh ?? this.speedKmh,
      rpm: rpm ?? this.rpm,
      maxRpm: maxRpm ?? this.maxRpm,
      redlineRpm: redlineRpm ?? this.redlineRpm,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      fuelPercent: fuelPercent ?? this.fuelPercent,
      coolantTempC: coolantTempC ?? this.coolantTempC,
      rangeKm: rangeKm ?? this.rangeKm,
      odometerKm: odometerKm ?? this.odometerKm,
      tripKm: tripKm ?? this.tripKm,
      outsideTempC: outsideTempC ?? this.outsideTempC,
      gear: gear ?? this.gear,
      gearNumber: gearNumber ?? this.gearNumber,
      tirePressures: tirePressures ?? this.tirePressures,
    );
  }
}