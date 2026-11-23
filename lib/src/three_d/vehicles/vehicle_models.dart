import 'dart:math' as math;
import 'dart:typed_data';

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;
import 'package:vector_math/vector_math.dart';

import '../geometry/mesh_builder.dart';
import '../import/imported_model.dart';
import '../import/model_loader.dart';
import '../scene/scene_model.dart';
import 'procedural_vehicle.dart' show BodyProportions;

/// A model file for a vehicle kind.
class VehicleModelAsset {
  const VehicleModelAsset(
    this.path, {
    this.yawRad = 0,
    this.zUp,
    this.keepAspect = false,
    this.autoYaw = false,
  });

  /// Find the front from the model itself (see [estimateYaw]); added to
  /// [yawRad].
  final bool autoYaw;

  /// Asset path (any format of [ModelFormat]).
  final String path;

  /// Extra rotation about the up axis when the model's front is not +z
  /// (glTF convention).
  final double yawRad;

  /// Up axis override (default: y-up, STL z-up).
  final bool? zUp;

  /// Scale uniformly to the target length and keep the model's own width
  /// and height (detailed, true-to-life models). Otherwise the model is
  /// stretched onto the kind's footprint (low-poly kits).
  final bool keepAspect;
}

/// Imported models per [TrafficVehicleKind] / [EgoVehicleModel].
///
/// Kinds without a model keep the procedural vehicles. Several models per
/// kind are spread across traffic for variety; the ego uses the first.
class VehicleModelSet {
  VehicleModelSet(this.name, this.assets, {this.license = ''});

  final String name;
  final String license;
  final Map<Object, List<VehicleModelAsset>> assets;
  final Map<Object, List<ImportedVehicleModel>> _loaded = {};
  final Map<Object, Future<void>> _loading = {};
  final Set<Object> _done = {};

  /// Every kind in [assets] is loaded.
  bool get isLoaded => assets.keys.every(_done.contains);

  /// The given kinds are loaded (kinds without assets count as loaded).
  bool isLoadedFor(Iterable<Object> kinds) =>
      kinds.every((k) => !assets.containsKey(k) || _done.contains(k));

  /// Loads the assets of [kinds] (all when null) once; failures are
  /// logged and skipped. Large ego models are only fetched when used.
  Future<void> load({AssetBundle? bundle, Iterable<Object>? kinds}) =>
      Future.wait([
        for (final kind in kinds ?? assets.keys)
          if (assets[kind] case final list?)
            _loading.putIfAbsent(kind, () async {
              for (final a in list) {
                try {
                  final m = await ModelLoader.asset(
                    a.path,
                    bundle: bundle,
                    zUp: a.zUp,
                  );
                  add(
                    kind,
                    m,
                    yawRad: a.yawRad + (a.autoYaw ? estimateYaw(m) : 0),
                    keepAspect: a.keepAspect,
                  );
                  if (m.triangleCount > 400000) {
                    debugPrint(
                      'auto_moto_dash 3D: ${a.path} has '
                      '${m.triangleCount} triangles; decimate it (e.g. '
                      "Blender's Decimate) for smooth traffic",
                    );
                  }
                } on Object catch (e) {
                  debugPrint('auto_moto_dash 3D: model ${a.path} failed: $e');
                }
              }
              _done.add(kind);
            }),
      ]);

  /// Adds an already imported model (custom sources, tests).
  void add(
    Object kind,
    ImportedModel model, {
    double yawRad = 0,
    bool keepAspect = false,
  }) {
    (_loaded[kind] ??= []).add(
      ImportedVehicleModel(model, yawRad: yawRad, keepAspect: keepAspect),
    );
    _done.add(kind);
  }

  List<ImportedVehicleModel> modelsFor(Object kind) =>
      _loaded[kind] ?? const [];

  /// Textures of every loaded model (unique by key).
  Iterable<ImportedImage> get images sync* {
    final seen = <String>{};
    for (final list in _loaded.values) {
      for (final m in list) {
        for (final i in m.model.images) {
          if (seen.add(i.key)) yield i;
        }
      }
    }
  }

