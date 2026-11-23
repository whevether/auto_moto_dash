/// First-person 3D cockpit and 3D instrument road views for
/// `auto_moto_dash`. Native platforms render with flutter_scene (Flutter
/// GPU); the web renders with bundled three.js r187.
library;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'src/three_d/camera/environment.dart';
import 'src/three_d/drive_scene.dart';
import 'src/three_d/drive_view.dart';
import 'src/three_d/scene/renderer_3d.dart';
import 'src/three_d/vehicles/vehicle_models.dart';

export 'src/three_d/backends/renderer_factory.dart' show createRenderer3D;
export 'src/three_d/camera/driver_camera.dart';
export 'src/three_d/camera/environment.dart';
export 'src/three_d/cockpit/cluster_texture.dart';
export 'src/three_d/cockpit/cockpit_rig.dart'
    show
        CabinKind,
        CabinProfile,
        ClusterFit,
        CockpitRig,
        carClusterAspect,
        clusterSlot,
        fitClusterInWheel,
        wheelHubTop,
        wheelRimRadius,
        wheelRimTube,
        wheelTiltRad;
export 'src/three_d/drive_scene.dart';
export 'src/three_d/drive_view.dart';
export 'src/three_d/geometry/mesh_builder.dart';
export 'src/three_d/import/gltf_importer.dart';
export 'src/three_d/import/imported_model.dart';
export 'src/three_d/import/model_loader.dart';
export 'src/three_d/import/obj_stl_importer.dart';
export 'src/three_d/scene/renderer_3d.dart';
export 'src/three_d/scene/scene_model.dart';
export 'src/three_d/vehicles/procedural_vehicle.dart';
export 'src/three_d/vehicles/vehicle_library.dart';
export 'src/three_d/vehicles/vehicle_models.dart';
export 'src/three_d/world/road_world.dart' show RoadPose, RoadWorld;
export 'src/three_d/world/traffic_simulation.dart';

/// Ready-made hooks for `AutoMotoDashboard`.
///
/// ```dart
/// AutoMotoDashboard(
///   telemetry: telemetry,
///   style: DashStyle.carEvTesla,
///   viewMode: DashViewMode.cockpit,
///   cockpitBuilder: AutoMotoDash3D.cockpitBuilder(road: sim.road),
///   roadViewBuilder: AutoMotoDash3D.roadViewBuilder(road: sim.road),
/// )
/// ```
abstract final class AutoMotoDash3D {
  static DashCockpitBuilder cockpitBuilder({
    RoadProfile? road,
    RoadScenario scenario = RoadScenario.highway,
    RenderQuality quality = RenderQuality.high,
    TimeOfDay3D timeOfDay = TimeOfDay3D.day,
    EgoVehicleModel? egoModel,
    void Function(EgoContact contact)? onContact,
    VehicleModelSet? models,
    CameraMode? cameraMode,
    ValueChanged<CameraMode>? onCameraModeChanged,
    bool showViewToggle = true,
  }) =>
      (context, request) => CockpitView(
        request: request,
        egoModel: egoModel,
        onContact: onContact,
        models: models,
        cameraMode: cameraMode,
        onCameraModeChanged: onCameraModeChanged,
        showViewToggle: showViewToggle,
        road: road,
        scenario: scenario,
        quality: quality,
        timeOfDay: timeOfDay,
      );

  static DashRoadViewBuilder roadViewBuilder({
    RoadProfile? road,
    RoadScenario scenario = RoadScenario.highway,
    RenderQuality quality = RenderQuality.medium,
    TimeOfDay3D timeOfDay = TimeOfDay3D.day,
    EgoVehicleModel? egoModel,
    VehicleModelSet? models,
  }) =>
      (context, request) => Road3DView(
        request: request,
        egoModel: egoModel,
        models: models,
        road: road,
        scenario: scenario,
        quality: quality,
        timeOfDay: timeOfDay,
      );
}
