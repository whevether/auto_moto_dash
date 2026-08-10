import 'dart:ui' show Color;

/// 目前有15种天气类型
enum FwWeatherType {
  heavyRainy,
  heavySnow,
  middleSnow,
  thunder,
  lightRainy,
  lightSnow,
  sunnyNight,
  sunny,
  cloudy,
  cloudyNight,
  middleRainy,
  overcast,
  hazy, // 霾
  foggy, // 雾
  dusty, // 浮尘
}

/// 数据加载状态
enum WeatherDataState {
  /// 初始化
  init,

  /// 正在加载
  loading,

  /// 加载结束
  finish,
}

/// 天气的相关工具类
class WeatherUtil {
  static bool isSnowRain(FwWeatherType weatherType) {
    return isRainy(weatherType) || isSnow(weatherType);
  }

  /// 判断是否下雨，小中大包括雷暴，都是属于雨的类型
  static bool isRainy(FwWeatherType weatherType) {
    return weatherType == FwWeatherType.lightRainy ||
        weatherType == FwWeatherType.middleRainy ||
        weatherType == FwWeatherType.heavyRainy ||
        weatherType == FwWeatherType.thunder;
  }

  /// 判断是否下雪
  static bool isSnow(FwWeatherType weatherType) {
    return weatherType == FwWeatherType.lightSnow ||
        weatherType == FwWeatherType.middleSnow ||
        weatherType == FwWeatherType.heavySnow;
  }

  // 根据天气类型获取背景的颜色值
  static List<Color> getColor(FwWeatherType weatherType) {
    switch (weatherType) {
      case FwWeatherType.sunny:
        return [Color(0xFF0071D1), Color(0xFF6DA6E4)];
      case FwWeatherType.sunnyNight:
        return [Color(0xFF061E74), Color(0xFF275E9A)];
      case FwWeatherType.cloudy:
        return [Color(0xFF5C82C1), Color(0xFF95B1DB)];
      case FwWeatherType.cloudyNight:
        return [Color(0xFF2C3A60), Color(0xFF4B6685)];
      case FwWeatherType.overcast:
        return [Color(0xFF8FA3C0), Color(0xFF8C9FB1)];
      case FwWeatherType.lightRainy:
        return [Color(0xFF556782), Color(0xFF7c8b99)];
      case FwWeatherType.middleRainy:
        return [Color(0xFF3A4B65), Color(0xFF495764)];
      case FwWeatherType.heavyRainy:
      case FwWeatherType.thunder:
        return [Color(0xFF3B434E), Color(0xFF565D66)];
      case FwWeatherType.hazy:
        return [Color(0xFF989898), Color(0xFF4B4B4B)];
      case FwWeatherType.foggy:
        return [Color(0xFFA6B3C2), Color(0xFF737F88)];
      case FwWeatherType.lightSnow:
        return [Color(0xFF6989BA), Color(0xFF9DB0CE)];
      case FwWeatherType.middleSnow:
        return [Color(0xFF8595AD), Color(0xFF95A4BF)];
      case FwWeatherType.heavySnow:
        return [Color(0xFF98A2BC), Color(0xFFA7ADBF)];
      case FwWeatherType.dusty:
        return [Color(0xFFB99D79), Color(0xFF6C5635)];
    }
  }

  // 根据天气类型获取天气的描述信息
  static String getWeatherDesc(FwWeatherType weatherType) {
    switch (weatherType) {
      case FwWeatherType.sunny:
      case FwWeatherType.sunnyNight:
        return "晴";
      case FwWeatherType.cloudy:
      case FwWeatherType.cloudyNight:
        return "多云";
      case FwWeatherType.overcast:
        return "阴";
      case FwWeatherType.lightRainy:
        return "小雨";
      case FwWeatherType.middleRainy:
        return "中雨";
      case FwWeatherType.heavyRainy:
        return "大雨";
      case FwWeatherType.thunder:
        return "雷阵雨";
      case FwWeatherType.hazy:
        return "雾";
      case FwWeatherType.foggy:
        return "霾";
      case FwWeatherType.lightSnow:
        return "小雪";
      case FwWeatherType.middleSnow:
        return "中雪";
      case FwWeatherType.heavySnow:
        return "大雪";
      case FwWeatherType.dusty:
        return "浮尘";
    }
  }
}
