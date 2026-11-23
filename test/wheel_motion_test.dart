import 'dart:io';
import 'dart:math' as math;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

const _kit = 'assets/models/kenney_car_kit';

Future<ImportedModel> _load(String file) => ModelLoader.parse(
  File(file).readAsBytesSync(),
  ModelFormat.glb,
  name: file,
  resolve: (uri) async =>
      File(ModelLoader.resolveRelative(file, uri)).readAsBytesSync(),
);

/// Drives hard (launch, brake, swerve) and records, per wheel, the lowest
/// point, the outer face and the centre in the ego's road frame.
List<List<List<double>>> _drive(DriveScene s) {
  final e = s.ego!;
  final model = s.model;
  final egoNode = model.nodes[e.root].parent;
  final out = List.generate(e.wheels.length, (_) => <List<double>>[]);
  for (var f = 0; f < 240; f++) {
    final t = f / 60;
    final speed = t < 2 ? 20 + 40 * t : math.max(0.0, 100 - 60 * (t - 2));
    s.update(
      1 / 60,
      DashTelemetry(
        speedKmh: speed,
        gear: Gear.drive,
        trajectory: VehicleTrajectory(
          steeringDeg: 120 * math.sin(t * 3),
          lateralAccelMps2: 6 * math.sin(t * 3),
        ),
      ),
    );
    if (f < 20) continue; // let the springs wind up
    final body = model.nodes[egoNode].transform;
    for (var w = 0; w < e.wheels.length; w++) {
      final g = e.wheels[w];
      final toRoad =
          body * model.nodes[e.root].transform * model.nodes[g].transform
              as Matrix4;
      var minY = 1e9, minX = 1e9, maxX = -1e9;
      final c = Vector3.zero();
      var n = 0;
      for (final node in model.nodes.where((x) => x.parent == g)) {
        final p = model.meshes[node.mesh!].positions;
        final m = toRoad * node.transform as Matrix4;
        for (var i = 0; i + 2 < p.length; i += 3) {
          final v = m.transform3(Vector3(p[i], p[i + 1], p[i + 2]));
          minY = math.min(minY, v.y);
          minX = math.min(minX, v.x);
          maxX = math.max(maxX, v.x);
          c.add(v);
          n++;
        }
      }
      c.scale(1 / n);
      out[w].add([minY, minX, maxX, c.x, c.y]);
    }
  }
  return out;
}

double _range(List<List<double>> s, int k) {
  final v = s.map((e) => e[k]);
  return v.reduce(math.max) - v.reduce(math.min);
}

void main() {
  test('spoked rims blur into a disc at speed, sharp when slow', () async {
    final set = VehicleModelSet('t', const {})
      ..add(
        EgoVehicleModel.sportCoupe,
        await _load('assets/models/khronos_car_concept/car_concept.glb'),
        keepAspect: true,
      );
    final s = DriveScene(
      style: DashStyle.carPorsche,
      road: RoadProfile(),
      mode: CameraMode.exterior,
      egoModel: EgoVehicleModel.sportCoupe,
      models: set,
    );
    final e = s.ego!;
    expect(e.blurDiscs.length, 4);
    void drive(double kmh) {
      for (var i = 0; i < 90; i++) {
        s.update(1 / 60, DashTelemetry(speedKmh: kmh, gear: Gear.drive));
      }
    }

    drive(5);
    expect(s.model.nodes[e.blurDiscs.first].visible, isFalse);
    drive(80);
    expect(s.model.nodes[e.blurDiscs.first].visible, isTrue);
    expect(s.model.materials[e.blurMaterial!].opacity, greaterThan(0.85));
    // The disc sits on the outer rim face, inside the tyre.
    for (final d in e.blurDiscs) {
      final m = s.model.nodes[d].transform;
      final r = m.getMaxScaleOnAxis();
      expect(r, inInclusiveRange(0.2, e.wheelRadius * 0.92));
    }
    // Single-piece low-poly wheels have nothing to blur.
    final kit = VehicleModelSet('k', const {})
      ..add(EgoVehicleModel.sedan, await _load('$_kit/sedan.glb'));
    final k = DriveScene(
      style: DashStyle.carPorsche,
      road: RoadProfile(),
      mode: CameraMode.exterior,
      egoModel: EgoVehicleModel.sedan,
      models: kit,
    );
    expect(k.ego!.blurDiscs, isEmpty);
  });

  for (final (file, kind, keep) in [
    ('$_kit/sedan.glb', EgoVehicleModel.sedan, false),
    ('$_kit/suv.glb', EgoVehicleModel.suv, false),
    (
      'assets/models/khronos_car_concept/car_concept.glb',
      EgoVehicleModel.sportCoupe,
      true,
    ),
  ]) {
    test('wheels stay planted and true while the body moves: $file', () async {
      final set = VehicleModelSet('t', const {})
        ..add(kind, await _load(file), keepAspect: keep);
      final s = DriveScene(
        style: DashStyle.carPorsche,
        road: RoadProfile(),
        mode: CameraMode.exterior,
        egoModel: kind,
        models: set,
      );
      // Four road wheels; a tailgate spare is body, not a rolling wheel.
      expect(s.ego!.wheels.length, 4);
      final stats = _drive(s);
      // The body really does pitch, roll and bounce …
      expect(s.camera.body.isIdentity(), isFalse);
      for (final w in stats) {
        // … but each wheel keeps touching the road (no sinking / lifting),
        expect(_range(w, 0), lessThan(0.006), reason: 'ground contact');
        // does not wobble sideways like a loose nut,
        expect(_range(w, 3), lessThan(0.002), reason: 'hub x');
        expect(_range(w, 4), lessThan(0.006), reason: 'hub height');
      }
      // Rear wheels are not steered: their faces stay put.
      for (var i = 0; i < 4; i++) {
        if (s.ego!.wheelPositions[i].z < 0) {
          expect(_range(stats[i], 1), lessThan(0.002), reason: 'rear camber');
          expect(_range(stats[i], 2), lessThan(0.002), reason: 'rear camber');
        }
      }
    });
  }
}
