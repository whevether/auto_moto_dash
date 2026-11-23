import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:vector_math/vector_math.dart';

import '../geometry/mesh_builder.dart';
import '../scene/renderer_3d.dart';
import '../scene/scene_model.dart';
import 'road_world.dart';

/// Deterministic per-index noise in [0, 1).
double hash01(int k, int salt) {
  var h = (k * 374761393 + salt * 668265263) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  return (h ^ (h >> 16)) / 0x80000000;
}

/// One kind of roadside object: shared meshes, a fixed pool of nodes
/// recycled along the road every [spacing] metres.
class _Pool {
  _Pool({
    required this.parts,
    required this.spacing,
    required this.slots,
    required this.place,
  });

  /// (mesh, material) pairs drawn per instance.
  final List<(int, int)> parts;
  final double spacing;
  final int slots;

  /// Placement for absolute index k: (s, lateral, scale, yaw) or null.
  final (double, double, Vector3, double)? Function(int k) place;
  final List<int> nodes = [];
}

/// Lamp posts, trees, buildings, distant hills per [RoadScenario].
class Scenery {
  Scenery(
    this.model,
    int parent,
    this.road, {
    RenderQuality quality = RenderQuality.high,
  }) : _root = model.group(parent, name: 'scenery') {
    final density = switch (quality) {
      RenderQuality.low => 0.5,
      RenderQuality.medium => 0.8,
      RenderQuality.high => 1.0,
    };
    _build(density);
  }

  final SceneModel model;
  final RoadProfile road;
  final int _root;
  final List<_Pool> _pools = [];
  late final int _lampMaterial;
  final List<int> _windowMaterials = [];

  int _mesh(MeshBuilder b) => model.addMesh(b.build());
  int _mat(Color c, {double roughness = 0.8, double metallic = 0}) =>
      model.addMaterial(
        MaterialDesc(color: c, roughness: roughness, metallic: metallic),
      );

