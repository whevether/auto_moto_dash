import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:vector_math/vector_math.dart';

import '../import/imported_model.dart';
import '../scene/scene_model.dart';
import 'procedural_vehicle.dart';
import 'vehicle_models.dart';

/// Vehicle meshes shared across instances and backends.
///
/// Kinds with a model in [models] use the imported model fitted to the
/// kind's [BodyProportions]; everything else uses [ProceduralVehicle].
class VehicleLibrary {
  VehicleLibrary({this.detail = 1, this.models});

  final int detail;
  final VehicleModelSet? models;

  final Map<(Object, VehicleSignature, int), VehicleMeshes> _meshes = {};
  final Map<(Object, VehicleSignature, int), _MeshIds> _ids = {};
  final Map<FittedVehicle, _FittedIds> _fittedIds = {};
  int? _beamMesh;

  /// Procedural meshes for a [TrafficVehicleKind] or [EgoVehicleModel] with
  /// the given styling cues.
  VehicleMeshes meshesFor(
    Object kind, [
    VehicleSignature signature = const VehicleSignature(),
    int? detail,
  ]) => _meshes.putIfAbsent((kind, signature, detail ?? this.detail), () {
    final d = detail ?? this.detail;
    final motorcycle =
        kind == TrafficVehicleKind.motorcycle ||
        (kind is EgoVehicleModel && kind.isMotorcycle);
    final p = proportionsOf(kind);
    return motorcycle
        ? ProceduralVehicle.motorcycle(p, detail: d)
        : ProceduralVehicle.car(p, detail: d, signature: signature);
  });

  static BodyProportions proportionsOf(Object kind) =>
      kind is TrafficVehicleKind
      ? proportionsForTraffic(kind)
      : proportionsForEgo(kind as EgoVehicleModel);

  /// Imported model used for [kind] / [variant], if any.
  FittedVehicle? fittedFor(Object kind, int variant) {
    final list = models?.modelsFor(kind) ?? const [];
    if (list.isEmpty) return null;
    return list[variant % list.length].fit(proportionsOf(kind));
  }

  _MeshIds _meshIds(
    SceneModel model,
    Object kind,
    VehicleSignature sig,
    int detail,
  ) => _ids.putIfAbsent((kind, sig, detail), () {
    final m = meshesFor(kind, sig, detail);
    int? add(MeshData3D d) => d.indices.isEmpty ? null : model.addMesh(d);
    return _MeshIds(
      body: add(m.body),
      glass: add(m.glass),
      trim: add(m.trim),
      chrome: add(m.chrome),
      plate: add(m.plate),
      wheel: add(m.wheel),
      rim: add(m.rim),
      tail: add(m.tailLamps),
      head: add(m.headLamps),
      left: add(m.leftIndicator),
      right: add(m.rightIndicator),
    );
  });

  int _beam(SceneModel model) => _beamMesh ??= model.addMesh(headlightBeam());
  int? _blurMesh;
  int _blurDisc(SceneModel model) =>
      _blurMesh ??= model.addMesh(wheelBlurDisc());

  /// Motion-blur disc over a rim face: [x] is the rim's outer face in hub
  /// space (sign = outward side), [radius] the rim radius.
  static Matrix4 _blurMatrix(double x, double radius) {
    final m = Matrix4.translation(Vector3(x + x.sign * 0.004, 0, 0));
    if (x < 0) m.rotateY(math.pi);
    return m..scaleByDouble(radius, radius, radius, 1);
  }

