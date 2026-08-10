import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/weather_type.dart';
import 'weather_painter.dart';

class WeatherLayer extends StatefulWidget {
  const WeatherLayer({
    super.key,
    required this.type,
    this.opacity = 1,
  });

  final WeatherType type;
  final double opacity;

  @override
  State<WeatherLayer> createState() => _WeatherLayerState();
}

class _WeatherLayerState extends State<WeatherLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _elapsed = elapsed;
      setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _elapsed.inMilliseconds / 1000.0;
    return RepaintBoundary(
      child: CustomPaint(
        painter: WeatherPainter(
          type: widget.type,
          progress: progress,
          opacity: widget.opacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}