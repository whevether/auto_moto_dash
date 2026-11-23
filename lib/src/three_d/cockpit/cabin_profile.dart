import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Cabin categories with distinct interior architecture.
enum CabinKind { sedan, fastback, coupe, wagon, suv, pickup }

/// Interior architecture of a car body style, relative to the driver's eye
/// (metres; z forward, y up). It shapes the windscreen rake, roof height,
/// cabin width, pillars and the bonnet seen through the glass so the view
/// from the seat matches the vehicle: a low raked coupe with fender peaks,
/// an upright SUV over a long flat bonnet, a boxy pickup with a power bulge.
@immutable
class CabinProfile {
  const CabinProfile({
    this.kind = CabinKind.sedan,
    this.halfWidth = 0.78,
    this.glassBaseDz = 1.02,
    this.glassTopDz = 0.30,
    this.roofDy = 0.30,
    this.glassBaseDy = 0.31,
    this.hoodLength = 1.9,
    this.hoodFall = 0.26,
    this.hoodRadius = 0.12,
    this.hoodWidth = 1.66,
    this.fenderRise = 0.015,
    this.hoodBulge = 0,
    this.pillarWidth = 0.1,
    this.grabHandles = false,
    this.sport = false,
  });

  final CabinKind kind;

  /// Inner half width of the cabin at the dash.
  final double halfWidth;

  /// Windscreen base / header ahead of the eye.
  final double glassBaseDz, glassTopDz;

  /// Headliner above the eye.
  final double roofDy;

  /// Lowest windscreen base below the eye (the dash pad may sit higher).
  final double glassBaseDy;

  /// Visible bonnet: length, drop toward the nose, edge rounding, width.
  final double hoodLength, hoodFall, hoodRadius, hoodWidth;

  /// Fender crowns standing above the bonnet (sports cars).
  final double fenderRise;

  /// Raised centre section of the bonnet (SUV / pickup).
  final double hoodBulge;

  /// A-pillar thickness.
  final double pillarWidth;

  /// Grab handles on the passenger side (off-road / utility).
  final bool grabHandles;

  /// Sports trim: dark technical trim, contrast stitching, paddles and a
  /// start button.
  final bool sport;

  bool get rugged => kind == CabinKind.suv || kind == CabinKind.pickup;

  static const sedan = CabinProfile();

  static const fastback = CabinProfile(
    kind: CabinKind.fastback,
    glassBaseDz: 1.1,
    glassTopDz: 0.26,
    roofDy: 0.27,
    hoodFall: 0.3,
    fenderRise: 0.035,
  );

  static const coupe = CabinProfile(
    kind: CabinKind.coupe,
    halfWidth: 0.76,
    glassBaseDz: 1.22,
    glassTopDz: 0.2,
    roofDy: 0.22,
    glassBaseDy: 0.29,
    hoodLength: 1.8,
    hoodFall: 0.34,
    hoodRadius: 0.1,
    hoodWidth: 1.7,
    fenderRise: 0.07,
    pillarWidth: 0.09,
    sport: true,
  );

  static const wagon = CabinProfile(
    kind: CabinKind.wagon,
    roofDy: 0.31,
    hoodFall: 0.24,
  );

  static const suv = CabinProfile(
    kind: CabinKind.suv,
    halfWidth: 0.82,
    glassBaseDz: 0.92,
    glassTopDz: 0.42,
    roofDy: 0.38,
    glassBaseDy: 0.3,
    hoodLength: 2.1,
    hoodFall: 0.1,
    hoodRadius: 0.08,
    hoodWidth: 1.78,
    fenderRise: 0,
    hoodBulge: 0.03,
    pillarWidth: 0.12,
    grabHandles: true,
  );

  static const pickup = CabinProfile(
    kind: CabinKind.pickup,
    halfWidth: 0.84,
    glassBaseDz: 0.86,
    glassTopDz: 0.46,
    roofDy: 0.4,
    glassBaseDy: 0.29,
    hoodLength: 2.3,
    hoodFall: 0.06,
    hoodRadius: 0.04,
    hoodWidth: 1.86,
    fenderRise: 0,
    hoodBulge: 0.05,
    pillarWidth: 0.13,
    grabHandles: true,
  );

  /// Cabin matching [model] (motorcycles use the rider layout instead).
  static CabinProfile forModel(EgoVehicleModel model) => switch (model) {
    EgoVehicleModel.fastback => fastback,
    EgoVehicleModel.sportCoupe => coupe,
    EgoVehicleModel.shootingBrake => wagon,
    EgoVehicleModel.suv => suv,
    EgoVehicleModel.pickup => pickup,
    _ => sedan,
  };
}
