import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../scene/scene_model.dart';

/// Body motion and first-person camera.
///
/// The body pitches with longitudinal acceleration (squat / dive), rolls
/// with lateral acceleration (or leans on a motorcycle) and bounces over
/// road texture; the camera rides with the body and turns slightly into
/// curves like a driver's head.
class DriverCamera {
  double _pitch = 0, _pitchVel = 0;
  double _roll = 0, _rollVel = 0;
  double _bump = 0;
  double _bumpPitch = 0;
  double _lookYaw = 0;

  /// Body transform (apply to the vehicle root).
  final Matrix4 body = Matrix4.identity();

  /// [longAccel] / [latAccel] in m/s² (lat positive in a right turn),
  /// [distance] along the road, [leanDeg] for motorcycles (positive right).
  void tick(
    double dt, {
    required double longAccel,
    required double latAccel,
    required double speed,
    required double distance,
    required double lookYawTarget,
    double leanDeg = 0,
    bool motorcycle = false,
    double roughness = 1,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    dt = math.min(dt, 0.05);
    // Spring-damper toward the quasi-static attitude.
    final pitchTarget = (longAccel * 0.006).clamp(-0.05, 0.04);
    final rollTarget = motorcycle
        ? -leanDeg * math.pi / 180
        : (latAccel * 0.008).clamp(-0.06, 0.06);
    const k = 60.0, c = 11.0;
    _pitchVel += (k * (pitchTarget - _pitch) - c * _pitchVel) * dt;
    _pitch += _pitchVel * dt;
    if (motorcycle) {
      _roll += (rollTarget - _roll) * (1 - math.exp(-8 * dt));
    } else {
      _rollVel += (k * (rollTarget - _roll) - c * _rollVel) * dt;
      _roll += _rollVel * dt;
    }
    // Road texture: a few incommensurate frequencies over distance.
    final amp = math.min(1.0, speed.abs() / 25) * roughness;
    final d = distance;
    _bump =
        amp *
        (0.004 * math.sin(d * 1.9) +
            0.0025 * math.sin(d * 4.7 + 1.3) +
            0.0015 * math.sin(d * 11.3 + 0.4));
    _bumpPitch =
        amp * (0.0012 * math.sin(d * 2.3 + 0.7) + 0.0008 * math.sin(d * 6.1));
    _lookYaw += (lookYawTarget - _lookYaw) * (1 - math.exp(-3 * dt));

    // Positive pitch target = nose up (acceleration squat).
    body
      ..setIdentity()
      ..translateByDouble(0, _bump, 0, 1)
      ..rotateX(-(_pitch + _bumpPitch))
      ..rotateZ(_roll);
  }

  double get rollRad => _roll;

  /// Writes the first-person camera at [eye] (vehicle frame).
  /// [pitchDownRad] tilts the line of sight down so the dash and cluster
  /// stay in frame (a car driver looks slightly down at the road).
  void applyDriver(
    CameraDesc cam,
    Vector3 eye,
    double fovDeg, {
    double pitchDownRad = 0.14,
  }) {
    final dir = Vector3(
      math.sin(_lookYaw),
      -math.tan(pitchDownRad),
      math.cos(_lookYaw),
    );
    cam.position.setFrom(body.transformed3(eye));
    cam.target.setFrom(body.transformed3(eye + dir * 10));
    cam.up.setFrom(body.getRotation() * Vector3(0, 1, 0));
    cam
      ..fovRad = fovDeg * math.pi / 180
      ..near = 0.03
      ..far = 900;
  }

  /// Orbit around the vehicle: [yaw] 0 looks from behind, π/2 from the
  /// right side; [pitch] is the elevation angle.
  void applyOrbit(
    CameraDesc cam, {
    required double yaw,
    required double pitch,
    required double distance,
    double targetHeight = 0.7,
    double fovDeg = 50,
  }) {
    final h = math.cos(pitch) * distance;
    cam.position.setValues(
      math.sin(yaw) * h,
      targetHeight + math.sin(pitch) * distance,
      -math.cos(yaw) * h,
    );
    if (cam.position.y < 0.25) cam.position.y = 0.25;
    cam.target.setValues(0, targetHeight, 0);
    cam.up.setValues(0, 1, 0);
    cam
      ..fovRad = fovDeg * math.pi / 180
      ..near = 0.05
      ..far = 700;
  }

  /// Chase view behind and above the vehicle (instrument road view).
  void applyChase(
    CameraDesc cam, {
    double height = 3.4,
    double distance = 8,
    double fovDeg = 48,
  }) {
    cam.position.setValues(0, height, -distance);
    cam.target.setValues(_lookYaw * 8, 0.8, 14);
    cam.up.setValues(0, 1, 0);
    cam
      ..fovRad = fovDeg * math.pi / 180
      ..near = 0.1
      ..far = 600;
  }
}
