import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

/// Renderer-independent triangle mesh.
///
/// Coordinates: x right, y up, z forward (metres). Front faces satisfy
/// `cross(b - a, c - a)` pointing outward; backends convert as needed.
class MeshData3D {
  MeshData3D({
    required this.positions,
    required this.normals,
    required this.indices,
    this.dynamic = false,
    this.uvs,
    this.colors,
  });

  /// Optional uv per vertex (v = 0 at the top edge of a texture).
  final Float32List? uvs;

  /// Optional linear RGBA per vertex, multiplied with the material colour
  /// when [MaterialDesc.vertexColors] is set (imported models).
  final Float32List? colors;

  /// xyz per vertex. Dynamic meshes may rewrite values (not the count).
  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;

  /// Positions / normals change at runtime (road strips).
  final bool dynamic;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// Surface description understood by every backend.
class MaterialDesc {
  MaterialDesc({
    this.color = const Color(0xFFFFFFFF),
    this.metallic = 0,
    this.roughness = 0.6,
    this.emissive = const Color(0xFF000000),
    this.emissiveStrength = 0,
    this.clearcoat = 0,
    this.opacity = 1,
    this.unlit = false,
    this.doubleSided = false,
    this.textureSlot,
    this.depthLayer = 0,
    this.vertexColors = false,
    this.textureEmissive = true,
  });

  /// The [textureSlot] image also drives emission (screens). Model
  /// textures set this to false so they are lit normally.
  final bool textureEmissive;

  /// Multiply by [MeshData3D.colors] (meshes without colours stay white).
  final bool vertexColors;

  Color color;
  double metallic;
  double roughness;
  Color emissive;
  double emissiveStrength;
  double clearcoat;

  /// Below 1 the material is alpha blended.
  double opacity;
  bool unlit;
  bool doubleSided;

  /// Name of a runtime texture (e.g. `cluster`) sampled as base colour.
  final String? textureSlot;

  /// Coplanar overlay ordering (road paint over asphalt).
  final int depthLayer;

  bool get transparent => opacity < 1;
}

/// Scene graph node. [parent] is -1 for the root.
class NodeDesc {
  NodeDesc({
    required this.parent,
    this.mesh,
    this.material,
    Matrix4? transform,
    this.visible = true,
    this.castsShadow = true,
    this.name = '',
  }) : transform = transform ?? Matrix4.identity();

  final int parent;
  final int? mesh;
  final int? material;
  Matrix4 transform;
  bool visible;
  final bool castsShadow;
  final String name;
}

enum LightKind { spot, point }

/// Punctual light attached to [node]; [direction] is in node space.
class LightDesc {
  LightDesc({
    required this.node,
    this.kind = LightKind.spot,
    this.color = const Color(0xFFFFFFFF),
    this.intensity = 1,
    this.range = 60,
    this.coneRad = 0.5,
    this.penumbra = 0.4,
    Vector3? direction,
    this.castsShadow = false,
  }) : direction = direction ?? Vector3(0, 0, 1);

  final int node;
  final LightKind kind;
  Color color;

  /// Candela-ish scale shared by both backends.
  double intensity;
  double range;
  double coneRad;
  double penumbra;
  Vector3 direction;
  final bool castsShadow;
}

/// Sky, sun, ambient light and fog.
class EnvironmentDesc {
  EnvironmentDesc({
    this.zenith = const Color(0xFF3F79C9),
    this.horizon = const Color(0xFFB9D3EE),
    this.ground = const Color(0xFF5A5650),
    Vector3? sunDirection,
    this.sunColor = const Color(0xFFFFF1DC),
    this.sunIntensity = 3,
    this.ambientIntensity = 1,
    this.fogColor = const Color(0xFFB9C9DA),
    this.fogDensity = 0.004,
    this.exposure = 1,
    this.night = false,
    this.shadows = true,
  }) : sunDirection = sunDirection ?? Vector3(-0.35, 0.6, 0.5);

  Color zenith;
  Color horizon;
  Color ground;

  /// Direction toward the sun (need not be unit length).
  Vector3 sunDirection;
  Color sunColor;
  double sunIntensity;
  double ambientIntensity;
  Color fogColor;

  /// Exponential fog density per metre.
  double fogDensity;
  double exposure;
  bool night;
  bool shadows;
}

/// Perspective camera in world space.
class CameraDesc {
  CameraDesc({
    Vector3? position,
    Vector3? target,
    Vector3? up,
    this.fovRad = 0.9,
    this.near = 0.05,
    this.far = 900,
  }) : position = position ?? Vector3(0, 1.2, 0),
       target = target ?? Vector3(0, 1.2, 10),
       up = up ?? Vector3(0, 1, 0);

