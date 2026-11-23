import 'dart:ui' as ui;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'backends/renderer_factory.dart';
import 'camera/environment.dart';
import 'cockpit/cluster_texture.dart';
import 'cockpit/cockpit_rig.dart';
import 'drive_scene.dart';
import 'import/model_loader.dart';
import 'scene/renderer_3d.dart';
import 'vehicles/vehicle_models.dart';

/// Live 3D view of a [DriveScene] on the platform backend.
///
/// The scene is rebuilt when the theme, road, viewpoint or quality change;
/// telemetry, weather and time of day update it in place.
class Drive3DView extends StatefulWidget {
  const Drive3DView({
    super.key,
    required this.telemetry,
    required this.style,
    this.mode = CameraMode.driver,
    this.road,
    this.scenario = RoadScenario.highway,
    this.quality = RenderQuality.high,
    this.timeOfDay = TimeOfDay3D.day,
    this.weather,
    this.cluster,
    this.egoPaint,
    this.egoModel,
    this.fallback,
    this.overlay,
    this.onContact,
    this.models,
    this.orbitGestures = true,
  });

  /// Imported vehicle models; loaded before the scene is built. Null keeps
  /// the procedural vehicles.
  final VehicleModelSet? models;

  /// Drag to orbit (and pinch / scroll to zoom) in [CameraMode.exterior].
  final bool orbitGestures;

  final DashTelemetry telemetry;
  final DashStyle style;
  final CameraMode mode;

  /// Shared road; pass `DriveSimulation.road` so the drawn road matches the
  /// simulated vehicle. Defaults to `RoadProfile(scenario: scenario)`.
  final RoadProfile? road;
  final RoadScenario scenario;
  final RenderQuality quality;
  final TimeOfDay3D timeOfDay;
  final WeatherType? weather;

  /// Instrument cluster projected onto the cockpit screens.
  final Widget? cluster;
  final Color? egoPaint;

  /// Overrides the theme's ego body style.
  final EgoVehicleModel? egoModel;

  /// Shown while loading and when 3D rendering is unavailable.
  final Widget? fallback;

  /// Flutter widgets drawn over the 3D view.
  final Widget? overlay;

  /// The ego was kept clear of another vehicle; hosts running their own
  /// simulation should adopt the corrected pose and speed.
  final void Function(EgoContact contact)? onContact;

  @override
  State<Drive3DView> createState() => _Drive3DViewState();
}

