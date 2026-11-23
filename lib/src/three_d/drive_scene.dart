import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:vector_math/vector_math.dart';

import 'camera/driver_camera.dart';
import 'camera/environment.dart';
import 'cockpit/cockpit_rig.dart';
import 'scene/renderer_3d.dart';
import 'scene/scene_model.dart';
import 'vehicles/procedural_vehicle.dart'
    show VehicleSignature, proportionsForEgo, signatureForTheme;
import 'vehicles/vehicle_library.dart';
import 'vehicles/vehicle_models.dart';
import 'world/road_world.dart';
import 'world/traffic_simulation.dart';

/// Viewpoint of a [DriveScene].
enum CameraMode {
  /// Driver's eyes inside the cockpit.
  driver,

  /// Behind and above the ego vehicle (instrument road view).
  chase,

  /// Orbit camera around the ego body (drag to turn, any weather / time).
  exterior;

  String get label => switch (this) {
    CameraMode.driver => '驾驶视角',
    CameraMode.chase => '追车视角',
    CameraMode.exterior => '车外环视',
  };

  CameraMode get next =>
      CameraMode.values[(index + 1) % CameraMode.values.length];
}

/// The ego was kept clear of another vehicle this frame.
///
/// Hosts driving their own simulation should adopt [distanceM] /
/// [laneOffsetM] and cap their speed at [speedLimitKmh] so the ego stops at
/// the other vehicle's bumper instead of driving through it.
@immutable
class EgoContact {
  const EgoContact({
    required this.distanceM,
    required this.laneOffsetM,
    this.speedLimitKmh,
    this.side = 0,
  });

  /// Corrected along-road distance and lateral offset of the ego.
  final double distanceM, laneOffsetM;

  /// Forward speed of the vehicle the ego ran into (null for side contact).
  final double? speedLimitKmh;

  /// Side contact: -1 blocked on the left, 1 on the right, 0 none.
  final int side;

  @override
  String toString() =>
      'EgoContact(s: ${distanceM.toStringAsFixed(2)}, '
      'lat: ${laneOffsetM.toStringAsFixed(2)}, '
      'limit: $speedLimitKmh, side: $side)';
}

class _Body {
  const _Body(this.s, this.lateral, this.length, this.width, this.speed);
  final double s, lateral, length, width;

  /// Speed along the road (negative for oncoming traffic).
  final double speed;
}

/// Renderer-independent 3D drive: road, scenery, traffic, ego cockpit or
/// body, lights and camera, advanced once per frame from [DashTelemetry].
class DriveScene {
  DriveScene({
    required this.style,
    required this.road,
    CameraMode mode = CameraMode.driver,
    this.quality = RenderQuality.high,
    this.timeOfDay = TimeOfDay3D.day,
    Color? egoPaint,
    EgoVehicleModel? egoModel,
    this.models,
    this.modelInterior = true,
  }) : _mode = mode, // ignore: prefer_initializing_formals
       egoModel = egoModel ?? style.egoVehicle,
       traffic = TrafficSimulation(
         road,
         density: switch (quality) {
           RenderQuality.low => 0.5,
           RenderQuality.medium => 0.8,
           RenderQuality.high => 1.0,
         },
       ),
       _library = VehicleLibrary(
         detail: quality == RenderQuality.low ? 0 : 1,
         models: models,
       ) {
    _build(egoPaint ?? style.egoPaint);
    _applyMode();
  }

  final DashStyle style;
  final RoadProfile road;
  final RenderQuality quality;

  /// Imported vehicle models (already loaded); null = procedural only.
  final VehicleModelSet? models;

  CameraMode _mode;

  /// Viewpoint; can change at any time (the cockpit and the ego body are
  /// both built, only one is shown).
  CameraMode get mode => _mode;
  set mode(CameraMode m) {
    if (m == _mode) return;
    _mode = m;
    _applyMode();
  }

  /// Exterior orbit: yaw around the vehicle (0 = behind, π/2 = right
  /// side), pitch above the horizon and distance in metres.
  double orbitYaw = 0.75, orbitPitch = 0.2, orbitDistance = 7.5;

  /// Turns the exterior orbit camera (drag deltas in radians / metres).
  void orbitBy({double yaw = 0, double pitch = 0, double zoom = 0}) {
    orbitYaw = (orbitYaw + yaw) % (2 * math.pi);
    orbitPitch = (orbitPitch + pitch).clamp(0.02, 1.2);
    orbitDistance = (orbitDistance + zoom).clamp(3.5, 25.0);
  }

