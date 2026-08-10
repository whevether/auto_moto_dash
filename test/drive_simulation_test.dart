import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P blocks powered acceleration', () {
    final d = DriveSimulation(gear: Gear.park);
    for (var i = 0; i < 30; i++) {
      d.tick(1 / 60, accelerating: true, braking: false);
    }
    expect(d.speedKmh, 0);
    expect(d.rpm, greaterThan(d.idleRpm));
  });

  test('N revs without adding speed from throttle', () {
    final d = DriveSimulation(gear: Gear.neutral, speedKmh: 40);
    final before = d.speedKmh;
    for (var i = 0; i < 20; i++) {
      d.tick(1 / 60, accelerating: true, braking: false);
    }
    expect(d.speedKmh, lessThan(before)); // coasts down
    expect(d.rpm, greaterThan(d.idleRpm + 2000));
  });

  test('D accelerates forward', () {
    final d = DriveSimulation(gear: Gear.drive);
    for (var i = 0; i < 60; i++) {
      d.tick(1 / 60, accelerating: true, braking: false);
    }
    expect(d.speedKmh, greaterThan(20));
  });

  test('cannot engage P or R while moving fast', () {
    final d = DriveSimulation(gear: Gear.drive, speedKmh: 60);
    expect(d.trySetGear(Gear.park), isFalse);
    expect(d.trySetGear(Gear.reverse), isFalse);
    expect(d.gear, Gear.drive);
    expect(d.trySetGear(Gear.neutral), isTrue);
  });

  test('R has low top speed', () {
    final d = DriveSimulation(gear: Gear.reverse);
    for (var i = 0; i < 300; i++) {
      d.tick(1 / 60, accelerating: true, braking: false);
    }
    expect(d.speedKmh, lessThanOrEqualTo(d.maxReverseSpeedKmh + 0.01));
  });
}