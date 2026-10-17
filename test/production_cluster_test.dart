import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/src/widgets/production/production_cluster_body.dart';
import 'package:auto_moto_dash/src/painters/production_cluster_painter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const sample = DashTelemetry(
    speedKmh: 88,
    rpm: 4200,
    fuelPercent: 62,
    batteryPercent: 85,
    rangeKm: 380,
    odometerKm: 12345.6,
    tripKm: 31.1,
    outsideTempC: 22.5,
    gear: Gear.drive,
    gearNumber: 3,
  );
  final styles = DashStyle.values.where((s) => !s.isDigitalHud);

  testWidgets('production themes fit phone, landscape and wide display', (
    tester,
  ) async {
    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(1440, 600),
    ]) {
      await tester.binding.setSurfaceSize(size);
      for (final style in styles) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AutoMotoDashboard(
                telemetry: sample,
                style: style,
                onGearSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 32));
        expect(
          tester.takeException(),
          isNull,
          reason: '${style.name} at $size',
        );
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(ProductionClusterBody),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(paint.painter, isA<ProductionClusterPainter>());
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('selector respects visibility and dispatches gear changes', (
    tester,
  ) async {
    Gear? selected;
    Widget view(bool visible) => MaterialApp(
      home: Scaffold(
        body: AutoMotoDashboard(
          telemetry: sample,
          style: DashStyle.classic,
          showGearSelector: visible,
          onGearSelected: (gear) => selected = gear,
        ),
      ),
    );
    await tester.pumpWidget(view(true));
    await tester.tap(find.text('N'));
    expect(selected, Gear.neutral);
    await tester.pumpWidget(view(false));
    expect(find.text('N'), findsNothing);
  });

  testWidgets('gauges paint zero scale and out of range telemetry safely', (
    tester,
  ) async {
    for (final style in styles) {
      await tester.pumpWidget(
        MaterialApp(
          home: AutoMotoDashboard(
            style: style,
            telemetry: const DashTelemetry(
              speedKmh: -12,
              maxRpm: 0,
              rpm: 18000,
              batteryPercent: -10,
              fuelPercent: 140,
              leftIndicator: true,
              rightIndicator: true,
              highBeam: true,
              engineWarning: true,
              parkingBrake: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: style.name);
    }
  });

  test('telltales retain values through copyWith and can be cleared', () {
    const t = DashTelemetry(
      leftIndicator: true,
      highBeam: true,
      engineWarning: true,
    );
    final changed = t.copyWith(rightIndicator: true, parkingBrake: true);
    expect(
      changed.leftIndicator &&
          changed.rightIndicator &&
          changed.highBeam &&
          changed.engineWarning &&
          changed.parkingBrake,
      isTrue,
    );
    expect(changed.copyWith(highBeam: false).highBeam, isFalse);
  });

  // Opt-in visual review, keeping generated files out of source control.
  test('render production theme review images', () async {
    if (!const bool.fromEnvironment('CLUSTER_PREVIEW')) return;
    final fontPath = const String.fromEnvironment('PREVIEW_FONT');
    if (fontPath.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
    }
    Directory('build/cluster_previews').createSync(recursive: true);
    for (final style in styles) {
      final size = style.isMotorcycle
          ? const Size(900, 520)
          : const Size(1200, 480);
      final recorder = ui.PictureRecorder();
      ProductionClusterPainter(
        telemetry: sample,
        style: style,
        speed: 88,
        rpm: 4200,
      ).paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/cluster_previews/${style.name}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