  void _applyMode() {
    final driver = _mode == CameraMode.driver;
    final r = rig;
    if (r != null) model.setVisible(r.root, driver);
    final e = ego;
    if (e != null) model.setVisible(e.root, !driver || usesModelCabin);
  }

  /// Drive from inside an imported model's own cabin when it has one.
  final bool modelInterior;

  /// The driver view uses the ego model's own interior.
  bool usesModelCabin = false;

  TimeOfDay3D timeOfDay;

  /// Body style of the ego vehicle (theme default unless overridden).
  final EgoVehicleModel egoModel;

  final SceneModel model = SceneModel();
  final TrafficSimulation traffic;
  final VehicleLibrary _library;
  final DriverCamera camera = DriverCamera();
  late final RoadWorld world;
  late final int _body;
  double _frameDt = 0;
  CockpitRig? rig;
  VehicleInstance? ego;
  final List<int> _headlights = [];
  late final int _tailGlow;

  final Map<TrafficVehicleKind, List<VehicleInstance>> _free = {};
  final Map<int, (TrafficVehicleKind, VehicleInstance)> _assigned = {};

  double distance = 0;

  /// Lateral offset of the ego after collision handling.
  double lateral = 0;

  /// Contact resolved in the latest [update] (null when clear).
  EgoContact? lastContact;

  /// Called whenever the ego had to be kept clear of another vehicle.
  void Function(EgoContact contact)? onContact;

  double _hostDistance = 0;
  double _sCorrection = 0, _latCorrection = 0;
  double _time = 0;

  /// Ego footprint used for collisions.
  late final EgoFootprint footprint = egoModel.isMotorcycle
      ? const EgoFootprint.motorcycle()
      : EgoFootprint(
          lengthM: proportionsForEgo(egoModel).length,
          widthM: proportionsForEgo(egoModel).width,
        );
  double _lastSpeed = 0;
  double _longAccel = 0;
  bool _hasSpeed = false;
  Conditions _conditions = const Conditions();
  TimeOfDay3D? _envTime;
  WeatherType? _envWeather;
  bool _envInit = false;

  late final CockpitSpec cockpit = _cockpitFor();

  CockpitSpec _cockpitFor() {
    final base = style.cockpit;
    if (egoModel == style.egoVehicle ||
        base.motorcycle ||
        egoModel.isMotorcycle) {
      return base;
    }
    return base.copyWith(
      eyeHeightM: switch (egoModel) {
        EgoVehicleModel.sportCoupe => 1.04,
        EgoVehicleModel.fastback => 1.13,
        EgoVehicleModel.suv => 1.45,
        EgoVehicleModel.pickup => 1.55,
        _ => 1.17,
      },
    );
  }

  void _build(Color paint) {
    final worldRoot = model.group(-1, name: 'world');
    world = RoadWorld(model, worldRoot, road, quality: quality);
    final trafficRoot = model.group(worldRoot, name: 'traffic');
    final pool = <TrafficVehicleKind, int>{
      TrafficVehicleKind.sedan: 14,
      TrafficVehicleKind.suv: 8,
      TrafficVehicleKind.pickup: 4,
      TrafficVehicleKind.van: 4,
      TrafficVehicleKind.truck: 4,
      TrafficVehicleKind.bus: road.scenario == RoadScenario.city ? 3 : 1,
      TrafficVehicleKind.motorcycle: 4,
    };
    final scale = switch (quality) {
      RenderQuality.low => 0.5,
      RenderQuality.medium => 0.75,
      RenderQuality.high => 1.0,
    };
    final rng = math.Random(17);
    for (final MapEntry(key: kind, value: n) in pool.entries) {
      final list = _free[kind] = [];
      for (var i = 0; i < math.max(1, (n * scale).round()); i++) {
        final heavy =
            kind == TrafficVehicleKind.truck || kind == TrafficVehicleKind.bus;
        final v = _library.instantiate(
          model,
          trafficRoot,
          kind,
          signature: heavy
              ? const VehicleSignature()
              : VehicleSignature.traffic[rng.nextInt(
                  VehicleSignature.traffic.length,
                )],
          variant: i,
          withBeams: quality != RenderQuality.low,
          name: kind.name,
        );
        model.setVisible(v.root, false);
        list.add(v);
      }
    }

    _body = model.group(-1, name: 'ego');
    // Both are built so the viewpoint can switch without a rebuild.
    final e = ego = _library.instantiate(
      model,
      _body,
      egoModel,
      paint: paint,
      signature: signatureForTheme(style),
      withBeams: true,
      name: 'ego',
      // The own car is seen up close in the exterior views.
      detail: quality == RenderQuality.low ? 1 : 2,
    );
    // A model with its own cabin is driven from inside it; otherwise the
    // generic themed cockpit is used.
    final own = modelInterior && !style.isMotorcycle ? e.cabin : null;
    rig = own != null
        ? CockpitRig.forModel(
            model,
            _body,
            cockpit,
            own,
            cabin: CabinProfile.forModel(egoModel),
          )
        : CockpitRig.build(
            model,
            _body,
            cockpit,
            paint: paint,
            cabin: CabinProfile.forModel(egoModel),
            // The bonnet seen from the seat matches the own car's body.
            noseZ: e.proportions.length / 2,
            bodyWidth: e.proportions.width,
          );
    usesModelCabin = own != null;
    // Red glow of the ego's tail lamps on the road behind it.
    final p = ego!.proportions;
    _tailGlow = model.addLight(
      LightDesc(
        node: model.group(
          _body,
          transform: Matrix4.translation(
            Vector3(0, math.min(p.height * 0.5, 1.1), -p.length / 2 - 0.25),
          ),
        ),
        kind: LightKind.point,
        color: const Color(0xFFFF2A1A),
        intensity: 0,
        range: 7,
      ),
    );
    // Ego headlights light the road ahead.
    final front = style.isMotorcycle
        ? [0.0]
        : [-p.width * 0.33, p.width * 0.33];
    for (final x in front) {
      final node = model.group(
        _body,
        transform: Matrix4.translation(
          Vector3(
            x,
            style.isMotorcycle ? 0.95 : math.min(p.height * 0.45, 1.0),
            p.length / 2 + 0.05,
          ),
        ),
      );
      _headlights.add(
        model.addLight(
          LightDesc(
            node: node,
            color: const Color(0xFFFFF4E2),
            intensity: 0,
            range: 80,
            coneRad: 0.48,
            penumbra: 0.55,
            direction: Vector3(0, -0.075, 1),
            castsShadow: quality == RenderQuality.high && x <= 0,
          ),
        ),
      );
    }
  }

