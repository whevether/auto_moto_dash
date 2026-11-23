import 'dart:math' as math;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:vector_math/vector_math.dart';

import '../geometry/mesh_builder.dart';
import '../scene/scene_model.dart';

/// Proportions of a parametric body (metres, x right, y up, z forward,
/// origin on the ground under the body centre).
class BodyProportions {
  const BodyProportions({
    required this.length,
    required this.width,
    required this.height,
    required this.wheelbase,
    this.wheelRadius = 0.33,
    this.clearance = 0.16,
    this.beltline = 0.63,
    this.roofStart = 0.2,
    this.roofEnd = 0.74,
    this.windscreenRake = 1.45,
    this.rearRake = 1.15,
    this.tailDrop = 0.04,
    this.hoodDrop = 0.08,
    this.bedLength = 0,
    this.boxy = false,
    this.bike = BikeStyle.naked,
    this.type = BodyType.sedan,
  });

  /// Body category; drives type-specific details (SUV cladding, coupe
  /// diffuser, pickup bed rails, ...).
  final BodyType type;

  final double length, width, height, wheelbase, wheelRadius, clearance;

  /// Beltline (window sill) height as a fraction of total height.
  final double beltline;

  /// Rear-glass base and windscreen base as fractions of length measured
  /// from the rear bumper.
  final double roofStart, roofEnd;

  /// Horizontal run of the windscreen / rear glass per metre of glass
  /// height (larger = more raked).
  final double windscreenRake, rearRake;

  /// How far the trunk deck drops below the beltline at the tail.
  final double tailDrop;

  /// How far the bonnet drops from the windscreen to the nose.
  final double hoodDrop;

  /// Open cargo bed length (pickups).
  final double bedLength;

  /// Vans, trucks and buses: vertical faces, tall glass.
  final bool boxy;

  /// Motorcycle body style (motorcycles only).
  final BikeStyle bike;
}

/// Body categories of [BodyProportions].
enum BodyType {
  sedan,
  fastback,
  coupe,
  wagon,
  suv,
  pickup,
  van,
  truck,
  bus,
  motorcycle,
}

/// Motorcycle body styles.
enum BikeStyle { sport, naked, adventure, cruiser, scooter }

/// Front grille treatments.
enum GrilleStyle { none, wide, kidney, mesh, slats }

/// Head-lamp graphics.
enum FrontLampStyle { slim, lightBar, round, quad }

/// Tail-lamp graphics.
enum RearLampStyle { pair, lightBar }

/// Brand-neutral styling cues that make one body read as a particular kind
/// of car (EV with a light bar, sports car with round lamps and a wing, a
/// premium saloon with chrome and a big grille). Not replicas of any
/// manufacturer's design.
@immutable
class VehicleSignature {
  const VehicleSignature({
    this.grille = GrilleStyle.slats,
    this.front = FrontLampStyle.slim,
    this.rear = RearLampStyle.pair,
    this.chrome = false,
    this.spoiler = false,
    this.roofRails = false,
    this.spokes = 5,
  });

  final GrilleStyle grille;
  final FrontLampStyle front;
  final RearLampStyle rear;
  final bool chrome, spoiler, roofRails;

  /// Number of rim spokes.
  final int spokes;

  /// Variety for surrounding traffic.
  static const traffic = <VehicleSignature>[
    VehicleSignature(),
    VehicleSignature(grille: GrilleStyle.wide, chrome: true, spokes: 10),
    VehicleSignature(
      grille: GrilleStyle.none,
      front: FrontLampStyle.lightBar,
      rear: RearLampStyle.lightBar,
      spokes: 6,
    ),
    VehicleSignature(grille: GrilleStyle.mesh, spokes: 7),
    VehicleSignature(grille: GrilleStyle.kidney, chrome: true, spokes: 8),
    VehicleSignature(grille: GrilleStyle.slats, roofRails: true, spokes: 6),
  ];

  @override
  bool operator ==(Object other) =>
      other is VehicleSignature &&
      grille == other.grille &&
      front == other.front &&
      rear == other.rear &&
      chrome == other.chrome &&
      spoiler == other.spoiler &&
      roofRails == other.roofRails &&
      spokes == other.spokes;

  @override
  int get hashCode =>
      Object.hash(grille, front, rear, chrome, spoiler, roofRails, spokes);
}

/// Styling cues of the theme's own car.
VehicleSignature signatureForTheme(DashStyle style) => switch (style) {
  DashStyle.carEvTesla => const VehicleSignature(
    grille: GrilleStyle.none,
    spokes: 5,
  ),
  DashStyle.carEvNio ||
  DashStyle.carEvLi ||
  DashStyle.carEvXpeng ||
  DashStyle.carEvLucid ||
  DashStyle.carEvZeekr ||
  DashStyle.carEvAito ||
  DashStyle.carEvByd => const VehicleSignature(
    grille: GrilleStyle.none,
    front: FrontLampStyle.lightBar,
    rear: RearLampStyle.lightBar,
    spokes: 6,
  ),
  DashStyle.carEvXiaomi || DashStyle.carEvTaycan => const VehicleSignature(
    grille: GrilleStyle.none,
    front: FrontLampStyle.quad,
    rear: RearLampStyle.lightBar,
    spoiler: true,
    spokes: 10,
  ),
  DashStyle.carPorsche => const VehicleSignature(
    grille: GrilleStyle.mesh,
    front: FrontLampStyle.round,
    rear: RearLampStyle.lightBar,
    spoiler: true,
    spokes: 5,
  ),
  DashStyle.racing => const VehicleSignature(
    grille: GrilleStyle.mesh,
    front: FrontLampStyle.slim,
    spoiler: true,
    spokes: 5,
  ),
  DashStyle.carBmwIdrive => const VehicleSignature(
    grille: GrilleStyle.kidney,
    chrome: true,
    spokes: 10,
  ),
  DashStyle.carMercedes || DashStyle.carAudi => const VehicleSignature(
    grille: GrilleStyle.wide,
    chrome: true,
    spokes: 10,
  ),
  DashStyle.carEvRivian => const VehicleSignature(
    grille: GrilleStyle.none,
    front: FrontLampStyle.round,
    rear: RearLampStyle.lightBar,
    roofRails: true,
    spokes: 6,
  ),
  DashStyle.carFord => const VehicleSignature(
    grille: GrilleStyle.slats,
    roofRails: false,
    spokes: 6,
  ),
  DashStyle.carVw ||
  DashStyle.carHyundai ||
  DashStyle.carNissan => const VehicleSignature(
    grille: GrilleStyle.slats,
    roofRails: true,
    spokes: 5,
  ),
  _ => const VehicleSignature(),
};

