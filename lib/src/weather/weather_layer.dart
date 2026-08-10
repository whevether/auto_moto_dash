import 'package:flutter/material.dart';

import '../models/weather_type.dart';
import 'fw/bg/weather_bg.dart';

/// Weather background layer backed by vendored flutter_weather_bg.
class WeatherLayer extends StatelessWidget {
  const WeatherLayer({
    super.key,
    required this.type,
    this.opacity = 1,
  });

  final WeatherType type;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final h = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            return WeatherBg(
              weatherType: type.toFwWeatherType,
              width: w,
              height: h,
            );
          },
        ),
      ),
    );
  }
}