  /// Adds one vehicle under [parent] and returns its handles. [variant]
  /// picks among several imported models for the kind.
  VehicleInstance instantiate(
    SceneModel model,
    int parent,
    Object kind, {
    Color paint = const Color(0xFFB0B4B8),
    VehicleSignature signature = const VehicleSignature(),
    bool withLights = false,
    bool withBeams = false,
    int variant = 0,
    String name = 'vehicle',
    int? detail,
  }) {
    final level = detail ?? this.detail;
    final fitted = fittedFor(kind, variant);
    final lamps = _LampMaterials(model);
    final root = model.group(parent, name: name);
    final paintMat = model.addMaterial(
      MaterialDesc(color: paint, metallic: 0.55, roughness: 0.28, clearcoat: 1),
    );
    final wheels = <int>[];
    final blurDiscs = <int>[];
    int? blurMat;
    int blurMaterial(Color color, double metallic) =>
        blurMat ??= model.addMaterial(
          MaterialDesc(
            color: color,
            metallic: metallic,
            roughness: 0.45,
            opacity: 0.5,
            vertexColors: true,
          ),
        );
    final List<Vector3> wheelPositions;
    final BodyProportions proportions;
    final double wheelRadius;
    final bool imported = fitted != null;
    ModelCabin? cabin;
    int? steeringNode;
    Matrix4? steeringBase;
    if (fitted != null) {
      final ids = _fittedIds.putIfAbsent(
        fitted,
        () => _FittedIds(model, fitted),
      );
      for (var i = 0; i < fitted.body.length; i++) {
        final part = fitted.body[i];
        model.meshNode(
          root,
          ids.body[i],
          part.paint ? paintMat : _importedMaterial(model, part),
          castsShadow: part.material.opacity >= 1,
        );
      }
      final hubs = <String, int>{};
      wheelPositions = [];
      for (var i = 0; i < fitted.wheels.length; i++) {
        final w = fitted.wheels[i];
        final key = w.pivot!.storage.map((e) => e.toStringAsFixed(3)).join(',');
        final g = hubs.putIfAbsent(key, () {
          final node = model.group(
            root,
            transform: Matrix4.translation(w.pivot!),
          );
          wheels.add(node);
          wheelPositions.add(w.pivot!.clone());
          final blur = ids.blur[key];
          if (blur != null) {
            final (radius, x, rim) = blur;
            blurDiscs.add(
              model.meshNode(
                node,
                _blurDisc(model),
                blurMaterial(rim.color, rim.metallic),
                castsShadow: false,
                transform: _blurMatrix(x, radius),
              ),
            );
          }
          return node;
        });
        model.meshNode(g, ids.wheels[i], _importedMaterial(model, w));
      }
      lamps.attach(model, root, ids.head, ids.tail, ids.left, ids.right);
      final cab = fitted.cabin;
      if (cab != null) {
        cabin = cab;
        steeringBase = Matrix4.translation(cab.hub);
        steeringNode = model.group(
          root,
          transform: steeringBase,
          name: 'steering',
        );
        for (var i = 0; i < fitted.steeringParts.length; i++) {
          model.meshNode(
            steeringNode,
            ids.steering[i],
            _importedMaterial(model, fitted.steeringParts[i]),
          );
        }
      }
      proportions = fitted.proportions;
      wheelRadius = fitted.wheelRadius;
    } else {
      final ids = _meshIds(model, kind, signature, level);
      final meshes = meshesFor(kind, signature, level);
      final glassMat = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF0B0F13),
          metallic: 0.3,
          roughness: 0.03,
          opacity: 0.86,
        ),
      );
      final trimMat = model.addMaterial(
        MaterialDesc(color: const Color(0xFF151618), roughness: 0.55),
      );
      final chromeMat = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFFD5D9DE),
          metallic: 1,
          roughness: 0.12,
        ),
      );
      final plateMat = model.addMaterial(
        MaterialDesc(color: const Color(0xFFE9ECEF), roughness: 0.5),
      );
      final wheelMat = model.addMaterial(
        MaterialDesc(color: const Color(0xFF111112), roughness: 0.92),
      );
      final rimMat = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFFA9AEB4),
          metallic: 0.9,
          roughness: 0.25,
        ),
      );
      void node(int? mesh, int mat, {bool shadow = true}) {
        if (mesh != null) model.meshNode(root, mesh, mat, castsShadow: shadow);
      }

      node(ids.body, paintMat);
      node(ids.glass, glassMat, shadow: false);
      node(ids.trim, trimMat);
      node(ids.chrome, chromeMat, shadow: false);
      node(ids.plate, plateMat);
      lamps.attach(model, root, ids.head, ids.tail, ids.left, ids.right);
      for (final w in meshes.wheelPositions) {
        final g = model.group(root, transform: _wheelMatrix(w, 0, 0, true));
        if (ids.wheel != null) model.meshNode(g, ids.wheel!, wheelMat);
        if (ids.rim != null) {
          model.meshNode(g, ids.rim!, rimMat);
          final rb = boundsOf(meshes.rim.positions);
          blurDiscs.add(
            model.meshNode(
              g,
              _blurDisc(model),
              blurMaterial(const Color(0xFFA9AEB4), 0.9),
              castsShadow: false,
              transform: _blurMatrix(rb.max.x, (rb.max.y - rb.min.y) / 2),
            ),
          );
        }
        wheels.add(g);
      }
      wheelPositions = meshes.wheelPositions;
      proportions = meshes.proportions;
      wheelRadius = meshes.proportions.wheelRadius;
    }

    final p = proportions;
    final motorcycle = p.width < 1.2;
    int? headLight;
    if (withLights) {
      final lampNode = model.group(
        root,
        transform: Matrix4.translation(
          Vector3(0, math.min(p.height * 0.45, 1.0), p.length / 2),
        ),
      );
      headLight = model.addLight(
        LightDesc(
          node: lampNode,
          color: const Color(0xFFFFF4E0),
          intensity: 0,
          range: 70,
          coneRad: 0.55,
          penumbra: 0.6,
          direction: Vector3(0, -0.08, 1),
          castsShadow: false,
        ),
      );
    }
    int? beams, beamMat;
    if (withBeams) {
      beamMat = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFFFFF3DA),
          opacity: 0.5,
          unlit: true,
          doubleSided: true,
          vertexColors: true,
        ),
      );
      beams = model.group(root, name: 'beams');
      final y = motorcycle ? 0.95 : math.min(p.height * 0.45, 1.0);
      for (final x in motorcycle ? [0.0] : [-p.width * 0.33, p.width * 0.33]) {
        model.meshNode(
          beams,
          _beam(model),
          beamMat,
          castsShadow: false,
          transform: Matrix4.translation(Vector3(x, y, p.length / 2 + 0.02)),
        );
      }
      model.setVisible(beams, false);
    }
    return VehicleInstance(
      root: root,
      paint: paintMat,
      tail: lamps.tail,
      head: lamps.head,
      left: lamps.left,
      right: lamps.right,
      wheels: wheels,
      blurDiscs: blurDiscs,
      blurMaterial: blurMat,
      wheelPositions: wheelPositions,
      proportions: proportions,
      wheelRadius: wheelRadius,
      imported: imported,
      cabin: cabin,
      steeringNode: steeringNode,
      steeringBase: steeringBase,
      headLight: headLight,
      beams: beams,
      beamMaterial: beamMat,
    );
  }

  int _importedMaterial(SceneModel model, FittedPart part) {
    final m = part.material;
    return model.addMaterial(
      MaterialDesc(
        color: m.color,
        metallic: m.metallic,
        roughness: m.roughness,
        emissive: m.emissive,
        emissiveStrength: m.emissiveStrength,
        opacity: m.opacity,
        doubleSided: m.doubleSided,
        textureSlot: m.image?.key,
        textureEmissive: false,
        vertexColors: part.mesh.colors != null,
      ),
    );
  }
}

