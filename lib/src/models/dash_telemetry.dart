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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TirePressures &&
          frontLeft == other.frontLeft &&
          frontRight == other.frontRight &&
          rearLeft == other.rearLeft &&
          rearRight == other.rearRight;

  @override
  int get hashCode =>
      Object.hashAll([frontLeft, frontRight, rearLeft, rearRight]);

  /// Finite, nonnegative pressures for instrument rendering.
  TirePressures normalized() {
    final result = TirePressures(
      frontLeft: _nonnegative(frontLeft),
      frontRight: _nonnegative(frontRight),
      rearLeft: _nonnegative(rearLeft),
      rearRight: _nonnegative(rearRight),
    );
    return result == this ? this : result;
  }

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
    this.speedLimitKmh = 120,
    this.gear = Gear.park,
    this.gearNumber,
    this.tirePressures = const TirePressures(),
    this.leftIndicator = false,
    this.rightIndicator = false,
    this.highBeam = false,
    this.parkingBrake = false,
    this.engineWarning = false,
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

  /// Speed limit in km/h; car overspeed warning when exceeded. 0 disables.
  final double speedLimitKmh;

  /// Automatic PRND position.
  final Gear gear;

  /// Manual gear number (1–6). When set, racing cluster prefers this over [gear].
  final int? gearNumber;
  final TirePressures tirePressures;

  /// Host-controlled telltales; never fabricated from speed or demo timing.
  final bool leftIndicator;
  final bool rightIndicator;
  final bool highBeam;
  final bool parkingBrake;
  final bool engineWarning;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashTelemetry &&
          speedKmh == other.speedKmh &&
          rpm == other.rpm &&
          maxRpm == other.maxRpm &&
          redlineRpm == other.redlineRpm &&
          batteryPercent == other.batteryPercent &&
          fuelPercent == other.fuelPercent &&
          coolantTempC == other.coolantTempC &&
          rangeKm == other.rangeKm &&
          odometerKm == other.odometerKm &&
          tripKm == other.tripKm &&
          outsideTempC == other.outsideTempC &&
          speedLimitKmh == other.speedLimitKmh &&
          gear == other.gear &&
          gearNumber == other.gearNumber &&
          tirePressures == other.tirePressures &&
          leftIndicator == other.leftIndicator &&
          rightIndicator == other.rightIndicator &&
          highBeam == other.highBeam &&
          parkingBrake == other.parkingBrake &&
          engineWarning == other.engineWarning;

  @override
  int get hashCode => Object.hashAll([
    speedKmh,
    rpm,
    maxRpm,
    redlineRpm,
    batteryPercent,
    fuelPercent,
    coolantTempC,
    rangeKm,
    odometerKm,
    tripKm,
    outsideTempC,
    speedLimitKmh,
    gear,
    gearNumber,
    tirePressures,
    leftIndicator,
    rightIndicator,
    highBeam,
    parkingBrake,
    engineWarning,
  ]);

  /// Returns finite, renderable values without changing host telemetry.
  /// Negative speeds display their magnitude; invalid levels fall back to zero.
  /// Valid instances retain their identity so static painters can skip work.
  DashTelemetry normalized() {
    final scale = maxRpm.isFinite && maxRpm > 0
        ? maxRpm.clamp(1000.0, 30000.0)
        : 8000.0;
    final result = copyWith(
      speedKmh: speedKmh.isFinite ? speedKmh.abs().clamp(0, 999) : 0,
      rpm: _nonnegative(rpm).clamp(0, scale),
      maxRpm: scale,
      redlineRpm: _finite(redlineRpm, scale).clamp(0, scale),
      batteryPercent: _nonnegative(batteryPercent).clamp(0, 100),
      fuelPercent: _nonnegative(fuelPercent).clamp(0, 100),
      coolantTempC: _finite(coolantTempC, 90),
      rangeKm: _nonnegative(rangeKm),
      odometerKm: _nonnegative(odometerKm),
      tripKm: _nonnegative(tripKm),
      outsideTempC: _finite(outsideTempC, 20),
      speedLimitKmh: _nonnegative(speedLimitKmh),
      clearGearNumber:
          gearNumber != null && (gearNumber! < 1 || gearNumber! > 6),
      tirePressures: tirePressures.normalized(),
    );
    return result == this ? this : result;
  }

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
    double? speedLimitKmh,
    Gear? gear,
    int? gearNumber,
    bool clearGearNumber = false,
    TirePressures? tirePressures,
    bool? leftIndicator,
    bool? rightIndicator,
    bool? highBeam,
    bool? parkingBrake,
    bool? engineWarning,
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
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      gear: gear ?? this.gear,
      gearNumber: clearGearNumber ? null : gearNumber ?? this.gearNumber,
      tirePressures: tirePressures ?? this.tirePressures,
      leftIndicator: leftIndicator ?? this.leftIndicator,
      rightIndicator: rightIndicator ?? this.rightIndicator,
      highBeam: highBeam ?? this.highBeam,
      parkingBrake: parkingBrake ?? this.parkingBrake,
      engineWarning: engineWarning ?? this.engineWarning,
    );
  }
}

double _finite(double value, double fallback) =>
    value.isFinite ? value : fallback;

double _nonnegative(double value) => value.isFinite && value > 0 ? value : 0;
