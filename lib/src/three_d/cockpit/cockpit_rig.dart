import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:vector_math/vector_math.dart';

import '../geometry/mesh_builder.dart';
import '../scene/scene_model.dart';
import '../vehicles/vehicle_models.dart' show ModelCabin;
import 'cabin_profile.dart';

export 'cabin_profile.dart';

/// Texture slot of the instrument cluster image.
const clusterSlot = 'cluster';

/// Cluster texture aspect ratios (width / height).
const carClusterAspect = 2.4;
const motoClusterAspect = 5 / 3;

/// Steering-wheel geometry (wheel frame: x right, y along the rim plane
/// towards the top, z away from the driver).
const double wheelRimRadius = 0.185;
const double wheelRimTube = 0.017;
const double wheelTiltRad = 0.40;

/// Top of the hub / airbag in the wheel frame.
const double wheelHubTop = 0.06;

/// Where the driver display goes and how big it is.
typedef ClusterFit = ({Vector3 centre, double width, double tilt});

/// Places a driver display of [aspect] at about [distance] ahead of [eye]
/// so that it is seen in full through the steering wheel's upper opening
/// (inside the rim, above the hub) when the wheel is straight.
///
/// The largest rectangle of the display's aspect that fits in the opening
/// (with a margin for the rim tube) is projected from the eye onto the
/// display plane; the display is the inscribed rectangle of that
/// projection, capped at [maxWidth].
ClusterFit fitClusterInWheel({
  required Vector3 eye,
  required Matrix4 wheelFrame,
  required double maxWidth,
  double distance = 0.72,
  double aspect = carClusterAspect,
  double tilt = 0.12,
  double margin = 0.012,
}) {
  final ri = wheelRimRadius - wheelRimTube - margin;
  final y0 = wheelHubTop + margin;
  // (aspect·h/2)² + (y0 + h)² = ri²
  final qa = aspect * aspect / 4 + 1, qb = 2 * y0, qc = y0 * y0 - ri * ri;
  final h = (-qb + math.sqrt(qb * qb - 4 * qa * qc)) / (2 * qa);
  final hw = aspect * h / 2;
  final mid = wheelFrame.transformed3(Vector3(0, y0 + h / 2, 0));
  final dir = mid - eye;
  final p0 = eye + dir * (distance / dir.z);
  final n = Vector3(0, math.sin(tilt), -math.cos(tilt));
  final up = Vector3(0, math.cos(tilt), math.sin(tilt));
  var halfW = double.infinity, top = double.infinity;
  var bottom = double.negativeInfinity;
  for (final (x, y, isTop) in [
    (-hw, y0 + h, true),
    (hw, y0 + h, true),
    (-hw, y0, false),
    (hw, y0, false),
  ]) {
    final q = wheelFrame.transformed3(Vector3(x, y, 0));
    final d = q - eye;
    final p = eye + d * ((p0 - eye).dot(n) / d.dot(n));
    final local = p - p0;
    halfW = math.min(halfW, (local.x).abs());
    final u = local.dot(up);
    if (isTop) {
      top = math.min(top, u);
    } else {
      bottom = math.max(bottom, u);
    }
  }
  final width = math.min(
    math.min(2 * halfW, (top - bottom) * aspect),
    maxWidth,
  );
  return (centre: p0 + up * ((top + bottom) / 2), width: width, tilt: tilt);
}