/// Unit disc in the y/z plane facing +x: a rim seen spinning fast. Vertex
/// colours shade it like smeared spokes (bright hub, darker spoke band
/// where spokes and gaps average out, bright rim lip); rotationally
/// symmetric, so the spin itself is invisible.
MeshData3D wheelBlurDisc({int segments = 40}) {
  const rings = [0.0, 0.16, 0.24, 0.5, 0.82, 0.9, 1.0];
  const shade = [0.95, 0.9, 0.55, 0.5, 0.42, 0.95, 0.85];
  final pos = <double>[], nor = <double>[], col = <double>[];
  final idx = <int>[];
  final row = segments + 1;
  for (var r = 0; r < rings.length; r++) {
    for (var s = 0; s <= segments; s++) {
      final a = s / segments * 2 * math.pi;
      pos.addAll([0, math.cos(a) * rings[r], math.sin(a) * rings[r]]);
      nor.addAll([1, 0, 0]);
      col.addAll([shade[r], shade[r], shade[r], 1]);
    }
  }
  for (var r = 0; r + 1 < rings.length; r++) {
    for (var s = 0; s < segments; s++) {
      final a = r * row + s, b = a + row, c = b + 1, d = a + 1;
      // cross(b - a, c - a) points to +x (scene winding).
      idx.addAll([a, b, c, a, c, d]);
    }
  }
  return MeshData3D(
    positions: Float32List.fromList(pos),
    normals: Float32List.fromList(nor),
    indices: Uint32List.fromList(idx),
    colors: Float32List.fromList(col),
  );
}

