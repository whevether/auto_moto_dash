import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';

bool _overlap(
  double s1,
  double l1,
  double w1,
  double lat1,
  double s2,
  double l2,
  double w2,
  double lat2,
) =>
    (s1 - s2).abs() < (l1 + l2) / 2 - 0.05 &&
    (lat1 - lat2).abs() < (w1 + w2) / 2 - 0.05;

void main() {
  group('collisions', () {
    for (final scenario in RoadScenario.values) {
      test('traffic never overlaps itself or the ego ($scenario)', () {
        final road = RoadProfile(scenario: scenario);
        final sim = TrafficSimulation(road, density: 1.5, seed: 11);
        var s = 0.0;
        var lat = road.laneCenter(road.egoLane);
        for (var i = 0; i < 6000; i++) {
          // Ego weaves between lanes at a fast, varying speed.
          final v = 22 + 12 * ((i ~/ 600) % 2);
          s += v / 60;
          lat = road.laneCenter(road.egoLane) + ((i ~/ 900) % 2) * 0.8;
          sim.tick(1 / 60, egoS: s, egoSpeed: v.toDouble(), egoLateral: lat);
          final vs = sim.vehicles;
          for (var a = 0; a < vs.length; a++) {
            final x = vs[a];
            expect(
              _overlap(x.s, x.length, x.width, x.lateral, s, 4.7, 1.9, lat) &&
                  x.s < s,
              isFalse,
              reason: 'vehicle ${x.id} drove into the ego at step $i',
            );
            for (var b = a + 1; b < vs.length; b++) {
              final y = vs[b];
              if (x.oncoming != y.oncoming) continue;
              expect(
                _overlap(
                  x.s,
                  x.length,
                  x.width,
                  x.lateral,
                  y.s,
                  y.length,
                  y.width,
                  y.lateral,
                ),
                isFalse,
                reason: 'vehicles ${x.id} and ${y.id} overlap at step $i',
              );
            }
          }
        }
      });
    }

    test('ego stops at the bumper of slower traffic instead of passing '
        'through', () {
      final road = RoadProfile();
      final scene = DriveScene(
        style: DashStyle.classic,
        road: road,
        quality: RenderQuality.low,
      );
      final contacts = <EgoContact>[];
      scene.onContact = contacts.add;
      final sim = DriveSimulation(road: road, gear: Gear.drive);
      for (var i = 0; i < 60 * 90; i++) {
        sim
          ..speedKmh = 160
          ..tick(1 / 60, accelerating: true, braking: false);
        final t = DashTelemetry(
          speedKmh: sim.speedKmh,
          gear: Gear.drive,
          trajectory: sim.trajectory,
        );
        scene.update(1 / 60, t);
        final c = scene.lastContact;
        if (c != null) {
          sim
            ..distanceM = c.distanceM
            ..laneOffsetM = c.laneOffsetM;
          final limit = c.speedLimitKmh;
          if (limit != null && sim.speedKmh > limit) sim.speedKmh = limit;
        }
        for (final v in scene.traffic.vehicles) {
          expect(
            _overlap(
              v.s,
              v.length,
              v.width,
              v.lateral,
              scene.distance,
              scene.footprint.lengthM,
              scene.footprint.widthM,
              scene.lateral,
            ),
            isFalse,
            reason: 'ego overlaps vehicle ${v.id} at step $i',
          );
        }
      }
      expect(contacts, isNotEmpty);
    });

    test('ego is kept beside a vehicle it steers into', () {
      final road = RoadProfile();
      final scene = DriveScene(
        style: DashStyle.classic,
        road: road,
        quality: RenderQuality.low,
      );
      final lane = road.egoLane;
      final other = lane > 0 ? lane - 1 : lane + 1;
      scene.update(0, const DashTelemetry(speedKmh: 0));
      scene.traffic.vehicles
        ..clear()
        ..add(
          SimVehicle(
            id: 99,
            kind: TrafficVehicleKind.truck,
            color: const Color(0xFFFFFFFF),
            lane: other,
            s: 0,
            v: 0,
            params: const IdmParams(desiredSpeed: 0.01),
            oncoming: false,
            lateral: road.laneCenter(other),
          ),
        );
      scene.traffic.density = 0;
      final t = DashTelemetry(
        speedKmh: 0,
        trajectory: VehicleTrajectory(
          laneOffsetM: road.laneCenter(other),
          distanceM: 0,
        ),
      );
      scene.update(1 / 60, t);
      final c = scene.lastContact!;
      expect(c.side, isNot(0));
      final gap =
          (scene.lateral - road.laneCenter(other)).abs() -
          (scene.footprint.widthM + 2.45) / 2;
      expect(gap, greaterThanOrEqualTo(0));
    });
  });
}