  /// This set plus every model file found under [folder] in the app's
  /// asset bundle (declare the folder in the app's pubspec `assets:`).
  /// Models found there replace this set's models for their kind.
  ///
  /// The kind comes from the file (or its sub-folder) name:
  /// * `ego-<body>`: own vehicle — `ego-sedan`, `ego-fastback`,
  ///   `ego-sportcoupe` (or `ego-coupe`), `ego-suv`, `ego-shootingbrake`
  ///   (`ego-wagon`), `ego-pickup`;
  /// * otherwise traffic — `sedan`/`car`, `suv`, `pickup`, `van`,
  ///   `truck`/`lorry`, `bus`, `motorcycle`/`moto`; several files per kind
  ///   are mixed in traffic (`sedan-bmw.glb`, `sedan-golf.glb` …).
  ///
  /// Optional tokens: `zup` (CAD / some OBJ exports), `rot90`, `rot180`,
  /// `rot270` (when the front is not detected correctly). Without a `rot`
  /// token the front is found from the model: the long axis, then head /
  /// tail lamps or the steering wheel. Real-world proportions are kept.
  Future<VehicleModelSet> withFolder(
    String folder, {
    AssetBundle? bundle,
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    final found = <Object, List<VehicleModelAsset>>{};
    final prefix = folder.endsWith('/') ? folder : '$folder/';
    for (final path in manifest.listAssets()) {
      if (!path.startsWith(prefix) || ModelFormat.of(path) == null) continue;
      final a = assetFromName(path, path.substring(prefix.length));
      if (a == null) {
        debugPrint('auto_moto_dash 3D: no vehicle kind in name: $path');
        continue;
      }
      (found[a.$1] ??= []).add(a.$2);
    }
    if (found.isEmpty) return this;
    return VehicleModelSet('$name + $folder', {
      ...assets,
      ...found,
    }, license: '$license; own models in $folder (see their licences)');
  }

  /// Kind and asset for a model file named per [withFolder] ([rel] is the
  /// path below the folder); null when no kind is recognised.
  static (Object, VehicleModelAsset)? assetFromName(String path, String rel) {
    final name = rel.toLowerCase().replaceAll(RegExp(r'\.[a-z0-9]+$'), '');
    final tokens = name.split(RegExp(r'[\s_\-./]+'));
    bool has(String t) => tokens.contains(t);
    double? yaw;
    if (has('rot90')) yaw = math.pi / 2;
    if (has('rot180')) yaw = math.pi;
    if (has('rot270')) yaw = -math.pi / 2;
    final zUp = has('zup') ? true : null;
    Object? kind;
    if (has('ego')) {
      final joined = tokens.join();
      for (final (keys, k) in const [
        (['sportcoupe', 'coupe'], EgoVehicleModel.sportCoupe),
        (['shootingbrake', 'wagon', 'estate'], EgoVehicleModel.shootingBrake),
        (['fastback'], EgoVehicleModel.fastback),
        (['suv'], EgoVehicleModel.suv),
        (['pickup'], EgoVehicleModel.pickup),
        (['sedan', 'car'], EgoVehicleModel.sedan),
      ]) {
        if (keys.any(joined.contains)) {
          kind = k;
          break;
        }
      }
    } else {
      for (final (keys, k) in const [
        (['suv'], TrafficVehicleKind.suv),
        (['pickup'], TrafficVehicleKind.pickup),
        (['van', 'minivan', 'mpv'], TrafficVehicleKind.van),
        (['truck', 'lorry'], TrafficVehicleKind.truck),
        (['bus', 'coach'], TrafficVehicleKind.bus),
        (
          ['motorcycle', 'moto', 'motorbike', 'bike'],
          TrafficVehicleKind.motorcycle,
        ),
        (['sedan', 'car', 'hatchback'], TrafficVehicleKind.sedan),
      ]) {
        if (keys.any(has)) {
          kind = k;
          break;
        }
      }
    }
    if (kind == null) return null;
    return (
      kind,
      VehicleModelAsset(
        path,
        yawRad: yaw ?? 0,
        autoYaw: yaw == null,
        zUp: zUp,
        keepAspect: true,
      ),
    );
  }

  static const _kit = 'packages/auto_moto_dash/assets/models/kenney_car_kit';
  static VehicleModelAsset _k(String n) => VehicleModelAsset('$_kit/$n.glb');

  static Map<Object, List<VehicleModelAsset>> get _kenney => {
    TrafficVehicleKind.sedan: [
      _k('sedan'),
      _k('sedan-sports'),
      _k('hatchback-sports'),
      _k('taxi'),
      _k('police'),
    ],
    TrafficVehicleKind.suv: [_k('suv'), _k('suv-luxury')],
    TrafficVehicleKind.pickup: [_k('truck'), _k('truck-flat')],
    TrafficVehicleKind.van: [_k('van'), _k('delivery-flat'), _k('ambulance')],
    TrafficVehicleKind.truck: [_k('delivery'), _k('garbage-truck')],
  };

  /// Kenney "Car Kit" 3.1 (CC0 1.0, www.kenney.nl), bundled with the
  /// package, for surrounding traffic. Buses, motorcycles and the ego stay
  /// procedural.
  static final VehicleModelSet kenneyCarKit = VehicleModelSet(
    'Kenney Car Kit',
    _kenney,
    license: 'CC0 1.0 — Kenney (www.kenney.nl)',
  );

  /// Detailed sports car with a full interior, wheels with brake discs and
  /// its own head / tail / indicator lamps: Khronos glTF sample "Car
  /// Concept" (CC-BY 4.0, trimmed: logos and textures removed).
  static const carConcept = VehicleModelAsset(
    'packages/auto_moto_dash/assets/models/khronos_car_concept/'
    'car_concept.glb',
    keepAspect: true,
  );

  /// Kenney traffic plus the detailed Car Concept as the own sports coupe
  /// (loaded only when that body style is driven).
  static final VehicleModelSet openModels = VehicleModelSet(
    'Open models',
    {
      ..._kenney,
      EgoVehicleModel.sportCoupe: [carConcept],
    },
    license:
        'Kenney Car Kit: CC0 1.0 (www.kenney.nl); Car Concept: CC-BY 4.0 '
        '(Khronos Group glTF-Sample-Assets, based on a CC0 model by '
        '"Unity Fan"; modified)',
  );
}

/// Yaw that turns [m]'s front to +z: the long horizontal axis becomes z,
/// and the head lamps (or else the steering wheel, which sits in the front
/// half) end up at +z. 0 when nothing tells front from back.
double estimateYaw(ImportedModel m) {
  final b = m.bounds;
  final size = b.max - b.min;
  final centre = (b.min + b.max) / 2;
  final sideways = size.x > size.z * 1.15;
  Vector3? mean(Iterable<ImportedPart> parts) {
    final s = Vector3.zero();
    var n = 0;
    for (final p in parts) {
      final pb = p.bounds;
      s.add((pb.min + pb.max) / 2);
      n++;
    }
    return n == 0 ? null : s / n.toDouble();
  }

  Vector3? front;
  final head = mean(m.parts.where((p) => p.lampRole == 'head'));
  final tail = mean(m.parts.where((p) => p.lampRole == 'tail'));
  if (head != null && tail != null) {
    front = head - tail;
  } else if (head != null) {
    front = head - centre;
  } else if (tail != null) {
    front = centre - tail;
  } else {
    final wheel = mean(m.parts.where((p) => p.isSteeringWheel));
    if (wheel != null) front = wheel - centre;
  }
  final candidates = sideways
      ? const [math.pi / 2, -math.pi / 2]
      : const [0.0, math.pi];
  if (front == null || front.length < 1e-6) return candidates.first;
  // Matrix3.rotationY(a) maps (x, z) to z' = -sin(a)·x + cos(a)·z.
  double z(double a) => -math.sin(a) * front!.x + math.cos(a) * front.z;
  return z(candidates[0]) >= z(candidates[1]) ? candidates[0] : candidates[1];
}

/// An imported vehicle; fitted meshes are cached per target size.
class ImportedVehicleModel {
  ImportedVehicleModel(this.model, {this.yawRad = 0, this.keepAspect = false});
  final ImportedModel model;
  final double yawRad;
  final bool keepAspect;
  final Map<BodyProportions, FittedVehicle> _fits = {};

