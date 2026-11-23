import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

import '../scene/handedness.dart';
import '../scene/renderer_3d.dart';
import '../scene/scene_model.dart';

extension type _BridgeModule(JSObject _) implements JSObject {
  external _Bridge create(web.HTMLCanvasElement canvas);
  external JSString get revision;
}

extension type _Bridge(JSObject _) implements JSObject {
  external void attach(JSObject model);
  external void apply(JSObject frame);
  external void updateTexture(
    JSString slot,
    JSUint8Array rgba,
    JSNumber width,
    JSNumber height,
  );
  external void dispose();
}

/// Bundled module path (Flutter web serves package assets under `assets/`).
const _bridgeUrl =
    'assets/packages/auto_moto_dash/assets/web/three_bridge.js';

int _viewSeq = 0;

JSArray<JSNumber> _c(ui.Color c) => [c.r.toJS, c.g.toJS, c.b.toJS].toJS;
JSArray<JSNumber> _v(List<double> v) => [for (final x in v) x.toJS].toJS;

JSFloat32Array _m(vm.Matrix4 m) => Handedness.matrixStorage(m).toJS;

JSObject _obj(Map<String, JSAny?> m) {
  final o = JSObject();
  m.forEach((k, v) => o.setProperty(k.toJS, v));
  return o;
}

/// Web backend: three.js r187 bundled with the package, drawn into a
/// `<canvas>` hosted by an [HtmlElementView].
class ThreeJsRenderer implements Renderer3D {
  ThreeJsRenderer() : _viewType = 'auto-moto-dash-3d-${_viewSeq++}';

  final String _viewType;
  late final web.HTMLCanvasElement _canvas;
  _Bridge? _bridge;
  SceneModel? _model;
  String _revision = '';

  @override
  String get backendName => 'three.js r$_revision (WebGL)';

  @override
  Future<void> attach(SceneModel model, RenderQuality quality) async {
    _canvas = web.HTMLCanvasElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      // Input stays with Flutter (overlays, gestures).
      ..style.pointerEvents = 'none';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _canvas,
    );
    final base = web.document.baseURI;
    final module = _BridgeModule(
      await importModule(Uri.parse(base).resolve(_bridgeUrl).toString().toJS)
          .toDart,
    );
    _revision = module.revision.toDart;
    final bridge = module.create(_canvas);
    bridge.attach(
      _obj({
        'quality': quality.name.toJS,
        'meshes': [
          for (final m in model.meshes)
            _obj({
              'positions': Handedness.vec3Array(m.positions).toJS,
              'normals': Handedness.vec3Array(m.normals).toJS,
              'indices': Handedness.indices(m.indices).toJS,
              'uvs': m.uvs?.toJS,
              'colors': m.colors?.toJS,
              'dynamic': m.dynamic.toJS,
            }),
        ].toJS,
        'materials': [
          for (final m in model.materials)
            _obj({
              'color': _c(m.color),
              'metallic': m.metallic.toJS,
              'roughness': m.roughness.toJS,
              'emissive': _c(m.emissive),
              'emissiveStrength': m.emissiveStrength.toJS,
              'clearcoat': m.clearcoat.toJS,
              'opacity': m.opacity.toJS,
              'unlit': m.unlit.toJS,
              'doubleSided': m.doubleSided.toJS,
              'textureSlot': m.textureSlot?.toJS,
              'depthLayer': m.depthLayer.toJS,
              'vertexColors': m.vertexColors.toJS,
              'textureEmissive': m.textureEmissive.toJS,
            }),
        ].toJS,
        'nodes': [
          for (final n in model.nodes)
            _obj({
              'parent': n.parent.toJS,
              'mesh': n.mesh?.toJS,
              'material': n.material?.toJS,
              'transform': _m(n.transform),
              'visible': n.visible.toJS,
              'castsShadow': n.castsShadow.toJS,
              'name': n.name.toJS,
            }),
        ].toJS,
        'lights': [
          for (final l in model.lights)
            _obj({
              'node': l.node.toJS,
              'kind': l.kind.name.toJS,
              'color': _c(l.color),
              'intensity': l.intensity.toJS,
              'range': l.range.toJS,
              'coneRad': l.coneRad.toJS,
              'penumbra': l.penumbra.toJS,
              'direction': _v(Handedness.vec(l.direction).storage),
              'castsShadow': l.castsShadow.toJS,
            }),
        ].toJS,
      }),
    );
    _bridge = bridge;
    _model = model;
  }

  @override
  void render(SceneFrame frame) {
    final bridge = _bridge, model = _model;
    if (bridge == null || model == null) return;
    final env = model.environment;
    final cam = frame.camera;
    bridge.apply(
      _obj({
        'meshes': [
          for (final i in frame.meshes)
            _obj({
              'i': i.toJS,
              'positions': Handedness.vec3Array(model.meshes[i].positions).toJS,
              'normals': Handedness.vec3Array(model.meshes[i].normals).toJS,
            }),
        ].toJS,
        'nodes': [
          for (final i in frame.nodes)
            _obj({
              'i': i.toJS,
              'm': _m(model.nodes[i].transform),
              'v': model.nodes[i].visible.toJS,
            }),
        ].toJS,
        'materials': [
          for (final i in frame.materials)
            _obj({
              'i': i.toJS,
              'color': _c(model.materials[i].color),
              'opacity': model.materials[i].opacity.toJS,
              'metallic': model.materials[i].metallic.toJS,
              'roughness': model.materials[i].roughness.toJS,
              'emissive': _c(model.materials[i].emissive),
              'emissiveStrength': model.materials[i].emissiveStrength.toJS,
            }),
        ].toJS,
        'lights': [
          for (final i in frame.lights)
            _obj({
              'i': i.toJS,
              'color': _c(model.lights[i].color),
              'intensity': model.lights[i].intensity.toJS,
              'range': model.lights[i].range.toJS,
              'coneRad': model.lights[i].coneRad.toJS,
              'direction': _v(
                Handedness.vec(model.lights[i].direction).storage,
              ),
            }),
        ].toJS,
        'env': frame.environment
            ? _obj({
                'zenith': _c(env.zenith),
                'horizon': _c(env.horizon),
                'ground': _c(env.ground),
                'sunDirection': _v(Handedness.vec(env.sunDirection).storage),
                'sunColor': _c(env.sunColor),
                'sunIntensity': env.sunIntensity.toJS,
                'ambientIntensity': env.ambientIntensity.toJS,
                'fogColor': _c(env.fogColor),
                'fogDensity': env.fogDensity.toJS,
                'exposure': env.exposure.toJS,
                'night': env.night.toJS,
                'shadows': env.shadows.toJS,
              })
            : null,
        'camera': _obj({
          'position': _v(Handedness.vec(cam.position).storage),
          'target': _v(Handedness.vec(cam.target).storage),
          'up': _v(Handedness.vec(cam.up).storage),
          'fovRad': cam.fovRad.toJS,
          'near': cam.near.toJS,
          'far': cam.far.toJS,
        }),
      }),
    );
  }

  @override
  Future<void> updateTexture(String slot, ui.Image image) async {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final bridge = _bridge;
    if (data == null || bridge == null) return;
    bridge.updateTexture(
      slot.toJS,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes).toJS,
      image.width.toJS,
      image.height.toJS,
    );
  }

  @override
  Widget buildView(BuildContext context) =>
      HtmlElementView(viewType: _viewType);

  @override
  void dispose() {
    _bridge?.dispose();
    _bridge = null;
  }
}
