import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/src/painters/production_cluster_painter.dart';
import 'package:auto_moto_dash/src/widgets/production/production_cluster_body.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final brandStyles = DashStyle.values.where((s) => s.isBrand).toList();

  test('26 brand themes are data driven and categorised consistently', () {
    expect(brandStyles, hasLength(26));
    for (final style in brandStyles) {
      final spec = style.spec!;
      expect(
        spec.isMotorcycle,
        style.isMotorcycle,
        reason: '${style.name} layout/category mismatch',
      );
      expect(spec.brand, isNotEmpty);
      expect(style.label, isNotEmpty);
      expect(style.labelEn, isNotEmpty);
      expect(style.isDigitalHud, isFalse);
    }
    expect(
      DashStyle.values.where((s) => !s.isBrand && !s.isDigitalHud),
      hasLength(9),
      reason: 'original production themes keep their hand-drawn painters',
    );
    expect(
      DashStyleX.forCategory(DashCategory.motorcycle).length,
      greaterThanOrEqualTo(12),
    );
  });

  test('unit conversion', () {
    const imperial = DashUnits.imperial;
    expect(imperial.speedValue(160.9344), closeTo(100, 1e-9));
    expect(imperial.distanceValue(1.609344), closeTo(1, 1e-9));
    expect(imperial.pressureValue(2), closeTo(29.0075, 1e-3));
    expect(imperial.temperatureValue(100), 212);
    expect(DashUnits.metric.pressureText(2.94), '2.9');
    expect(
      const DashUnits(pressure: PressureUnit.kPa).pressureText(2.5),
      '250',
    );
    expect(DashUnits.metric == const DashUnits(), isTrue);
  });

  test('extended telemetry is copied, compared and normalized', () {
    const t = DashTelemetry(
      absWarning: true,
      seatbeltWarning: true,
      doorOpen: true,
      batteryWarning: true,
      charging: true,
      cruiseActive: true,
      tractionControlOff: true,
      driveMode: 'SPORT',
      leanAngleDeg: 400,
      powerPercent: double.nan,
    );
    final n = t.normalized();
    expect(n.leanAngleDeg, 90);
    expect(n.powerPercent, 0);
    expect(n.driveMode, 'SPORT');
    expect(t.copyWith(clearDriveMode: true).driveMode, isNull);
    expect(t.copyWith(absWarning: false).absWarning, isFalse);
    expect(n == n.copyWith(), isTrue);
    expect(n == n.copyWith(doorOpen: false), isFalse);
    expect(n.hashCode, n.copyWith().hashCode);
    expect(n.toString(), contains('DashTelemetry'));
  });

  testWidgets('every theme survives extreme telemetry and all telltales', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    for (final units in [DashUnits.metric, DashUnits.imperial]) {
      for (final style in DashStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: AutoMotoDashboard(
              style: style,
              units: units,
              telemetry: const DashTelemetry(
                speedKmh: 999,
                rpm: 99999,
                maxRpm: 30000,
                batteryPercent: 5,
                charging: true,
                absWarning: true,
                seatbeltWarning: true,
                doorOpen: true,
                batteryWarning: true,
                cruiseActive: true,
                tractionControlOff: true,
                leftIndicator: true,
                rightIndicator: true,
                highBeam: true,
                engineWarning: true,
                parkingBrake: true,
                gear: Gear.drive,
                gearNumber: 6,
                driveMode: 'TRACK',
                leanAngleDeg: -45,
                powerPercent: -80,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 32));
        expect(
          tester.takeException(),
          isNull,
          reason: '${style.name} ${units.speedLabel}',
        );
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('brand badge builder replaces the wordmark for brand themes', (
    tester,
  ) async {
    Widget view(DashStyle style, {bool badge = true}) => MaterialApp(
      home: AutoMotoDashboard(
        style: style,
        telemetry: const DashTelemetry(speedKmh: 50),
        brandBadgeBuilder: badge
            ? (context, s) => Text('LOGO ${s.name}')
            : null,
      ),
    );

    ProductionClusterPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(ProductionClusterBody),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as ProductionClusterPainter;

    await tester.pumpWidget(view(DashStyle.carAudi));
    expect(find.text('LOGO carAudi'), findsOneWidget);
    expect(painter().showBrandWordmark, isFalse);

    await tester.pumpWidget(view(DashStyle.carAudi, badge: false));
    expect(find.textContaining('LOGO'), findsNothing);
    expect(painter().showBrandWordmark, isTrue);

    // Original themes have no badge slot.
    await tester.pumpWidget(view(DashStyle.classic));
    expect(find.textContaining('LOGO'), findsNothing);
  });

  testWidgets('units drive digital HUD labels and semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: AutoMotoDashboard(
          style: DashStyle.hud,
          units: DashUnits.imperial,
          telemetry: DashTelemetry(speedKmh: 160.9344, odometerKm: 1609.344),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('MPH'), findsOneWidget);
    expect(find.text('KM/H'), findsNothing);
    expect(find.textContaining('ODO 1000 mi'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AutoMotoDashboard(
          style: DashStyle.carHyundai,
          units: DashUnits.imperial,
          telemetry: DashTelemetry(speedKmh: 160.9344),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('100 mph')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AutoMotoDashboard(
          style: DashStyle.carHyundai,
          semanticsLabel: 'Hyundai cluster',
          telemetry: DashTelemetry(),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Hyundai cluster'), findsOneWidget);
    semantics.dispose();
  });
}