  void _build(double density) {
    final city = road.scenario == RoadScenario.city;
    final highway = road.scenario == RoadScenario.highway;
    final right = road.carriagewayRight;
    final left = road.oncomingLeft;

    // Street lamps.
    final pole = _mesh(
      MeshBuilder()
        ..cylinderY(Vector3.zero(), 0.11, 0.07, 9, segments: 8)
        ..box(Vector3(-0.9, 8.95, 0), Vector3(1.9, 0.1, 0.12)),
    );
    final head = _mesh(
      MeshBuilder()..box(Vector3(-1.75, 8.85, 0), Vector3(0.6, 0.12, 0.28)),
    );
    final poleMat = _mat(
      const Color(0xFF7D8186),
      roughness: 0.5,
      metallic: 0.7,
    );
    _lampMaterial = model.addMaterial(
      MaterialDesc(
        color: const Color(0xFFDADCD0),
        emissive: const Color(0xFFFFD9A0),
      ),
    );
    if (city || highway) {
      final spacing = city ? 32.0 : 48.0;
      final sides = city
          ? [right + 1.2, left - 1.2]
          : [right + 3.4, road.carriagewayLeft - road.medianM / 2];
      for (final (i, lat) in sides.indexed) {
        _pools.add(
          _Pool(
            parts: [(pole, poleMat), (head, _lampMaterial)],
            spacing: spacing,
            slots: (480 / spacing).ceil() + 1,
            // Arm points over the road: mirror on the left side.
            place: (k) => (
              k * spacing + i * spacing / 2,
              lat,
              Vector3(lat > 0 ? 1 : -1, 1, 1),
              0,
            ),
          ),
        );
      }
    }

    // Trees (trunk + two canopy blobs).
    if (!city || density > 0.7) {
      final trunk = _mesh(
        MeshBuilder()..cylinderY(Vector3.zero(), 0.18, 0.12, 2.6, segments: 7),
      );
      final canopy = _mesh(
        MeshBuilder()
          ..ellipsoid(
            Vector3(0, 3.6, 0),
            Vector3(1.7, 1.9, 1.7),
            segments: 9,
            rings: 6,
          )
          ..ellipsoid(
            Vector3(0.5, 4.8, 0.2),
            Vector3(1.1, 1.2, 1.1),
            segments: 8,
            rings: 5,
          ),
      );
      final conifer = _mesh(
        MeshBuilder()
          ..cylinderY(Vector3(0, 1.6, 0), 1.6, 0, 3.6, segments: 9)
          ..cylinderY(Vector3(0, 3.6, 0), 1.2, 0, 3.0, segments: 9),
      );
      final bark = _mat(const Color(0xFF5B4632));
      final leaf = _mat(const Color(0xFF3F6B2A), roughness: 0.9);
      final pine = _mat(const Color(0xFF2E4F2A), roughness: 0.9);
      final spacing = (city ? 16.0 : 9.0) / density;
      for (final side in [1.0, -1.0]) {
        final edge = side > 0 ? right + (highway ? 7 : 3) : left - 3;
        for (final (salt, mesh, mat) in [
          (1, canopy, leaf),
          (2, conifer, pine),
        ]) {
          _pools.add(
            _Pool(
              parts: [(trunk, bark), (mesh, mat)],
              spacing: spacing,
              slots: (460 / spacing).ceil() + 1,
              place: (k) {
                final r = hash01(k, salt * 7 + (side > 0 ? 0 : 3));
                if (r < (city ? 0.35 : 0.2)) return null;
                final depth = city ? 1.0 : 1 + hash01(k, salt + 11) * 22;
                final sc = 0.75 + hash01(k, salt + 5) * 0.7;
                return (
                  k * spacing + r * spacing,
                  edge + side * depth,
                  Vector3.all(sc),
                  hash01(k, salt + 9) * math.pi * 2,
                );
              },
            ),
          );
        }
      }
    }

    // City blocks: unit boxes scaled per instance.
    if (city) {
      final box = _mesh(
        MeshBuilder()..box(Vector3(0, 0.5, 0), Vector3(1, 1, 1)),
      );
      final roofs = _mesh(
        MeshBuilder()..box(Vector3(0, 1.0, 0), Vector3(0.86, 0.04, 0.86)),
      );
      final roofMat = _mat(const Color(0xFF3C3E40));
      const palette = [
        Color(0xFF8D96A0),
        Color(0xFFB9AE9C),
        Color(0xFF6F7F8E),
        Color(0xFFA6A39D),
      ];
      for (final (ci, colour) in palette.indexed) {
        final m = model.addMaterial(
          MaterialDesc(
            color: colour,
            roughness: ci.isEven ? 0.35 : 0.75,
            metallic: ci.isEven ? 0.4 : 0,
            emissive: const Color(0xFFFFE2A8),
          ),
        );
        _windowMaterials.add(m);
        for (final side in [1.0, -1.0]) {
          const spacing = 26.0 * 4;
          _pools.add(
            _Pool(
              parts: [(box, m), (roofs, roofMat)],
              spacing: spacing,
              slots: (480 / spacing).ceil() + 1,
              place: (k) {
                final r = hash01(k, ci * 13 + (side > 0 ? 1 : 2));
                final w = 12 + r * 14;
                final h = 9 + hash01(k, ci + 40) * (ci == 2 ? 70 : 32);
                final d = 10 + hash01(k, ci + 50) * 10;
                final edge = side > 0 ? right + 4.5 : left - 4.5;
                return (
                  k * spacing + ci * spacing / 4,
                  edge + side * (d / 2 + 2 + r * 3),
                  Vector3(w, h, d),
                  0,
                );
              },
            ),
          );
        }
      }
    }

    // Distant hills on open roads.
    if (!city) {
      final hill = _mesh(
        MeshBuilder()
          ..ellipsoid(Vector3.zero(), Vector3(1, 1, 1), segments: 14, rings: 7),
      );
      final hillMat = _mat(const Color(0xFF557347), roughness: 1);
      for (final side in [1.0, -1.0]) {
        const spacing = 140.0;
        _pools.add(
          _Pool(
            parts: [(hill, hillMat)],
            spacing: spacing,
            slots: 5,
            place: (k) => (
              k * spacing,
              side * (150 + hash01(k, side > 0 ? 3 : 4) * 120),
              Vector3(90 + hash01(k, 8) * 80, 18 + hash01(k, 9) * 40, 70),
              0,
            ),
          ),
        );
      }
    }

    for (final pool in _pools) {
      for (var j = 0; j < pool.slots; j++) {
        final g = model.group(_root);
        for (final (mesh, mat) in pool.parts) {
          model.meshNode(g, mesh, mat);
        }
        pool.nodes.add(g);
      }
    }
  }

  void update(RoadWorld world, double s0) {
    for (final pool in _pools) {
      final k0 = ((s0 - RoadWorld.back) / pool.spacing).floor();
      for (var j = 0; j < pool.slots; j++) {
        final k = k0 + j;
        final p = pool.place(k);
        final node = pool.nodes[j];
        if (p == null || !world.covers(p.$1)) {
          model.setVisible(node, false);
          continue;
        }
        final pose = world.poseAt(p.$1, p.$2);
        final m = Matrix4.translation(pose.position)
          ..rotateY(pose.yaw + p.$4)
          ..scaleByVector3(p.$3);
        model.setTransform(node, m);
        model.setVisible(node, true);
      }
    }
  }

  bool? _night;

  void setNight(bool night) {
    if (_night == night) return;
    _night = night;
    model.setEmissive(_lampMaterial, night ? 8 : 0);
    for (final m in _windowMaterials) {
      model.setEmissive(m, night ? 0.35 : 0);
    }
  }
}
