import 'dart:io';

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';

const _concept = 'assets/models/khronos_car_concept/car_concept.glb';
const _kit = 'assets/models/kenney_car_kit';

Future<ImportedModel> _load(String file) => ModelLoader.parse(
  File(file).readAsBytesSync(),
  ModelFormat.glb,
  name: file,
  resolve: (uri) async =>
      File(ModelLoader.resolveRelative(file, uri)).readAsBytesSync(),
);

DriveScene _scene(
  EgoVehicleModel kind,
  VehicleModelSet set, {
  bool own = true,
}) => DriveScene(
  style: DashStyle.carPorsche,
  road: RoadProfile(),
  egoModel: kind,
  models: set,
  modelInterior: own,
);

void main() {
  test('a model with its own interior is driven from inside it', () async {
    final set = VehicleModelSet(
      't',
      const {},
    )..add(EgoVehicleModel.sportCoupe, await _load(_concept), keepAspect: true);
    final f = set
        .modelsFor(EgoVehicleModel.sportCoupe)
        .first
        .fit(proportionsForEgo(EgoVehicleModel.sportCoupe));
    final c = f.cabin!;
    // ignore: avoid_print
    print('hub ${c.hub} axis ${c.axis} r ${c.radius} eye ${c.eye}');
    // Left-hand drive wheel in the front half, at chest height, facing the
    // driver (axis mostly forward, tilted).
    expect(c.hub.z, greaterThan(-0.5));
    expect(c.hub.y, inInclusiveRange(0.6, 1.1));
    expect(c.axis.z, greaterThan(0.7));
    expect(c.radius, inInclusiveRange(0.14, 0.22));
    expect(f.steeringParts, isNotEmpty);

    final s = _scene(EgoVehicleModel.sportCoupe, set);
    expect(s.usesModelCabin, isTrue);
    final e = s.ego!;
    // Driver view shows the model (its seats, dash, wheel) plus the live
    // instrument display; the generic cabin is not built.
    expect(s.model.nodes[e.root].visible, isTrue);
    expect(s.rig!.clusterMaterial, greaterThanOrEqualTo(0));
    expect(s.rig!.steeringNode, isNull);
    expect(s.rig!.eye.y, closeTo(c.hub.y + 0.36, 1e-6));
    // The model's steering wheel turns with the trajectory.
    s.update(
      1 / 30,
      const DashTelemetry(
        speedKmh: 30,
        gear: Gear.drive,
        trajectory: VehicleTrajectory(steeringDeg: 90),
      ),
    );
    final m = s.model.nodes[e.steeringNode!].transform;
    expect(m.getTranslation().distanceTo(c.hub), lessThan(1e-4));
    expect(m.getRotation().isIdentity(), isFalse);

    // Opting out keeps the generic cockpit.
    expect(
      _scene(EgoVehicleModel.sportCoupe, set, own: false).usesModelCabin,
      isFalse,
    );
  });

  test('exterior-only models keep the generic cockpit', () async {
    final set = VehicleModelSet('t', const {})
      ..add(EgoVehicleModel.sedan, await _load('$_kit/sedan.glb'));
    final s = _scene(EgoVehicleModel.sedan, set);
    expect(s.usesModelCabin, isFalse);
    expect(s.ego!.cabin, isNull);
    expect(s.rig!.steeringNode, isNotNull);
  });
}
