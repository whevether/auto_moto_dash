import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('trajectory / traffic telemetry', () {
    test('normalized clamps trajectory and drops invalid vehicles', () {
      const t = DashTelemetry(
        trajectory: VehicleTrajectory(steeringDeg: double.infinity, headingDeg: 400, distanceM: double.nan),
        trafficVehicles: [
          TrafficVehicle(id: 1, zM: 10),
          TrafficVehicle(id: 2, zM: double.nan),
        ],
      );
      final n = t.normalized();
      expect(n.trajectory!.steeringDeg, 0);
      expect(n.trajectory!.headingDeg, VehicleTrajectory.maxHeadingDeg);
      expect(n.trajectory!.distanceM, isNull);
      expect(n.trafficVehicles!.map((v) => v.id), [1]);
    });

    test('valid telemetry keeps identity; copyWith clears', () {
      const t = DashTelemetry(
        trajectory: VehicleTrajectory(laneOffsetM: 0.5),
        trafficVehicles: [TrafficVehicle(id: 1)],
      );
      expect(identical(t.normalized(), t), isTrue);
      final c = t.copyWith(clearTrajectory: true, clearTrafficVehicles: true);
      expect(c.trajectory, isNull);
      expect(c.trafficVehicles, isNull);
      expect(t == t.copyWith(), isTrue);
    });
  });

  group('DriveSimulation lateral', () {
    test('steering moves the vehicle sideways; lane keep re-centres', () {
      final sim = DriveSimulation(road: RoadProfile(scenario: RoadScenario.highway), gear: Gear.drive, speedKmh: 80);
      for (var i = 0; i < 60; i++) {
        sim.tick(1 / 60, accelerating: true, braking: false, steer: 1);
      }
      expect(sim.laneOffsetM, greaterThan(0.3));
      expect(sim.steeringDeg, greaterThan(0));
      expect(sim.trajectory.distanceM, greaterThan(10));
      for (var i = 0; i < 60 * 20; i++) {
        sim.tick(1 / 60, accelerating: true, braking: false);
      }
      final lane = sim.road.laneAt(sim.laneOffsetM);
      expect((sim.laneOffsetM - sim.road.laneCenter(lane)).abs(), lessThan(0.4));
      expect(sim.laneOffsetM, inInclusiveRange(sim.road.carriagewayLeft, sim.road.carriagewayRight));
    });

    test('steering wheel moves like a real one, not erratically', () {
      final road = RoadProfile(scenario: RoadScenario.city);
      // Crawling off-centre with lane keep: no violent correction.
      final crawl = DriveSimulation(road: road, gear: Gear.drive, speedKmh: 4)..laneOffsetM = 1.2;
      var maxDeg = 0.0, maxStep = 0.0, prev = crawl.steeringDeg;
      for (var i = 0; i < 60 * 5; i++) {
        crawl.tick(1 / 60, accelerating: false, braking: false);
        crawl.speedKmh = 4;
        maxDeg = maxDeg < crawl.steeringDeg.abs() ? crawl.steeringDeg.abs() : maxDeg;
        final step = (crawl.steeringDeg - prev).abs();
        maxStep = maxStep < step ? step : maxStep;
        prev = crawl.steeringDeg;
      }
      expect(maxDeg, lessThan(90));
      expect(maxStep, lessThan(180 / 60 + 1e-6));

      // At motorway speed full key input is a small, wound-in angle.
      final fast = DriveSimulation(road: RoadProfile(scenario: RoadScenario.highway), gear: Gear.drive, speedKmh: 120);
      fast.tick(1 / 60, accelerating: false, braking: false, steer: 1);
      expect(fast.steeringDeg.abs(), lessThan(10));
      for (var i = 0; i < 60; i++) {
        fast.tick(1 / 60, accelerating: false, braking: false, steer: 1);
      }
      expect(fast.steeringDeg, inInclusiveRange(5, 45));

      // Parked: the wheel does not move at all, even with input held.
      final parked = DriveSimulation(road: road, gear: Gear.park);
      for (var i = 0; i < 60 * 3; i++) {
        parked.tick(1 / 60, accelerating: false, braking: false, steer: -1);
      }
      expect(parked.steeringDeg, 0);

      // Manoeuvring slowly: full lock is about one turn, not several, and
      // the wheel stays there once released at a crawl.
      final slow = DriveSimulation(road: road, gear: Gear.drive, speedKmh: 5);
      for (var i = 0; i < 60 * 3; i++) {
        slow.tick(1 / 60, accelerating: false, braking: false, steer: -1);
        slow.speedKmh = 5;
      }
      final lock = slow.steeringDeg;
      expect(lock, inInclusiveRange(-380, -300));
      slow.speedKmh = 0;
      for (var i = 0; i < 60; i++) {
        slow.tick(1 / 60, accelerating: false, braking: false);
      }
      expect(slow.steeringDeg, closeTo(lock, 1e-6));
    });

    test('a knock jerks the wheel, which then settles', () {
      final sim = DriveSimulation(road: RoadProfile(scenario: RoadScenario.highway), gear: Gear.drive, speedKmh: 60);
      for (var i = 0; i < 60 * 3; i++) {
        sim.tick(1 / 60, accelerating: false, braking: false);
        sim.speedKmh = 60;
      }
      final before = sim.steeringDeg;
      sim.impact(side: 1, severity: 0.8);
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        sim.tick(1 / 60, accelerating: false, braking: false);
        sim.speedKmh = 60;
        if ((sim.steeringDeg - before).abs() > peak.abs()) peak = sim.steeringDeg - before;
      }
      // Hit on the right: the wheel is yanked to the left.
      expect(peak, lessThan(-20));
      for (var i = 0; i < 60 * 3; i++) {
        sim.tick(1 / 60, accelerating: false, braking: false);
        sim.speedKmh = 60;
      }
      expect((sim.steeringDeg - before).abs(), lessThan(15));
    });

    test('road profile lane geometry is consistent', () {
      for (final s in RoadScenario.values) {
        final r = RoadProfile(scenario: s);
        expect(r.laneCenter(r.egoLane), 0);
        expect(r.carriagewayRight, greaterThan(0));
        expect(r.oncomingLeft, lessThan(r.carriagewayLeft));
        expect(r.curvatureAt(123).isFinite && r.elevationAt(456).isFinite, isTrue);
      }
    });
  });

  group('theme mappings', () {
    test('every theme has a consistent cockpit and ego model', () {
      for (final s in DashStyle.values) {
        expect(s.cockpit.motorcycle, s.isMotorcycle, reason: s.name);
        expect(s.egoVehicle.isMotorcycle, s.isMotorcycle, reason: s.name);
        expect(s.cockpit.eyeHeightM, greaterThan(0.9));
      }
      expect(DashStyle.carEvTesla.cockpit.steering, SteeringControl.yoke);
      expect(DashStyle.carEvLi.cockpit.hud, isTrue);
    });
  });

  group('AutoMotoDashboard hooks', () {
    testWidgets('cockpit mode delegates to cockpitBuilder with the cluster', (tester) async {
      DashCockpitRequest? got;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoMotoDashboard(
            telemetry: const DashTelemetry(speedKmh: 50),
            style: DashStyle.carEvTesla,
            viewMode: DashViewMode.cockpit,
            weather: WeatherType.lightRain,
            cockpitBuilder: (context, request) {
              got = request;
              return SizedBox.expand(key: const Key('cockpit'), child: request.cluster);
            },
          ),
        ),
      );
      expect(find.byKey(const Key('cockpit')), findsOneWidget);
      expect(got!.telemetry.speedKmh, 50);
      expect(got!.weather, WeatherType.lightRain);
    });

    testWidgets('cockpit mode without builder falls back to the cluster', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AutoMotoDashboard(telemetry: DashTelemetry(), viewMode: DashViewMode.cockpit),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('roadViewBuilder fills the road area of road themes', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoMotoDashboard(
            telemetry: const DashTelemetry(speedKmh: 30),
            style: DashStyle.carEvTesla,
            roadViewBuilder: (context, request) {
              calls++;
              return const ColoredBox(key: Key('road3d'), color: Colors.blue);
            },
          ),
        ),
      );
      expect(calls, greaterThan(0));
      expect(find.byKey(const Key('road3d')), findsOneWidget);
    });
  });
}
