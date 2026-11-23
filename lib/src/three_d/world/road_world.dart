import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:vector_math/vector_math.dart';

import '../geometry/mesh_builder.dart';
import '../scene/renderer_3d.dart';
import '../scene/scene_model.dart';
import 'scenery.dart';

/// Pose of a point on the road in the ego frame (x right, y up, z forward,
/// origin on the ground under the ego vehicle).
class RoadPose {
  RoadPose(this.position, this.yaw, this.pitch);
  final Vector3 position;

  /// Road heading relative to the ego heading (positive = right).
  final double yaw;
  final double pitch;

  Matrix4 matrix({double extraYaw = 0, double roll = 0}) =>
      Matrix4.translation(position)
        ..rotateY(yaw + extraYaw)
        ..rotateX(-pitch)
        ..rotateZ(roll);
}

/// Procedural road around the ego vehicle.
///
/// The centreline is integrated from [RoadProfile.curvatureAt] and
/// [RoadProfile.elevationAt] every frame, so the drawn road always matches
/// the simulated one. Surfaces are fixed-topology strips rewritten in place;
/// scenery is pooled and recycled as the vehicle advances.
class RoadWorld {
  RoadWorld(
    this.model,
    int parent,
    this.road, {
    RenderQuality quality = RenderQuality.high,
  }) : _root = model.group(parent, name: 'road'),
       ahead = quality == RenderQuality.low ? 260 : 420 {
    _n = ((ahead + back) / step).round() + 1;
    _cx = Float64List(_n);
    _cy = Float64List(_n);
    _cz = Float64List(_n);
    _yaw = Float64List(_n);
    _pitch = Float64List(_n);
    _build(quality);
  }

  final SceneModel model;
  final RoadProfile road;
  final int _root;
  static const back = 60.0;
  static const step = 3.0;
  final double ahead;

  late final int _n;
  late final Float64List _cx, _cy, _cz, _yaw, _pitch;
  double _s0 = 0;

  final List<_Strip> _strips = [];
  final List<_Dashes> _dashes = [];
  late final Scenery _scenery;
  late final int asphaltMaterial;
  late final int groundMaterial;

  RoadScenario get scenario => road.scenario;

  // ---------------------------------------------------------------- layout

  void _build(RenderQuality quality) {
    final city = scenario == RoadScenario.city;
    final highway = scenario == RoadScenario.highway;
    asphaltMaterial = model.addMaterial(
      MaterialDesc(color: const Color(0xFF3A3C3F), roughness: 0.88),
    );
    groundMaterial = model.addMaterial(
      MaterialDesc(
        color: city ? const Color(0xFF6E6C68) : const Color(0xFF4C6B34),
        roughness: 0.95,
      ),
    );
    final shoulder = model.addMaterial(
      MaterialDesc(color: const Color(0xFF4A4A48), roughness: 0.9),
    );
    final white = model.addMaterial(
      MaterialDesc(
        color: const Color(0xFFE6E6E2),
        roughness: 0.6,
        depthLayer: 2,
      ),
    );
    final yellow = model.addMaterial(
      MaterialDesc(
        color: const Color(0xFFE0B020),
        roughness: 0.6,
        depthLayer: 2,
      ),
    );
    final rail = model.addMaterial(
      MaterialDesc(
        color: const Color(0xFFB8BEC4),
        metallic: 0.8,
        roughness: 0.35,
        doubleSided: true,
      ),
    );
    final median = model.addMaterial(
      MaterialDesc(color: const Color(0xFF8D8F8C), roughness: 0.85),
    );

    final left = road.oncomingLeft;
    final right = road.carriagewayRight;
    // Asphalt spans both carriageways.
    _strip(asphaltMaterial, left - 0.6, right + (highway ? 2.5 : 0.6), y: 0);
    if (highway) {
      // Grass median between carriageways.
      _strip(
        groundMaterial,
        road.carriagewayLeft - road.medianM + 0.4,
        road.carriagewayLeft - 0.4,
        y: 0.02,
        layer: 1,
      );
    }
    if (city) {
      // Raised sidewalks then plazas.
      _strip(median, right + 0.6, right + 4.5, y: 0.15);
      _strip(median, left - 4.5, left - 0.6, y: 0.15);
      _strip(groundMaterial, right + 4.5, right + 90, y: 0.15);
      _strip(groundMaterial, left - 90, left - 4.5, y: 0.15);
    } else {
      final edge = highway ? 2.5 : 0.6;
      _strip(shoulder, right + edge, right + edge + 1.2, y: -0.02);
      _strip(groundMaterial, right + edge + 1.2, right + 120, y: -0.12);
      _strip(shoulder, left - 1.8, left - 0.6, y: -0.02);
      _strip(groundMaterial, left - 120, left - 1.8, y: -0.12);
    }

    // Lane markings.
    final dashLen = highway ? 6.0 : 3.0, period = highway ? 15.0 : 9.0;
    for (var l = 1; l < road.lanes; l++) {
      _dash(white, road.laneCenter(l) - road.laneWidthM / 2, dashLen, period);
    }
    for (var l = 1; l < road.oncomingLanes; l++) {
      _dash(
        white,
        road.oncomingLaneCenter(l) + road.laneWidthM / 2,
        dashLen,
        period,
      );
    }
    _line(white, right - 0.1);
    _line(white, left + 0.1);
    final centre = road.carriagewayLeft - road.medianM / 2;
    switch (scenario) {
      case RoadScenario.city:
        _line(yellow, centre - 0.12);
        _line(yellow, centre + 0.12);
      case RoadScenario.rural:
        _dash(yellow, centre, 4, 10);
      case RoadScenario.highway:
        _line(yellow, road.carriagewayLeft + 0.15);
        _line(yellow, road.carriagewayLeft - road.medianM - 0.15);
    }

    // Guard rails.
    if (highway) {
      _rail(rail, centre);
      _rail(rail, right + 2.9);
      _rail(rail, left - 1.2);
    } else if (scenario == RoadScenario.rural) {
      _rail(rail, right + 1.4);
    }

    _scenery = Scenery(model, _root, road, quality: quality);
  }