/// Translucent light cone in front of a lamp (+z, slightly down), alpha
/// fading with distance through vertex colours.
MeshData3D headlightBeam({
  double length = 13,
  double r0 = 0.1,
  double r1 = 1.7,
  double pitch = -0.05,
  int segments = 16,
}) {
  final rings = 4;
  final pos = <double>[], nor = <double>[], col = <double>[];
  final idx = <int>[];
  for (var r = 0; r <= rings; r++) {
    final t = r / rings;
    final z = length * t;
    final rad = r0 + (r1 - r0) * t;
    final a = 0.32 * math.pow(1 - t, 1.6);
    for (var s = 0; s <= segments; s++) {
      final ang = s / segments * 2 * math.pi;
      final x = math.cos(ang) * rad, y = math.sin(ang) * rad * 0.55;
      pos.addAll([x, y + z * pitch, z]);
      nor.addAll([math.cos(ang), math.sin(ang), 0]);
      col.addAll([1, 0.95, 0.85, a.toDouble()]);
    }
  }
  final row = segments + 1;
  for (var r = 0; r < rings; r++) {
    for (var s = 0; s < segments; s++) {
      final a = r * row + s, b = a + 1, c = a + row, d = c + 1;
      idx.addAll([a, c, b, b, c, d]);
    }
  }
  return MeshData3D(
    positions: Float32List.fromList(pos),
    normals: Float32List.fromList(nor),
    indices: Uint32List.fromList(idx),
    colors: Float32List.fromList(col),
  );
}

class _LampMaterials {
  _LampMaterials(SceneModel model)
    : tail = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF5A0A0A),
          emissive: const Color(0xFFFF1A1A),
          roughness: 0.3,
        ),
      ),
      head = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFFD8DCE0),
          emissive: const Color(0xFFFFF6E0),
          roughness: 0.15,
        ),
      ),
      left = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF6A4A10),
          emissive: const Color(0xFFFFA000),
        ),
      ),
      right = model.addMaterial(
        MaterialDesc(
          color: const Color(0xFF6A4A10),
          emissive: const Color(0xFFFFA000),
        ),
      );

  final int tail, head, left, right;

  void attach(SceneModel model, int root, int? h, int? t, int? l, int? r) {
    void node(int? mesh, int mat) {
      if (mesh != null) model.meshNode(root, mesh, mat, castsShadow: false);
    }

    node(t, tail);
    node(h, head);
    node(l, left);
    node(r, right);
  }
}

/// Wheel transform: hub position, steer, spin; procedural left wheels are
/// turned around so the rim faces outward.
Matrix4 _wheelMatrix(Vector3 p, double steerRad, double spin, bool flipLeft) {
  final m = Matrix4.translation(p);
  if (steerRad != 0) m.rotateY(steerRad);
  m.rotateX(spin);
  if (flipLeft && p.x < 0) m.rotateY(math.pi);
  return m;
}

class _MeshIds {
  _MeshIds({
    required this.body,
    required this.glass,
    required this.trim,
    required this.chrome,
    required this.plate,
    required this.wheel,
    required this.rim,
    required this.tail,
    required this.head,
    required this.left,
    required this.right,
  });
  final int? body, glass, trim, chrome, plate, wheel, rim;
  final int? tail, head, left, right;
}

class _FittedIds {
  _FittedIds(SceneModel model, FittedVehicle f)
    : body = [for (final p in f.body) model.addMesh(p.mesh)],
      wheels = [for (final p in f.wheels) model.addMesh(p.mesh)],
      steering = [for (final p in f.steeringParts) model.addMesh(p.mesh)],
      head = _add(model, f.headLamps),
      tail = _add(model, f.tailLamps),
      left = _add(model, f.leftIndicator),
      right = _add(model, f.rightIndicator),
      blur = _blurInfo(f);