  /// Advances by [dt] seconds.
  void update(double dt, DashTelemetry t, {WeatherType? weather}) {
    if (!dt.isFinite || dt < 0) dt = 0;
    dt = math.min(dt, 0.1);
    _frameDt = dt;
    _time += dt;
    final traj = t.trajectory;
    final reverse = t.gear == Gear.reverse;
    final speed = t.speedKmh / 3.6 * (reverse ? -1 : 1);
    final prev = distance;
    final double hostS;
    if (traj?.distanceM != null) {
      hostS = _hostDistance = traj!.distanceM!;
    } else {
      hostS = _hostDistance += speed * dt;
    }
    final hostLat = traj?.laneOffsetM ?? 0;
    if (dt > 0) {
      final raw = _hasSpeed ? (speed - _lastSpeed) / dt : 0.0;
      _longAccel += (raw - _longAccel) * (1 - math.exp(-6 * dt));
      _lastSpeed = speed;
      _hasSpeed = true;
    }
    // Corrections from earlier contacts fade out; hosts that adopt the
    // contact (see [onContact]) keep them at zero.
    _sCorrection = _relax(_sCorrection, 3 * dt);
    _latCorrection = _relax(_latCorrection, 0.8 * dt);
    var egoS = hostS + _sCorrection;
    var egoLat = hostLat + _latCorrection;

    // Traffic.
    final host = t.trafficVehicles;
    final bodies = <_Body>[];
    if (host == null) {
      traffic.tick(
        dt,
        egoS: egoS,
        egoSpeed: speed,
        egoLateral: egoLat,
        egoLength: footprint.lengthM,
        egoWidth: footprint.widthM,
      );
      for (final v in traffic.vehicles) {
        bodies.add(
          _Body(v.s, v.lateral, v.length, v.width, v.oncoming ? -v.v : v.v),
        );
      }
    } else {
      for (final v in host) {
        final yaw = v.headingDeg * math.pi / 180;
        bodies.add(
          _Body(
            hostS + v.zM,
            hostLat + v.xM,
            v.kind.lengthM,
            vehicleWidthM(v.kind),
            v.speedKmh / 3.6 * math.cos(yaw),
          ),
        );
      }
    }
    final contact = _resolveEgo(bodies, egoS, egoLat);
    if (contact != null) {
      egoS = contact.distanceM;
      egoLat = contact.laneOffsetM;
      onContact?.call(contact);
    }
    lastContact = contact;
    _sCorrection = egoS - hostS;
    _latCorrection = egoLat - hostLat;
    distance = egoS;
    lateral = egoLat;
    final ds = distance - prev;

    final heading = (traj?.headingDeg ?? 0) * math.pi / 180;
    final latAccel =
        traj?.lateralAccelMps2 ?? speed * speed * road.curvatureAt(distance);

    _updateEnvironment(weather);
    world.update(distance, lateral, heading);

    final night = timeOfDay != TimeOfDay3D.day || _conditions.overcast > 0.85;
    final murky = _conditions.fog || _conditions.rain > 0.5;
    // Light cones read at night and in fog / rain.
    final beams = night || _conditions.fog;
    final beamOpacity = murky
        ? 0.85
        : (timeOfDay == TimeOfDay3D.night ? 0.5 : 0.3);
    _beams = beams;
    _beamOpacity = beamOpacity;
    final blinkOn = (_time * 1.5) % 1 < 0.5;
    final seen = <int>{};
    if (host == null) {
      for (final v in traffic.vehicles) {
        final yaw = (v.targetLateral - v.lateral).abs() > 0.05
            ? (v.targetLateral - v.lateral).sign * 0.05
            : 0.0;
        _place(
          v.id,
          v.kind,
          v.color,
          v.s,
          v.lateral,
          (v.oncoming ? math.pi : 0) + (v.oncoming ? -yaw : yaw),
          v.v * dt,
          braking: v.braking,
          left: v.leftIndicator,
          right: v.rightIndicator,
          lights: night,
          blinkOn: blinkOn,
          seen: seen,
        );
      }
    } else {
      for (final v in host) {
        _place(
          v.id,
          v.kind,
          v.color,
          hostS + v.zM,
          hostLat + v.xM,
          v.headingDeg * math.pi / 180,
          v.speedKmh / 3.6 * dt,
          braking: v.braking,
          left: v.leftIndicator,
          right: v.rightIndicator,
          lights: v.headlights || night,
          blinkOn: blinkOn,
          seen: seen,
        );
      }
    }
    for (final id
        in _assigned.keys.where((id) => !seen.contains(id)).toList()) {
      final (kind, inst) = _assigned.remove(id)!;
      model.setVisible(inst.root, false);
      _free[kind]!.add(inst);
    }

    // Ego body, cockpit and lights.
    final ahead = world.poseAt(distance + 25, lateral).position;
    camera.tick(
      dt,
      longAccel: _longAccel,
      latAccel: latAccel,
      speed: speed,
      distance: distance,
      lookYawTarget: _mode == CameraMode.driver
          ? math.atan2(ahead.x, ahead.z) * 0.35
          : math.atan2(ahead.x, ahead.z) * 0.6,
      leanDeg: t.leanAngleDeg,
      motorcycle: style.isMotorcycle,
      roughness: road.scenario == RoadScenario.rural ? 1.6 : 1,
    );
    model.setTransform(_body, camera.body);
    final steering = traj?.steeringDeg ?? 0;
    final lowBeam = night || _conditions.rain > 0.5 || _conditions.fog;
    final r = rig;
    if (r != null) {
      r.setSteering(model, steering);
      r.tickRain(model, dt, rain: _conditions.rain, speed: speed.abs());
    }
    final on = lowBeam || t.highBeam;
    final braking = _longAccel < -1.5 || t.speedKmh < 0.5;
    final e = ego;
    if (e != null) {
      e.setSteering(model, steering);
      e.rollWheels(
        model,
        ds,
        dt: dt,
        steerRad:
            steering / DriveSimulation.defaultSteeringRatio * math.pi / 180,
        // A motorcycle leans with its wheels; a car's body moves over them.
        chassis: style.isMotorcycle ? null : camera.body,
      );
      e.setLamps(
        model,
        braking: braking,
        headlights: on,
        leftIndicator: t.leftIndicator,
        rightIndicator: t.rightIndicator,
        blinkOn: blinkOn,
        highBeam: t.highBeam,
        // From the driver's seat the cones would fog the windscreen.
        beams: _mode != CameraMode.driver && (beams || t.highBeam && night),
        beamOpacity: beamOpacity,
      );
    }
    final glow = model.lights[_tailGlow];
    final glowI = _mode == CameraMode.driver
        ? 0.0
        : (braking ? 9.0 : (on ? 3.0 : 0.0));
    if (glow.intensity != glowI) {
      glow.intensity = glowI;
      model.markLight(_tailGlow);
    }
    switch (_mode) {
      case CameraMode.driver when r != null:
        camera.applyDriver(
          model.camera,
          r.eye,
          cockpit.fovDeg,
          pitchDownRad: style.isMotorcycle ? 0.035 : 0.14,
        );
      case CameraMode.exterior:
        camera.applyOrbit(
          model.camera,
          yaw: orbitYaw,
          pitch: orbitPitch,
          distance:
              orbitDistance *
              (e == null ? 1 : e.proportions.length / 4.7).clamp(0.6, 2.5),
          targetHeight: (e?.proportions.height ?? 1.4) * 0.5,
        );
      default:
        camera.applyChase(
          model.camera,
          height: math.max(3.4, (e?.proportions.height ?? 1.4) * 2.2),
          distance: math.max(8.0, (e?.proportions.length ?? 4.7) * 1.7),
        );
    }
    for (final l in _headlights) {
      final light = model.lights[l];
      final intensity = on ? (t.highBeam ? 1400.0 : 600.0) : 0.0;
      final range = t.highBeam ? 160.0 : 75.0;
      if (light.intensity != intensity || light.range != range) {
        light
          ..intensity = intensity
          ..range = range
          ..coneRad = t.highBeam ? 0.42 : 0.5
          ..direction.setValues(0, t.highBeam ? -0.02 : -0.08, 1);
        model.markLight(l);
      }
    }
  }

