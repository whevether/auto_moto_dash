import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/src/animation/smoothed_value.dart';
import 'package:auto_moto_dash/src/painters/production_cluster_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('smoothing is frame-rate independent and reaches the exact target', () {
    final slow = SmoothedValue(0);
    final fast = SmoothedValue(0);
    for (var i = 0; i < 30; i++) {
      slow.tick(100, 1 / 30);
    }
    for (var i = 0; i < 120; i++) {
      fast.tick(100, 1 / 120);
    }
    expect(slow.value, closeTo(fast.value, 1e-9));
    expect(slow.value, 100);
    slow.tick(double.nan, 1 / 60);
    slow.tick(0, double.infinity);
    expect(slow.value, 100);
  });

  Widget view(DashStyle style, double speed) => MaterialApp(
    home: Scaffold(
      body: AutoMotoDashboard(
        style: style,
        telemetry: DashTelemetry(
          speedKmh: speed,
          rpm: speed * 30,
          speedLimitKmh: 0,
        ),
      ),
    ),
  );

  testWidgets('static themes stop scheduling animation frames when settled', (
    tester,
  ) async {
    for (final style in DashStyle.values.where(
      (s) => s != DashStyle.techNeon && s != DashStyle.pulseBreath,
    )) {
      await tester.pumpWidget(view(style, 0));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: style.name);
      await tester.pumpWidget(view(style, 80));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: '${style.name} after update',
      );
      if (!style.isDigitalHud) {
        final paint = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<ProductionClusterPainter>()
            .single;
        expect(paint.speed, 80);
      }
    }
  });

  testWidgets('overspeed pulse starts and stops as the threshold changes', (
    tester,
  ) async {
    Widget layer(double speed) => MaterialApp(
      home: OverspeedWarningLayer(
        speedKmh: speed,
        speedLimitKmh: 120,
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(layer(130));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(layer(100));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
      OverspeedShiftLights.computeLit(speedKmh: double.nan, speedLimitKmh: 120),
      0,
    );
    expect(
      OverspeedShiftLights.computeLit(
        speedKmh: 130,
        speedLimitKmh: 120,
        count: -1,
      ),
      0,
    );
  });

  testWidgets(
    'all themes survive nonfinite telemetry in a small landscape viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final style in DashStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: AutoMotoDashboard(
              style: style,
              lightSpeedThresholdKmh: double.nan,
              telemetry: const DashTelemetry(
                speedKmh: double.nan,
                rpm: double.infinity,
                batteryPercent: double.nan,
                fuelPercent: double.infinity,
                odometerKm: double.infinity,
                rangeKm: double.nan,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: style.name);
      }
    },
  );
}