BodyProportions proportionsForTraffic(TrafficVehicleKind kind) =>
    switch (kind) {
      TrafficVehicleKind.sedan => const BodyProportions(
        type: BodyType.sedan,
        length: 4.7,
        width: 1.84,
        height: 1.45,
        wheelbase: 2.8,
        tailDrop: 0.03,
      ),
      TrafficVehicleKind.suv => const BodyProportions(
        type: BodyType.suv,
        length: 4.75,
        width: 1.93,
        height: 1.72,
        wheelbase: 2.85,
        wheelRadius: 0.37,
        clearance: 0.21,
        roofStart: 0.03,
        roofEnd: 0.75,
        windscreenRake: 1.15,
        rearRake: 0.3,
        tailDrop: 0,
        hoodDrop: 0.06,
        beltline: 0.6,
      ),
      TrafficVehicleKind.pickup => const BodyProportions(
        type: BodyType.pickup,
        length: 5.6,
        width: 2.0,
        height: 1.88,
        wheelbase: 3.5,
        wheelRadius: 0.4,
        clearance: 0.25,
        roofStart: 0.325,
        roofEnd: 0.72,
        windscreenRake: 1.0,
        rearRake: 0.08,
        beltline: 0.66,
        hoodDrop: 0.05,
        bedLength: 1.75,
      ),
      TrafficVehicleKind.van => const BodyProportions(
        type: BodyType.van,
        length: 5.2,
        width: 2.0,
        height: 2.3,
        wheelbase: 3.3,
        wheelRadius: 0.36,
        roofStart: 0.0,
        roofEnd: 0.84,
        windscreenRake: 0.6,
        rearRake: 0.02,
        tailDrop: 0,
        hoodDrop: 0.12,
        boxy: true,
        beltline: 0.45,
      ),
      TrafficVehicleKind.truck => const BodyProportions(
        type: BodyType.truck,
        length: 9.5,
        width: 2.45,
        height: 3.4,
        wheelbase: 5.2,
        wheelRadius: 0.52,
        clearance: 0.35,
        tailDrop: 0,
        boxy: true,
        beltline: 0.42,
      ),
      TrafficVehicleKind.bus => const BodyProportions(
        type: BodyType.bus,
        length: 12,
        width: 2.55,
        height: 3.2,
        wheelbase: 6.2,
        wheelRadius: 0.5,
        clearance: 0.3,
        roofStart: 0.0,
        roofEnd: 1,
        windscreenRake: 0.05,
        rearRake: 0.02,
        tailDrop: 0,
        hoodDrop: 0,
        boxy: true,
        beltline: 0.33,
      ),
      TrafficVehicleKind.motorcycle => const BodyProportions(
        type: BodyType.motorcycle,
        length: 2.15,
        width: 0.8,
        height: 1.15,
        wheelbase: 1.45,
        wheelRadius: 0.31,
      ),
    };

BodyProportions proportionsForEgo(EgoVehicleModel model) => switch (model) {
  EgoVehicleModel.sedan => proportionsForTraffic(TrafficVehicleKind.sedan),
  EgoVehicleModel.fastback => const BodyProportions(
    type: BodyType.fastback,
    length: 4.72,
    width: 1.88,
    height: 1.44,
    wheelbase: 2.88,
    wheelRadius: 0.35,
    roofStart: 0.07,
    roofEnd: 0.74,
    windscreenRake: 1.6,
    rearRake: 2.4,
    tailDrop: 0.02,
    hoodDrop: 0.1,
  ),
  EgoVehicleModel.sportCoupe => const BodyProportions(
    type: BodyType.coupe,
    length: 4.55,
    width: 1.92,
    height: 1.3,
    wheelbase: 2.55,
    wheelRadius: 0.35,
    clearance: 0.11,
    roofStart: 0.14,
    roofEnd: 0.7,
    windscreenRake: 1.9,
    rearRake: 2.2,
    tailDrop: 0.02,
    hoodDrop: 0.12,
    beltline: 0.62,
  ),
  EgoVehicleModel.suv => proportionsForTraffic(TrafficVehicleKind.suv),
  EgoVehicleModel.shootingBrake => const BodyProportions(
    type: BodyType.wagon,
    length: 4.9,
    width: 1.9,
    height: 1.5,
    wheelbase: 3.0,
    wheelRadius: 0.35,
    roofStart: 0.04,
    roofEnd: 0.74,
    windscreenRake: 1.45,
    rearRake: 0.5,
    tailDrop: 0,
    hoodDrop: 0.09,
  ),
  EgoVehicleModel.pickup => proportionsForTraffic(TrafficVehicleKind.pickup),
  EgoVehicleModel.sportBike => const BodyProportions(
    type: BodyType.motorcycle,
    length: 2.08,
    width: 0.72,
    height: 1.12,
    wheelbase: 1.42,
    wheelRadius: 0.3,
    bike: BikeStyle.sport,
  ),
  EgoVehicleModel.adventureBike => const BodyProportions(
    type: BodyType.motorcycle,
    length: 2.25,
    width: 0.95,
    height: 1.45,
    wheelbase: 1.52,
    wheelRadius: 0.34,
    bike: BikeStyle.adventure,
  ),
  EgoVehicleModel.cruiserBike => const BodyProportions(
    type: BodyType.motorcycle,
    length: 2.4,
    width: 0.95,
    height: 1.1,
    wheelbase: 1.65,
    wheelRadius: 0.32,
    bike: BikeStyle.cruiser,
  ),
  EgoVehicleModel.scooter => const BodyProportions(
    type: BodyType.motorcycle,
    length: 1.85,
    width: 0.7,
    height: 1.15,
    wheelbase: 1.3,
    wheelRadius: 0.22,
    bike: BikeStyle.scooter,
  ),
};

/// Meshes of one vehicle, split by material role so paint, glass and lamps
/// can be tinted / lit independently. Shared by every instance.
class VehicleMeshes {
  VehicleMeshes({
    required this.body,
    required this.glass,
    required this.trim,
    required this.chrome,
    required this.plate,
    required this.wheel,
    required this.rim,
    required this.tailLamps,
    required this.headLamps,
    required this.leftIndicator,
    required this.rightIndicator,
    required this.proportions,
    required this.wheelPositions,
  });

  final MeshData3D body, glass, trim, chrome, plate;

  /// Tyre (rubber, wheel well shadow) and rim (alloy). Built for a wheel on
  /// the right side (outer face +x); left wheels are turned around.
  final MeshData3D wheel, rim;
  final MeshData3D tailLamps, headLamps, leftIndicator, rightIndicator;
  final BodyProportions proportions;

  /// Wheel hub centres in vehicle space.
  final List<Vector3> wheelPositions;
}