  FittedVehicle fit(BodyProportions p) => _fits.putIfAbsent(
    p,
    () => FittedVehicle._(model, p, yawRad, keepAspect: keepAspect),
  );
}

/// Driver's place in an imported model's own cabin (vehicle space).
class ModelCabin {
  ModelCabin({required this.hub, required this.axis, required this.radius});

  /// Steering wheel centre and its spin axis (pointing away from the
  /// driver), outer rim radius.
  final Vector3 hub, axis;
  final double radius;

  /// Wheel frame: x right, y up along the rim plane, z = [axis]; scaled so
  /// the generic wheel geometry (rim radius 0.185) matches this wheel.
  Matrix4 wheelFrame(double genericRadius) {
    final z = axis.normalized();
    final x = Vector3(0, 1, 0).cross(z)..normalize();
    final y = z.cross(x)..normalize();
    final k = radius / genericRadius;
    return Matrix4.columns(
      Vector4(x.x * k, x.y * k, x.z * k, 0),
      Vector4(y.x * k, y.y * k, y.z * k, 0),
      Vector4(z.x * k, z.y * k, z.z * k, 0),
      Vector4(hub.x, hub.y, hub.z, 1),
    );
  }

  /// Typical seated eye point: about 0.6 m behind and 0.36 m above the
  /// wheel centre, in line with the wheel.
  Vector3 get eye {
    final back = Vector3(-axis.x, 0, -axis.z);
    if (back.length < 1e-6) back.setValues(0, 0, -1);
    back.normalize();
    return hub + back * 0.6 + Vector3(0, 0.36, 0);
  }
}

class FittedPart {
  FittedPart(this.mesh, this.material, [this.pivot, this.paint = false]);
  final MeshData3D mesh;
  final ImportedMaterial material;

