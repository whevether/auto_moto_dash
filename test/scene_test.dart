import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:auto_moto_dash/src/three_d/scene/handedness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

void main() {
  group('SceneModel', () {
    test('takeFrame reports and clears changes', () {
      final m = SceneModel();
      final mat = m.addMaterial(MaterialDesc());
      final mesh = m.addMesh(
        (MeshBuilder()..box(Vector3.zero(), Vector3.all(1))).build(),
      );
      final g = m.group(-1);
      final n = m.meshNode(g, mesh, mat);
      final first = m.takeFrame();
      expect(first.environment, isTrue);
      expect(m.takeFrame().nodes, isEmpty);
      m.setTransform(n, Matrix4.translation(Vector3(1, 0, 0)));
      m.setEmissive(mat, 2);
      m.setEmissive(mat, 2);
      final f = m.takeFrame();
      expect(f.nodes, [n]);
      expect(f.materials, [mat]);
      expect(f.environment, isFalse);
    });

    test('worldTransform composes parents', () {
      final m = SceneModel();
      final a = m.group(-1, transform: Matrix4.translation(Vector3(1, 0, 0)));
      final b = m.group(a, transform: Matrix4.translation(Vector3(0, 2, 0)));
      expect(m.worldTransform(b).getTranslation(), Vector3(1, 2, 0));
    });

    test('setVisible ignores no-op changes', () {
      final m = SceneModel();
      final n = m.group(-1);
      m.takeFrame();
      m.setVisible(n, true);
      expect(m.takeFrame().nodes, isEmpty);
    });
  });

  group('MeshBuilder', () {
    test('box faces point outward', () {
      final mesh = (MeshBuilder()..box(Vector3(0, 1, 0), Vector3.all(2)))
          .build();
      final p = mesh.positions, idx = mesh.indices;
      for (var t = 0; t < idx.length; t += 3) {
        Vector3 v(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
        final a = v(idx[t]), b = v(idx[t + 1]), c = v(idx[t + 2]);
        final n = (b - a).cross(c - a);
        expect(n.dot((a + b + c) / 3 - Vector3(0, 1, 0)), greaterThan(0));
      }
    });

    test('strip faces point up', () {
      final s = StripMesh(3);
      for (var i = 0; i < 3; i++) {
        s.set(i, Vector3(-1, 0, i * 2.0), Vector3(1, 0, i * 2.0));
      }
      final p = s.positions, idx = s.indices;
      Vector3 v(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
      for (var t = 0; t < idx.length; t += 3) {
        final n = (v(idx[t + 1]) - v(idx[t])).cross(v(idx[t + 2]) - v(idx[t]));
        expect(n.y, greaterThan(0));
      }
    });

    test('texturedQuad honours facing', () {
      final q = MeshBuilder.texturedQuad(
        Vector3.zero(),
        Vector3(1, 0, 0),
        Vector3(0, 1, 0),
        1,
        1,
        facing: Vector3(0, 0, -1),
      );
      final p = q.positions, i = q.indices;
      Vector3 v(int k) => Vector3(p[k * 3], p[k * 3 + 1], p[k * 3 + 2]);
      final n = (v(i[1]) - v(i[0])).cross(v(i[2]) - v(i[0]));
      expect(n.z, lessThan(0));
      expect(q.uvs, isNotNull);
    });
  });

  group('Handedness', () {
    test('matrix conjugation equals mirroring points', () {
      final m = Matrix4.translation(Vector3(1, 2, 3))
        ..rotateY(0.4)
        ..rotateX(0.2);
      final p = Vector3(0.3, -0.5, 2);
      final viaMatrix = Handedness.matrix(m).transformed3(Handedness.vec(p));
      final viaPoint = Handedness.vec(m.transformed3(p));
      expect((viaMatrix - viaPoint).length, lessThan(1e-5));
    });

    test('winding flips so front faces survive the mirror', () {
      final mesh = (MeshBuilder()..box(Vector3.zero(), Vector3.all(1))).build();
      final p = Handedness.vec3Array(mesh.positions);
      final idx = Handedness.indices(mesh.indices);
      Vector3 v(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
      for (var t = 0; t < idx.length; t += 3) {
        final a = v(idx[t]), b = v(idx[t + 1]), c = v(idx[t + 2]);
        expect((b - a).cross(c - a).dot((a + b + c) / 3), greaterThan(0));
      }
    });
  });

  group('IDM / MOBIL', () {
    const idm = IdmParams(desiredSpeed: 30);

    test('accelerates on a free road and stops at desired speed', () {
      expect(idm.accel(10, double.infinity, 0), greaterThan(1));
      expect(idm.accel(30, double.infinity, 0).abs(), lessThan(1e-9));
    });

    test('brakes when closing on a slow leader', () {
      expect(idm.accel(25, 15, 15), lessThan(-3));
      expect(idm.accel(25, 15, 15), greaterThanOrEqualTo(-9));
    });

    test('simulation keeps gaps and stays finite', () {
      final road = RoadProfile(scenario: RoadScenario.highway);
      final sim = TrafficSimulation(road, seed: 1);
      var s = 0.0;
      for (var i = 0; i < 3000; i++) {
        s += 25 / 60;
        sim.tick(1 / 60, egoS: s, egoSpeed: 25, egoLateral: 0);
      }
      expect(sim.vehicles, isNotEmpty);
      for (final v in sim.vehicles) {
        expect(v.s.isFinite && v.v.isFinite && v.lateral.isFinite, isTrue);
        expect(v.v, greaterThanOrEqualTo(0));
        expect(
          v.lane,
          inInclusiveRange(
            0,
            v.oncoming ? road.oncomingLanes - 1 : road.lanes - 1,
          ),
        );
      }
      // No two same-lane vehicles overlap.
      for (final a in sim.vehicles) {
        for (final b in sim.vehicles) {
          if (identical(a, b) || a.oncoming != b.oncoming || a.lane != b.lane) {
            continue;
          }
          if ((a.lateral - a.targetLateral).abs() > 0.05 ||
              (b.lateral - b.targetLateral).abs() > 0.05) {
            continue;
          }
          expect(
            (a.s - b.s).abs(),
            greaterThan((a.length + b.length) / 2 - 0.5),
          );
        }
      }
    });

    test('changes lane to pass a slow leader', () {
      final road = RoadProfile(scenario: RoadScenario.highway);
      final sim = TrafficSimulation(road, density: 0);
      final slow = SimVehicle(
        id: 1,
        kind: TrafficVehicleKind.truck,
        color: const Color(0xFFFFFFFF),
        lane: 1,
        s: 1060,
        v: 15,
        params: const IdmParams(desiredSpeed: 15),
        oncoming: false,
        lateral: road.laneCenter(1),
      );
      final fast = SimVehicle(
        id: 2,
        kind: TrafficVehicleKind.sedan,
        color: const Color(0xFFFFFFFF),
        lane: 1,
        s: 1020,
        v: 30,
        params: const IdmParams(desiredSpeed: 33),
        oncoming: false,
        lateral: road.laneCenter(1),
      );
      sim.vehicles.addAll([slow, fast]);
      var changed = false;
      for (var i = 0; i < 600 && !changed; i++) {
        sim.tick(
          1 / 30,
          egoS: 0,
          egoSpeed: 0,
          egoLateral: road.laneCenter(2) + 40,
        );
        changed = fast.lane != 1;
        if (fast.leftIndicator || fast.rightIndicator) changed = true;
      }
      expect(changed, isTrue);
    });
  });

  group('RoadWorld', () {
    test('ego sits at the origin and the road follows curvature', () {
      final road = RoadProfile(scenario: RoadScenario.rural, seed: 3);
      final m = SceneModel();
      final w = RoadWorld(m, m.group(-1), road);
      // Find a right-hand bend.
      var s = 0.0;
      while (road.curvatureAt(s + 30) < 0.005) {
        s += 5;
      }
      w.update(s, 0, 0);
      final here = w.poseAt(s, 0).position;
      expect(here.length, lessThan(1e-6));
      final ahead = w.poseAt(s + 60, 0);
      expect(ahead.position.z, greaterThan(40));
      expect(ahead.position.x, greaterThan(0.5)); // bends right
      expect(ahead.yaw, greaterThan(0));
      expect(m.takeFrame().meshes, isNotEmpty);
    });

    test('lateral offset and heading move the road the other way', () {
      final road = RoadProfile(scenario: RoadScenario.highway);
      final m = SceneModel();
      final w = RoadWorld(m, m.group(-1), road);
      w.update(100, 1.5, 0);
      expect(w.poseAt(100, 0).position.x, closeTo(-1.5, 1e-6));
      w.update(100, 0, 0.1);
      expect(w.poseAt(150, 0).position.x, lessThan(-3));
    });
  });

  group('DriveScene', () {
    const t = DashTelemetry(speedKmh: 90, gear: Gear.drive);

    test('builds every theme cockpit and advances', () {
      for (final style in DashStyle.values) {
        final scene = DriveScene(
          style: style,
          road: RoadProfile(),
          quality: RenderQuality.low,
        );
        for (var i = 0; i < 20; i++) {
          scene.update(1 / 30, t, weather: WeatherType.heavyRain);
        }
        final frame = scene.model.takeFrame();
        expect(frame.camera.position.y, greaterThan(0.5), reason: style.name);
        expect(scene.rig, isNotNull);
        expect(scene.rig!.motorcycle, style.isMotorcycle);
        expect(scene.cockpit.motorcycle, style.isMotorcycle);
        for (final n in scene.model.nodes) {
          expect(
            n.transform.storage.every((v) => v.isFinite),
            isTrue,
            reason: style.name,
          );
        }
      }
    });

    test('host traffic overrides the simulation', () {
      final scene = DriveScene(
        style: DashStyle.carEvTesla,
        road: RoadProfile(),
        mode: CameraMode.chase,
      );
      scene.update(
        1 / 30,
        t.copyWith(
          trafficVehicles: const [
            TrafficVehicle(id: 42, kind: TrafficVehicleKind.bus, zM: 30),
          ],
          trajectory: const VehicleTrajectory(distanceM: 500),
        ),
      );
      expect(scene.distance, 500);
      final visibleBuses = scene.model.nodes
          .where((n) => n.name == 'bus' && n.visible)
          .length;
      expect(visibleBuses, 1);
      expect(scene.ego, isNotNull);
    });

    test('steering rotates the wheel node', () {
      final scene = DriveScene(style: DashStyle.classic, road: RoadProfile());
      scene.update(
        1 / 30,
        t.copyWith(trajectory: const VehicleTrajectory(steeringDeg: 90)),
      );
      final rig = scene.rig!;
      final m = scene.model.nodes[rig.steeringNode!].transform;
      final x = m.getRotation() * Vector3(1, 0, 0);
      // Rim's local +x tilts down (clockwise) for a right turn.
      expect(x.y, lessThan(-0.5));
      expect(math.pi, greaterThan(3));
    });
  });
}