class _Drive3DViewState extends State<Drive3DView>
    with SingleTickerProviderStateMixin {
  DriveScene? _scene;
  Renderer3D? _renderer;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _ready = false;
  Object? _error;
  int _generation = 0;

  RoadProfile get _road =>
      widget.road ?? RoadProfile(scenario: widget.scenario);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _create();
  }

  void _create() {
    final gen = ++_generation;
    _ready = false;
    _error = null;
    final models = widget.models;
    // Traffic models plus the driven body style only (detailed ego models
    // are large).
    final kinds = <Object>[
      ...TrafficVehicleKind.values,
      widget.egoModel ?? widget.style.egoVehicle,
    ];
    if (models != null && !models.isLoadedFor(kinds)) {
      _scene = null;
      models.load(kinds: kinds).then((_) {
        if (mounted && gen == _generation) setState(() => _build(gen));
      });
      return;
    }
    _build(gen);
  }

  void _build(int gen) {
    final scene = _scene = DriveScene(
      style: widget.style,
      road: _road,
      mode: widget.mode,
      quality: widget.quality,
      timeOfDay: widget.timeOfDay,
      egoPaint: widget.egoPaint,
      egoModel: widget.egoModel,
      models: widget.models,
    )..onContact = (c) => widget.onContact?.call(c);
    // Prime the scene so the first frame is complete.
    scene.update(0, widget.telemetry, weather: widget.weather);
    // Backends may throw synchronously (no Impeller / Flutter GPU, no
    // WebGL); every failure falls back to the 2D cluster.
    final Renderer3D renderer;
    final Future<void> attached;
    try {
      renderer = createRenderer3D();
      attached = renderer.attach(scene.model, widget.quality);
    } catch (e) {
      _renderer = null;
      _error = e;
      return;
    }
    _renderer = renderer;
    attached.then(
      (_) {
        if (!mounted || gen != _generation) return;
        setState(() => _ready = true);
        _last = Duration.zero;
        if (!_ticker.isActive) _ticker.start();
        _uploadTextures(scene, renderer, gen);
      },
      onError: (Object e) {
        if (!mounted || gen != _generation) return;
        setState(() => _error = e);
      },
    );
  }

  @override
  void didUpdateWidget(Drive3DView old) {
    super.didUpdateWidget(old);
    final roadChanged = widget.road != null
        ? !identical(widget.road, old.road)
        : (old.road != null || widget.scenario != old.scenario);
    if (widget.style != old.style ||
        widget.quality != old.quality ||
        widget.egoPaint != old.egoPaint ||
        widget.egoModel != old.egoModel ||
        widget.models != old.models ||
        roadChanged) {
      _ticker.stop();
      _renderer?.dispose();
      _renderer = null;
      _create();
      _scene?.mode = widget.mode;
    } else {
      _scene
        ?..timeOfDay = widget.timeOfDay
        ..mode = widget.mode;
    }
  }

  /// Model textures (decoded once, shared by every scene).
  Future<void> _uploadTextures(
    DriveScene scene,
    Renderer3D renderer,
    int gen,
  ) async {
    final models = widget.models;
    if (models == null) return;
    final slots = {
      for (final m in scene.model.materials)
        if (m.textureSlot != null && m.textureSlot != clusterSlot)
          m.textureSlot!,
    };
    for (final image in models.images) {
      if (!slots.contains(image.key)) continue;
      try {
        final decoded = await ModelLoader.decodeImage(image);
        if (!mounted || gen != _generation) return;
        await renderer.updateTexture(image.key, decoded);
      } on Object catch (e) {
        debugPrint('auto_moto_dash 3D: texture ${image.key} failed: $e');
      }
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final r = _renderer, scene = _scene;
    if (!_ready || r == null || scene == null) return;
    scene.update(dt, widget.telemetry, weather: widget.weather);
    r.render(scene.model.takeFrame());
  }

  Future<void> _onCluster(ui.Image image) async {
    final r = _renderer;
    if (!_ready || r == null) return;
    await r.updateTexture(clusterSlot, image);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cluster = widget.cluster;
    final r = _renderer;
    if (_error != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.fallback ?? cluster ?? const SizedBox.expand(),
          Positioned(
            left: 12,
            top: 12,
            child: _Notice('3D 渲染不可用（${_error.runtimeType}），已退回仪表视图'),
          ),
          ?widget.overlay,
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cluster != null)
          ClusterTextureCapture(
            logicalSize: widget.style.isMotorcycle
                ? const Size(800, 480)
                : const Size(1200, 500),
            pixelRatio: widget.quality == RenderQuality.high ? 1.25 : 1,
            onFrame: _onCluster,
            child: cluster,
          ),
        if (!_ready) widget.fallback ?? cluster ?? const SizedBox.expand(),
        if (_ready && r != null)
          Positioned.fill(
            child: widget.orbitGestures && widget.mode == CameraMode.exterior
                ? _OrbitGestures(
                    onOrbit: (yaw, pitch, zoom) =>
                        _scene?.orbitBy(yaw: yaw, pitch: pitch, zoom: zoom),
                    child: r.buildView(context),
                  )
                : r.buildView(context),
          ),
        ?widget.overlay,
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCC000000),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
      ),
    ),
  );
}

/// First-person driver cockpit for [DashCockpitRequest] (used through
/// `AutoMotoDash3D.cockpitBuilder`).
///
/// A button (top left) switches between the driver's seat, the exterior
/// orbit and the chase camera in any weather or time of day. Pass
/// [cameraMode] to control the viewpoint from the host instead.
class CockpitView extends StatefulWidget {
  const CockpitView({
    super.key,
    required this.request,
    this.road,
    this.scenario = RoadScenario.highway,
    this.quality = RenderQuality.high,
    this.timeOfDay = TimeOfDay3D.day,
    this.egoModel,
    this.onContact,
    this.models,
    this.cameraMode,
    this.onCameraModeChanged,
    this.showViewToggle = true,
  });

