import '../models/gear.dart';

/// Simple automatic-transmission drive model for demos / mock telemetry.
///
/// Rules approximate real PRND behavior:
/// - **P**: drivetrain locked; no speed gain; engine stays near idle.
/// - **R**: reverse drive, low top speed.
/// - **N**: throttle revs the engine only; vehicle coasts, no powered accel.
/// - **D**: normal forward drive.
///
/// Shifts into **P** / **R** are blocked while moving too fast.
class DriveSimulation {
  DriveSimulation({
    this.speedKmh = 0,
    this.rpm = 800,
    this.gear = Gear.park,
    this.maxSpeedKmh = 260,
    this.maxReverseSpeedKmh = 45,
    this.maxRpm = 8000,
    this.idleRpm = 800,
  });

  double speedKmh;
  double rpm;
  Gear gear;

  final double maxSpeedKmh;
  final double maxReverseSpeedKmh;
  final double maxRpm;
  final double idleRpm;

  /// Latest acceleration in km/h per second (positive = speeding up).
  double accelerationKmhps = 0;

  static const double _parkEngageMaxSpeed = 2.5;
  static const double _reverseEngageMaxSpeed = 5.0;

  /// Attempt a gear change. Returns `false` when the shift is rejected.
  bool trySetGear(Gear next) {
    if (next == gear) return true;

    if (next == Gear.park && speedKmh > _parkEngageMaxSpeed) {
      return false;
    }
    if (next == Gear.reverse && speedKmh > _reverseEngageMaxSpeed) {
      return false;
    }
    // Leaving P while “rolling” is fine; entering D/R from P requires stop-ish.
    if (gear == Gear.park &&
        (next == Gear.drive || next == Gear.reverse) &&
        speedKmh > _parkEngageMaxSpeed) {
      return false;
    }

    gear = next;
    return true;
  }

  /// Step gears by [delta] (-1 / +1). Returns whether the shift applied.
  bool shiftBy(int delta) {
    if (delta == 0) return true;
    final values = Gear.values;
    final i = (values.indexOf(gear) + delta).clamp(0, values.length - 1);
    return trySetGear(values[i]);
  }

  void tick(
    double dt, {
    required bool accelerating,
    required bool braking,
  }) {
    if (dt <= 0) return;

    final prevSpeed = speedKmh;
    var nextSpeed = speedKmh;
    var targetRpm = idleRpm.toDouble();

    const brakeRate = 78.0;
    const coastRate = 26.0;
    const driveAccel = 58.0;
    const reverseAccel = 32.0;

    switch (gear) {
      case Gear.park:
        // Parking pawl: pull to a stop, ignore throttle for motion.
        if (nextSpeed > 0) {
          nextSpeed = (nextSpeed - brakeRate * 1.4 * dt).clamp(0, maxSpeedKmh);
        }
        targetRpm = accelerating ? idleRpm + 400 : idleRpm.toDouble();
        break;

      case Gear.neutral:
        if (braking) {
          nextSpeed -= brakeRate * dt;
        } else {
          nextSpeed -= coastRate * dt;
        }
        nextSpeed = nextSpeed.clamp(0, maxSpeedKmh);
        // Throttle only revs the engine.
        targetRpm = accelerating
            ? (idleRpm + 5200).clamp(idleRpm, maxRpm).toDouble()
            : idleRpm + nextSpeed * 4;
        break;

      case Gear.reverse:
        if (braking) {
          nextSpeed -= brakeRate * dt;
        } else if (accelerating) {
          nextSpeed += reverseAccel * dt;
        } else {
          nextSpeed -= coastRate * 1.1 * dt;
        }
        nextSpeed = nextSpeed.clamp(0, maxReverseSpeedKmh);
        targetRpm = accelerating
            ? (idleRpm + 900 + nextSpeed * 55).clamp(idleRpm, maxRpm - 500)
            : (idleRpm + nextSpeed * 28).clamp(idleRpm, maxRpm * 0.6);
        break;

      case Gear.drive:
        if (braking) {
          nextSpeed -= brakeRate * dt;
        } else if (accelerating) {
          // Milder pull at low speed, stronger mid-range (auto kick-down feel).
          final pull = driveAccel * (0.65 + 0.55 * (nextSpeed / maxSpeedKmh));
          nextSpeed += pull * dt;
        } else {
          nextSpeed -= coastRate * dt;
        }
        nextSpeed = nextSpeed.clamp(0, maxSpeedKmh);
        targetRpm = accelerating
            ? (idleRpm + 700 + nextSpeed * 26).clamp(idleRpm, maxRpm)
            : (idleRpm + nextSpeed * 16).clamp(idleRpm, maxRpm * 0.85);
        break;
    }

    speedKmh = nextSpeed;
    accelerationKmhps = (speedKmh - prevSpeed) / dt;

    final rpmT = (10 * dt).clamp(0.0, 1.0);
    rpm += (targetRpm - rpm) * rpmT;
    rpm = rpm.clamp(idleRpm.toDouble(), maxRpm.toDouble());
  }
}