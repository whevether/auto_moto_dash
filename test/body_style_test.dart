import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cars = EgoVehicleModel.values.where((m) => !m.isMotorcycle);

  test('every car body style gets its own cabin', () {
    final kinds = {for (final m in cars) CabinProfile.forModel(m).kind};
    expect(kinds.length, cars.length);
    final coupe = CabinProfile.forModel(EgoVehicleModel.sportCoupe);
    final sedan = CabinProfile.forModel(EgoVehicleModel.sedan);
    final suv = CabinProfile.forModel(EgoVehicleModel.suv);
    final pickup = CabinProfile.forModel(EgoVehicleModel.pickup);
    // Low raked coupe, upright SUV / pickup with long flat bonnets.
    expect(coupe.roofDy, lessThan(sedan.roofDy));
    expect(suv.roofDy, greaterThan(sedan.roofDy));
    expect(
      coupe.glassBaseDz - coupe.glassTopDz,
      greaterThan(suv.glassBaseDz - suv.glassTopDz),
    );
    expect(pickup.hoodFall, lessThan(coupe.hoodFall));
    expect(pickup.halfWidth, greaterThan(coupe.halfWidth));
    expect(coupe.sport, isTrue);
    expect(suv.grabHandles && pickup.grabHandles, isTrue);
  });

  for (final m in cars) {
    test('$m: cockpit and detailed body follow the body style', () {
      final s = DriveScene(
        style: DashStyle.classic,
        road: RoadProfile(),
        egoModel: m,
        quality: RenderQuality.high,
      );
      expect(s.rig!.cabin, CabinProfile.forModel(m));
      expect(s.ego!.imported, isFalse);
      expect(s.ego!.proportions.type, proportionsForEgo(m).type);
      s.update(1 / 30, const DashTelemetry(speedKmh: 50, gear: Gear.drive));
    });
  }

  test('type-specific exterior details', () {
    int tris(EgoVehicleModel m, String part, {int detail = 1}) {
      final v = ProceduralVehicle.car(proportionsForEgo(m), detail: detail);
      return switch (part) {
        'trim' => v.trim.triangleCount,
        'chrome' => v.chrome.triangleCount,
        _ => v.body.triangleCount,
      };
    }

    // SUV cladding / arch flares, pickup running boards and bed rails.
    expect(
      tris(EgoVehicleModel.suv, 'trim'),
      greaterThan(tris(EgoVehicleModel.sedan, 'trim')),
    );
    expect(
      tris(EgoVehicleModel.pickup, 'trim'),
      greaterThan(tris(EgoVehicleModel.sedan, 'trim')),
    );
    // Quad exhaust on the coupe.
    expect(
      tris(EgoVehicleModel.sportCoupe, 'chrome'),
      greaterThan(tris(EgoVehicleModel.sedan, 'chrome')),
    );
    // Higher detail for the own car.
    expect(
      tris(EgoVehicleModel.sedan, 'body', detail: 2),
      greaterThan(tris(EgoVehicleModel.sedan, 'body')),
    );
  });

  test('bundled kit is used for traffic, not for the own car', () {
    final kit = VehicleModelSet.kenneyCarKit;
    expect(kit.assets.keys.whereType<EgoVehicleModel>(), isEmpty);
    expect(kit.assets.keys.whereType<TrafficVehicleKind>(), isNotEmpty);
  });
}