/// Box from [a] to [c] with cross-section [w] × [d].
void _bar(MeshBuilder b, Vector3 a, Vector3 c, double w, double d) {
  final dir = c - a;
  final len = dir.length;
  if (len < 1e-6) return;
  final y = dir / len;
  final ref = y.z.abs() < 0.9 ? Vector3(0, 0, 1) : Vector3(1, 0, 0);
  final x = ref.cross(y)..normalize();
  final z = x.cross(y)..normalize();
  final mid = (a + c) / 2;
  final m = Matrix4.columns(
    Vector4(x.x, x.y, x.z, 0),
    Vector4(y.x, y.y, y.z, 0),
    Vector4(z.x, z.y, z.z, 0),
    Vector4(mid.x, mid.y, mid.z, 1),
  );
  b.withTransform(m, () => b.box(Vector3.zero(), Vector3(w, len, d)));
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

class _Parts {
  final body = MeshBuilder(), glass = MeshBuilder(), trim = MeshBuilder();
  final chrome = MeshBuilder(), plate = MeshBuilder();
  final tail = MeshBuilder(), head = MeshBuilder();
  final li = MeshBuilder(), ri = MeshBuilder();
  final tyre = MeshBuilder(), rim = MeshBuilder();

  VehicleMeshes build(BodyProportions p, List<Vector3> wheels) => VehicleMeshes(
    body: body.build(),
    glass: glass.build(),
    trim: trim.build(),
    chrome: chrome.build(),
    plate: plate.build(),
    wheel: tyre.build(),
    rim: rim.build(),
    tailLamps: tail.build(),
    headLamps: head.build(),
    leftIndicator: li.build(),
    rightIndicator: ri.build(),
    proportions: p,
    wheelPositions: wheels,
  );
}

/// Builds the shared procedural vehicles.
class ProceduralVehicle {
  /// Tyre with a hollow centre, a dark wheel well disc and an alloy rim with
  /// [spokes] spokes on the outer (+x) face.
  static void _wheel(
    _Parts o,
    double r,
    double tw, {
    required int detail,
    int spokes = 5,
  }) {
    final segs = 16 + detail * 10;
    o.tyre
      ..cylinderX(Vector3.zero(), r, tw, segments: segs, innerRadius: r * 0.7)
      // Shoulder: slightly narrower ring so the tread reads as rounded.
      ..cylinderX(
        Vector3.zero(),
        r * 0.985,
        tw * 1.04,
        segments: segs,
        caps: false,
      )
      ..cylinderX(Vector3(-tw * 0.05, 0, 0), r * 0.62, tw * 0.55, segments: 12);
    o.rim
      ..cylinderX(
        Vector3(tw * 0.1, 0, 0),
        r * 0.7,
        tw * 0.6,
        segments: segs,
        innerRadius: r * 0.62,
      )
      ..cylinderX(Vector3(tw * 0.33, 0, 0), r * 0.16, 0.035, segments: 12);
    for (var k = 0; k < spokes; k++) {
      final a = 2 * math.pi * k / spokes;
      final d = Vector3(0, math.sin(a), math.cos(a));
      _bar(
        o.rim,
        Vector3(tw * 0.3, 0, 0) + d * (r * 0.12),
        Vector3(tw * 0.24, 0, 0) + d * (r * 0.66),
        r * (spokes > 7 ? 0.07 : 0.11),
        0.03,
      );
    }
  }

  static VehicleMeshes car(
    BodyProportions p, {
    int detail = 1,
    VehicleSignature signature = const VehicleSignature(),
  }) {
    if (p.boxy && p.length > 8 && p.beltline > 0.4) return _truck(p, detail);
    final o = _Parts();
    final sig = signature;
    final hl = p.length / 2, hw = p.width / 2;
    final belt = p.height * p.beltline;
    final c = p.clearance;
    final r = p.wheelRadius;
    final tw = r * (p.boxy ? 0.78 : 0.68);
    final roofY = p.height;

    // Axles: front overhang slightly shorter than the rear one.
    final overhangs = p.length - p.wheelbase;
    final zf = hl - overhangs * (p.boxy ? 0.38 : 0.45);
    final zr = zf - p.wheelbase;
    final axles = [zf, zr];
    final archR = r + (p.boxy ? 0.08 : 0.06);
    final wx = hw - tw / 2 - 0.02;

    final zA = -hl + p.roofEnd * p.length; // windscreen base (front)
    final zC = -hl + p.roofStart * p.length; // rear glass base
    final bedEnd = p.bedLength > 0
        ? -hl + p.bedLength
        : double.negativeInfinity;
    final bedFloor = 2 * r + 0.1;

    double nose(double z) => _clamp01((z - (hl - 0.5)) / 0.5);
    double tailT(double z) => _clamp01(((-hl + 0.4) - z) / 0.4);
    double widthAt(double z) {
      final n = nose(z), t = tailT(z);
      final k = p.boxy ? 0.025 : 0.08;
      return p.width * (1 - k * n * n * n - k * 0.8 * t * t * t);
    }

    double bottomAt(double z) {
      final n = nose(z), t = tailT(z);
      var b =
          c + (p.boxy ? 0.05 : 0.16) * n * n + (p.boxy ? 0.05 : 0.12) * t * t;
      for (final za in axles) {
        final dz = z - za;
        if (dz.abs() < archR) {
          b = math.max(b, r + math.sqrt(archR * archR - dz * dz));
        }
      }
      return b;
    }

    double topAt(double z) {
      if (z < bedEnd - 0.03) return bedFloor;
      var t = belt;
      if (z > zA) {
        // Bonnet falls toward the nose, then rounds over.
        final k = _clamp01((z - zA) / (hl - zA));
        t -= p.hoodDrop * math.pow(k, 1.4);
        final u = _clamp01((z - (hl - 0.28)) / 0.28);
        t -= (1 - math.sqrt(1 - u * u)) * (p.boxy ? 0.12 : 0.2);
      } else if (z < zC) {
        final k = _clamp01((zC - z) / (zC + hl));
        t -= p.tailDrop * k * k;
        final u = _clamp01(((-hl + 0.16) - z) / 0.16);
        t -= (1 - math.sqrt(1 - u * u)) * (p.boxy ? 0.06 : 0.1);
      }
      return t;
    }

    // Stations: uniform, dense around the wheel arches and the bed step.
    final zs = <double>[
      for (var i = 0; i <= 18 + detail * 12; i++)
        -hl + p.length * i / (18 + detail * 12),
      for (final za in axles)
        for (var k = 0; k <= 8 + detail * 4; k++)
          za - archR + 2 * archR * k / (8 + detail * 4),
      if (p.bedLength > 0) ...[bedEnd - 0.04, bedEnd - 0.02],
      for (var k = 0; k <= 6; k++) hl - 0.28 * k / 6,
    ]..sort();
    final stations = <double>[];
    for (final z in zs) {
      if (z < -hl || z > hl) continue;
      if (stations.isEmpty || z - stations.last > 0.012) stations.add(z);
    }
    o.body.loft([
      for (final z in stations)
        MeshBuilder.roundedSection(
          z: z,
          width: widthAt(z),
          bottom: bottomAt(z),
          top: topAt(z),
          radius: p.boxy ? 0.07 : 0.11,
          topWidth: widthAt(z) * (p.boxy ? 0.98 : 0.93),
        ),
    ]);
    // Wheel-well liners and underbody (dark), seen through the arches.
    o.trim.box(
      Vector3(0, (c + 2 * r + 0.04) / 2, (zf + zr) / 2),
      Vector3(p.width - 2 * tw - 0.1, 2 * r + 0.04 - c, zf - zr + 2 * archR),
    );

    // Greenhouse.
    final gh = roofY - belt;
    // Roof runs from zF0 (rear) to zF1 (front).
    var zF1 = zA - gh * p.windscreenRake;
    var zF0 = zC + gh * p.rearRake;
    if (zF1 - zF0 < 0.2) {
      final m = (zF0 + zF1) / 2;
      zF0 = m - 0.1;
      zF1 = m + 0.1;
    }
    final gw = p.width * (p.boxy ? 0.96 : 0.88);
    final rw = p.width * (p.boxy ? 0.94 : 0.74);
    final cabin = <(double, double, double)>[
      (zA, belt + 0.03, gw * 0.97),
      ((zA + zF1) / 2, belt + gh * 0.62, (gw + rw) / 2),
      (zF1, roofY, rw),
      (zF0, roofY, rw),
      ((zF0 + zC) / 2, belt + gh * (p.boxy ? 0.9 : 0.6), (gw + rw) / 2),
      (zC, belt + 0.03, gw * 0.97),
    ];
    o.glass.loft([
      for (final (z, top, topW) in cabin)
        MeshBuilder.roundedSection(
          z: z,
          width: gw,
          bottom: belt - 0.04,
          top: top,
          radius: p.boxy ? 0.06 : 0.1,
          topWidth: topW,
        ),
    ]);
    // Roof skin in body colour.
    o.body.loft([
      for (final z in [zF0 - 0.04, zF1 + 0.06])
        MeshBuilder.roundedSection(
          z: z,
          width: rw * 1.0,
          bottom: roofY - 0.03,
          top: roofY + 0.02,
          radius: 0.02,
        ),
    ]);
    // Pillars: A (body), B (black), C (body, thick on saloons).
    for (final s in [-1.0, 1.0]) {
      _bar(
        o.body,
        Vector3(s * gw * 0.485, belt, zA - 0.02),
        Vector3(s * rw * 0.49, roofY, zF1),
        0.07,
        0.06,
      );
      if (!p.boxy) {
        final zb = (zA + zC) / 2 + 0.05;
        _bar(
          o.trim,
          Vector3(s * gw * 0.5, belt, zb),
          Vector3(s * rw * 0.5, roofY - 0.01, zb),
          0.09,
          0.03,
        );
      }
      _bar(
        o.body,
        Vector3(s * rw * 0.49, roofY, zF0),
        Vector3(s * gw * 0.485, belt, zC + 0.06),
        p.boxy ? 0.08 : 0.16,
        0.06,
      );
      if (sig.chrome) {
        _bar(
          o.chrome,
          Vector3(s * (gw / 2 + 0.006), belt + 0.005, zA),
          Vector3(s * (gw / 2 + 0.006), belt + 0.005, zC),
          0.012,
          0.012,
        );
      }
    }
    if (sig.roofRails ||
        p.type == BodyType.suv ||
        p.type == BodyType.wagon ||
        p.boxy && p.length < 6) {
      for (final s in [-1.0, 1.0]) {
        _bar(
          o.trim,
          Vector3(s * rw * 0.44, roofY + 0.06, zF0 + 0.02),
          Vector3(s * rw * 0.44, roofY + 0.06, zF1 - 0.05),
          0.035,
          0.03,
        );
        for (final z in [zF0 + 0.06, zF1 - 0.08]) {
          o.trim.box(
            Vector3(s * rw * 0.44, roofY + 0.035, z),
            Vector3(0.03, 0.05, 0.05),
          );
        }
      }
    }

    // Seats seen through the glass.
    if (!p.boxy && gh > 0.35) {
      final zFront = zA - 1.05;
      final rows = [zFront, if (zFront - 0.85 > zC + 0.15) zFront - 0.85];
      for (final z in rows) {
        for (final x in [-0.38, 0.38]) {
          o.trim
            ..box(
              Vector3(x * p.width / 1.84, belt + 0.02, z),
              Vector3(0.46, 0.56, 0.12),
            )
            ..box(
              Vector3(x * p.width / 1.84, belt + 0.38, z + 0.02),
              Vector3(0.24, 0.16, 0.1),
            );
        }
      }
    }

    // Pickup bed: walls and tailgate on the low deck.
    if (p.bedLength > 0) {
      for (final s in [-1.0, 1.0]) {
        o.body.box(
          Vector3(s * (hw - 0.04), (bedFloor + belt) / 2, (-hl + bedEnd) / 2),
          Vector3(0.07, belt - bedFloor, p.bedLength),
        );
      }
      o.body.box(
        Vector3(0, (bedFloor + belt) / 2, -hl + 0.035),
        Vector3(p.width - 0.04, belt - bedFloor, 0.07),
      );
      o.trim.box(
        Vector3(0, bedFloor + 0.01, (-hl + bedEnd) / 2),
        Vector3(p.width - 0.16, 0.02, p.bedLength - 0.1),
      );
    }

    // Door seams and handles.
    if (!p.boxy) {
      final zb = (zA + zC) / 2;
      final front = zf - archR - 0.08;
      final seams = p.bedLength > 0 || zA - zC < 2.2
          ? [front, front - 1.2]
          : [front, zb, zr + archR + 0.1];
      for (final s in [-1.0, 1.0]) {
        for (final z in seams) {
          final x = s * (widthAt(z) / 2 + 0.003);
          o.trim.box(
            Vector3(x, (bottomAt(z) + 0.05 + belt - 0.02) / 2, z),
            Vector3(0.006, belt - 0.07 - bottomAt(z), 0.008),
          );
        }
        for (var i = 0; i < seams.length - 1; i++) {
          final z = seams[i + 1] + 0.18;
          (sig.chrome ? o.chrome : o.body).box(
            Vector3(s * (widthAt(z) / 2 + 0.012), belt - 0.08, z),
            Vector3(0.02, 0.025, 0.13),
          );
        }
      }
    }

    // Mirrors (painted caps on black arms) with repeaters.
    for (final s in [-1.0, 1.0]) {
      final mz = zA - 0.14;
      o.trim.box(
        Vector3(s * (hw + 0.02), belt + 0.04, mz),
        Vector3(0.1, 0.05, 0.08),
      );
      o.body.ellipsoid(
        Vector3(s * (hw + 0.11), belt + 0.08, mz),
        Vector3(0.1, 0.06, 0.05),
        segments: 10,
        rings: 6,
      );
      (s < 0 ? o.li : o.ri).box(
        Vector3(s * (hw + 0.15), belt + 0.06, mz + 0.03),
        Vector3(0.06, 0.015, 0.02),
      );
    }

    // ---- Front fascia.
    final noseTop = topAt(hl);
    final frontZ = hl + 0.004;
    final lampY = noseTop - (p.boxy ? 0.16 : 0.08);
    // Lower intake, splitter and plate.
    o.trim.box(
      Vector3(0, bottomAt(hl) + 0.12, frontZ - 0.01),
      Vector3(p.width * 0.62, 0.12, 0.03),
    );
    o.plate.box(
      Vector3(0, bottomAt(hl) + 0.28, frontZ + 0.01),
      Vector3(0.44, 0.14, 0.012),
    );
    switch (sig.grille) {
      case GrilleStyle.none:
        break;
      case GrilleStyle.wide:
        o.trim.box(
          Vector3(0, lampY - 0.1, frontZ),
          Vector3(p.width * 0.42, 0.2, 0.03),
        );
        if (sig.chrome) {
          for (final dy in [-0.05, 0.0, 0.05]) {
            o.chrome.box(
              Vector3(0, lampY - 0.1 + dy, frontZ + 0.016),
              Vector3(p.width * 0.4, 0.008, 0.008),
            );
          }
          o.chrome.box(
            Vector3(0, lampY - 0.1, frontZ + 0.022),
            Vector3(0.09, 0.09, 0.01),
          );
        }
      case GrilleStyle.kidney:
        for (final s in [-1.0, 1.0]) {
          o.trim.box(
            Vector3(s * 0.13, lampY - 0.09, frontZ),
            Vector3(0.22, 0.17, 0.03),
          );
          if (sig.chrome) {
            o.chrome.box(
              Vector3(s * 0.13, lampY - 0.09, frontZ + 0.012),
              Vector3(0.235, 0.185, 0.01),
            );
          }
        }
      case GrilleStyle.mesh:
        o.trim.box(
          Vector3(0, bottomAt(hl) + 0.2, frontZ + 0.002),
          Vector3(p.width * 0.78, 0.2, 0.03),
        );
      case GrilleStyle.slats:
        o.trim.box(
          Vector3(0, lampY - 0.08, frontZ),
          Vector3(p.width * (p.boxy ? 0.6 : 0.5), 0.15, 0.03),
        );
        for (final dy in [-0.04, 0.0, 0.04]) {
          o.chrome.box(
            Vector3(0, lampY - 0.08 + dy, frontZ + 0.016),
            Vector3(p.width * (p.boxy ? 0.58 : 0.48), 0.01, 0.01),
          );
        }
    }
    final lx = hw - (p.boxy ? 0.25 : 0.27);
    switch (sig.front) {
      case FrontLampStyle.slim:
        for (final s in [-1.0, 1.0]) {
          o.head
            ..box(Vector3(s * lx, lampY, frontZ), Vector3(0.4, 0.07, 0.03))
            ..box(
              Vector3(s * (lx + 0.03), lampY + 0.045, frontZ - 0.01),
              Vector3(0.34, 0.018, 0.03),
            );
        }
      case FrontLampStyle.lightBar:
        o.head.box(
          Vector3(0, lampY + 0.04, frontZ + 0.002),
          Vector3(p.width * 0.86, 0.022, 0.03),
        );
        for (final s in [-1.0, 1.0]) {
          o.head.box(
            Vector3(s * lx, lampY - 0.08, frontZ),
            Vector3(0.24, 0.06, 0.03),
          );
        }
      case FrontLampStyle.round:
        for (final s in [-1.0, 1.0]) {
          o.head.ellipsoid(
            Vector3(s * lx, lampY, frontZ - 0.01),
            Vector3(0.095, 0.095, 0.035),
            segments: 14,
            rings: 6,
          );
        }
      case FrontLampStyle.quad:
        for (final s in [-1.0, 1.0]) {
          for (final dx in [-0.05, 0.05]) {
            for (final dy in [-0.03, 0.03]) {
              o.head.box(
                Vector3(s * lx + dx, lampY + dy, frontZ),
                Vector3(0.05, 0.035, 0.03),
              );
            }
          }
        }
    }
    for (final s in [-1.0, 1.0]) {
      (s < 0 ? o.li : o.ri).box(
        Vector3(s * (hw - 0.07), lampY - 0.02, frontZ - 0.02),
        Vector3(0.07, 0.05, 0.035),
      );
    }

    // ---- Rear.
    final tailTop = topAt(-hl);
    final rearZ = -hl - 0.004;
    final tailY = tailTop - (p.boxy ? 0.3 : 0.09);
    switch (sig.rear) {
      case RearLampStyle.pair:
        for (final s in [-1.0, 1.0]) {
          o.tail
            ..box(
              Vector3(s * (hw - 0.22), tailY, rearZ),
              Vector3(0.42, 0.09, 0.03),
            )
            ..box(
              Vector3(s * (widthAt(-hl + 0.12) / 2 + 0.002), tailY, -hl + 0.12),
              Vector3(0.012, 0.08, 0.2),
            );
        }
      case RearLampStyle.lightBar:
        o.tail.box(
          Vector3(0, tailY + 0.02, rearZ),
          Vector3(p.width * 0.9, 0.03, 0.03),
        );
        for (final s in [-1.0, 1.0]) {
          o.tail.box(
            Vector3(s * (hw - 0.2), tailY - 0.02, rearZ),
            Vector3(0.34, 0.06, 0.03),
          );
        }
    }
    if (p.boxy) {
      o.tail.box(
        Vector3(0, roofY - 0.1, rearZ),
        Vector3(p.width * 0.3, 0.04, 0.03),
      );
    } else if (p.bedLength == 0) {
      // High-mounted stop lamp at the top of the rear glass.
      o.tail.box(
        Vector3(0, roofY - 0.01, zF0 - (zF0 - zC) * 0.1),
        Vector3(0.32, 0.02, 0.03),
      );
    }
    for (final s in [-1.0, 1.0]) {
      (s < 0 ? o.li : o.ri).box(
        Vector3(s * (hw - 0.1), tailY - 0.1, rearZ),
        Vector3(0.12, 0.04, 0.03),
      );
    }
    o.plate.box(
      Vector3(0, tailY - 0.2, rearZ - 0.006),
      Vector3(0.44, 0.14, 0.012),
    );
    o.trim.box(
      Vector3(0, bottomAt(-hl) + 0.08, rearZ + 0.01),
      Vector3(p.width * 0.8, 0.12, 0.05),
    );
    if (sig.spoiler && !p.boxy) {
      final z = -hl + 0.14;
      final y = topAt(z) + 0.09;
      o.body.box(Vector3(0, y, z), Vector3(p.width * 0.82, 0.025, 0.16));
      for (final s in [-1.0, 1.0]) {
        o.trim.box(
          Vector3(s * 0.4, (topAt(z) + y) / 2, z),
          Vector3(0.03, y - topAt(z), 0.06),
        );
      }
    }

    // ---- Type-specific details.
    final type = p.type;
    final rugged = type == BodyType.suv || type == BodyType.pickup;
    final ev = sig.grille == GrilleStyle.none;
    final midZ = (zf + zr) / 2;
    final sillLen = zf - zr - 2 * archR - 0.08;
    // Black window surround where there is no chrome.
    if (!p.boxy && !sig.chrome) {
      for (final s in [-1.0, 1.0]) {
        _bar(
          o.trim,
          Vector3(s * (gw / 2 + 0.004), belt + 0.006, zA - 0.02),
          Vector3(s * (gw / 2 + 0.004), belt + 0.006, zC + 0.04),
          0.018,
          0.018,
        );
      }
    }
    if (rugged) {
      // Unpainted arch flares and lower cladding.
      for (final za in axles) {
        for (final s in [-1.0, 1.0]) {
          const n = 10;
          final rr = archR + 0.03;
          Vector3 at(int i) {
            final a = math.pi * i / n;
            return Vector3(
              s * (widthAt(za) / 2 + 0.015),
              r + math.sin(a) * rr,
              za + math.cos(a) * rr,
            );
          }

          for (var k = 0; k < n; k++) {
            _bar(o.trim, at(k), at(k + 1), 0.06, 0.06);
          }
        }
      }
      for (final s in [-1.0, 1.0]) {
        o.trim.box(
          Vector3(s * (widthAt(midZ) / 2 + 0.008), bottomAt(midZ) + 0.08, midZ),
          Vector3(0.03, 0.16, sillLen),
        );
        if (type == BodyType.pickup) {
          // Running boards.
          o.trim.box(
            Vector3(s * (widthAt(midZ) / 2 + 0.07), c + 0.05, midZ),
            Vector3(0.16, 0.035, sillLen),
          );
        }
      }
      // Skid plates and fog lamps.
      o.chrome
        ..box(
          Vector3(0, bottomAt(hl) + 0.05, hl - 0.04),
          Vector3(p.width * 0.46, 0.05, 0.1),
        )
        ..box(
          Vector3(0, bottomAt(-hl) + 0.05, -hl + 0.04),
          Vector3(p.width * 0.4, 0.05, 0.1),
        );
      for (final s in [-1.0, 1.0]) {
        o.head.box(
          Vector3(s * (hw - 0.3), bottomAt(hl) + 0.2, hl + 0.006),
          Vector3(0.12, 0.05, 0.02),
        );
      }
    } else if (!p.boxy) {
      // Painted side sills; sports cars get skirts, splitter, diffuser.
      final sport = type == BodyType.coupe;
      for (final s in [-1.0, 1.0]) {
        o.trim.box(
          Vector3(
            s * (widthAt(midZ) / 2 + (sport ? 0.02 : 0.005)),
            bottomAt(midZ) + 0.04,
            midZ,
          ),
          Vector3(sport ? 0.05 : 0.02, sport ? 0.07 : 0.05, sillLen),
        );
      }
      if (sport) {
        o.trim
          ..box(
            Vector3(0, bottomAt(hl) + 0.015, hl - 0.02),
            Vector3(p.width * 0.86, 0.025, 0.14),
          )
          ..box(
            Vector3(0, bottomAt(-hl) + 0.05, -hl + 0.05),
            Vector3(p.width * 0.62, 0.1, 0.14),
          );
        for (final x in [-0.3, -0.1, 0.1, 0.3]) {
          o.trim.box(
            Vector3(x, bottomAt(-hl) + 0.03, -hl + 0.03),
            Vector3(0.015, 0.12, 0.2),
          );
        }
      }
      if (type == BodyType.fastback && !sig.spoiler) {
        // Ducktail lip.
        final z = -hl + 0.1;
        o.body.box(
          Vector3(0, topAt(z) + 0.012, z),
          Vector3(p.width * 0.78, 0.03, 0.14),
        );
      }
      if (type == BodyType.wagon) {
        // Roof spoiler over the tailgate glass.
        o.body.box(
          Vector3(0, roofY + 0.01, zF0 - 0.06),
          Vector3(rw * 0.96, 0.03, 0.2),
        );
      }
    }
    if (type == BodyType.pickup && p.bedLength > 0) {
      // Bed rail caps, tailgate handle, tow hitch.
      for (final s in [-1.0, 1.0]) {
        o.trim.box(
          Vector3(s * (hw - 0.04), belt + 0.012, (-hl + bedEnd) / 2),
          Vector3(0.1, 0.025, p.bedLength),
        );
      }
      o.trim
        ..box(Vector3(0, belt - 0.08, -hl - 0.004), Vector3(0.22, 0.05, 0.02))
        ..box(
          Vector3(0, bottomAt(-hl) - 0.02, -hl - 0.12),
          Vector3(0.07, 0.07, 0.22),
        );
    }
    // Exhaust tips (none on EVs).
    if (!ev && !p.boxy) {
      final tips = switch (type) {
        BodyType.coupe => [-0.56, -0.44, 0.44, 0.56],
        BodyType.pickup => [0.62],
        BodyType.suv => [-0.6, 0.6],
        _ => [-0.52, 0.52],
      };
      for (final x in tips) {
        o.chrome.withTransform(
          Matrix4.translation(
            Vector3(x * p.width / 1.84, bottomAt(-hl) + 0.08, -hl - 0.02),
          )..rotateY(math.pi / 2),
          () => o.chrome.cylinderX(
            Vector3.zero(),
            type == BodyType.coupe ? 0.045 : 0.04,
            0.14,
            segments: 12,
            innerRadius: 0.03,
          ),
        );
      }
    }

    // ---- Wheels.
    _wheel(o, r, tw, detail: detail, spokes: sig.spokes);
    final wheels = <Vector3>[
      for (final z in axles)
        for (final s in [-1.0, 1.0]) Vector3(s * wx, r, z),
    ];
    return o.build(p, wheels);
  }

  /// Rigid truck: cab-over cab, chassis and a box body.
  static VehicleMeshes _truck(BodyProportions p, int detail) {
    final o = _Parts();
    final hl = p.length / 2, hw = p.width / 2;
    final r = p.wheelRadius;
    final tw = r * 0.62;
    const cabLen = 2.2;
    final cabRear = hl - cabLen;
    final cabTop = p.height - 0.3;
    final belt = p.height * p.beltline;
    final frameY = 2 * r + 0.08;
    final zf = hl - 1.25;
    final zr = zf - p.wheelbase;
    final archR = r + 0.06;
    // Cab body with front wheel arch.
    final zs = <double>[
      for (var k = 0; k <= 10; k++) cabRear + cabLen * k / 10,
      for (var k = 0; k <= 8; k++) zf - archR + 2 * archR * k / 8,
    ]..sort();
    final st = <double>[];
    for (final z in zs) {
      if (st.isEmpty || z - st.last > 0.01) st.add(z);
    }
    o.body.loft([
      for (final z in st)
        MeshBuilder.roundedSection(
          z: z,
          width: p.width - 0.04,
          bottom: (z - zf).abs() < archR
              ? r + math.sqrt(archR * archR - (z - zf) * (z - zf))
              : p.clearance + 0.25,
          top: belt,
          radius: 0.08,
        ),
    ]);
    o.glass.loft([
      for (final (z, t) in [
        (cabRear + 0.02, cabTop),
        (hl - 0.3, cabTop),
        (hl - 0.06, cabTop - 0.12),
      ])
        MeshBuilder.roundedSection(
          z: z,
          width: p.width - 0.08,
          bottom: belt - 0.04,
          top: t,
          radius: 0.08,
        ),
    ]);
    o.body
      ..box(
        Vector3(0, cabTop + 0.02, cabRear + cabLen / 2 - 0.08),
        Vector3(p.width - 0.06, 0.06, cabLen - 0.2),
      )
      // Roof deflector.
      ..loft([
        for (final (z, b, t) in [
          (cabRear + 0.1, cabTop, p.height - 0.02),
          (hl - 0.6, cabTop, cabTop + 0.05),
        ])
          MeshBuilder.roundedSection(
            z: z,
            width: p.width - 0.2,
            bottom: b,
            top: t,
            radius: 0.05,
          ),
      ]);
    for (final s in [-1.0, 1.0]) {
      _bar(
        o.body,
        Vector3(s * (hw - 0.06), belt, hl - 0.08),
        Vector3(s * (hw - 0.06), cabTop, hl - 0.3),
        0.1,
        0.08,
      );
      o.trim
        ..box(
          Vector3(s * (hw + 0.16), belt + 0.35, hl - 0.25),
          Vector3(0.06, 0.38, 0.12),
        )
        ..box(
          Vector3(s * (hw + 0.08), belt + 0.5, hl - 0.25),
          Vector3(0.18, 0.03, 0.03),
        );
    }
    // Chassis and box body.
    o.trim.box(
      Vector3(0, frameY - 0.15, (cabRear + (-hl)) / 2),
      Vector3(p.width * 0.55, 0.3, cabRear + hl),
    );
    final boxLen = cabRear - 0.15 + hl;
    o.plate.box(
      Vector3(0, (frameY + p.height) / 2, -hl + boxLen / 2),
      Vector3(p.width, p.height - frameY, boxLen),
    );
    for (final s in [-1.0, 1.0]) {
      o.trim
        ..box(
          Vector3(s * 0.3, (frameY + p.height) / 2, -hl - 0.006),
          Vector3(0.03, p.height - frameY - 0.1, 0.01),
        )
        // Side guards.
        ..box(
          Vector3(s * (hw - 0.05), frameY - 0.25, (zf + zr) / 2 - 0.3),
          Vector3(0.03, 0.12, (zf - zr) - 2 * archR - 0.8),
        );
    }
    o.trim
      ..box(
        Vector3(0, frameY - 0.05, -hl + 0.05),
        Vector3(p.width * 0.95, 0.12, 0.08),
      )
      ..box(
        Vector3(0, p.clearance + 0.35, hl + 0.01),
        Vector3(p.width * 0.95, 0.28, 0.06),
      )
      ..box(
        Vector3(0, belt - 0.3, hl + 0.01),
        Vector3(p.width * 0.55, 0.35, 0.03),
      );
    for (final s in [-1.0, 1.0]) {
      o.head.box(
        Vector3(s * (hw - 0.3), p.clearance + 0.4, hl + 0.045),
        Vector3(0.32, 0.12, 0.03),
      );
      o.tail.box(
        Vector3(s * (hw - 0.28), frameY - 0.05, -hl - 0.03),
        Vector3(0.3, 0.09, 0.03),
      );
      (s < 0 ? o.li : o.ri)
        ..box(
          Vector3(s * (hw - 0.08), p.clearance + 0.4, hl + 0.045),
          Vector3(0.1, 0.1, 0.03),
        )
        ..box(
          Vector3(s * (hw - 0.08), frameY - 0.05, -hl - 0.03),
          Vector3(0.1, 0.09, 0.03),
        );
    }
    o.tail.box(
      Vector3(0, p.height - 0.08, -hl - 0.01),
      Vector3(p.width * 0.4, 0.04, 0.02),
    );
    o.plate.box(
      Vector3(0, frameY - 0.22, -hl - 0.02),
      Vector3(0.44, 0.22, 0.012),
    );
    _wheel(o, r, tw, detail: detail, spokes: 8);
    final wx = hw - tw / 2 - 0.04;
    final wheels = <Vector3>[
      for (final z in [zf, zr, zr - 1.35])
        for (final s in [-1.0, 1.0]) Vector3(s * wx, r, z),
    ];
    return o.build(p, wheels);
  }

  /// Motorcycle with rider, shaped by [BodyProportions.bike].
  static VehicleMeshes motorcycle(BodyProportions p, {int detail = 1}) {
    final o = _Parts();
    final r = p.wheelRadius;
    final hb = p.wheelbase / 2;
    final style = p.bike;
    final scooter = style == BikeStyle.scooter;
    final seatY = switch (style) {
      BikeStyle.cruiser => 0.68,
      BikeStyle.adventure => 0.88,
      BikeStyle.scooter => 0.78,
      _ => 0.82,
    };
    final barsY = switch (style) {
      BikeStyle.sport => seatY + 0.08,
      BikeStyle.cruiser => seatY + 0.42,
      BikeStyle.adventure => seatY + 0.36,
      BikeStyle.scooter => seatY + 0.3,
      BikeStyle.naked => seatY + 0.28,
    };
    final barsZ = hb - (style == BikeStyle.cruiser ? 0.35 : 0.28);
    final barHalf = switch (style) {
      BikeStyle.sport => 0.3,
      BikeStyle.cruiser => 0.42,
      BikeStyle.adventure => 0.42,
      _ => 0.36,
    };

    // Fork (raked) and swingarm.
    final forkTop = Vector3(0, barsY - 0.06, barsZ);
    for (final s in [-1.0, 1.0]) {
      _bar(
        o.chrome,
        forkTop + Vector3(s * 0.08, 0, 0),
        Vector3(s * 0.08, r, hb),
        0.045,
        0.045,
      );
    }
    for (final s in [-1.0, 1.0]) {
      _bar(
        o.trim,
        Vector3(s * 0.1, r + 0.18, -0.15),
        Vector3(s * 0.1, r, -hb),
        0.05,
        0.07,
      );
    }
    // Engine / frame block.
    if (scooter) {
      o.trim.box(Vector3(0, r + 0.08, -hb * 0.55), Vector3(0.2, 0.22, 0.5));
    } else {
      o.trim
        ..box(Vector3(0, r + 0.12, 0.05), Vector3(0.3, 0.36, 0.5))
        ..box(Vector3(0, r + 0.32, 0.25), Vector3(0.22, 0.18, 0.25));
      // Exhaust.
      _bar(
        o.chrome,
        Vector3(0.16, r - 0.05, 0.1),
        Vector3(0.18, r + (style == BikeStyle.sport ? 0.35 : 0.1), -hb + 0.1),
        0.09,
        0.09,
      );
    }

    // Bodywork.
    switch (style) {
      case BikeStyle.sport:
        o.body
          ..loft([
            for (final (z, w, b, t) in [
              (-0.1, 0.26, r + 0.2, seatY + 0.04),
              (0.3, 0.42, r + 0.0, seatY + 0.12),
              (hb - 0.15, 0.44, r + 0.1, barsY + 0.06),
              (hb + 0.12, 0.2, r + 0.3, barsY - 0.02),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: w,
                bottom: b,
                top: t,
                radius: 0.08,
              ),
          ])
          ..loft([
            for (final (z, w, t) in [
              (-0.12, 0.26, seatY + 0.02),
              (-hb + 0.05, 0.14, seatY + 0.18),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: w,
                bottom: seatY - 0.16,
                top: t,
                radius: 0.05,
              ),
          ]);
        o.glass.box(
          Vector3(0, barsY + 0.13, hb - 0.08),
          Vector3(0.28, 0.16, 0.02),
        );
      case BikeStyle.naked:
      case BikeStyle.adventure:
        final adv = style == BikeStyle.adventure;
        o.body
          ..ellipsoid(
            Vector3(0, seatY + 0.06, 0.22),
            Vector3(adv ? 0.24 : 0.2, 0.13, 0.3),
            segments: 14,
            rings: 7,
          )
          ..loft([
            for (final (z, w, t) in [
              (-0.1, 0.24, seatY + 0.02),
              (-hb + 0.1, 0.16, seatY + 0.1),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: w,
                bottom: seatY - 0.14,
                top: t,
                radius: 0.05,
              ),
          ]);
        if (adv) {
          // Beak, tall screen and panniers.
          _bar(
            o.body,
            Vector3(0, r + 0.42, hb - 0.05),
            Vector3(0, r + 0.3, hb + 0.25),
            0.16,
            0.05,
          );
          o.glass.box(
            Vector3(0, barsY + 0.25, barsZ + 0.12),
            Vector3(0.34, 0.36, 0.02),
          );
          for (final s in [-1.0, 1.0]) {
            o.trim.box(
              Vector3(s * 0.33, seatY - 0.15, -hb + 0.25),
              Vector3(0.18, 0.36, 0.5),
            );
          }
        }
      case BikeStyle.cruiser:
        o.body
          ..ellipsoid(
            Vector3(0, seatY + 0.18, 0.28),
            Vector3(0.2, 0.12, 0.32),
            segments: 14,
            rings: 7,
          )
          // Fenders.
          ..loft([
            for (final (z, t) in [
              (hb - 0.25, r * 2 + 0.02),
              (hb + 0.3, r + 0.2),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: 0.2,
                bottom: t - 0.04,
                top: t,
                radius: 0.02,
              ),
          ])
          ..loft([
            for (final (z, t) in [
              (-hb + 0.3, r * 2 + 0.04),
              (-hb - 0.35, r + 0.25),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: 0.28,
                bottom: t - 0.06,
                top: t,
                radius: 0.03,
              ),
          ]);
        o.trim.box(Vector3(0, seatY, -0.2), Vector3(0.38, 0.08, 0.5));
      case BikeStyle.scooter:
        o.body
          ..loft([
            for (final (z, w, b, t) in [
              (hb - 0.05, 0.34, r + 0.05, barsY - 0.05),
              (hb - 0.25, 0.4, r + 0.0, barsY - 0.1),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: w,
                bottom: b,
                top: t,
                radius: 0.1,
              ),
          ])
          ..box(Vector3(0, r + 0.05, 0.05), Vector3(0.36, 0.08, 0.7))
          ..loft([
            for (final (z, w, t) in [
              (-0.25, 0.36, seatY),
              (-hb - 0.15, 0.24, seatY + 0.05),
            ])
              MeshBuilder.roundedSection(
                z: z,
                width: w,
                bottom: r + 0.05,
                top: t,
                radius: 0.08,
              ),
          ]);
        o.trim.box(Vector3(0, seatY + 0.04, -0.4), Vector3(0.34, 0.08, 0.6));
    }

    // Handlebar.
    _bar(
      o.trim,
      Vector3(-barHalf, barsY, barsZ),
      Vector3(barHalf, barsY, barsZ),
      0.03,
      0.03,
    );
    for (final s in [-1.0, 1.0]) {
      o.trim.box(
        Vector3(s * (barHalf - 0.04), barsY + 0.12, barsZ + 0.05),
        Vector3(0.08, 0.05, 0.02),
      ); // mirrors
    }

    // Rider: legs, torso, arms, helmet.
    final crouch = switch (style) {
      BikeStyle.sport => 0.75,
      BikeStyle.cruiser => -0.15,
      _ => 0.25,
    };
    final hip = Vector3(0, seatY + 0.08, -0.22);
    final torsoLen = 0.6;
    final shoulder =
        hip +
        Vector3(0, math.cos(crouch) * torsoLen, math.sin(crouch) * torsoLen);
    _bar(o.trim, hip, shoulder, 0.36, 0.22);
    o.trim.ellipsoid(
      shoulder + Vector3(0, 0.2, 0.04 + 0.08 * math.sin(crouch)),
      Vector3(0.14, 0.15, 0.16),
      segments: 12,
      rings: 7,
    );
    o.body.ellipsoid(
      shoulder + Vector3(0, 0.22, 0.06 + 0.08 * math.sin(crouch)),
      Vector3(0.12, 0.1, 0.13),
      segments: 10,
      rings: 5,
    ); // helmet colour stripe
    for (final s in [-1.0, 1.0]) {
      final hand = Vector3(s * (barHalf - 0.06), barsY, barsZ);
      final sh = shoulder + Vector3(s * 0.2, -0.05, 0);
      final elbow = (sh + hand) / 2 + Vector3(s * 0.06, -0.06, 0);
      _bar(o.trim, sh, elbow, 0.08, 0.08);
      _bar(o.trim, elbow, hand, 0.07, 0.07);
      final knee = switch (style) {
        BikeStyle.cruiser => Vector3(s * 0.22, seatY + 0.05, 0.25),
        BikeStyle.scooter => Vector3(s * 0.18, seatY - 0.05, 0.15),
        _ => Vector3(s * 0.2, seatY - 0.02, 0.12),
      };
      final foot = switch (style) {
        BikeStyle.cruiser => Vector3(s * 0.25, r + 0.05, 0.55),
        BikeStyle.scooter => Vector3(s * 0.12, r + 0.1, 0.25),
        _ => Vector3(s * 0.18, r + 0.05, -0.15),
      };
      _bar(o.trim, hip + Vector3(s * 0.12, 0, 0), knee, 0.13, 0.14);
      _bar(o.trim, knee, foot, 0.1, 0.11);
    }

    // Lamps.
    final headZ = style == BikeStyle.sport ? hb + 0.12 : hb + 0.02;
    final headY = style == BikeStyle.cruiser
        ? barsY - 0.2
        : (style == BikeStyle.sport ? barsY - 0.02 : barsY - 0.16);
    if (style == BikeStyle.cruiser || style == BikeStyle.naked) {
      o.head.ellipsoid(
        Vector3(0, headY, headZ),
        Vector3(0.09, 0.09, 0.05),
        segments: 12,
        rings: 6,
      );
    } else {
      o.head.box(Vector3(0, headY, headZ), Vector3(0.2, 0.05, 0.04));
    }
    final tailY = style == BikeStyle.sport ? seatY + 0.14 : seatY - 0.02;
    o.tail.box(Vector3(0, tailY, -hb - 0.05), Vector3(0.14, 0.05, 0.03));
    o.plate.box(Vector3(0, r + 0.32, -hb - 0.12), Vector3(0.2, 0.12, 0.01));
    for (final s in [-1.0, 1.0]) {
      (s < 0 ? o.li : o.ri)
        ..box(
          Vector3(s * 0.14, tailY - 0.06, -hb - 0.03),
          Vector3(0.04, 0.03, 0.04),
        )
        ..box(
          Vector3(s * 0.13, headY, headZ - 0.05),
          Vector3(0.04, 0.03, 0.04),
        );
    }

    // Wheels: narrow tyres, spoked or alloy.
    final tw = scooter ? 0.11 : (style == BikeStyle.cruiser ? 0.15 : 0.13);
    _wheel(
      o,
      r,
      tw,
      detail: detail,
      spokes: style == BikeStyle.adventure ? 12 : 5,
    );
    return o.build(p, [Vector3(0, r, hb), Vector3(0, r, -hb)]);
  }
}