  /// Wheel hub (vehicle space); the mesh is centred on it.
  final Vector3? pivot;

  /// Main body paint: drawn with the vehicle's paint colour.
  final bool paint;
}

/// An imported model placed on [BodyProportions].
///
/// Low-poly kits are stretched onto the footprint; `keepAspect` models
/// scale uniformly to the target length and report their own width and
/// height. Wheels scale uniformly about their hubs so they stay round
/// (tyre, rim and disc of one wheel are grouped by position). Lamps come
/// from the model's lamp materials when it has them, otherwise lenses are
/// added on the body surface.
class FittedVehicle {
  FittedVehicle._(
    ImportedModel model,
    BodyProportions target,
    double yawRad, {
    bool keepAspect = false,
  }) {
    final rot = Matrix3.rotationY(yawRad);
    final parts = [
      for (final p in model.parts)
        (p, yawRad == 0 ? p.mesh : _rotated(p.mesh, rot)),
    ];
    final b = Aabb3.minMax(
      Vector3.all(double.infinity),
      Vector3.all(double.negativeInfinity),
    );
    for (final (_, m) in parts) {
      b.hull(boundsOf(m.positions));
    }
    final size = b.max - b.min;
    final c = Vector3(
      (b.min.x + b.max.x) / 2,
      b.min.y,
      (b.min.z + b.max.z) / 2,
    );
    final Vector3 s;
    if (keepAspect) {
      s = Vector3.all(target.length / math.max(size.z, 1e-6));
    } else {
      s = Vector3(
        target.width / math.max(size.x, 1e-6),
        target.height / math.max(size.y, 1e-6),
        target.length / math.max(size.z, 1e-6),
      );
    }
    // Wheels: group parts whose centre lies inside a bigger wheel part
    // (tyre ⊃ rim ⊃ disc); the biggest part of a group defines the hub.
    final ws = s.y;
    final wheelParts = [
      for (final (p, m) in parts)
        if (p.isWheel) (p, m, boundsOf(m.positions)),
    ];
    double vol(Aabb3 a) {
      final d = a.max - a.min;
      return d.x * d.y * d.z;
    }

    wheelParts.sort((a, b) => vol(b.$3).compareTo(vol(a.$3)));
    final hubs = <Aabb3>[];
    final hubOf = <ImportedPart, Aabb3>{};
    final hubFix = <Aabb3, Matrix3>{};
    final hubYaw = <Aabb3, double>{};
    for (final (p, m, bb) in wheelParts) {
      final centre = (bb.min + bb.max) / 2;
      Aabb3? hub;
      for (final h in hubs) {
        if (centre.x >= h.min.x - 1e-3 &&
            centre.x <= h.max.x + 1e-3 &&
            centre.z >= h.min.z - 1e-3 &&
            centre.z <= h.max.z + 1e-3) {
          hub = h;
          break;
        }
      }
      if (hub == null) {
        hub = Aabb3.copy(bb);
        hubs.add(hub);
        // Showroom models often ship with the front wheels steered; the
        // largest part (tyre) tells the real axle, which is turned back
        // onto x so the wheel spins about its own axle.
        final yaw = _axleYaw(m);
        hubYaw[hub] = yaw;
        if (yaw.abs() > 0.01) hubFix[hub] = Matrix3.rotationY(yaw);
      }
      hubOf[p] = hub;
    }
    // Only wheels on the ground with a sideways axle roll; a spare tyre on
    // the tailgate (axle along z, up in the air) stays part of the body.
    if (hubs.isNotEmpty) {
      final ground = hubs.map((h) => h.min.y).reduce(math.min);
      for (final h in hubs) {
        final tall = h.max.y - h.min.y;
        final rolling =
            hubYaw[h]!.abs() < math.pi / 4 && h.min.y - ground < tall * 0.25;
        if (!rolling) {
          hubOf.removeWhere((_, v) => identical(v, h));
          hubFix.remove(h);
        }
      }
    }
    // Fixed brake callipers sitting in a steered hub follow the same fix.
    Aabb3? calliperHub(ImportedPart p, MeshData3D m) {
      final n = p.name.toLowerCase();
      if (!(n.contains('brakepad') ||
          n.contains('calip') ||
          n.contains('callip'))) {
        return null;
      }
      final b = boundsOf(m.positions);
      final centre = (b.min + b.max) / 2;
      for (final h in hubFix.keys) {
        if (centre.x >= h.min.x &&
            centre.x <= h.max.x &&
            centre.z >= h.min.z &&
            centre.z <= h.max.z) {
          return h;
        }
      }
      return null;
    }

    var radius = 0.0;
    final head = <MeshData3D>[], tail = <MeshData3D>[], ind = <MeshData3D>[];
    for (var (p, m) in parts) {
      final hb = hubOf[p];
      if (hb != null) {
        final hubSrc = (hb.min + hb.max) / 2;
        radius = math.max(radius, (hb.max.y - hb.min.y) / 2 * ws);
        var local = _transform(m, hubSrc, Vector3.all(ws), Vector3.zero());
        final fix = hubFix[hb];
        if (fix != null) local = _rotated(local, fix);
        final pivot = Vector3(
          (hubSrc.x - c.x) * s.x,
          (hubSrc.y - c.y) * s.y,
          (hubSrc.z - c.z) * s.z,
        );
        wheels.add(FittedPart(local, p.material, pivot));
        continue;
      }
      final ch = calliperHub(p, m);
      if (ch != null) {
        final o = (ch.min + ch.max) / 2;
        final one = Vector3.all(1);
        m = _transform(
          _rotated(_transform(m, o, one, Vector3.zero()), hubFix[ch]!),
          Vector3.zero(),
          one,
          o,
        );
      }
      final mesh = _transform(m, c, s, Vector3.zero());
      if (keepAspect && p.isSteeringWheel) {
        steeringParts.add(FittedPart(mesh, p.material));
        continue;
      }
      if (p.isInterior) _interiorParts++;
      switch (p.lampRole) {
        case 'head':
          head.add(mesh);
        case 'tail':
          tail.add(mesh);
        case 'indicator':
          ind.add(mesh);
        default:
          body.add(FittedPart(mesh, p.material, null, p.isPaint));
      }
    }
    wheelRadius = radius > 0 ? radius : target.wheelRadius;
    if (keepAspect) {
      final zs = [for (final w in wheels) w.pivot!.z];
      proportions = BodyProportions(
        type: target.type,
        length: size.z * s.z,
        width: size.x * s.x,
        height: size.y * s.y,
        wheelbase: zs.isEmpty
            ? target.wheelbase
            : zs.reduce(math.max) - zs.reduce(math.min),
        wheelRadius: wheelRadius,
        clearance: target.clearance,
      );
    } else {
      proportions = target;
    }
    // Synthetic lenses only for roles the model does not provide.
    if (head.isEmpty || tail.isEmpty) _buildLamps();
    if (head.isNotEmpty) headLamps = _merge(head);
    if (tail.isNotEmpty) tailLamps = _merge(tail);
    if (ind.isNotEmpty) {
      final (l, r) = _splitByX(_merge(ind));
      leftIndicator = l;
      rightIndicator = r;
    } else if (!_synth) {
      _buildLamps(onlyIndicators: true);
    }
    _fitCabin();
  }

