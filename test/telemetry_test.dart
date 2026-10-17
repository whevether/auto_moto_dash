import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telemetry and tire pressures compare by value', () {
    const t = DashTelemetry(speedKmh: 80);
    final copy = t.copyWith(tirePressures: t.tirePressures.copyWith());
    expect(copy, t);
    expect(copy.hashCode, t.hashCode);
    expect(t.copyWith(highBeam: true), isNot(t));
    expect(
      t.copyWith(tirePressures: const TirePressures(frontLeft: 1.8)),
      isNot(t),
    );
  });

  test('normalization preserves valid telemetry identity', () {
    const t = DashTelemetry(speedKmh: 80);
    expect(identical(t.normalized(), t), isTrue);
  });

  test('normalization handles nonfinite and out of range sensor data', () {
    const t = DashTelemetry(
      speedKmh: double.nan,
      rpm: double.infinity,
      maxRpm: 0,
      redlineRpm: double.nan,
      batteryPercent: -20,
      fuelPercent: 150,
      coolantTempC: double.infinity,
      outsideTempC: double.nan,
      rangeKm: -1,
      odometerKm: double.infinity,
      tripKm: -2,
      speedLimitKmh: double.nan,
      gearNumber: 8,
      tirePressures: TirePressures(frontLeft: double.nan, rearRight: -1),
    );
    final safe = t.normalized();
    expect(safe.speedKmh, 0);
    expect(safe.rpm, 0);
    expect(safe.maxRpm, 8000);
    expect(safe.redlineRpm, 8000);
    expect(safe.batteryPercent, 0);
    expect(safe.fuelPercent, 100);
    expect(safe.rangeKm, 0);
    expect(safe.odometerKm, 0);
    expect(safe.tripKm, 0);
    expect(safe.coolantTempC, 90);
    expect(safe.outsideTempC, 20);
    expect(safe.speedLimitKmh, 0);
    expect(safe.gearNumber, isNull);
    expect(safe.tirePressures.frontLeft, 0);
    expect(safe.tirePressures.rearRight, 0);
    expect(const DashTelemetry(speedKmh: -15).normalized().speedKmh, 15);
    expect(const DashTelemetry(maxRpm: 1e308).normalized().maxRpm, 30000);
  });

  test('copyWith can explicitly clear the manual gear', () {
    const t = DashTelemetry(gearNumber: 4);
    expect(t.copyWith(speedKmh: 30).gearNumber, 4);
    expect(t.copyWith(clearGearNumber: true).gearNumber, isNull);
  });
}
