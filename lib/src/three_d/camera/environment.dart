import 'dart:ui' show Color;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:vector_math/vector_math.dart';

import '../scene/scene_model.dart';

/// Lighting time of day for 3D views.
enum TimeOfDay3D {
  day,
  dusk,
  night;

  String get label => switch (this) {
    TimeOfDay3D.day => '白天',
    TimeOfDay3D.dusk => '黄昏',
    TimeOfDay3D.night => '夜晚',
  };
}

/// Derived weather conditions.
class Conditions {
  const Conditions({
    this.rain = 0,
    this.snow = false,
    this.fog = false,
    this.overcast = 0,
  });

  /// 0 (dry) .. 1 (heavy rain).
  final double rain;
  final bool snow;
  final bool fog;

  /// 0 (clear) .. 1 (fully overcast).
  final double overcast;

  bool get wet => rain > 0 || snow;

  static Conditions of(WeatherType? w) => switch (w) {
    null || WeatherType.sunny => const Conditions(),
    WeatherType.cloudy => const Conditions(overcast: 0.4),
    WeatherType.overcast => const Conditions(overcast: 0.8),
    WeatherType.lightRain => const Conditions(rain: 0.35, overcast: 0.8),
    WeatherType.mediumRain => const Conditions(rain: 0.65, overcast: 0.9),
    WeatherType.heavyRain ||
    WeatherType.thunderstorm => const Conditions(rain: 1, overcast: 1),
    WeatherType.lightSnow ||
    WeatherType.sunnySnow => const Conditions(snow: true, overcast: 0.5),
    WeatherType.mediumSnow ||
    WeatherType.heavySnow => const Conditions(snow: true, overcast: 0.9),
    WeatherType.fog => const Conditions(fog: true, overcast: 0.7),
    _ => const Conditions(overcast: 0.5),
  };
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1))!;

/// Sky, sun, ambient and fog for [time] and [c]; shared by both backends
/// (ACES tone mapping, sRGB output, same exposure).
EnvironmentDesc environmentFor(
  TimeOfDay3D time,
  Conditions c, {
  required bool shadows,
}) {
  final grey = c.overcast;
  final (
    zenith,
    horizon,
    ground,
    sunColor,
    sunI,
    ambient,
    sunDir,
    exposure,
  ) = switch (time) {
    TimeOfDay3D.day => (
      const Color(0xFF3C78C8),
      const Color(0xFFBCD4EC),
      const Color(0xFF5B5852),
      const Color(0xFFFFF3E0),
      3.2,
      1.0,
      Vector3(-0.35, 0.75, 0.45),
      1.0,
    ),
    TimeOfDay3D.dusk => (
      const Color(0xFF2A3E6E),
      const Color(0xFFF2A066),
      const Color(0xFF3A3430),
      const Color(0xFFFFA860),
      1.6,
      0.55,
      Vector3(0.5, 0.12, 0.85),
      1.1,
    ),
    TimeOfDay3D.night => (
      const Color(0xFF03060E),
      const Color(0xFF101A2A),
      const Color(0xFF07080A),
      const Color(0xFF9DB0D8),
      0.06,
      0.12,
      Vector3(-0.3, 0.6, 0.2),
      1.25,
    ),
  };
  final overcastSky = time == TimeOfDay3D.night
      ? const Color(0xFF0A0C10)
      : const Color(0xFF8E959C);
  final fogBase = time == TimeOfDay3D.night
      ? const Color(0xFF0C1016)
      : _mix(horizon, const Color(0xFFA9B2BA), grey);
  final fogDensity = c.fog
      ? 0.03
      : 0.0025 + c.rain * 0.009 + (c.snow ? 0.008 : 0) + grey * 0.002;
  return EnvironmentDesc(
    zenith: _mix(zenith, overcastSky, grey * 0.85),
    horizon: _mix(horizon, overcastSky, grey * 0.7),
    ground: ground,
    sunDirection: sunDir,
    sunColor: sunColor,
    sunIntensity: sunI * (1 - grey * 0.75),
    ambientIntensity: ambient * (1 - grey * 0.2),
    fogColor: fogBase,
    fogDensity: fogDensity,
    exposure: exposure,
    night: time == TimeOfDay3D.night,
    shadows: shadows && grey < 0.75 && time != TimeOfDay3D.night,
  );
}