  static double _relax(double v, double step) =>
      v.abs() <= step ? 0 : v - v.sign * step;

  /// Pushes the ego out of any body it overlaps, along the axis of least
  /// penetration: a rear-end stops it at the bumper, a side swipe keeps it
  /// beside the other vehicle.
  EgoContact? _resolveEgo(List<_Body> bodies, double s, double lat) {
    final fp = footprint;
    double? limit;
    var side = 0;
    var hit = false;
    for (var pass = 0; pass < 3; pass++) {
      var moved = false;
      for (final b in bodies) {
        final ds = b.s - s, dl = b.lateral - lat;
        final needS = (fp.lengthM + b.length) / 2 + minBumperGapM * 0.5;
        final needL = (fp.widthM + b.width) / 2 + minSideGapM * 0.4;
        final oz = needS - ds.abs(), ox = needL - dl.abs();
        if (oz <= 0 || ox <= 0) continue;
        hit = moved = true;
        if (oz <= ox) {
          final ahead = ds >= 0;
          s = ahead ? b.s - needS : b.s + needS;
          final v = ahead ? math.max(0.0, b.speed) : 0.0;
          limit = limit == null ? v : math.min(limit, v);
        } else {
          final dir = dl >= 0 ? 1 : -1;
          lat = b.lateral - dir * needL;
          side = dir;
        }
      }
      if (!moved) break;
    }
    if (!hit) return null;
    return EgoContact(
      distanceM: s,
      laneOffsetM: lat,
      speedLimitKmh: limit == null ? null : limit * 3.6,
      side: side,
    );
  }