  final DashCockpitRequest request;
  final EgoVehicleModel? egoModel;
  final void Function(EgoContact contact)? onContact;
  final RoadProfile? road;
  final RoadScenario scenario;
  final RenderQuality quality;
  final TimeOfDay3D timeOfDay;
  final VehicleModelSet? models;

  /// Controlled viewpoint (null: the view toggle owns it).
  final CameraMode? cameraMode;
  final ValueChanged<CameraMode>? onCameraModeChanged;
  final bool showViewToggle;

  @override
  State<CockpitView> createState() => _CockpitViewState();
}

class _CockpitViewState extends State<CockpitView> {
  CameraMode _own = CameraMode.driver;

  CameraMode get _mode => widget.cameraMode ?? _own;

  void _toggle() {
    final next = _mode.next;
    if (widget.cameraMode == null) setState(() => _own = next);
    widget.onCameraModeChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final accent = r.style.cockpit.ambientColor;
    return Drive3DView(
      telemetry: r.telemetry,
      style: r.style,
      mode: _mode,
      road: widget.road,
      scenario: widget.scenario,
      quality: widget.quality,
      timeOfDay: widget.timeOfDay,
      weather: r.weather,
      cluster: r.cluster,
      egoModel: widget.egoModel,
      models: widget.models,
      onContact: widget.onContact,
      overlay: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showViewToggle)
            Positioned(
              left: 16,
              top: 16,
              child: _ViewToggle(mode: _mode, accent: accent, onTap: _toggle),
            ),
          if (r.showGearSelector)
            Positioned(
              // Top-right keeps the bottom free for host controls.
              right: 16,
              top: 16,
              child: GearSelector(
                gear: r.telemetry.gear,
                accent: accent,
                onGearSelected: r.onGearSelected,
                onGearPointerDown: r.onGearPointerDown,
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.mode,
    required this.accent,
    required this.onTap,
  });
  final CameraMode mode;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '切换视角，当前${mode.label}',
    child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xB3000000),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            mode == CameraMode.exterior
                ? '${mode.label} · 拖动旋转 ▸ ${mode.next.label}'
                : '${mode.label} ▸ ${mode.next.label}',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Drag to orbit, pinch or scroll to zoom.
class _OrbitGestures extends StatefulWidget {
  const _OrbitGestures({required this.onOrbit, required this.child});
  final void Function(double yaw, double pitch, double zoom) onOrbit;
  final Widget child;

  @override
  State<_OrbitGestures> createState() => _OrbitGesturesState();
}

class _OrbitGesturesState extends State<_OrbitGestures> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (e) {
      if (e is PointerScrollEvent) {
        widget.onOrbit(0, 0, e.scrollDelta.dy * 0.01);
      }
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _scale = 1,
      onScaleUpdate: (d) {
        final zoom = d.pointerCount > 1 ? (_scale - d.scale) * 8 : 0.0;
        _scale = d.scale;
        widget.onOrbit(
          d.focalPointDelta.dx * 0.008,
          d.focalPointDelta.dy * 0.005,
          zoom,
        );
      },
      child: widget.child,
    ),
  );
}

/// 3D chase view of the theme's ego vehicle and surrounding traffic for the
/// instrument cluster's road area (used through
/// `AutoMotoDash3D.roadViewBuilder`).
class Road3DView extends StatelessWidget {
  const Road3DView({
    super.key,
    required this.request,
    this.road,
    this.scenario = RoadScenario.highway,
    this.quality = RenderQuality.medium,
    this.timeOfDay = TimeOfDay3D.day,
    this.egoModel,
    this.models,
  });

  final DashRoadViewRequest request;
  final EgoVehicleModel? egoModel;
  final RoadProfile? road;
  final RoadScenario scenario;
  final RenderQuality quality;
  final TimeOfDay3D timeOfDay;
  final VehicleModelSet? models;

  @override
  Widget build(BuildContext context) => Drive3DView(
    telemetry: request.telemetry,
    style: request.style,
    mode: CameraMode.chase,
    egoModel: egoModel,
    models: models,
    road: road,
    scenario: scenario,
    quality: quality,
    timeOfDay: timeOfDay,
  );
}
