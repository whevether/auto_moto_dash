import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders digital HUD with mileage strip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(
              speedKmh: 88,
              batteryPercent: 99,
              odometerKm: 12345,
              rangeKm: 462,
            ),
            style: DashStyle.hud,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('KM/H'), findsOneWidget);
    expect(find.textContaining('ODO'), findsOneWidget);
    expect(find.textContaining('续航'), findsOneWidget);
  });

  testWidgets('renders classic analog cluster', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(speedKmh: 60, rpm: 2500),
            style: DashStyle.classic,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(AutoMotoDashboard), findsOneWidget);
  });

  testWidgets('renders Tesla EV cluster with battery', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(
              speedKmh: 80,
              batteryPercent: 85,
              rangeKm: 380,
              odometerKm: 5000,
            ),
            style: DashStyle.carEvTesla,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('续航'), findsWidgets);
    expect(find.textContaining('85%'), findsWidgets);
  });

  testWidgets('renders motorcycle fuel TFT', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(
              speedKmh: 45,
              rpm: 4000,
              fuelPercent: 70,
              odometerKm: 11415,
              rangeKm: 180,
            ),
            style: DashStyle.motoFuelTft,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.textContaining('ODO'), findsOneWidget);
  });

  testWidgets('shows overspeed shift lights on car when over limit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(
              speedKmh: 130,
              speedLimitKmh: 120,
            ),
            style: DashStyle.hud,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      OverspeedShiftLights.computeLit(speedKmh: 130, speedLimitKmh: 120),
      greaterThan(0),
    );
  });

  test('dash styles are separated by category', () {
    final carStyles = DashStyleX.forCategory(DashCategory.car);
    final motoStyles = DashStyleX.forCategory(DashCategory.motorcycle);

    expect(carStyles, contains(DashStyle.hud));
    expect(carStyles, contains(DashStyle.carEvTesla));
    expect(carStyles, isNot(contains(DashStyle.motoFuelTft)));

    expect(motoStyles, contains(DashStyle.motoEvNiu));
    expect(motoStyles, isNot(contains(DashStyle.classic)));
  });

  test('weather labels cover requested set', () {
    final labels = WeatherType.values.map((e) => e.label).toSet();
    for (final name in [
      '大雨',
      '大雪',
      '中雪',
      '雷阵雨',
      '小雨',
      '小雪',
      '下雪晴',
      '晴',
      '多云',
      '中雨',
      '阴',
      '雾',
      '霾',
      '浮尘',
    ]) {
      expect(labels.contains(name), isTrue, reason: name);
    }
  });
}