  static int? _add(SceneModel m, MeshData3D d) =>
      d.indices.isEmpty ? null : m.addMesh(d);

  /// Per hub (keyed like the hub groups): rim radius, rim outer face x and
  /// rim material, for wheels with a separate (spoked) rim. Single-piece
  /// wheels (tyre and hub in one mesh) get no blur disc.
  static Map<String, (double, double, ImportedMaterial)> _blurInfo(
    FittedVehicle f,
  ) {
    final groups = <String, List<(Aabb3, ImportedMaterial)>>{};
    final pivots = <String, Vector3>{};
    for (final w in f.wheels) {
      final key = w.pivot!.storage.map((e) => e.toStringAsFixed(3)).join(',');
      (groups[key] ??= []).add((boundsOf(w.mesh.positions), w.material));
      pivots[key] = w.pivot!;
    }
    final out = <String, (double, double, ImportedMaterial)>{};
    groups.forEach((key, parts) {
      double r(Aabb3 b) => (b.max.y - b.min.y) / 2;
      final tyre = parts.map((p) => r(p.$1)).reduce(math.max);
      final rims = parts.where((p) => r(p.$1) < tyre * 0.92).toList();
      if (rims.isEmpty) return;
      rims.sort((a, b) => r(b.$1).compareTo(r(a.$1)));
      final outward = pivots[key]!.x >= 0;
      var x = outward ? -double.infinity : double.infinity;
      for (final (b, _) in rims) {
        x = outward ? math.max(x, b.max.x) : math.min(x, b.min.x);
      }
      out[key] = (r(rims.first.$1), x, rims.first.$2);
    });
    return out;
  }

  final Map<String, (double, double, ImportedMaterial)> blur;
  final List<int> body, wheels, steering;
  final int? head, tail, left, right;
}

/// Handles to one vehicle in a [SceneModel].
class VehicleInstance {
  VehicleInstance({
    required this.root,
    required this.paint,
    required this.tail,
    required this.head,
    required this.left,
    required this.right,
    required this.wheels,
    this.blurDiscs = const [],
    this.blurMaterial,
    required this.wheelPositions,
    required this.proportions,
    double? wheelRadius,
    this.imported = false,
    this.cabin,
    this.steeringNode,
    Matrix4? steeringBase,
    this.headLight,
    this.beams,
    this.beamMaterial,
  }) : wheelRadius = wheelRadius ?? proportions.wheelRadius,
       steeringBase = steeringBase ?? Matrix4.identity();

  /// The model's own cabin (null for generic / procedural vehicles).
  final ModelCabin? cabin;

  /// The model's steering wheel, turned by [setSteering].
  final int? steeringNode;
  final Matrix4 steeringBase;

  /// Turns the model's steering wheel (degrees, positive = right),
  /// clockwise as seen by the driver like the generic cockpit.
  void setSteering(SceneModel model, double steeringDeg) {
    final node = steeringNode, c = cabin;
    if (node == null || c == null) return;
    final m = steeringBase.clone()
      ..rotate(c.axis, -steeringDeg * math.pi / 180);
    model.setTransform(node, m);
  }

  final int root, paint, tail, head, left, right;
  final List<int> wheels;
  final List<Vector3> wheelPositions;
  final BodyProportions proportions;
  final double wheelRadius;

  /// Built from an imported model (keeps its own colours; [paint] unused).
  final bool imported;
  final int? headLight;

  /// Group of headlight beam cones (null when not built).
  final int? beams;
  final int? beamMaterial;
  double _wheelAngle = 0;
  double _omega = 0;
  bool _blurOn = true;

  /// Motion-blur discs over the rims (hidden when slow) and their shared
  /// material (null when the wheels have no separate rim).
  final List<int> blurDiscs;
  final int? blurMaterial;

  /// Largest visible wheel turn per frame (radians).
  static const double maxSpinPerFrame = 0.5;

