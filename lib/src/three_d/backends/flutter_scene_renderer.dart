import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart';

import '../scene/renderer_3d.dart';
import '../scene/scene_model.dart';

Vector3 _rgb(ui.Color c) => Vector3(_lin(c.r), _lin(c.g), _lin(c.b));
Vector4 _rgba(ui.Color c, double a) =>
    Vector4(_lin(c.r), _lin(c.g), _lin(c.b), a);

/// sRGB → linear (both backends treat [MaterialDesc] colours as sRGB).
double _lin(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// Native backend: maps [SceneModel] onto flutter_scene (Flutter GPU).
///
/// flutter_scene 0.24+ uses the scene's own convention (x right, y up,
/// z forward; `right = up × forward`), so data is uploaded unmirrored.
/// Mirroring x here (as the three.js backend must) renders the whole view
/// flipped left-right: mirrored cluster text and reversed steering.
class FlutterSceneRenderer implements Renderer3D {
  // Created in [attach]: constructing a Scene throws without Impeller /
  // Flutter GPU, and that must surface as an attach error (2D fallback).
  late final fs.Scene _scene;
  bool _hasScene = false;
  SceneModel? _model;
  final List<fs.MeshGeometry> _geometries = [];
  final List<fs.Material> _materials = [];
  final List<fs.Node> _nodes = [];
  final List<Object> _lights = [];
  final Map<String, fs.GpuTextureSource> _textures = {};
  final fs.PerspectiveCamera _camera = fs.PerspectiveCamera();
  bool _ready = false;

  @override
  String get backendName => 'flutter_scene (Flutter GPU)';

  @override
  Future<void> attach(SceneModel model, RenderQuality quality) async {
    _scene = fs.Scene();
    _hasScene = true;
    await fs.Scene.initializeStaticResources();
    _model = model;
    for (final mesh in model.meshes) {
      _geometries.add(
        fs.MeshGeometry.fromArrays(
          positions: mesh.positions,
          normals: mesh.normals,
          indices: mesh.indices,
          texCoords: mesh.uvs,
          colors: mesh.colors,
          storage: mesh.dynamic
              ? fs.GeometryStorage.updatable
              : fs.GeometryStorage.fixed,
          retainCpuData: mesh.dynamic,
        ),
      );
    }
    for (final m in model.materials) {
      _materials.add(_createMaterial(m));
    }
    for (var i = 0; i < model.nodes.length; i++) {
      final d = model.nodes[i];
      final node = fs.Node(
        name: d.name,
        localTransform: d.transform.clone(),
      );
      if (d.mesh != null && d.material != null) {
        node.mesh = fs.Mesh(_geometries[d.mesh!], _materials[d.material!]);
      }
      node.visible = d.visible;
      _nodes.add(node);
      if (d.parent < 0) {
        _scene.add(node);
      } else {
        _nodes[d.parent].add(node);
      }
    }
    for (final l in model.lights) {
      final Object light;
      if (l.kind == LightKind.spot) {
        final spot = fs.SpotLight(
          color: _rgb(l.color),
          intensity: l.intensity,
          range: l.range,
          direction: l.direction.clone(),
          innerConeAngle: l.coneRad * (1 - l.penumbra),
          outerConeAngle: l.coneRad,
          castsShadow: l.castsShadow && quality == RenderQuality.high,
        );
        _nodes[l.node].addComponent(fs.SpotLightComponent(spot));
        light = spot;
      } else {
        final point = fs.PointLight(
          color: _rgb(l.color),
          intensity: l.intensity,
          range: l.range,
        );
        _nodes[l.node].addComponent(fs.PointLightComponent(point));
        light = point;
      }
      _lights.add(light);
    }
    _scene.antiAliasingMode = quality == RenderQuality.low
        ? fs.AntiAliasingMode.none
        : fs.AntiAliasingMode.msaa;
    _shadows = quality == RenderQuality.high;
    _applyEnvironment(model.environment);
    _ready = true;
    render(model.takeFrame());
  }

  bool _shadows = true;

  fs.Material _createMaterial(MaterialDesc m) {
    if (m.unlit) {
      final u = fs.UnlitMaterial();
      u.baseColorFactor = _rgba(m.color, m.opacity);
      u.vertexColorWeight = m.vertexColors ? 1 : 0;
      if (m.transparent) u.alphaMode = fs.AlphaMode.blend;
      u.doubleSided = m.doubleSided;
      u.depthLayer = m.depthLayer;
      return u;
    }
    final p = fs.PhysicallyBasedMaterial();
    _syncPbr(p, m);
    p.doubleSided = m.doubleSided;
    p.depthLayer = m.depthLayer;
    return p;
  }

  void _syncPbr(fs.PhysicallyBasedMaterial p, MaterialDesc m) {
    p.baseColorFactor = _rgba(m.color, m.opacity);
    p.metallicFactor = m.metallic;
    p.roughnessFactor = m.roughness;
    final e = _rgb(m.emissive);
    p.emissiveFactor = Vector4(e.x, e.y, e.z, 1);
    p.emissiveStrength = m.emissiveStrength;
    p.alphaMode = m.transparent ? fs.AlphaMode.blend : fs.AlphaMode.opaque;
    p.vertexColorWeight = m.vertexColors ? 1 : 0;
  }

  void _applyEnvironment(EnvironmentDesc env) {
    _scene.directionalLight = fs.DirectionalLight(
      direction: -env.sunDirection.normalized(),
      color: _rgb(env.sunColor),
      intensity: env.sunIntensity,
      castsShadow: env.shadows && _shadows,
      shadowMaxDistance: 80,
    );
    _scene.skybox = fs.Skybox(
      fs.GradientSkySource(
        zenithColor: _rgb(env.zenith),
        horizonColor: _rgb(env.horizon),
        groundColor: _rgb(env.ground),
        sunDirection: env.sunDirection.normalized(),
        sunColor: env.night ? Vector3(0.6, 0.65, 0.8) : Vector3(3, 2.7, 2.2),
      ),
    );
    _scene.environmentIntensity = env.ambientIntensity;
    _scene.exposure = env.exposure;
    _scene.toneMapping = fs.ToneMappingMode.aces;
    _scene.fog
      ..enabled = env.fogDensity > 0
      ..mode = fs.FogMode.exponentialSquared
      ..density = env.fogDensity
      ..color = _rgb(env.fogColor);
  }

  @override
  void render(SceneFrame frame) {
    final model = _model;
    if (!_ready || model == null) return;
    for (final i in frame.meshes) {
      final mesh = model.meshes[i];
      _geometries[i]
        ..updatePositions(mesh.positions)
        ..updateNormals(mesh.normals);
    }
    for (final i in frame.nodes) {
      final d = model.nodes[i];
      _nodes[i]
        ..localTransform = d.transform.clone()
        ..visible = d.visible;
    }
    for (final i in frame.materials) {
      final m = model.materials[i];
      final mat = _materials[i];
      if (mat is fs.PhysicallyBasedMaterial) {
        _syncPbr(mat, m);
      } else if (mat is fs.UnlitMaterial) {
        mat.baseColorFactor = _rgba(
          Color.lerp(m.color, m.emissive, m.emissiveStrength.clamp(0, 1))!,
          m.opacity,
        );
      }
    }
    for (final i in frame.lights) {
      final d = model.lights[i];
      final l = _lights[i];
      if (l is fs.SpotLight) {
        l
          ..color = _rgb(d.color)
          ..intensity = d.intensity
          ..range = d.range
          ..innerConeAngle = d.coneRad * (1 - d.penumbra)
          ..outerConeAngle = d.coneRad
          ..direction = d.direction.clone();
      } else if (l is fs.PointLight) {
        l
          ..color = _rgb(d.color)
          ..intensity = d.intensity;
      }
    }
    if (frame.environment) _applyEnvironment(model.environment);
    final c = frame.camera;
    _camera
      ..position = c.position.clone()
      ..target = c.target.clone()
      ..up = c.up.clone()
      ..fovRadiansY = c.fovRad
      ..fovNear = c.near
      ..fovFar = c.far;
  }

  @override
  Future<void> updateTexture(String slot, ui.Image image) async {
    final model = _model;
    if (!_ready || model == null) return;
    final texture = fs.GpuTextureSource(await fs.gpuTextureFromImage(image));
    _textures[slot] = texture;
    for (var i = 0; i < model.materials.length; i++) {
      if (model.materials[i].textureSlot != slot) continue;
      final mat = _materials[i];
      if (mat is fs.UnlitMaterial) {
        mat.baseColorTexture = texture;
      } else if (mat is fs.PhysicallyBasedMaterial) {
        mat.baseColorTexture = texture;
        if (model.materials[i].textureEmissive) mat.emissiveTexture = texture;
      }
    }
  }

  @override
  Widget buildView(BuildContext context) => fs.SceneView(
    _scene,
    cameraBuilder: (_) => _camera,
    // Compile every pipeline before the first visible frame.
    warmUp: true,
  );

  @override
  void dispose() {
    _ready = false;
    if (!_hasScene) return;
    for (final n in _nodes.where((n) => n.parent == null)) {
      _scene.remove(n);
    }
    _nodes.clear();
  }
}