/// Adds a box spanning from [a] to [b] (thickness [w] × [d]).
void beam(MeshBuilder b, Vector3 a, Vector3 c, double w, double d) {
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

/// Handles to the animated parts of a cockpit.
class CockpitRig {
  CockpitRig._(this.spec, this.eye, this.cabin);

  final CockpitSpec spec;

  /// Interior architecture of the body style.
  final CabinProfile cabin;

  /// Driver eye point in the vehicle frame.
  final Vector3 eye;

  late final int root;
  int? steeringNode;
  Matrix4 steeringBase = Matrix4.identity();
  final List<(int, Matrix4)> wipers = [];

  /// Material showing the cluster texture (-1 when none).
  int clusterMaterial = -1;

  /// Driver display behind the wheel (null for centre-display and rider
  /// layouts).
  ClusterFit? driverDisplay;
  int? paintMaterial;
  int? ambientMaterial;

  /// Rain on the windscreen.
  QuadBatchMesh? drops;
  int? dropsMesh;
  Vector3 _glassBase = Vector3.zero(), _glassUp = Vector3(0, 1, 0);
  double _glassLength = 0;
  final List<Vector3> _pivots = [];
  double _armLength = 0;

  /// Front of the own car's body and its width (vehicle frame), so the
  /// bonnet seen from the seat ends at the real nose and spans the real
  /// fenders.
  double? _noseZ, _bodyWidth;
  final List<_Drop> _drops = [];
  double _wiperAngle = 0, _wiperPhase = 0;
  final math.Random _rng = math.Random(5);

  bool get motorcycle => spec.motorcycle;

  /// Builds the cockpit for [spec] under [parent].
  static CockpitRig build(
    SceneModel model,
    int parent,
    CockpitSpec spec, {
    required Color paint,
    CabinProfile cabin = CabinProfile.sedan,
    double? noseZ,
    double? bodyWidth,
  }) {
    final eye = Vector3(spec.eyeLateralM, spec.eyeHeightM, spec.eyeZM);
    final rig = CockpitRig._(spec, eye, cabin);
    rig._noseZ = noseZ;
    rig._bodyWidth = bodyWidth;
    rig.root = model.group(parent, name: 'cockpit');
    if (spec.motorcycle) {
      rig._buildMoto(model, paint);
    } else {
      rig._buildCar(model, paint);
    }
    return rig;
  }

  /// Cockpit for a vehicle model with its own cabin: the model provides
  /// seats, dash, wheel and pillars; this only adds the live driver
  /// display, fitted into the model's steering-wheel opening just behind
  /// the rim so the model's dash never covers it.
  static CockpitRig forModel(
    SceneModel model,
    int parent,
    CockpitSpec spec,
    ModelCabin modelCabin, {
    CabinProfile cabin = CabinProfile.sedan,
  }) {
    final eye = modelCabin.eye;
    final rig = CockpitRig._(spec, eye, cabin);
    rig.root = model.group(parent, name: 'cockpit');
    final frame = modelCabin.wheelFrame(wheelRimRadius);
    final fit = fitClusterInWheel(
      eye: eye,
      wheelFrame: frame,
      maxWidth: spec.clusterWidthM,
      distance: modelCabin.hub.z - eye.z + 0.07,
    );
    rig.driverDisplay = fit;
    rig.clusterMaterial = rig._screen(
      model,
      fit.centre,
      fit.width,
      carClusterAspect,
      fit.tilt,
      slot: clusterSlot,
    );
    return rig;
  }

  int _mat(
    SceneModel m,
    Color c, {
    double roughness = 0.7,
    double metallic = 0,
    double clearcoat = 0,
  }) => m.addMaterial(
    MaterialDesc(
      color: c,
      roughness: roughness,
      metallic: metallic,
      clearcoat: clearcoat,
    ),
  );

  void _add(
    SceneModel model,
    MeshBuilder b,
    int material, {
    int? parent,
    bool shadow = true,
  }) {
    if (b.isEmpty) return;
    model.meshNode(
      parent ?? root,
      model.addMesh(b.build()),
      material,
      castsShadow: shadow,
    );
  }

  int _screen(
    SceneModel model,
    Vector3 centre,
    double width,
    double aspect,
    double tiltRad, {
    String? slot,
    Color color = const Color(0xFF101418),
    double opacity = 1,
  }) {
    // Faces the driver, tilted back by [tiltRad].
    final up = Vector3(0, math.cos(tiltRad), math.sin(tiltRad));
    final facing = Vector3(0, math.sin(tiltRad), -math.cos(tiltRad));
    final mesh = MeshBuilder.texturedQuad(
      centre,
      Vector3(1, 0, 0),
      up,
      width,
      width / aspect,
      facing: facing,
    );
    final mat = model.addMaterial(
      MaterialDesc(
        color: slot != null ? const Color(0xFFFFFFFF) : color,
        unlit: true,
        textureSlot: slot,
        opacity: opacity,
      ),
    );
    model.meshNode(root, model.addMesh(mesh), mat, castsShadow: false);
    // Glossy cover glass for reflections.
    final glass = MeshBuilder.texturedQuad(
      centre + facing * 0.004,
      Vector3(1, 0, 0),
      up,
      width,
      width / aspect,
      facing: facing,
    );
    final glassMat = model.addMaterial(
      MaterialDesc(
        color: const Color(0xFF0A0C10),
        roughness: 0.04,
        metallic: 0.1,
        opacity: 0.12,
      ),
    );
    if (opacity >= 1) {
      model.meshNode(root, model.addMesh(glass), glassMat, castsShadow: false);
    }
    return mat;
  }

  // -------------------------------------------------------------------- car

  void _buildCar(SceneModel model, Color paint) {
    final s = spec;
    final e = eye;
    final cab = cabin;
    final halfW = cab.halfWidth;
    // Steering wheel: centre 0.36 m below and 0.5 m ahead of the eyes, rim
    // top leaning away from the driver.
    final wheelCentre = Vector3(e.x, e.y - 0.36, e.z + 0.50);
    steeringBase = Matrix4.translation(wheelCentre)..rotateX(wheelTiltRad);
    // Driver display fitted into the wheel's upper opening so the rim and
    // hub never cover it at zero steering.
    final fit = fitClusterInWheel(
      eye: e,
      wheelFrame: steeringBase,
      maxWidth: s.clusterWidthM,
    );
    final clusterW = fit.width;
    if (s.cluster == ClusterPlacement.binnacle ||
        s.cluster == ClusterPlacement.slimStrip ||
        s.cluster == ClusterPlacement.widePanel) {
      driverDisplay = fit;
    }
    final clusterH = clusterW / carClusterAspect;
    final clusterCentre = fit.centre;
    final clusterUp = Vector3(0, math.cos(fit.tilt), math.sin(fit.tilt));
    final clusterTop = clusterCentre + clusterUp * (clusterH / 2);
    final clusterBottom = clusterCentre - clusterUp * (clusterH / 2);
    // The dash pad passes just under the display and rises to the
    // windscreen.
    final dashZ = clusterCentre.z;
    final dashTopY = clusterBottom.y - 0.012;
    final glassBaseZ = e.z + cab.glassBaseDz, glassTopZ = e.z + cab.glassTopDz;
    final glassBaseY = math.max(dashTopY + 0.02, e.y - cab.glassBaseDy);
    final roofY = e.y + cab.roofDy;

    final dashMat = _mat(model, s.dashColor, roughness: 0.75);
    final dashTopMat = _mat(model, s.dashTopColor, roughness: 0.9);
    final trimMat = cab.sport
        // Dark technical (carbon-look) trim.
        ? _mat(model, const Color(0xFF23272C), roughness: 0.22, metallic: 0.35)
        : _mat(model, s.trimColor, roughness: 0.35, metallic: 0.6);
    final pillarMat = _mat(model, s.pillarColor, roughness: 0.85);
    final headliner = _mat(model, s.headlinerColor, roughness: 0.95);
    final wheelMat = _mat(model, s.wheelColor, roughness: 0.55);
    paintMaterial = _mat(
      model,
      paint,
      roughness: 0.28,
      metallic: 0.6,
      clearcoat: 1,
    );
    ambientMaterial = model.addMaterial(
      MaterialDesc(
        color: s.ambientColor,
        emissive: s.ambientColor,
        emissiveStrength: 1.2,
      ),
    );

    // Dashboard: lower body + soft top pad sloping to the windscreen.
    final dash = MeshBuilder()
      ..box(
        Vector3(0, dashTopY - 0.24, dashZ + 0.2),
        Vector3(halfW * 2, 0.48, 0.62),
      )
      ..box(
        Vector3(0.05, e.y - 0.72, e.z + 0.32),
        Vector3(0.26, 0.24, 0.62),
      ); // console
    _add(model, dash, dashMat);
    final pad = MeshBuilder()
      ..loft([
        for (final (z, y) in [
          (dashZ - 0.16, dashTopY - 0.05),
          (dashZ + 0.06, dashTopY),
          (glassBaseZ, glassBaseY),
        ])
          MeshBuilder.roundedSection(
            z: z,
            width: halfW * 2,
            bottom: y - 0.06,
            top: y,
            radius: 0.03,
          ),
      ]);
    _add(model, pad, dashTopMat);
    final trim = MeshBuilder()
      ..box(
        Vector3(0, dashTopY - 0.17, dashZ - 0.11),
        Vector3(halfW * 2 - 0.1, 0.025, 0.02),
      );
    _add(model, trim, trimMat);
    final ambient = MeshBuilder()
      ..box(
        Vector3(0, dashTopY - 0.2, dashZ - 0.105),
        Vector3(halfW * 2 - 0.2, 0.006, 0.01),
      );
    _add(model, ambient, ambientMaterial!, shadow: false);

    // Bonnet visible beyond the dash, shaped by the body style.
    // Sized to the own car: it ends at the real nose and spans the real
    // fenders, so the view over the bonnet matches the exterior and no road
    // shows beside or beyond it inside the car's outline.
    final bw = _bodyWidth, nose = _noseZ;
    final hw = bw != null ? math.max(cab.hoodWidth, bw - 0.05) : cab.hoodWidth;
    final hl = nose != null
        ? (nose - 0.03 - glassBaseZ).clamp(0.8, cab.hoodLength + 0.3)
        : cab.hoodLength;
    final fall = cab.hoodFall * math.min(1.0, hl / cab.hoodLength);
    // (station, bonnet fall, width, extra nose roll-off)
    final hoodStations = [
      (0.0, 0.0, hw * 0.975, 0.0),
      (0.47, 0.38, hw * 1.0, 0.0),
      (0.8, 0.7, hw * 0.99, 0.0),
      (0.93, 0.88, hw * 0.97, 0.02),
      (1.0, 1.0, hw * 0.9, 0.09),
    ];
    final hood = MeshBuilder()
      ..loft([
        for (final (t, f, w, roll) in hoodStations)
          MeshBuilder.roundedSection(
            z: glassBaseZ + hl * t,
            width: w,
            // Deep sides: the fenders run down past the beltline, so the
            // road is never seen under the bonnet edge.
            bottom: glassBaseY - 0.02 - fall * f - 0.55,
            top: glassBaseY - 0.02 - fall * f - roll,
            radius: cab.hoodRadius,
          ),
      ]);
    if (cab.fenderRise > 0) {
      // Fender crowns either side of a lower bonnet.
      for (final sx in [-1.0, 1.0]) {
        hood.withTransform(
          Matrix4.translation(Vector3(sx * (hw / 2 - 0.13), 0, 0)),
          () => hood.loft([
            for (final (t, f, _, roll) in hoodStations)
              MeshBuilder.roundedSection(
                z: glassBaseZ + hl * t - (t == 0 ? 0.0 : 0.02),
                width: 0.26,
                bottom: glassBaseY - 0.02 - fall * f - 0.2,
                top:
                    glassBaseY -
                    0.02 -
                    fall * f * 0.85 -
                    roll +
                    cab.fenderRise * (1 - 0.4 * t),
                radius: 0.09,
              ),
          ]),
        );
      }
    }
    if (cab.hoodBulge > 0) {
      // Power bulge down the middle.
      hood.loft([
        for (final (t, f, _, _) in hoodStations.take(3))
          MeshBuilder.roundedSection(
            z: glassBaseZ + hl * t + 0.04,
            width: hw * 0.42,
            bottom: glassBaseY - 0.12 - fall * f,
            top: glassBaseY - 0.02 - fall * f + cab.hoodBulge * (1 - t),
            radius: 0.04,
          ),
      ]);
    }
    _add(model, hood, paintMaterial!);

    // A pillars, header, roof, doors, B pillars.
    final frame = MeshBuilder();
    for (final sx in [-1.0, 1.0]) {
      beam(
        frame,
        Vector3(sx * (halfW - 0.04), glassBaseY, glassBaseZ - 0.02),
        Vector3(sx * (halfW - 0.1), roofY, glassTopZ),
        cab.pillarWidth,
        cab.pillarWidth * 0.7,
      );
      beam(
        frame,
        Vector3(sx * (halfW + 0.02), e.y - 0.85, e.z - 0.55),
        Vector3(sx * (halfW + 0.02), roofY, e.z - 0.55),
        0.06,
        0.12,
      );
    }
    beam(
      frame,
      Vector3(-(halfW - 0.1), roofY, glassTopZ),
      Vector3(halfW - 0.1, roofY, glassTopZ),
      0.08,
      0.06,
    );
    _add(model, frame, pillarMat);
    final roof = MeshBuilder()
      ..box(
        Vector3(0, roofY + 0.03, (glassTopZ + e.z - 1) / 2),
        Vector3(halfW * 2, 0.04, glassTopZ - e.z + 1),
      );
    _add(model, roof, headliner);
    final doors = MeshBuilder();
    for (final sx in [-1.0, 1.0]) {
      doors
        ..box(
          Vector3(sx * (halfW + 0.02), e.y - 0.55, e.z + 0.2),
          Vector3(0.08, 0.6, 1.5),
        )
        ..box(
          Vector3(sx * (halfW - 0.02), e.y - 0.3, e.z + 0.1),
          Vector3(0.05, 0.05, 1.1),
        ); // sill top
    }
    _add(model, doors, dashMat);

    // Mirrors.
    final mirrorBody = MeshBuilder()
      ..box(
        Vector3(0.02, roofY - 0.1, glassTopZ + 0.16),
        Vector3(0.26, 0.07, 0.03),
      )
      ..box(
        Vector3(0.02, roofY - 0.04, glassTopZ + 0.14),
        Vector3(0.03, 0.08, 0.02),
      );
    for (final sx in [-1.0, 1.0]) {
      mirrorBody.box(
        Vector3(sx * (halfW + 0.2), glassBaseY + 0.05, glassBaseZ - 0.1),
        Vector3(0.2, 0.12, 0.06),
      );
    }
    _add(model, mirrorBody, pillarMat);
    final mirrorGlass = MeshBuilder()
      ..facingQuad(
        Vector3(-0.1, roofY - 0.07, glassTopZ + 0.144),
        Vector3(0.14, roofY - 0.07, glassTopZ + 0.144),
        Vector3(0.14, roofY - 0.13, glassTopZ + 0.144),
        Vector3(-0.1, roofY - 0.13, glassTopZ + 0.144),
        Vector3(0, 0, -1),
      );
    _add(
      model,
      mirrorGlass,
      _mat(model, const Color(0xFF9AA4AE), roughness: 0.02, metallic: 1),
      shadow: false,
    );

    // Windscreen: faint tint, rain and wipers live on its plane.
    _glassBase = Vector3(0, glassBaseY, glassBaseZ);
    final glassTop = Vector3(0, roofY, glassTopZ);
    _glassUp = (glassTop - _glassBase)..normalize();
    _glassLength = (glassTop - _glassBase).length;
    final glassNormal = Vector3(1, 0, 0).cross(_glassUp)..normalize();
    final wind = MeshBuilder()
      ..facingQuad(
        Vector3(-(halfW - 0.05), _glassBase.y, _glassBase.z),
        Vector3(halfW - 0.05, _glassBase.y, _glassBase.z),
        Vector3(halfW - 0.12, glassTop.y, glassTop.z),
        Vector3(-(halfW - 0.12), glassTop.y, glassTop.z),
        -glassNormal,
      );
    _add(
      model,
      wind,
      model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF8FA6B5),
          roughness: 0.02,
          opacity: 0.05,
          doubleSided: true,
        ),
      ),
      shadow: false,
    );
    _buildWipersAndRain(model, glassNormal);
    _buildCabinDetails(
      model,
      halfW: halfW,
      dashTopY: dashTopY,
      dashFaceZ: dashZ - 0.11,
      glassBaseZ: glassBaseZ,
      glassBaseY: glassBaseY,
      glassTopZ: glassTopZ,
      roofY: roofY,
      dashMat: dashMat,
      trimMat: trimMat,
      pillarMat: pillarMat,
      headliner: headliner,
    );

    // Displays.
    switch (s.cluster) {
      case ClusterPlacement.binnacle:
        // Open visor over the display (a closed hood would hide it); its
        // front lip stays above the driver's line of sight to the top edge.
        final visor = MeshBuilder()
          ..loft([
            for (final (dz, b, t) in [
              (-0.05, 0.034, 0.052),
              (0.06, 0.018, 0.05),
              (0.16, 0.0, 0.036),
            ])
              MeshBuilder.roundedSection(
                z: clusterCentre.z + dz,
                width: clusterW + 0.09,
                bottom: clusterTop.y + b,
                top: clusterTop.y + t,
                radius: 0.008,
              ),
          ]);
        _add(model, visor, dashTopMat);
        final housing = MeshBuilder()
          ..box(
            Vector3(
              e.x,
              (dashTopY + clusterTop.y + 0.04) / 2,
              clusterCentre.z + 0.1,
            ),
            Vector3(clusterW + 0.09, clusterTop.y + 0.04 - dashTopY, 0.12),
          );
        _add(model, housing, dashTopMat);
        clusterMaterial = _screen(
          model,
          clusterCentre,
          clusterW,
          carClusterAspect,
          fit.tilt,
          slot: clusterSlot,
        );
      case ClusterPlacement.slimStrip:
        clusterMaterial = _screen(
          model,
          clusterCentre,
          clusterW,
          carClusterAspect,
          fit.tilt,
          slot: clusterSlot,
        );
        final bezel = MeshBuilder()
          ..box(
            Vector3(
              e.x,
              (clusterBottom.y + dashTopY) / 2,
              clusterCentre.z + 0.03,
            ),
            Vector3(clusterW * 0.3, clusterBottom.y - dashTopY + 0.02, 0.03),
          )
          ..box(
            clusterCentre + Vector3(0, 0, 0.012),
            Vector3(clusterW + 0.012, clusterH + 0.012, 0.012),
          );
        _add(model, bezel, trimMat);
      case ClusterPlacement.widePanel:
        clusterMaterial = _screen(
          model,
          clusterCentre,
          clusterW,
          carClusterAspect,
          fit.tilt,
          slot: clusterSlot,
        );
        final left = e.x - clusterW / 2 - 0.03, right = 0.38;
        final panel = MeshBuilder()
          ..box(
            Vector3(
              (left + right) / 2,
              clusterCentre.y,
              clusterCentre.z + 0.012,
            ),
            Vector3(right - left, clusterH + 0.03, 0.02),
          );
        _add(
          model,
          panel,
          _mat(model, const Color(0xFF050607), roughness: 0.1),
        );
      case ClusterPlacement.centerDisplay:
      case ClusterPlacement.motoTft:
        clusterMaterial = -1;
    }
    switch (s.centerScreen) {
      case CenterScreen.none:
        break;
      case CenterScreen.landscape:
      case CenterScreen.floating:
        final w = s.centerScreenWidthM;
        final c = Vector3(
          0.12,
          dashTopY + (s.centerScreen == CenterScreen.floating ? 0.1 : 0.02),
          dashZ + 0.0,
        );
        final m = _screen(
          model,
          c,
          w,
          16 / 10,
          0.18,
          slot: s.cluster == ClusterPlacement.centerDisplay
              ? clusterSlot
              : null,
          color: const Color(0xFF1B2A3A),
        );
        if (s.cluster == ClusterPlacement.centerDisplay) clusterMaterial = m;
      case CenterScreen.portrait:
        _screen(
          model,
          Vector3(0.12, dashTopY - 0.08, dashZ + 0.02),
          0.2,
          0.75,
          0.25,
          color: const Color(0xFF1B2A3A),
        );
    }
    if (s.hud) {
      _screen(
        model,
        Vector3(e.x, e.y - 0.12, e.z + 2.4),
        0.55,
        carClusterAspect,
        0,
        slot: clusterSlot,
        opacity: 0.4,
      );
    }

    // Steering wheel.
    // (Placed above; the display sits in its upper opening.)
    final wheelRoot = model.group(
      root,
      transform: steeringBase.clone(),
      name: 'steering',
    );
    steeringNode = wheelRoot;
    final w = MeshBuilder();
    const r = wheelRimRadius;
    switch (s.steering) {
      case SteeringControl.round:
        w.torus(Vector3.zero(), r, wheelRimTube, segments: 40);
      case SteeringControl.flatBottom:
        w.torus(
          Vector3.zero(),
          r,
          0.018,
          segments: 30,
          startRad: -math.pi / 3,
          sweepRad: math.pi * 5 / 3,
        );
        beam(
          w,
          Vector3(-r * 0.5, -r * 0.866, 0),
          Vector3(r * 0.5, -r * 0.866, 0),
          0.032,
          0.03,
        );
      case SteeringControl.yoke:
        w.torus(
          Vector3(0, 0, 0),
          r,
          0.02,
          segments: 12,
          startRad: -math.pi / 2.6,
          sweepRad: math.pi / 1.3,
        );
        w.torus(
          Vector3(0, 0, 0),
          r,
          0.02,
          segments: 12,
          startRad: math.pi - math.pi / 2.6,
          sweepRad: math.pi / 1.3,
        );
        beam(
          w,
          Vector3(-r * 0.93, -r * 0.37, 0),
          Vector3(r * 0.93, -r * 0.37, 0),
          0.035,
          0.03,
        );
      case SteeringControl.handlebar:
        break;
    }
    // Spokes and hub with airbag.
    beam(w, Vector3(-r * 0.95, 0, 0.01), Vector3(-0.05, 0, 0.01), 0.035, 0.016);
    beam(w, Vector3(r * 0.95, 0, 0.01), Vector3(0.05, 0, 0.01), 0.035, 0.016);
    beam(w, Vector3(0, -r * 0.92, 0.01), Vector3(0, -0.05, 0.01), 0.04, 0.016);
    w.ellipsoid(
      Vector3(0, 0, 0.02),
      Vector3(0.075, 0.06, 0.03),
      segments: 12,
      rings: 6,
    );
    _add(model, w, wheelMat, parent: wheelRoot);
    if (cab.sport) {
      // Shift paddles behind the rim.
      final paddles = MeshBuilder();
      for (final sx in [-1.0, 1.0]) {
        paddles.box(
          Vector3(sx * (r + 0.02), 0.03, 0.035),
          Vector3(0.05, 0.075, 0.008),
        );
      }
      _add(
        model,
        paddles,
        _mat(model, const Color(0xFFB8BEC6), roughness: 0.2, metallic: 1),
        parent: wheelRoot,
      );
    }
    final badge = MeshBuilder()
      ..ellipsoid(
        Vector3(0, 0, -0.012),
        Vector3(0.018, 0.018, 0.004),
        segments: 10,
        rings: 4,
      );
    _add(model, badge, trimMat, parent: wheelRoot, shadow: false);
    final column = MeshBuilder();
    beam(
      column,
      wheelCentre + Vector3(0, -0.02, 0.05),
      wheelCentre + Vector3(0, -0.12, 0.35),
      0.07,
      0.07,
    );
    _add(model, column, dashMat);
  }

  /// Side glass, door cards, vents, glovebox, visors and the trim that
  /// tells the body styles apart.
  void _buildCabinDetails(
    SceneModel model, {
    required double halfW,
    required double dashTopY,
    required double dashFaceZ,
    required double glassBaseZ,
    required double glassBaseY,
    required double glassTopZ,
    required double roofY,
    required int dashMat,
    required int trimMat,
    required int pillarMat,
    required int headliner,
  }) {
    final e = eye, cab = cabin;
    final beltY = e.y - 0.27;
    final rearZ = e.z - 0.52;

    // Side windows with their upper frames.
    final side = MeshBuilder(), frame = MeshBuilder();
    for (final sx in [-1.0, 1.0]) {
      final x = sx * (halfW + 0.03);
      final a = Vector3(x, beltY, rearZ);
      final b = Vector3(x, beltY, glassBaseZ - 0.08);
      final c = Vector3(x, roofY - 0.03, glassTopZ - 0.02);
      final d = Vector3(x, roofY - 0.03, rearZ);
      side.facingQuad(a, b, c, d, Vector3(-sx, 0, 0));
      beam(frame, d, c, 0.03, 0.03);
      // Door card: armrest, pull handle, inner release.
      frame
        ..box(
          Vector3(sx * (halfW - 0.03), e.y - 0.52, e.z + 0.02),
          Vector3(0.09, 0.05, 0.52),
        )
        ..box(
          Vector3(sx * (halfW - 0.01), e.y - 0.36, e.z + 0.32),
          Vector3(0.03, 0.12, 0.05),
        );
    }
    _add(
      model,
      side,
      model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF8FA6B5),
          roughness: 0.02,
          opacity: 0.07,
          doubleSided: true,
        ),
      ),
      shadow: false,
    );
    _add(model, frame, pillarMat);
    final handles = MeshBuilder();
    for (final sx in [-1.0, 1.0]) {
      handles.box(
        Vector3(sx * (halfW - 0.035), e.y - 0.4, e.z + 0.42),
        Vector3(0.015, 0.025, 0.1),
      );
    }

    // Air vents: driver outer, centre pair, passenger outer.
    final ventMat = _mat(model, const Color(0xFF070809), roughness: 0.6);
    final vents = MeshBuilder(), slats = MeshBuilder();
    final ventW = cab.rugged ? 0.17 : (cab.sport ? 0.12 : 0.15);
    final ventH = cab.sport ? 0.07 : 0.055;
    for (final (x, dy) in [
      (-(halfW - 0.11), 0.09),
      (0.04, 0.14),
      (0.2, 0.14),
      (halfW - 0.11, 0.09),
    ]) {
      final c = Vector3(x, dashTopY - dy, dashFaceZ - 0.006);
      if (cab.sport) {
        // Round "turbine" vents.
        vents.withTransform(
          Matrix4.translation(c)..rotateY(math.pi / 2),
          () => vents.cylinderX(Vector3.zero(), ventH / 2 + 0.008, 0.02),
        );
        slats.box(c - Vector3(0, 0, 0.012), Vector3(ventH, 0.006, 0.006));
        slats.box(c - Vector3(0, 0, 0.012), Vector3(0.006, ventH, 0.006));
      } else {
        vents.box(c, Vector3(ventW, ventH, 0.02));
        for (final k in [-1.0, 0.0, 1.0]) {
          slats.box(
            c + Vector3(0, k * ventH * 0.28, -0.012),
            Vector3(ventW - 0.01, 0.005, 0.006),
          );
        }
      }
    }
    _add(model, vents, ventMat, shadow: false);
    _add(model, slats, trimMat, shadow: false);

    // Glovebox seam and latch on the passenger side.
    handles
      ..box(
        Vector3(halfW * 0.55, dashTopY - 0.3, dashFaceZ - 0.003),
        Vector3(halfW * 0.6, 0.004, 0.004),
      )
      ..box(
        Vector3(halfW * 0.55, dashTopY - 0.26, dashFaceZ - 0.006),
        Vector3(0.08, 0.015, 0.01),
      );

    // Sun visors folded against the headliner.
    final visors = MeshBuilder();
    for (final x in [e.x, -e.x]) {
      visors.box(
        Vector3(x, roofY - 0.025, glassTopZ - 0.14),
        Vector3(0.36, 0.018, 0.17),
      );
    }
    _add(model, visors, headliner);

    if (cab.grabHandles) {
      // Passenger A-pillar handle; pickups also get a dash grab bar.
      final grab = MeshBuilder();
      final x = halfW - 0.12;
      beam(
        grab,
        Vector3(x, glassBaseY + 0.12, glassBaseZ - 0.2),
        Vector3(x - 0.02, roofY - 0.12, glassTopZ + 0.08),
        0.025,
        0.025,
      );
      if (cab.kind == CabinKind.pickup) {
        final y = dashTopY - 0.05, z = dashFaceZ - 0.07;
        beam(
          grab,
          Vector3(0.32, y, z),
          Vector3(halfW - 0.08, y, z),
          0.03,
          0.03,
        );
        for (final gx in [0.32, halfW - 0.08]) {
          beam(grab, Vector3(gx, y, z), Vector3(gx, y, dashFaceZ), 0.03, 0.03);
        }
      }
      _add(model, grab, _mat(model, const Color(0xFF2B2D30), roughness: 0.8));
    }

    if (cab.sport) {
      // Contrast stitching along the pad and an engine start button.
      final stitch = MeshBuilder()
        ..box(
          Vector3(0, dashTopY - 0.052, dashFaceZ - 0.052),
          Vector3(halfW * 2 - 0.12, 0.004, 0.004),
        );
      _add(
        model,
        stitch,
        _mat(model, const Color(0xFFC62828), roughness: 0.6),
        shadow: false,
      );
      final start = MeshBuilder();
      start.withTransform(
        Matrix4.translation(Vector3(0.3, dashTopY - 0.2, dashFaceZ - 0.01))
          ..rotateY(math.pi / 2),
        () => start.cylinderX(Vector3.zero(), 0.02, 0.015),
      );
      _add(
        model,
        start,
        model.addMaterial(
          MaterialDesc(
            color: const Color(0xFF8E0D0D),
            emissive: const Color(0xFFFF3030),
            emissiveStrength: 0.6,
          ),
        ),
        shadow: false,
      );
    } else if (cab.kind == CabinKind.sedan || cab.kind == CabinKind.wagon) {
      // Brushed-metal / wood-look strip across the passenger dash.
      handles.box(
        Vector3(halfW * 0.45, dashTopY - 0.15, dashFaceZ - 0.005),
        Vector3(halfW * 0.8, 0.03, 0.01),
      );
    }
    _add(model, handles, trimMat, shadow: false);
  }

  void _buildWipersAndRain(SceneModel model, Vector3 glassNormal) {
    final arm = MeshBuilder();
    _armLength = _glassLength * 0.85;
    beam(arm, Vector3(0, 0, 0), Vector3(_armLength, 0, 0), 0.012, 0.012);
    beam(
      arm,
      Vector3(_armLength * 0.12, 0.01, 0.004),
      Vector3(_armLength, 0.01, 0.004),
      0.006,
      0.02,
    );
    final armMesh = model.addMesh(arm.build());
    final armMat = _mat(model, const Color(0xFF0E0E0F), roughness: 0.6);
    // Local frame: x right, y up the glass, z out of the glass (toward outside).
    final y = _glassUp, x = Vector3(1, 0, 0), z = x.cross(y)..normalize();
    for (final px in [-0.42, 0.18]) {
      final pivot = _glassBase + Vector3(px, 0, 0) + z * 0.02;
      _pivots.add(pivot);
      final base = Matrix4.columns(
        Vector4(x.x, x.y, x.z, 0),
        Vector4(y.x, y.y, y.z, 0),
        Vector4(z.x, z.y, z.z, 0),
        Vector4(pivot.x, pivot.y, pivot.z, 1),
      );
      final node = model.meshNode(
        root,
        armMesh,
        armMat,
        transform: base.clone(),
        castsShadow: false,
      );
      wipers.add((node, base));
    }
    const count = 90;
    final mesh = QuadBatchMesh(count);
    for (var q = 0; q < count; q++) {
      mesh.hide(q);
      _drops.add(_Drop());
    }
    drops = mesh;
    dropsMesh = model.addMesh(mesh.toMesh());
    model.meshNode(
      root,
      dropsMesh!,
      model.addMaterial(
        MaterialDesc(
          color: const Color(0xFFDDE6EE),
          unlit: true,
          opacity: 0.35,
          doubleSided: true,
        ),
      ),
      castsShadow: false,
    );
  }

  // ------------------------------------------------------------- motorcycle

  void _buildMoto(SceneModel model, Color paint) {
    final s = spec;
    final e = eye;
    paintMaterial = _mat(
      model,
      paint,
      roughness: 0.25,
      metallic: 0.5,
      clearcoat: 1,
    );
    final black = _mat(model, const Color(0xFF151617), roughness: 0.6);
    final metal = _mat(
      model,
      const Color(0xFFB0B5BA),
      roughness: 0.25,
      metallic: 0.9,
    );
    final barsY = e.y - 0.5, barsZ = e.z + 0.55;

    // Tank and fairing.
    final tank = MeshBuilder()
      ..ellipsoid(
        Vector3(0, e.y - 0.78, e.z + 0.25),
        Vector3(0.2, 0.13, 0.32),
        segments: 16,
        rings: 8,
      );
    _add(model, tank, paintMaterial!);
    final cowl = MeshBuilder()
      ..loft([
        for (final (z, w, b, t) in [
          (barsZ + 0.02, 0.42, barsY - 0.22, barsY + 0.04),
          (barsZ + 0.25, 0.36, barsY - 0.3, barsY + 0.02),
          (barsZ + 0.55, 0.2, barsY - 0.38, barsY - 0.1),
        ])
          MeshBuilder.roundedSection(
            z: z,
            width: w,
            bottom: b,
            top: t,
            radius: 0.08,
          ),
      ]);
    _add(model, cowl, paintMaterial!);
    clusterMaterial = _screen(
      model,
      Vector3(0, barsY + 0.06, barsZ + 0.08),
      s.clusterWidthM,
      motoClusterAspect,
      0.75,
      slot: clusterSlot,
    );
    final screen = MeshBuilder()
      ..facingQuad(
        Vector3(-0.2, barsY + 0.1, barsZ + 0.2),
        Vector3(0.2, barsY + 0.1, barsZ + 0.2),
        Vector3(0.16, barsY + 0.38, barsZ + 0.32),
        Vector3(-0.16, barsY + 0.38, barsZ + 0.32),
        Vector3(0, 0.3, -1),
      );
    _add(
      model,
      screen,
      model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF7A8C99),
          roughness: 0.03,
          opacity: 0.25,
          doubleSided: true,
        ),
      ),
      shadow: false,
    );

    // Handlebar assembly steers.
    final pivot = Vector3(0, barsY, barsZ);
    steeringBase = Matrix4.translation(pivot)..rotateX(-0.45);
    final bars = model.group(
      root,
      transform: steeringBase.clone(),
      name: 'handlebar',
    );
    steeringNode = bars;
    final bar = MeshBuilder()
      ..cylinderX(Vector3.zero(), 0.014, 0.74, segments: 10);
    for (final sx in [-1.0, 1.0]) {
      bar.cylinderX(Vector3(sx * 0.32, 0, 0), 0.02, 0.12, segments: 10);
      beam(
        bar,
        Vector3(sx * 0.29, 0, 0),
        Vector3(sx * 0.33, 0.28, 0.06),
        0.012,
        0.012,
      );
      bar.box(Vector3(sx * 0.35, 0.3, 0.07), Vector3(0.12, 0.07, 0.02));
      beam(
        bar,
        Vector3(sx * 0.09, 0, 0),
        Vector3(sx * 0.09, -0.6, 0.25),
        0.05,
        0.05,
      );
    }
    _add(model, bar, black, parent: bars);
    final clamp = MeshBuilder()
      ..box(Vector3(0, -0.02, 0.02), Vector3(0.24, 0.04, 0.08));
    _add(model, clamp, metal, parent: bars);
  }

  // ---------------------------------------------------------------- animation

  /// Steering-wheel angle in degrees (positive = right).
  void setSteering(SceneModel model, double steeringDeg) {
    final node = steeringNode;
    if (node == null) return;
    final rad = steeringDeg * math.pi / 180;
    final m = steeringBase.clone();
    if (motorcycle) {
      m.rotateY(rad / 12);
    } else {
      // Clockwise as seen by the driver for a right turn.
      m.rotateZ(-rad);
    }
    model.setTransform(node, m);
  }

  /// Advances wipers and rain. [rain] is 0..1, [speed] m/s.
  void tickRain(
    SceneModel model,
    double dt, {
    required double rain,
    required double speed,
  }) {
    final mesh = drops;
    if (mesh == null) return;
    // Wipers: continuous sweep when raining.
    final prev = _wiperAngle;
    if (rain > 0) {
      _wiperPhase += dt * (0.6 + rain * 0.9);
      _wiperAngle = (1 - math.cos(_wiperPhase * 2 * math.pi)) / 2 * 1.75;
    } else if (_wiperAngle > 0) {
      _wiperAngle = math.max(0, _wiperAngle - dt * 2);
    }
    for (final (node, base) in wipers) {
      model.setTransform(node, base.clone()..rotateZ(_wiperAngle));
    }
    // Drops.
    final spawn = rain * (40 + speed * 1.5) * dt;
    var toSpawn = spawn.floor() + (_rng.nextDouble() < spawn % 1 ? 1 : 0);
    final x = Vector3(1, 0, 0), up = _glassUp;
    final z = x.cross(up)..normalize();
    final lo = math.min(prev, _wiperAngle), hi = math.max(prev, _wiperAngle);
    for (var q = 0; q < _drops.length; q++) {
      final d = _drops[q];
      if (!d.alive && toSpawn > 0) {
        toSpawn--;
        d
          ..alive = true
          ..u = (_rng.nextDouble() * 2 - 1) * 0.7
          ..v = _rng.nextDouble() * _glassLength * 0.95
          ..size = 0.006 + _rng.nextDouble() * 0.012;
      }
      if (!d.alive) continue;
      // Air flow pushes drops up the glass at speed.
      d.v += dt * math.max(0, speed - 12) * 0.01;
      if (d.v > _glassLength) d.alive = false;
      for (final p in _pivots) {
        final rel = Vector3(d.u, 0, 0) + up * d.v - (p - _glassBase);
        final dist = math.sqrt(rel.x * rel.x + rel.dot(up) * rel.dot(up));
        final ang = math.atan2(rel.dot(up), rel.x);
        if (dist < _armLength &&
            ang >= lo - 0.02 &&
            ang <= hi + 0.02 &&
            hi - lo > 1e-4) {
          d.alive = false;
        }
      }
      if (!d.alive) {
        mesh.hide(q);
        continue;
      }
      final c = _glassBase + x * d.u + up * d.v - z * 0.004;
      final hx = x * d.size, hy = up * (d.size * 1.3);
      mesh.setQuad(q, c - hx - hy, c + hx - hy, c + hx + hy, c - hx + hy);
    }
    model.markMesh(dropsMesh!);
  }
}

class _Drop {
  bool alive = false;
  double u = 0, v = 0, size = 0.01;
}
