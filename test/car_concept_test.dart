import 'dart:io';

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';

const _file = 'assets/models/khronos_car_concept/car_concept.glb';

void main() {
  late ImportedModel model;
  setUpAll(() async {
    model = await ModelLoader.parse(
      File(_file).readAsBytesSync(),
      ModelFormat.glb,
      name: 'car_concept',
    );
  });

  test('trimmed asset: no textures or logo parts', () {
    expect(model.images, isEmpty);
    final names = model.parts.map((p) => p.name).toSet();
    expect(names, isNot(contains('License Plate')));
    expect(names, isNot(contains('InteriorSteeringEmblem')));
    expect(model.triangleCount, greaterThan(100000));
    // Steering wheel and brake callipers are not road wheels.
    expect(
      model.parts.where((p) => p.isWheel).map((p) => p.name),
      everyElement(isNot(anyOf(contains('Steering'), contains('BrakePad')))),
    );
    final glass = model.parts.firstWhere((p) => p.material.name == 'Glass');
    expect(glass.material.opacity, lessThan(0.5));
    // Texture-driven emission (dash, mirrors) is not flattened to a glow.
    for (final p in model.parts) {
      if (p.material.name == 'Mirror' || p.material.name == 'Dashboard') {
        expect(p.material.emissiveStrength, 0);
      }
    }
  });

  test('fits the coupe true to its proportions', () {
    final target = proportionsForEgo(EgoVehicleModel.sportCoupe);
    final f = ImportedVehicleModel(model, keepAspect: true).fit(target);
    final p = f.proportions;
    expect(p.length, closeTo(target.length, 0.05));
    // Real car aspect, not stretched onto the footprint.
    expect(p.height / p.length, closeTo(1.2 / 4.3, 0.06));
    expect(p.wheelbase, inInclusiveRange(2.3, 3.0));
    // Four wheels, each tyre + rim + disc on one hub, touching the ground.
    final hubs = {
      for (final w in f.wheels)
        w.pivot!.storage.map((e) => e.toStringAsFixed(3)).join(','),
    };
    expect(hubs.length, 4);
    for (final w in f.wheels) {
      expect(w.pivot!.y - f.wheelRadius, closeTo(0, 0.05));
    }
    // The model's front wheels are authored steered 30°; after fitting every
    // tyre must sit straight, axle on x, so spinning about x does not wobble.
    final treads = f.wheels.where((w) => w.material.name == 'Tiretread');
    expect(treads.length, 4);
    for (final w in treads) {
      final b = boundsOf(w.mesh.positions);
      final width = b.max.x - b.min.x, depth = b.max.z - b.min.z;
      expect(width, lessThan(0.4), reason: 'tyre not turned');
      expect(depth, closeTo(b.max.y - b.min.y, 0.02), reason: 'round in y/z');
      expect((b.min.z + b.max.z).abs(), lessThan(0.01), reason: 'centred');
    }
    // Callipers of the steered wheels are straightened with them.
    for (final c in model.parts.where((p) => p.name.contains('BrakePad'))) {
      expect(c.isWheel, isFalse);
    }
    // Own lamps: head at the front, tail at the rear, indicators per side.
    expect(f.ownLamps, isTrue);
    final head = boundsOf(f.headLamps.positions);
    final tail = boundsOf(f.tailLamps.positions);
    expect(head.min.z, greaterThan(p.length / 2 - 1.2));
    expect(tail.max.z, lessThan(-p.length / 2 + 1.2));
    expect(f.leftIndicator.triangleCount, greaterThan(0));
    expect(f.rightIndicator.triangleCount, greaterThan(0));
    final lx = boundsOf(f.leftIndicator.positions);
    expect(lx.max.x, lessThanOrEqualTo(0.05));
    expect(f.body.where((b) => b.paint), isNotEmpty);
  });

  test('drives as the own sports coupe with the theme paint', () {
    final set = VehicleModelSet('t', const {})
      ..add(EgoVehicleModel.sportCoupe, model, keepAspect: true);
    final s = DriveScene(
      style: DashStyle.carPorsche,
      road: RoadProfile(),
      mode: CameraMode.exterior,
      timeOfDay: TimeOfDay3D.night,
      egoModel: EgoVehicleModel.sportCoupe,
      models: set,
    );
    for (var i = 0; i < 5; i++) {
      s.update(1 / 30, const DashTelemetry(speedKmh: 60, gear: Gear.drive));
    }
    final e = s.ego!;
    expect(e.imported, isTrue);
    expect(e.wheels.length, 4);
    expect(s.model.materials[e.head].emissiveStrength, greaterThan(1));
    expect(s.model.nodes[e.beams!].visible, isTrue);
    final paintNodes = s.model.nodes.where((n) => n.material == e.paint);
    expect(paintNodes, isNotEmpty);
    // The cockpit view still uses the matching coupe cabin.
    expect(s.rig!.cabin.kind, CabinKind.coupe);
  });

  test('openModels loads the big ego model only when needed', () {
    final set = VehicleModelSet.openModels;
    expect(set.assets[EgoVehicleModel.sportCoupe], isNotEmpty);
    expect(set.isLoadedFor([EgoVehicleModel.sedan]), isTrue);
    expect(set.isLoadedFor([EgoVehicleModel.sportCoupe]), isFalse);
  });
}
