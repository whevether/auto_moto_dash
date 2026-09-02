import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Cluster background that stays translucent when weather/particles are active.
class ClusterSurface extends StatelessWidget {
  const ClusterSurface({
    super.key,
    required this.dimForWeather,
    required this.child,
    this.baseColor = const Color(0xFF0A0A0A),
    this.weatherScrimAlpha = 0.22,
    this.solidAlpha = 0.88,
    this.padding,
  });

  final bool dimForWeather;
  final Widget child;
  final Color baseColor;
  final double weatherScrimAlpha;
  final double solidAlpha;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (dimForWeather)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: weatherScrimAlpha),
                  Colors.black.withValues(alpha: weatherScrimAlpha * 0.65),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          )
        else
          ColoredBox(color: baseColor.withValues(alpha: solidAlpha)),
        if (dimForWeather)
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: ColoredBox(
                color: baseColor.withValues(alpha: 0.42),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (padding != null)
          Padding(padding: padding!, child: child)
        else
          child,
      ],
    );
  }
}
