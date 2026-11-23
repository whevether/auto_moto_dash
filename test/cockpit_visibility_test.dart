import 'dart:math' as math;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:auto_moto_dash/auto_moto_dash_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// Whether the straight steering wheel blocks the ray from [eye] to [p].
bool _wheelBlocks(Vector3 eye, Vector3 p, Matrix4 wheelFrame) {
  final inv = Matrix4.inverted(wheelFrame);
  final a = inv.transformed3(eye), b = inv.transformed3(p);
  // Test the rim plane and the planes at ± tube (the rim is a 3D tube).
  for (final z in [-wheelRimTube, 0.0, wheelRimTube]) {
    final t = (z - a.z) / (b.z - a.z);
    if (t <= 0 || t >= 1) continue;
    final q = a + (b - a) * t;
    final r = math.sqrt(q.x * q.x + q.y * q.y);
    final tube = math.sqrt(math.max(0, wheelRimTube * wheelRimTube - z * z));
    if ((r - wheelRimRadius).abs() <= tube) return true;
    if (z == 0) {
      final hub = q.x * q.x / (0.075 * 0.075) + q.y * q.y / (0.06 * 0.06);
      if (hub <= 1) return true;
      if (q.y.abs() < 0.0175 && q.x.abs() < wheelRimRadius) return true;
      if (q.x.abs() < 0.02 && q.y < 0 && q.y > -wheelRimRadius) return true;
    }
  }
  return false;
}

void main() {
  final themes = DashStyle.values.where(
    (s) =>
        !s.isMotorcycle && s.cockpit.cluster != ClusterPlacement.centerDisplay,
  );
  for (final style in themes) {
    test('$style: the steering wheel does not cover the driver display', () {
      final scene = DriveScene(
        style: style,
        road: RoadProfile(),
        quality: RenderQuality.low,
      );
      final rig = scene.rig!;
      final fit = rig.driverDisplay!;
      final up = Vector3(0, math.cos(fit.tilt), math.sin(fit.tilt));
      final right = Vector3(1, 0, 0);
      final h = fit.width / carClusterAspect;
      var blocked = 0, total = 0;
      for (var i = 0; i <= 24; i++) {
        for (var j = 0; j <= 10; j++) {
          final p =
              fit.centre +
              right * (fit.width * (i / 24 - 0.5)) +
              up * (h * (j / 10 - 0.5));
          total++;
          if (_wheelBlocks(rig.eye, p, rig.steeringBase)) blocked++;
        }
      }
      expect(blocked, 0, reason: '$blocked of $total samples covered');
      // Still a readable size and inside the camera's view.
      expect(fit.width, greaterThan(0.2));
      final toCentre = fit.centre - rig.eye;
      final downDeg = math.atan2(-toCentre.y, toCentre.z) * 180 / math.pi;
      final view = scene.cockpit.fovDeg / 2 + 0.14 * 180 / math.pi;
      expect(downDeg + h / toCentre.z * 90 / math.pi, lessThan(view));
    });
  }
}
