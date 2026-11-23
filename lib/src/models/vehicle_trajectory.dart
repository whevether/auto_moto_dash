import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Ego vehicle pose relative to the road, used by 3D road / cockpit views.
///
/// Units are SI: metres, degrees, 1/m. Positive [laneOffsetM] is to the
/// right of the reference lane centre; positive [headingDeg] / [steeringDeg]
/// turn right; positive [roadCurvature] bends the road to the right.
@immutable
class VehicleTrajectory {
  const VehicleTrajectory({
    this.laneOffsetM = 0,
    this.headingDeg = 0,
    this.steeringDeg = 0,
    this.roadCurvature = 0,
    this.distanceM,
    this.lateralAccelMps2 = 0,
    this.plannedPath = const [],
  });

  /// Lateral offset from the reference lane centre in metres.
  final double laneOffsetM;

  /// Heading relative to the road tangent in degrees.
  final double headingDeg;

  /// Steering-wheel angle in degrees (not road-wheel angle).
  final double steeringDeg;

  /// Road curvature at the vehicle in 1/m (0 = straight).
  final double roadCurvature;

  /// Cumulative distance along the road in metres. When set, 3D views follow
  /// the shared `RoadProfile` at this position; when `null` they integrate
  /// speed themselves and bend the road by [roadCurvature].
  final double? distanceM;

  /// Lateral acceleration in m/s² (positive = pushed left in a right turn).
  final double lateralAccelMps2;

  /// Optional planned path in ego coordinates (x right, y forward), metres.
  final List<Offset> plannedPath;

  static const maxSteeringDeg = 900.0;
  static const maxHeadingDeg = 90.0;
  static const maxCurvature = 0.2;

  /// Finite, clamped values safe for rendering.
  VehicleTrajectory normalized() {
    double f(double v, double limit) =>
        v.isFinite ? v.clamp(-limit, limit) : 0;
    final path = plannedPath
        .where((p) => p.dx.isFinite && p.dy.isFinite)
        .toList(growable: false);
    final result = VehicleTrajectory(
      laneOffsetM: f(laneOffsetM, 50),
      headingDeg: f(headingDeg, maxHeadingDeg),
      steeringDeg: f(steeringDeg, maxSteeringDeg),
      roadCurvature: f(roadCurvature, maxCurvature),
      distanceM: distanceM == null || !distanceM!.isFinite
          ? null
          : distanceM!.clamp(0, double.maxFinite),
      lateralAccelMps2: f(lateralAccelMps2, 30),
      plannedPath: path.length == plannedPath.length ? plannedPath : path,
    );
    return result == this ? this : result;
  }

  VehicleTrajectory copyWith({
    double? laneOffsetM,
    double? headingDeg,
    double? steeringDeg,
    double? roadCurvature,
    double? distanceM,
    bool clearDistance = false,
    double? lateralAccelMps2,
    List<Offset>? plannedPath,
  }) {
    return VehicleTrajectory(
      laneOffsetM: laneOffsetM ?? this.laneOffsetM,
      headingDeg: headingDeg ?? this.headingDeg,
      steeringDeg: steeringDeg ?? this.steeringDeg,
      roadCurvature: roadCurvature ?? this.roadCurvature,
      distanceM: clearDistance ? null : distanceM ?? this.distanceM,
      lateralAccelMps2: lateralAccelMps2 ?? this.lateralAccelMps2,
      plannedPath: plannedPath ?? this.plannedPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleTrajectory &&
          laneOffsetM == other.laneOffsetM &&
          headingDeg == other.headingDeg &&
          steeringDeg == other.steeringDeg &&
          roadCurvature == other.roadCurvature &&
          distanceM == other.distanceM &&
          lateralAccelMps2 == other.lateralAccelMps2 &&
          listEquals(plannedPath, other.plannedPath);

  @override
  int get hashCode => Object.hash(
    laneOffsetM,
    headingDeg,
    steeringDeg,
    roadCurvature,
    distanceM,
    lateralAccelMps2,
    Object.hashAll(plannedPath),
  );

  @override
  String toString() =>
      'VehicleTrajectory(offset: ${laneOffsetM.toStringAsFixed(2)} m, '
      'heading: ${headingDeg.toStringAsFixed(1)}°, '
      'steer: ${steeringDeg.toStringAsFixed(0)}°)';
}
