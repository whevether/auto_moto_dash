import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/src/painters/particles/black_hole_painter.dart';
import 'package:auto_moto_dash/src/painters/particles/ion_storm_painter.dart';
import 'package:auto_moto_dash/src/painters/particles/star_tunnel_painter.dart';
import 'package:auto_moto_dash/src/painters/particles/wind_rush_painter.dart';
import 'package:auto_moto_dash/src/weather/fw/bg/weather_bg.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/image_utils.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/weather_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final assets = <String, ByteData>{
    for (final file in Directory(
      'assets/weather_bg',
    ).listSync().whereType<File>())
      'packages/auto_moto_dash/${file.path}': ByteData.sublistView(
        file.readAsBytesSync(),
      ),
  };
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'flutter/assets',
          (message) async => assets[const StringCodec().decodeMessage(message)],
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets(
    'weather assets decode with package paths and failed batches propagate errors',
    (tester) async {
      await tester.runAsync(() async {
        final images = await ImageUtils.getImages([
          'assets/weather_bg/rain.webp',
          'assets/weather_bg/snow.webp',
        ]);
        for (final image in images) {
          expect(image.width, greaterThan(0));
          image.dispose();
        }
        await expectLater(
          ImageUtils.getImages([
            'assets/weather_bg/cloud.webp',
            'assets/weather_bg/missing.webp',
          ]),
          throwsA(isA<FlutterError>()),
        );
      });
    },
  );

  testWidgets(
    'weather switches, resizes and unmounts while images are loading',
    (tester) async {
      for (final type in [
        FwWeatherType.sunny,
        FwWeatherType.thunder,
        FwWeatherType.heavySnow,
        FwWeatherType.sunnyNight,
      ]) {
        for (final size in [const Size(800, 400), const Size(390, 700)]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: WeatherBg(
                  weatherType: type,
                  width: size.width,
                  height: size.height,
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull, reason: '$type at $size');
        }
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: WeatherBg(
            weatherType: FwWeatherType.thunder,
            width: 800,
            height: 400,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all particle effects tolerate high speed and invalid thresholds at dashboard boundary',
    (tester) async {
      for (final effect in ParticleEffect.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: AutoMotoDashboard(
              style: DashStyle.hud,
              particleEffect: effect,
              lightSpeedThresholdKmh: double.nan,
              telemetry: const DashTelemetry(speedKmh: 999),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull, reason: effect.name);
      }
    },
  );

  test(
    'particle color changes repaint, and small wind counts paint safely',
    () {
      const a = Colors.blue;
      const b = Colors.red;
      expect(
        StarTunnelPainter(distance: 0, flowSpeed: 1, accent: a).shouldRepaint(
          StarTunnelPainter(distance: 0, flowSpeed: 1, accent: b),
        ),
        isTrue,
      );
      expect(
        IonStormPainter(
          distance: 0,
          flowSpeed: 1,
          accent: a,
        ).shouldRepaint(IonStormPainter(distance: 0, flowSpeed: 1, accent: b)),
        isTrue,
      );
      expect(
        BlackHolePainter(
          distance: 0,
          flowSpeed: 1,
          accent: a,
        ).shouldRepaint(BlackHolePainter(distance: 0, flowSpeed: 1, accent: b)),
        isTrue,
      );
      for (final count in [-1, 0, 1, 3, 52]) {
        final recorder = ui.PictureRecorder();
        WindRushPainter(
          distance: 1,
          flowSpeed: 1.4,
          accent: a,
          count: count,
        ).paint(Canvas(recorder), const Size(800, 400));
        recorder.endRecording().dispose();
      }
    },
  );
}
