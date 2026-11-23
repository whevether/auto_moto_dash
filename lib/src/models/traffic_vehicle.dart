import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Body type of a surrounding (traffic) vehicle.
enum TrafficVehicleKind {
  sedan,
  suv,
  pickup,
  van,
  truck,
  bus,
  motorcycle;

  /// Approximate body length in metres (used for spacing / collision gaps).
  double get lengthM => switch (this) {
    TrafficVehicleKind.sedan => 4.7,
    TrafficVehicleKind.suv => 4.9,
    TrafficVehicleKind.pickup => 5.6,
    TrafficVehicleKind.van => 5.2,
    TrafficVehicleKind.truck => 9.5,
    TrafficVehicleKind.bus => 12.0,
    TrafficVehicleKind.motorcycle => 2.2,
  };

  String get label => switch (this) {
    TrafficVehicleKind.sedan => '轿车',
    TrafficVehicleKind.suv => 'SUV',
    TrafficVehicleKind.pickup => '皮卡',
    TrafficVehicleKind.van => '厢式车',
    TrafficVehicleKind.truck => '货车',
    TrafficVehicleKind.bus => '公交',
    TrafficVehicleKind.motorcycle => '摩托',
  };
}

/// A surrounding vehicle in ego coordinates, e.g. from perception / ADAS.
///
/// [xM] is to the right of the ego vehicle, [zM] ahead of it (metres, from
/// ego centre to the other vehicle's centre). [headingDeg] is relative to the
/// ego heading (180 = oncoming).
@immutable
class TrafficVehicle {
  const TrafficVehicle({
    required this.id,
    this.kind = TrafficVehicleKind.sedan,
    this.xM = 0,
    this.zM = 20,
    this.headingDeg = 0,
    this.speedKmh = 0,
    this.color = const Color(0xFFB0B4B8),
    this.braking = false,
    this.leftIndicator = false,
    this.rightIndicator = false,
    this.headlights = false,
  });

  final int id;
  final TrafficVehicleKind kind;
  final double xM;
  final double zM;
  final double headingDeg;
  final double speedKmh;
  final Color color;
  final bool braking;
  final bool leftIndicator;
  final bool rightIndicator;
  final bool headlights;

  bool get isValid =>
      xM.isFinite && zM.isFinite && headingDeg.isFinite && speedKmh.isFinite;

  TrafficVehicle copyWith({
    TrafficVehicleKind? kind,
    double? xM,
    double? zM,
    double? headingDeg,
    double? speedKmh,
    Color? color,
    bool? braking,
    bool? leftIndicator,
    bool? rightIndicator,
    bool? headlights,
  }) {
    return TrafficVehicle(
      id: id,
      kind: kind ?? this.kind,
      xM: xM ?? this.xM,
      zM: zM ?? this.zM,
      headingDeg: headingDeg ?? this.headingDeg,
      speedKmh: speedKmh ?? this.speedKmh,
      color: color ?? this.color,
      braking: braking ?? this.braking,
      leftIndicator: leftIndicator ?? this.leftIndicator,
      rightIndicator: rightIndicator ?? this.rightIndicator,
      headlights: headlights ?? this.headlights,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrafficVehicle &&
          id == other.id &&
          kind == other.kind &&
          xM == other.xM &&
          zM == other.zM &&
          headingDeg == other.headingDeg &&
          speedKmh == other.speedKmh &&
          color == other.color &&
          braking == other.braking &&
          leftIndicator == other.leftIndicator &&
          rightIndicator == other.rightIndicator &&
          headlights == other.headlights;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    xM,
    zM,
    headingDeg,
    speedKmh,
    color,
    braking,
    leftIndicator,
    rightIndicator,
    headlights,
  );

  @override
  String toString() =>
      'TrafficVehicle($id ${kind.name} x:${xM.toStringAsFixed(1)} '
      'z:${zM.toStringAsFixed(1)} ${speedKmh.round()} km/h)';
}
