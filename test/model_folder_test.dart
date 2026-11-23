import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Matrix3, Vector3;

ImportedPart _box(
  String name,
  double x,
  double z,
  double hx,
  double hz, {
  String material = '',
}) {
  final p = <double>[];
  for (final sx in [-1, 1]) {
    for (final sy in [0, 1]) {
      for (final sz in [-1, 1]) {
        p.addAll([x + sx * hx, sy * 1.0, z + sz * hz]);
      }
    }
  }
  return ImportedPart(
    name,
    MeshData3D(
      positions: Float32List.fromList(p),
      normals: Float32List(p.length),
      indices: Uint32List.fromList([0, 1, 2]),
    ),
    ImportedMaterial(name: material),
  );
}

void main() {
  test('file names pick the vehicle kind', () {
    Object? kind(String rel) =>
        VehicleModelSet.assetFromName('assets/vehicles/$rel', rel)?.$1;
    expect(kind('ego-sedan.glb'), EgoVehicleModel.sedan);
    expect(kind('ego_coupe_porsche.glb'), EgoVehicleModel.sportCoupe);
    expect(kind('ego-wagon.obj'), EgoVehicleModel.shootingBrake);
    expect(kind('ego-suv-x5.glb'), EgoVehicleModel.suv);
    expect(kind('sedan-golf.glb'), TrafficVehicleKind.sedan);
    expect(kind('car_toyota.glb'), TrafficVehicleKind.sedan);
    expect(kind('suv rav4.glb'), TrafficVehicleKind.suv);
    expect(kind('city-bus.glb'), TrafficVehicleKind.bus);
    expect(kind('lorry.stl'), TrafficVehicleKind.truck);
    expect(kind('moto/scene.gltf'), TrafficVehicleKind.motorcycle);
    expect(kind('tree.glb'), isNull);
    final a = VehicleModelSet.assetFromName(
      'x/van-rot90-zup.obj',
      'van-rot90-zup.obj',
    )!.$2;
    expect(a.yawRad, closeTo(math.pi / 2, 1e-9));
    expect(a.autoYaw, isFalse);
    expect(a.zUp, isTrue);
    expect(a.keepAspect, isTrue);
    expect(
      VehicleModelSet.assetFromName('x/sedan.glb', 'sedan.glb')!.$2.autoYaw,
      isTrue,
    );
  });

  test('front is found from the lamps / long axis', () {
    // Along x, head lamps at +x: needs a quarter turn bringing +x to +z.
    final side = ImportedModel([
      _box('body', 0, 0, 2.3, 0.9),
      _box('l1', 2.2, 0, 0.1, 0.5, material: 'Headlight'),
      _box('l2', -2.2, 0, 0.1, 0.5, material: 'Taillight'),
    ]);
    final a = estimateYaw(side);
    final v = Matrix3.rotationY(a).transformed(Vector3(1, 0, 0));
    expect(v.z, closeTo(1, 1e-6));
    // Along z but facing backwards: half turn.
    final back = ImportedModel([
      _box('body', 0, 0, 0.9, 2.3),
      _box('l1', 0, -2.2, 0.5, 0.1, material: 'Head lamp'),
    ]);
    expect(estimateYaw(back).abs(), closeTo(math.pi, 1e-9));
  });

  test('the bundled models are already facing +z', () async {
    for (final f in [
      'assets/models/khronos_car_concept/car_concept.glb',
      'assets/models/kenney_car_kit/sedan.glb',
    ]) {
      final m = await ModelLoader.parse(
        File(f).readAsBytesSync(),
        ModelFormat.glb,
        name: f,
        resolve: (u) async =>
            File(ModelLoader.resolveRelative(f, u)).readAsBytesSync(),
      );
      expect(estimateYaw(m), 0, reason: f);
    }
  });
}
