// ignore_for_file: library_private_types_in_public_api

import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/constants.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/image_utils.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/print_utils.dart';
import 'package:auto_moto_dash/src/weather/fw/utils/weather_type.dart';

//// 雨雪动画层
class WeatherRainSnowBg extends StatefulWidget {
  final FwWeatherType weatherType;
  final double viewWidth;
  final double viewHeight;

  const WeatherRainSnowBg({
    super.key,
    required this.weatherType,
    required this.viewWidth,
    required this.viewHeight,
  });

  @override
  State<WeatherRainSnowBg> createState() => _WeatherRainSnowBgState();
}

class _WeatherRainSnowBgState extends State<WeatherRainSnowBg>
    with SingleTickerProviderStateMixin {
  ui.Image? _rainImage;
  ui.Image? _snowImage;
  late final AnimationController _controller;
  final List<RainSnowParams> _rainSnows = [];
  WeatherDataState _state = WeatherDataState.init;
  Duration _lastFrame = Duration.zero;

  /// 异步加载雨 / 雪图片。
  Future<void> _fetchImages() async {
    weatherPrint("开始获取雨雪图片");
    final images = await ImageUtils.getImages([
      'assets/weather_bg/rain.webp',
      'assets/weather_bg/snow.webp',
    ]);
    final rain = images[0];
    final snow = images[1];
    if (!mounted) {
      rain.dispose();
      snow.dispose();
      return;
    }
    _rainImage = rain;
    _snowImage = snow;
    setState(() {});
  }

  /// 根据当前 size 初始化雨 / 雪粒子参数。
  void _initParams() {
    _state = WeatherDataState.loading;
    if (widget.viewWidth > 0 && widget.viewHeight > 0 && _rainSnows.isEmpty) {
      if (WeatherUtil.isSnowRain(widget.weatherType)) {
        final count = _particleCountFor(widget.weatherType);
        final widthRatio = widget.viewWidth / kDesignWidth;
        final heightRatio = widget.viewHeight / kDesignHeight;
        for (int i = 0; i < count; i++) {
          _rainSnows.add(
            RainSnowParams(
              widget.viewWidth,
              widget.viewHeight,
              widget.weatherType,
            )..init(widthRatio, heightRatio),
          );
        }
        weatherPrint("初始化雨参数成功 ${_rainSnows.length}");
      }
    }
    if (!_controller.isAnimating) {
      _lastFrame = Duration.zero;
      _controller.repeat();
    }
    _state = WeatherDataState.finish;
  }

  static int _particleCountFor(FwWeatherType t) {
    switch (t) {
      case FwWeatherType.lightRainy:
        return 70;
      case FwWeatherType.middleRainy:
        return 100;
      case FwWeatherType.heavyRainy:
      case FwWeatherType.thunder:
        return 200;
      case FwWeatherType.lightSnow:
        return 30;
      case FwWeatherType.middleSnow:
        return 100;
      case FwWeatherType.heavySnow:
        return 200;
      default:
        return 0;
    }
  }

  @override
  void didUpdateWidget(WeatherRainSnowBg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherType != widget.weatherType ||
        oldWidget.viewWidth != widget.viewWidth ||
        oldWidget.viewHeight != widget.viewHeight) {
      _rainSnows.clear();
      _initParams();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(minutes: 1),
      vsync: this,
    )..addListener(_advance);
    _fetchImages().catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'auto_moto_dash',
          context: ErrorDescription('loading weather assets'),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state == WeatherDataState.init) _initParams();
  }

  void _advance() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final frames =
        ((elapsed - _lastFrame).inMicroseconds / 1e6).clamp(0, 0.05) * 60;
    _lastFrame = elapsed;
    final snow = WeatherUtil.isSnow(widget.weatherType);
    for (final p in _rainSnows) {
      p.y += p.speed * frames;
      if (snow) {
        p.x +=
            sin(p.y / (300 + 50 * p.alpha)) *
            (1 + 0.5 * p.alpha) *
            p.widthRatio *
            frames;
      }
      if (p.y > p.height / p.scale) {
        p.y = snow
            ? -p.height * p.scale
            : -(_rainImage?.height.toDouble() ?? 0);
        p.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _rainImage?.dispose();
    _snowImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state != WeatherDataState.finish) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: RainSnowPainter(this, _controller),
    );
  }
}

/// 绘制雨 / 雪粒子。
///
/// 绑定到 [AnimationController]，由它触发 repaint —— widget 本身不重建。
class RainSnowPainter extends CustomPainter {
  final Paint _paint = Paint();
  final _WeatherRainSnowBgState _state;

  RainSnowPainter(this._state, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final weatherType = _state.widget.weatherType;
    if (WeatherUtil.isSnow(weatherType) && _state._snowImage != null) {
      _drawParticles(canvas, _state._snowImage!);
    } else if (WeatherUtil.isRainy(weatherType) && _state._rainImage != null) {
      _drawParticles(canvas, _state._rainImage!);
    }
  }

  void _drawParticles(Canvas canvas, ui.Image image) {
    for (final p in _state._rainSnows) {
      canvas.save();
      canvas.scale(p.scale);
      // 用 modulate + 白色 alpha 等价于 alpha-only ColorFilter，
      // 避免每帧构建 4x5 matrix list。
      _paint.colorFilter = ColorFilter.mode(
        Color.fromRGBO(255, 255, 255, p.alpha),
        BlendMode.modulate,
      );
      canvas.drawImage(image, Offset(p.x, p.y), _paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RainSnowPainter old) => true;
}

class RainSnowParams {
  /// x 坐标
  double x = 0;

  /// y 坐标
  double y = 0;

  /// 下落速度
  double speed = 0;

  /// 绘制的缩放
  double scale = 1;

  /// 视图宽度（不随屏幕旋转变化）
  final double width;

  /// 视图高度
  final double height;

  /// 透明度
  double alpha = 1;

  /// 天气类型
  final FwWeatherType weatherType;

  double widthRatio = 1;
  double heightRatio = 1;

  RainSnowParams(this.width, this.height, this.weatherType);

  void init(double widthRatio, double heightRatio) {
    this.widthRatio = widthRatio;
    this.heightRatio = max(heightRatio, 0.65);
    reset();
    // 初始 y 分布在整个屏幕高度内，避免一开始全在顶部
    y = kRandom.nextDouble() * height / scale;
  }

  /// 粒子移出屏幕后重置位置 / 速度 / 透明度等。
  void reset() {
    final ratio = _speedRatio(weatherType);
    final double random = 0.4 + 0.12 * kRandom.nextDouble() * 5;
    if (WeatherUtil.isRainy(weatherType)) {
      scale = random * 1.2;
      speed = 30 * random * ratio * heightRatio;
      alpha = random * 0.6;
    } else {
      scale = random * 0.8 * heightRatio;
      speed = 8 * random * ratio * heightRatio;
      alpha = random;
    }
    x = (kRandom.nextDouble() * width * 1.2 - width * 0.1) / scale;
  }

  static double _speedRatio(FwWeatherType t) {
    switch (t) {
      case FwWeatherType.lightRainy:
      case FwWeatherType.lightSnow:
        return 0.5;
      case FwWeatherType.middleRainy:
      case FwWeatherType.middleSnow:
        return 0.75;
      case FwWeatherType.heavyRainy:
      case FwWeatherType.thunder:
      case FwWeatherType.heavySnow:
        return 1;
      default:
        return 1;
    }
  }
}
