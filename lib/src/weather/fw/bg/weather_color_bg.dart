import 'package:material_ui/material_ui.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/weather_type.dart';

/// 颜色背景层
class WeatherColorBg extends StatelessWidget {
  final FwWeatherType weatherType;

  /// 控制背景的高度
  final double? height;

  const WeatherColorBg({super.key, required this.weatherType, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: WeatherUtil.getColor(weatherType),
          stops: const [0, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