  void _strip(int material, double l, double r, {double y = 0, int layer = 0}) {
    if (layer > 0) {
      final base = model.materials[material];
      material = model.addMaterial(
        MaterialDesc(
          color: base.color,
          roughness: base.roughness,
          depthLayer: layer,
        ),
      );
    }
    final mesh = StripMesh(_n);
    final id = model.addMesh(mesh.toMesh());
    model.meshNode(_root, id, material, castsShadow: false);
    _strips.add(_Strip(mesh, id, l, r, y, vertical: false));
  }

  void _line(int material, double lateral, {double width = 0.15}) {
    final mesh = StripMesh(_n);
    final id = model.addMesh(mesh.toMesh());
    model.meshNode(_root, id, material, castsShadow: false);
    _strips.add(
      _Strip(
        mesh,
        id,
        lateral - width / 2,
        lateral + width / 2,
        0.012,
        vertical: false,
      ),
    );
  }

  void _rail(int material, double lateral) {
    final mesh = StripMesh(_n);
    final id = model.addMesh(mesh.toMesh());
    model.meshNode(_root, id, material);
    _strips.add(
      _Strip(mesh, id, lateral, lateral, 0.45, vertical: true, height: 0.32),
    );
  }

  void _dash(int material, double lateral, double length, double period) {
    final count = ((ahead + back) / period).ceil() + 2;
    final mesh = QuadBatchMesh(count);
    final id = model.addMesh(mesh.toMesh());
    model.meshNode(_root, id, material, castsShadow: false);
    _dashes.add(_Dashes(mesh, id, lateral, length, period));
  }

  // -------------------------------------------------------------- sampling

  /// Recomputes the road around the ego at distance [s0], lateral offset
  /// [laneOffset] (from the reference lane) and relative heading [heading].
  void update(double s0, double laneOffset, double heading) {
    _s0 = s0;
    // Integrate the centreline in the road frame at s0 (x lateral, z along).
    final i0 = (back / step).round();
    final rx = Float64List(_n), rz = Float64List(_n), th = Float64List(_n);
    for (var i = i0 + 1; i < _n; i++) {
      final k = road.curvatureAt(s0 + (i - i0 - 0.5) * step);
      th[i] = th[i - 1] + k * step;
      final a = (th[i] + th[i - 1]) / 2;
      rx[i] = rx[i - 1] + math.sin(a) * step;
      rz[i] = rz[i - 1] + math.cos(a) * step;
    }
    for (var i = i0 - 1; i >= 0; i--) {
      final k = road.curvatureAt(s0 + (i - i0 + 0.5) * step);
      th[i] = th[i + 1] - k * step;
      final a = (th[i] + th[i + 1]) / 2;
      rx[i] = rx[i + 1] - math.sin(a) * step;
      rz[i] = rz[i + 1] - math.cos(a) * step;
    }
    final c = math.cos(heading), s = math.sin(heading);
    final e0 = road.elevationAt(s0);
    final p0 = math.atan(road.gradeAt(s0));
    final cp = math.cos(p0), sp = math.sin(p0);
    for (var i = 0; i < _n; i++) {
      final dx = rx[i] - laneOffset, dz = rz[i];
      final x = dx * c - dz * s;
      final z = dx * s + dz * c;
      final y = road.elevationAt(s0 + (i - i0) * step) - e0;
      _cx[i] = x;
      _cz[i] = z * cp + y * sp;
      _cy[i] = y * cp - z * sp;
      _yaw[i] = th[i] - heading;
      _pitch[i] = math.atan(road.gradeAt(s0 + (i - i0) * step)) - p0;
    }
    _rebuild();
  }