  void _place(
    int id,
    TrafficVehicleKind kind,
    Color color,
    double s,
    double lateral,
    double yaw,
    double ds, {
    required bool braking,
    required bool left,
    required bool right,
    required bool lights,
    required bool blinkOn,
    required Set<int> seen,
  }) {
    if (!world.covers(s)) return;
    var slot = _assigned[id];
    if (slot != null && slot.$1 != kind) {
      model.setVisible(slot.$2.root, false);
      _free[slot.$1]!.add(slot.$2);
      _assigned.remove(id);
      slot = null;
    }
    if (slot == null) {
      final free = _free[kind]!;
      if (free.isEmpty) return;
      slot = (kind, free.removeLast());
      _assigned[id] = slot;
      model.setVisible(slot.$2.root, true);
    }
    final inst = slot.$2;
    final paint = model.materials[inst.paint];
    if (paint.color != color) {
      paint.color = color;
      model.markMaterial(inst.paint);
    }
    seen.add(id);
    final pose = world.poseAt(s, lateral);
    model.setTransform(inst.root, pose.matrix(extraYaw: yaw));
    inst.rollWheels(model, ds.abs(), dt: _frameDt);
    inst.setLamps(
      model,
      braking: braking,
      headlights: lights,
      leftIndicator: left,
      rightIndicator: right,
      blinkOn: blinkOn,
      beams: _beams,
      beamOpacity: _beamOpacity * 0.8,
    );
  }

  bool _beams = false;
  double _beamOpacity = 0.5;

  void _updateEnvironment(WeatherType? weather) {
    if (_envInit && _envTime == timeOfDay && _envWeather == weather) return;
    _envInit = true;
    _envTime = timeOfDay;
    _envWeather = weather;
    _conditions = Conditions.of(weather);
    model.environment = environmentFor(
      timeOfDay,
      _conditions,
      shadows: quality != RenderQuality.low,
    );
    model.markEnvironment();
    world.setConditions(
      wet: _conditions.wet,
      night: timeOfDay != TimeOfDay3D.day,
    );
  }
}