  /// Steering wheel parts (vehicle space until [_fitCabin] re-centres them
  /// on [cabin]'s hub).
  final List<FittedPart> steeringParts = [];
  int _interiorParts = 0;

  /// The model's own cabin (steering wheel and interior), when it has one;
  /// the driver view then uses it instead of the generic cockpit.
  ModelCabin? cabin;

  void _fitCabin() {
    if (steeringParts.isEmpty) return;
    final all = _merge([for (final p in steeringParts) p.mesh]);
    final b = boundsOf(all.positions);
    final hub = (b.min + b.max) / 2;
    final radius = math.max(b.max.x - b.min.x, b.max.y - b.min.y) / 2;
    // Only a real interior (seats, dash …) around a plausible wheel.
    if (_interiorParts < 2 || radius < 0.1 || radius > 0.3) {
      body.addAll(steeringParts);
      steeringParts.clear();
      return;
    }
    var axis = _thinAxis(all.positions);
    if (axis.z < 0) axis = -axis; // away from the driver
    final local = [
      for (final p in steeringParts)
        FittedPart(
          _transform(p.mesh, hub, Vector3.all(1), Vector3.zero()),
          p.material,
        ),
    ];
    steeringParts
      ..clear()
      ..addAll(local);
    cabin = ModelCabin(hub: hub, axis: axis, radius: radius);
  }

