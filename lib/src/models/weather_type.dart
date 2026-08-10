import '../weather/fw/utils/weather_type.dart';

/// Optional animated weather background (public API).
enum WeatherType {
  sunny,
  cloudy,
  overcast,
  lightRain,
  mediumRain,
  heavyRain,
  thunderstorm,
  lightSnow,
  mediumSnow,
  heavySnow,
  sunnySnow,
  fog,
  haze,
  dust,
}

extension WeatherTypeX on WeatherType {
  String get label => switch (this) {
        WeatherType.sunny => '晴',
        WeatherType.cloudy => '多云',
        WeatherType.overcast => '阴',
        WeatherType.lightRain => '小雨',
        WeatherType.mediumRain => '中雨',
        WeatherType.heavyRain => '大雨',
        WeatherType.thunderstorm => '雷阵雨',
        WeatherType.lightSnow => '小雪',
        WeatherType.mediumSnow => '中雪',
        WeatherType.heavySnow => '大雪',
        WeatherType.sunnySnow => '下雪晴',
        WeatherType.fog => '雾',
        WeatherType.haze => '霾',
        WeatherType.dust => '浮尘',
      };

  /// Maps to vendored flutter_weather_bg types.
  FwWeatherType get toFwWeatherType => switch (this) {
        WeatherType.sunny => FwWeatherType.sunny,
        WeatherType.cloudy => FwWeatherType.cloudy,
        WeatherType.overcast => FwWeatherType.overcast,
        WeatherType.lightRain => FwWeatherType.lightRainy,
        WeatherType.mediumRain => FwWeatherType.middleRainy,
        WeatherType.heavyRain => FwWeatherType.heavyRainy,
        WeatherType.thunderstorm => FwWeatherType.thunder,
        WeatherType.lightSnow => FwWeatherType.lightSnow,
        WeatherType.mediumSnow => FwWeatherType.middleSnow,
        WeatherType.heavySnow => FwWeatherType.heavySnow,
        WeatherType.sunnySnow => FwWeatherType.lightSnow,
        WeatherType.fog => FwWeatherType.foggy,
        WeatherType.haze => FwWeatherType.hazy,
        WeatherType.dust => FwWeatherType.dusty,
      };
}