  /// Updates lamps; [blinkOn] is the shared indicator phase. [beams]
  /// shows the light cones (night / fog, seen from outside).
  void setLamps(
    SceneModel model, {
    required bool braking,
    required bool headlights,
    required bool leftIndicator,
    required bool rightIndicator,
    required bool blinkOn,
    bool highBeam = false,
    bool beams = false,
    double beamOpacity = 0.5,
  }) {
    model.setEmissive(tail, braking ? 6 : (headlights ? 1.6 : 0.15));
    model.setEmissive(head, headlights ? (highBeam ? 9 : 5) : 0.2);
    model.setEmissive(left, leftIndicator && blinkOn ? 6 : 0);
    model.setEmissive(right, rightIndicator && blinkOn ? 6 : 0);
    final b = this.beams;
    if (b != null) {
      model.setVisible(b, beams && headlights);
      final m = beamMaterial!;
      final o = highBeam ? math.min(0.95, beamOpacity * 1.4) : beamOpacity;
      if (model.materials[m].opacity != o) {
        model.materials[m].opacity = o;
        model.markMaterial(m);
      }
    }
    final l = headLight;
    if (l != null) {
      final light = model.lights[l];
      final intensity = headlights ? (highBeam ? 260.0 : 120.0) : 0.0;
      final range = highBeam ? 140.0 : 70.0;
      if (light.intensity != intensity || light.range != range) {
        light
          ..intensity = intensity
          ..range = range
          ..direction.setValues(0, highBeam ? -0.02 : -0.09, 1);
        model.markLight(l);
      }
    }
  }

  /// Spins wheels by distance travelled [ds] and steers the front axle.
  ///
  /// [chassis] is the sprung-body motion (pitch / roll / bounce) applied
  /// to the parent node; wheels are unsprung, so it is cancelled for them
  /// and they stay upright on the road while the body moves over them.
  ///
  /// Like a real wheel filmed at speed, the spokes blur into a disc
  /// ([blurDiscs] fade in with the spin rate), so the rim never strobes or
  /// jitters back and forth when frames arrive unevenly. [dt] is the frame
  /// time; without it the spin rate is not tracked.
  void rollWheels(
    SceneModel model,
    double ds, {
    double dt = 0,
    double steerRad = 0,
    Matrix4? chassis,
  }) {
    final unsprung = chassis == null ? null : Matrix4.inverted(chassis);
    if (dt > 0) {
      // Spin rate from distance, smoothed so contact corrections and
      // uneven frames do not flicker the blur.
      final omega = (ds / dt / wheelRadius).abs();
      _omega += (omega - _omega) * (1 - math.exp(-8 * dt));
      _updateBlur(model);
    }
    // Cap the per-frame turn below half a spoke pitch (5 spokes = 72°) so
    // the rim never appears to turn backwards (wagon-wheel effect); by then
    // the blur disc hides the spokes anyway.
    _wheelAngle += (ds / wheelRadius).clamp(-maxSpinPerFrame, maxSpinPerFrame);
    _wheelAngle %= 2 * math.pi;
    for (var i = 0; i < wheels.length; i++) {
      final p = wheelPositions[i];
      final m = _wheelMatrix(p, p.z > 0 ? steerRad : 0, _wheelAngle, !imported);
      model.setTransform(wheels[i], unsprung == null ? m : unsprung * m);
    }
  }

  /// Smoothed wheel spin rate (rad/s).
  double get spinRate => _omega;

  /// Opacity of the rim blur at [omega] rad/s: spokes start to smear around
  /// 15 km/h and read as a solid disc from about 40 km/h.
  static double blurOpacity(double omega) {
    final t = ((omega - 5) / 20).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t) * 0.94;
  }

  void _updateBlur(SceneModel model) {
    final m = blurMaterial;
    if (m == null) return;
    final o = blurOpacity(_omega);
    final mat = model.materials[m];
    if ((mat.opacity - o).abs() < 0.01 && (o > 0.02) == _blurOn) return;
    mat.opacity = math.max(o, 0.001);
    model.markMaterial(m);
    final on = o > 0.02;
    if (on != _blurOn) {
      _blurOn = on;
      for (final d in blurDiscs) {
        model.setVisible(d, on);
      }
    }
  }
}