  /// Pose of the road point at absolute distance [s], [lateral] metres right
  /// of the reference lane centre, [height] above the surface.
  RoadPose poseAt(double s, double lateral, {double height = 0}) {
    final f = ((s - _s0) + back) / step;
    final i = f.floor().clamp(0, _n - 2);
    final t = (f - i).clamp(-4.0, 4.0);
    double lerp(Float64List a) => a[i] + (a[i + 1] - a[i]) * t;
    final yaw = lerp(_yaw);
    final pitch = lerp(_pitch);
    return RoadPose(
      Vector3(
        lerp(_cx) + lateral * math.cos(yaw),
        lerp(_cy) + height,
        lerp(_cz) - lateral * math.sin(yaw),
      ),
      yaw,
      pitch,
    );
  }

  /// Whether [s] is inside the generated stretch.
  bool covers(double s) => s > _s0 - back + step && s < _s0 + ahead - step;

  final Vector3 _a = Vector3.zero(), _b = Vector3.zero(), _nrm = Vector3.zero();

  void _station(int i, double lateral, double y, Vector3 out) {
    final yaw = _yaw[i];
    out.setValues(
      _cx[i] + lateral * math.cos(yaw),
      _cy[i] + y,
      _cz[i] - lateral * math.sin(yaw),
    );
  }

  void _rebuild() {
    for (final st in _strips) {
      for (var i = 0; i < _n; i++) {
        if (st.vertical) {
          _station(i, st.left, st.y - st.height / 2, _a);
          _station(i, st.left, st.y + st.height / 2, _b);
          _nrm.setValues(math.cos(_yaw[i]), 0, -math.sin(_yaw[i]));
          st.mesh.setNormal(i, _nrm);
        } else {
          _station(i, st.left, st.y, _a);
          _station(i, st.right, st.y, _b);
        }
        st.mesh.set(i, _a, _b);
      }
      model.markMesh(st.id);
    }
    final bl = Vector3.zero(), br = Vector3.zero();
    final fr = Vector3.zero(), fl = Vector3.zero();
    for (final d in _dashes) {
      final k0 = ((_s0 - back) / d.period).floor();
      for (var q = 0; q < d.mesh.count; q++) {
        final s = (k0 + q) * d.period;
        if (!covers(s) || !covers(s + d.length)) {
          d.mesh.hide(q);
          continue;
        }
        _dashCorner(s, d.lateral - 0.075, bl);
        _dashCorner(s, d.lateral + 0.075, br);
        _dashCorner(s + d.length, d.lateral + 0.075, fr);
        _dashCorner(s + d.length, d.lateral - 0.075, fl);
        d.mesh.setQuad(q, bl, br, fr, fl);
      }
      model.markMesh(d.id);
    }
    _scenery.update(this, _s0);
  }

  void _dashCorner(double s, double lateral, Vector3 out) =>
      out.setFrom(poseAt(s, lateral, height: 0.012).position);

  // ------------------------------------------------------------- lighting

  /// Wet roads turn glossy; night lights lamps and windows.
  void setConditions({required bool wet, required bool night}) {
    final asphalt = model.materials[asphaltMaterial];
    final roughness = wet ? 0.28 : 0.88;
    if (asphalt.roughness != roughness) {
      asphalt
        ..roughness = roughness
        ..color = wet ? const Color(0xFF2A2C2E) : const Color(0xFF3A3C3F);
      model.markMaterial(asphaltMaterial);
    }
    _scenery.setNight(night);
  }
}

class _Strip {
  _Strip(
    this.mesh,
    this.id,
    this.left,
    this.right,
    this.y, {
    required this.vertical,
    this.height = 0,
  });
  final StripMesh mesh;
  final int id;
  final double left, right, y, height;
  final bool vertical;
}

class _Dashes {
  _Dashes(this.mesh, this.id, this.lateral, this.length, this.period);
  final QuadBatchMesh mesh;
  final int id;
  final double lateral, length, period;
}
