import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders digital HUD', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AutoMotoDashboard(
            telemetry: DashTelemetry(speedKmh: 88, batteryPercent: 99),
            style: DashStyle.hud,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('KM/H'), findsOneWidget);
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