  /// Direction of least spread of [p] (the normal of a flat part).
  static Vector3 _thinAxis(Float32List p) {
    final n = p.length ~/ 3;
    final mean = Vector3.zero();
    for (var i = 0; i < n; i++) {
      mean.add(Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]));
    }
    mean.scale(1 / n);
    final c = Matrix3.zero();
    for (var i = 0; i < n; i++) {
      final d = Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]) - mean;
      for (var r = 0; r < 3; r++) {
        for (var k = 0; k < 3; k++) {
          c.setEntry(r, k, c.entry(r, k) + d[r] * d[k]);
        }
      }
    }
    // Two largest axes by power iteration; the thin one is their cross.
    Vector3 dominant(Matrix3 m, [Vector3? not]) {
      var v = Vector3(0.577, 0.577, 0.577);
      for (var i = 0; i < 64; i++) {
        if (not != null) v -= not * v.dot(not);
        v = m.transformed(v);
        if (v.length < 1e-12) return Vector3(0, 0, 1);
        v.normalize();
      }
      return v;
    }

    final a = dominant(c);
    final b = dominant(c, a);
    return a.cross(b)..normalize();
  }

  late final BodyProportions proportions;
  final List<FittedPart> body = [], wheels = [];
  late final double wheelRadius;
  late MeshData3D headLamps, tailLamps, leftIndicator, rightIndicator;
  bool _synth = false;

  /// The model brought its own lamp graphics.
  bool get ownLamps => !_synth;

  static MeshData3D _merge(List<MeshData3D> list) {
    var nv = 0, ni = 0;
    for (final m in list) {
      nv += m.positions.length;
      ni += m.indices.length;
    }
    final p = Float32List(nv), n = Float32List(nv), idx = Uint32List(ni);
    var ov = 0, oi = 0;
    for (final m in list) {
      p.setAll(ov, m.positions);
      n.setAll(ov, m.normals);
      final base = ov ~/ 3;
      for (var i = 0; i < m.indices.length; i++) {
        idx[oi + i] = m.indices[i] + base;
      }
      ov += m.positions.length;
      oi += m.indices.length;
    }
    return MeshData3D(positions: p, normals: n, indices: idx);
  }

  /// Triangles left (x < 0) and right of the centre line.
  static (MeshData3D, MeshData3D) _splitByX(MeshData3D m) {
    final l = <int>[], r = <int>[];
    final p = m.positions, idx = m.indices;
    for (var t = 0; t + 2 < idx.length; t += 3) {
      final x = p[idx[t] * 3] + p[idx[t + 1] * 3] + p[idx[t + 2] * 3];
      (x < 0 ? l : r).addAll([idx[t], idx[t + 1], idx[t + 2]]);
    }
    // Compact: keep only the vertices each side uses.
    MeshData3D sub(List<int> tri) {
      final map = <int, int>{};
      final pos = <double>[], nor = <double>[];
      final idx = Uint32List(tri.length);
      for (var k = 0; k < tri.length; k++) {
        idx[k] = map.putIfAbsent(tri[k], () {
          final v = tri[k] * 3;
          pos.addAll([p[v], p[v + 1], p[v + 2]]);
          nor.addAll([m.normals[v], m.normals[v + 1], m.normals[v + 2]]);
          return map.length;
        });
      }
      return MeshData3D(
        positions: Float32List.fromList(pos),
        normals: Float32List.fromList(nor),
        indices: idx,
      );
    }

    return (sub(l), sub(r));
  }

  /// Yaw `a` such that `Matrix3.rotationY(a)` turns the wheel's axle (the
  /// thin direction of its x/z footprint) onto the x axis; 0 when the part
  /// is not clearly wheel-shaped.
  static double _axleYaw(MeshData3D m) {
    final p = m.positions;
    final n = p.length ~/ 3;
    if (n < 8) return 0;
    var mx = 0.0, mz = 0.0;
    for (var i = 0; i < n; i++) {
      mx += p[i * 3];
      mz += p[i * 3 + 2];
    }
    mx /= n;
    mz /= n;
    var cxx = 0.0, czz = 0.0, cxz = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = p[i * 3] - mx, dz = p[i * 3 + 2] - mz;
      cxx += dx * dx;
      czz += dz * dz;
      cxz += dx * dz;
    }
    // Principal axes of the 2×2 covariance; the minor one is the axle.
    final tr = (cxx + czz) / 2;
    final d = math.sqrt(math.pow((cxx - czz) / 2, 2) + cxz * cxz);
    final major = tr + d, minor = tr - d;
    if (major <= 0 || minor / major > 0.5) return 0;
    final theta = 0.5 * math.atan2(2 * cxz, cxx - czz);
    var ax = math.cos(theta + math.pi / 2), az = math.sin(theta + math.pi / 2);
    if (ax < 0) {
      ax = -ax;
      az = -az;
    }
    return math.atan2(az, ax);
  }

  static MeshData3D _rotated(MeshData3D m, Matrix3 r) {
    final p = Float32List.fromList(m.positions);
    final n = Float32List.fromList(m.normals);
    for (var i = 0; i + 2 < p.length; i += 3) {
      final a = r.transformed(Vector3(p[i], p[i + 1], p[i + 2]));
      final b = r.transformed(Vector3(n[i], n[i + 1], n[i + 2]));
      p
        ..[i] = a.x
        ..[i + 1] = a.y
        ..[i + 2] = a.z;
      n
        ..[i] = b.x
        ..[i + 1] = b.y
        ..[i + 2] = b.z;
    }
    return MeshData3D(
      positions: p,
      normals: n,
      indices: m.indices,
      uvs: m.uvs,
      colors: m.colors,
    );
  }

  /// (v - origin) * scale + offset; normals use the inverse scale.
  static MeshData3D _transform(
    MeshData3D m,
    Vector3 origin,
    Vector3 scale,
    Vector3 offset,
  ) {
    final p = Float32List(m.positions.length);
    final n = Float32List(m.normals.length);
    for (var i = 0; i + 2 < p.length; i += 3) {
      p[i] = (m.positions[i] - origin.x) * scale.x + offset.x;
      p[i + 1] = (m.positions[i + 1] - origin.y) * scale.y + offset.y;
      p[i + 2] = (m.positions[i + 2] - origin.z) * scale.z + offset.z;
      final nx = m.normals[i] / scale.x, ny = m.normals[i + 1] / scale.y;
      final nz = m.normals[i + 2] / scale.z;
      final l = math.sqrt(nx * nx + ny * ny + nz * nz);
      final k = l > 1e-12 ? 1 / l : 0.0;
      n[i] = nx * k;
      n[i + 1] = ny * k;
      n[i + 2] = nz * k;
    }
    return MeshData3D(
      positions: p,
      normals: n,
      indices: m.indices,
      uvs: m.uvs,
      colors: m.colors,
    );
  }

  /// Distance along ±z to the body surface at (x, y), from outside.
  double? surfaceZ(double x, double y, {required bool front}) {
    final o = Vector3(x, y, front ? 100 : -100);
    final d = Vector3(0, 0, front ? -1 : 1);
    double? best;
    for (final part in body) {
      final p = part.mesh.positions, idx = part.mesh.indices;
      Vector3 v(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
      for (var t = 0; t + 2 < idx.length; t += 3) {
        final a = v(idx[t]), e1 = v(idx[t + 1]) - a, e2 = v(idx[t + 2]) - a;
        final h = d.cross(e2);
        final det = e1.dot(h);
        if (det.abs() < 1e-12) continue;
        final f = 1 / det, sv = o - a;
        final u = f * sv.dot(h);
        if (u < 0 || u > 1) continue;
        final q = sv.cross(e1);
        final w = f * d.dot(q);
        if (w < 0 || u + w > 1) continue;
        final dist = f * e2.dot(q);
        if (dist > 0 && (best == null || dist < best)) best = dist;
      }
    }
    if (best == null) return null;
    return front ? 100 - best : -100 + best;
  }

  void _buildLamps({bool onlyIndicators = false}) {
    _synth = true;
    final p = proportions;
    final w = p.width, h = p.height, l = p.length;
    final head = MeshBuilder(), tail = MeshBuilder();
    final li = MeshBuilder(), ri = MeshBuilder();
    final hy = math.min(0.45 * h, 1.0), ty = math.min(0.55 * h, 1.15);
    final lampW = math.min(0.2 * w, 0.42), lampH = math.max(0.07, 0.05 * h);
    for (final side in const [-1.0, 1.0]) {
      final hx = side * (w / 2 - lampW / 2 - 0.08);
      final fz = surfaceZ(hx, hy, front: true) ?? l / 2;
      head.box(Vector3(hx, hy, fz + 0.004), Vector3(lampW, lampH, 0.03));
      final tz = surfaceZ(hx, ty, front: false) ?? -l / 2;
      tail.box(Vector3(hx, ty, tz - 0.004), Vector3(lampW, lampH * 1.1, 0.03));
      // Indicators: outboard of each lamp, front and rear.
      final ix = side * (w / 2 - 0.06);
      final ind = side < 0 ? li : ri;
      final fzi = surfaceZ(ix, hy, front: true) ?? fz;
      final tzi = surfaceZ(ix, ty, front: false) ?? tz;
      ind.box(Vector3(ix, hy - lampH, fzi + 0.004), Vector3(0.1, 0.05, 0.03));
      ind.box(Vector3(ix, ty - lampH, tzi - 0.004), Vector3(0.1, 0.05, 0.03));
    }
    // High-mounted stop lamp.
    final sz = surfaceZ(0, math.min(0.8 * h, 1.4), front: false);
    if (sz != null) {
      tail.box(
        Vector3(0, math.min(0.8 * h, 1.4), sz - 0.004),
        Vector3(0.3, 0.035, 0.02),
      );
    }
    if (!onlyIndicators) {
      headLamps = head.build();
      tailLamps = tail.build();
    }
    leftIndicator = li.build();
    rightIndicator = ri.build();
  }
}