  final Vector3 position;
  final Vector3 target;
  final Vector3 up;
  double fovRad;
  double near;
  double far;

  void copyFrom(CameraDesc other) {
    position.setFrom(other.position);
    target.setFrom(other.target);
    up.setFrom(other.up);
    fovRad = other.fovRad;
    near = other.near;
    far = other.far;
  }
}

/// Retained scene description. Mutate through the `mark*` helpers so the
/// next [takeFrame] reports what changed.
class SceneModel {
  final List<MeshData3D> meshes = [];
  final List<MaterialDesc> materials = [];
  final List<NodeDesc> nodes = [];
  final List<LightDesc> lights = [];
  EnvironmentDesc environment = EnvironmentDesc();
  final CameraDesc camera = CameraDesc();

  final Set<int> _dirtyNodes = {};
  final Set<int> _dirtyMaterials = {};
  final Set<int> _dirtyMeshes = {};
  final Set<int> _dirtyLights = {};
  bool _dirtyEnvironment = true;

  int addMesh(MeshData3D mesh) {
    meshes.add(mesh);
    return meshes.length - 1;
  }

  int addMaterial(MaterialDesc material) {
    materials.add(material);
    return materials.length - 1;
  }

  int addNode(NodeDesc node) {
    assert(node.parent < nodes.length, 'parent must be added first');
    nodes.add(node);
    return nodes.length - 1;
  }

  int addLight(LightDesc light) {
    lights.add(light);
    return lights.length - 1;
  }

  /// Convenience: group node with no mesh.
  int group(int parent, {Matrix4? transform, String name = ''}) =>
      addNode(NodeDesc(parent: parent, transform: transform, name: name));

  /// Convenience: mesh node.
  int meshNode(
    int parent,
    int mesh,
    int material, {
    Matrix4? transform,
    bool castsShadow = true,
    String name = '',
  }) => addNode(
    NodeDesc(
      parent: parent,
      mesh: mesh,
      material: material,
      transform: transform,
      castsShadow: castsShadow,
      name: name,
    ),
  );

  void setTransform(int node, Matrix4 m) {
    nodes[node].transform.setFrom(m);
    _dirtyNodes.add(node);
  }

  void setVisible(int node, bool visible) {
    final n = nodes[node];
    if (n.visible == visible) return;
    n.visible = visible;
    _dirtyNodes.add(node);
  }

  void setEmissive(int material, double strength, {Color? emissive}) {
    final m = materials[material];
    if (m.emissiveStrength == strength &&
        (emissive == null || emissive == m.emissive)) {
      return;
    }
    m.emissiveStrength = strength;
    if (emissive != null) m.emissive = emissive;
    _dirtyMaterials.add(material);
  }

  void markMaterial(int material) => _dirtyMaterials.add(material);
  void markMesh(int mesh) => _dirtyMeshes.add(mesh);
  void markLight(int light) => _dirtyLights.add(light);
  void markEnvironment() => _dirtyEnvironment = true;

  /// Reports and clears pending changes.
  SceneFrame takeFrame() {
    final frame = SceneFrame._(
      nodes: List.of(_dirtyNodes),
      materials: List.of(_dirtyMaterials),
      meshes: List.of(_dirtyMeshes),
      lights: List.of(_dirtyLights),
      environment: _dirtyEnvironment,
      camera: camera,
    );
    _dirtyNodes.clear();
    _dirtyMaterials.clear();
    _dirtyMeshes.clear();
    _dirtyLights.clear();
    _dirtyEnvironment = false;
    return frame;
  }

  /// World transform of [node] (parent chain composed).
  Matrix4 worldTransform(int node) {
    final m = nodes[node].transform.clone();
    var p = nodes[node].parent;
    while (p >= 0) {
      m.setFrom(nodes[p].transform * m);
      p = nodes[p].parent;
    }
    return m;
  }

  int get triangleCount {
    var n = 0;
    for (final node in nodes) {
      if (node.mesh != null) n += meshes[node.mesh!].triangleCount;
    }
    return n;
  }
}

/// Changes since the previous frame, consumed by `Renderer3D.render`.
class SceneFrame {
  SceneFrame._({
    required this.nodes,
    required this.materials,
    required this.meshes,
    required this.lights,
    required this.environment,
    required this.camera,
  });

  final List<int> nodes;
  final List<int> materials;
  final List<int> meshes;
  final List<int> lights;
  final bool environment;
  final CameraDesc camera;
}
