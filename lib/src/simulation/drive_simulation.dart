import 'dart:math' as math;

import '../models/gear.dart';
import '../models/vehicle_trajectory.dart';
import 'road_profile.dart';

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
    RoadProfile? road,
    this.wheelbaseM = 2.9,
    this.steeringRatio = defaultSteeringRatio,
    this.laneKeepAssist = true,
  }) : road = road ?? RoadProfile(),
       _rollingInReverse = gear == Gear.reverse {
    if (!maxSpeedKmh.isFinite ||
        maxSpeedKmh <= 0 ||
        !maxReverseSpeedKmh.isFinite ||
        maxReverseSpeedKmh <= 0 ||
        !maxRpm.isFinite ||
        !idleRpm.isFinite ||
        idleRpm < 0 ||
        maxRpm < idleRpm) {
      throw ArgumentError(
        'Drive limits must be finite and positive, with maxRpm >= idleRpm.',
      );
    }
    if (!speedKmh.isFinite || !rpm.isFinite) {
      throw ArgumentError('Initial speed and RPM must be finite.');
    }
    speedKmh = speedKmh.clamp(0, maxSpeedKmh);
    rpm = rpm.clamp(idleRpm, maxRpm);
  }

  double speedKmh;
  double rpm;
  Gear gear;
  bool _rollingInReverse;

  final double maxSpeedKmh;
  final double maxReverseSpeedKmh;
  final double maxRpm;
  final double idleRpm;

  /// Latest acceleration in km/h per second (positive = speeding up).
  double accelerationKmhps = 0;

  /// Procedural road the vehicle drives on (shared with 3D views).
  final RoadProfile road;
  final double wheelbaseM;

  /// Steering-wheel degrees per road-wheel degree.
  final double steeringRatio;

  /// Default [steeringRatio]: a quick, sporty rack, so full lock is about
  /// one turn of the wheel each way (≈ 360°) instead of many.
  static const double defaultSteeringRatio = 12;

  /// Keeps the vehicle centred in the nearest lane when there is no steering
  /// input, and follows the road's bends (a demo-grade lane-keep assist).
  bool laneKeepAssist;

  /// Distance travelled along the road in metres.
  double distanceM = 0;

  /// Lateral offset from the reference lane centre (positive = right).
  double laneOffsetM = 0;

  /// Heading relative to the road tangent in radians (positive = right).
  double headingRad = 0;

  /// Road-wheel steering angle in radians (positive = right).
  double roadWheelRad = 0;

  /// Lateral acceleration in m/s².
  double lateralAccelMps2 = 0;

  /// Steering-wheel angle in degrees.
  double get steeringDeg => roadWheelRad * 180 / math.pi * steeringRatio;

  /// Road curvature under the vehicle.
  double get roadCurvature => road.curvatureAt(distanceM);

  /// Pose on the road for 3D views (`DashTelemetry.trajectory`).
  VehicleTrajectory get trajectory => VehicleTrajectory(
    laneOffsetM: laneOffsetM,
    headingDeg: headingRad * 180 / math.pi,
    steeringDeg: steeringDeg,
    roadCurvature: roadCurvature,
    distanceM: distanceM,
    lateralAccelMps2: lateralAccelMps2,
  );

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

    if (next == Gear.drive &&
        _rollingInReverse &&
        speedKmh > _reverseEngageMaxSpeed) {
      return false;
    }
    if (next == Gear.drive || next == Gear.reverse) {
      _rollingInReverse = next == Gear.reverse;
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

  /// Advances the model by [dt] seconds. [steer] is the driver's steering
  /// input from -1 (full left) to 1 (full right).
  void tick(
    double dt, {
    required bool accelerating,
    required bool braking,
    double steer = 0,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    _tickLongitudinal(dt, accelerating: accelerating, braking: braking);
    _tickLateral(dt, steer.isFinite ? steer.clamp(-1.0, 1.0) : 0);
  }

  /// Driver input after the hands have turned the wheel (keys are on/off,
  /// a real driver winds the wheel in over a moment).
  double _hands = 0;

  /// Steering kickback after a knock (road-wheel radians) and its rate:
  /// a damped spring, so the wheel jerks and settles back.
  double _kick = 0, _kickRate = 0;

  /// Road-wheel lock (radians); the steering wheel turns
  /// `maxRoadWheelRad × steeringRatio` (≈ 1 turn) to full lock.
  static const double maxRoadWheelRad = 0.52;

  /// Below this speed (m/s, ≈ 1 km/h) the car counts as stopped: the
  /// wheel neither follows the driver's buttons nor any assist.
  static const double _stoppedMps = 0.3;

  /// Lane-keep only corrects above this speed (m/s, ≈ 11 km/h); slower,
  /// a hands-off wheel simply stays where it is.
  static const double _laneKeepMinMps = 3;

  /// A bump from another vehicle: [side] -1 = hit on the left, 1 = right
  /// (0 = head-on / rear), [severity] 0..1. The front wheels are knocked
  /// away from the impact and the steering wheel jerks, then settles.
  void impact({double side = 0, double severity = 0.5}) {
    if (!side.isFinite || !severity.isFinite) return;
    final s = severity.clamp(0.0, 1.0);
    // A knock on the right pushes the front of the car to the left.
    final dir = side == 0 ? (_kick >= 0 ? 1.0 : -1.0) * 0.4 : -side.sign;
    _kickRate += dir * (1.2 + 2.5 * s);
  }

  void _tickLateral(double dt, double steer) {
    final v = speedKmh / 3.6 * (_rollingInReverse ? -1 : 1);
    final speed = v.abs();
    final k = road.curvatureAt(distanceM);
    // Feed-forward keeps the vehicle on the bend in both modes.
    final feedForward = math.atan(wheelbaseM * k);

    // Hands wind the wheel in (~0.35 s to the input) and let it go faster.
    final handRate = (steer.abs() > _hands.abs() ? 3.0 : 5.0) * dt;
    _hands += (steer - _hands).clamp(-handRate, handRate);
    if (_hands.abs() < 1e-3 && steer == 0) _hands = 0;

    // Largest road-wheel angle the tyres can use at this speed (≈ 6 m/s²
    // lateral grip), so the wheel only moves a little on the motorway.
    double gripLimit(double aLat) => speed < 1
        ? maxRoadWheelRad
        : math.atan(wheelbaseM * aLat / (speed * speed));

    double target;
    // Steering-wheel speed (°/s at the rim) the driver / assist turns at.
    double rimRate;
    final stopped = speed < _stoppedMps;
    // Stopped: the wheel stays put whatever the buttons do (no dry-steering
    // spin while parked / waiting), and the hands let go.
    if (stopped || (steer == 0 && speed <= 1.5)) _hands = 0;
    if (stopped) {
      target = roadWheelRad - _kick;
      rimRate = 0;
    } else if (_hands.abs() > 0.01) {
      final maxWheel = gripLimit(6).clamp(0.03, maxRoadWheelRad);
      target = (laneKeepAssist ? feedForward : 0) + _hands * maxWheel;
      rimRate = 360;
    } else if (laneKeepAssist && speed > _laneKeepMinMps) {
      final lane = road.laneAt(laneOffsetM);
      final error = laneOffsetM - road.laneCenter(lane);
      final lookahead = math.max(10.0, speed * 1.6);
      final headingTarget = math.atan(-error / lookahead);
      const tau = 0.9;
      final correction = math.atan(
        wheelbaseM * (headingTarget - headingRad) / (tau * speed),
      );
      final limit = gripLimit(2.0).clamp(0.01, 0.2);
      target = feedForward + correction.clamp(-limit, limit);
      rimRate = 180;
    } else if (speed > _laneKeepMinMps) {
      // Hands off: caster self-centres the wheel, quicker with speed.
      target = laneKeepAssist ? feedForward : 0;
      rimRate = math.min(30 + speed * 12, 360);
    } else {
      // Crawling with hands off: the wheel stays where it is.
      target = roadWheelRad - _kick;
      rimRate = 0;
    }
    target = target.clamp(-maxRoadWheelRad, maxRoadWheelRad);

    // Smooth, then rate-limit like a real steering rack.
    final base = roadWheelRad - _kick;
    final maxStep = rimRate / steeringRatio * math.pi / 180 * dt;
    var next = base + (target - base) * (1 - math.exp(-8 * dt));
    next = base + (next - base).clamp(-maxStep, maxStep);
    if ((target - next).abs() < 1e-4) next = target;

    // Kickback spring (≈ 2.5 Hz, well damped).
    if (_kick != 0 || _kickRate != 0) {
      const w = 2 * math.pi * 2.5, zeta = 0.45;
      _kickRate += (-w * w * _kick - 2 * zeta * w * _kickRate) * dt;
      _kick += _kickRate * dt;
      _kick = _kick.clamp(-0.3, 0.3);
      if (_kick.abs() < 1e-4 && _kickRate.abs() < 1e-3) {
        _kick = 0;
        _kickRate = 0;
      }
    }
    roadWheelRad = (next + _kick).clamp(-maxRoadWheelRad, maxRoadWheelRad);

    final yawRate = v / wheelbaseM * math.tan(roadWheelRad);
    headingRad += (yawRate - k * v * math.cos(headingRad)) * dt;
    headingRad = headingRad.clamp(-math.pi / 3, math.pi / 3);
    laneOffsetM += v * math.sin(headingRad) * dt;
    distanceM += v * math.cos(headingRad) * dt;
    lateralAccelMps2 = speed * yawRate.abs() * yawRate.sign * (v < 0 ? -1 : 1);

    // Keep the vehicle on its carriageway (kerbs / barriers).
    final left = road.carriagewayLeft + 0.9;
    final right = road.carriagewayRight - 0.9;
    if (laneOffsetM < left || laneOffsetM > right) {
      laneOffsetM = laneOffsetM.clamp(left, right);
      headingRad *= 0.5;
    }
  }

  void _tickLongitudinal(
    double dt, {
    required bool accelerating,
    required bool braking,
  }) {
    if (!speedKmh.isFinite) speedKmh = 0;
    if (!rpm.isFinite) rpm = idleRpm;
    speedKmh = speedKmh.clamp(0, maxSpeedKmh);

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
            ? (idleRpm + 900 + nextSpeed * 55).clamp(
                idleRpm,
                math.max(idleRpm, maxRpm - 500),
              )
            : (idleRpm + nextSpeed * 28).clamp(
                idleRpm,
                math.max(idleRpm, maxRpm * 0.6),
              );
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
            : (idleRpm + nextSpeed * 16).clamp(
                idleRpm,
                math.max(idleRpm, maxRpm * 0.85),
              );
        break;
    }

    speedKmh = nextSpeed;
    accelerationKmhps = (speedKmh - prevSpeed) / dt;

    final rpmT = (10 * dt).clamp(0.0, 1.0);
    rpm += (targetRpm - rpm) * rpmT;
    rpm = rpm.clamp(idleRpm.toDouble(), maxRpm.toDouble());
    if ((targetRpm - rpm).abs() < 0.5) rpm = targetRpm;
  }
}
