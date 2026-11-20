import 'dart:async';
import 'dart:math' as math;

import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const DashDemoApp());
}

class DashDemoApp extends StatelessWidget {
  const DashDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Moto Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: Color(0xFF4FC3F7)),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
      ),
      home: const DashDemoPage(),
    );
  }
}

class DashDemoPage extends StatefulWidget {
  const DashDemoPage({super.key});

  @override
  State<DashDemoPage> createState() => _DashDemoPageState();
}

class _DashDemoPageState extends State<DashDemoPage>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final DriveSimulation _drive = DriveSimulation();

  DashStyle _style = DashStyle.classic;
  DashCategory _category = DashCategory.car;
  WeatherType? _weather;
  ParticleEffect? _particle;
  bool _panelOpen = false;
  bool _rainbow = false;
  bool _imperial = false;
  String? _gearHint;
  Timer? _gearHintTimer;
  double _distanceKm = 0;
  double _power = 0; // EV 功率/回收 -100..100
  double _lean = 0; // 摩托倾角
  double _simTime = 0;

  bool _pointerAccelerating = false;
  bool _keyAccelerating = false;
  bool _keyBraking = false;
  bool _suppressAccel = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  bool get _accelerating =>
      !_suppressAccel && (_pointerAccelerating || _keyAccelerating);

  DashTelemetry get _telemetry => DashTelemetry(
    speedKmh: _drive.speedKmh,
    rpm: _drive.rpm,
    maxRpm: _drive.maxRpm,
    redlineRpm: 7000,
    batteryPercent: _battery,
    fuelPercent: _fuel,
    coolantTempC: _coolant,
    rangeKm: _battery * 4.7,
    speedLimitKmh: 120,
    odometerKm: 12345.6 + _distanceKm,
    tripKm: 31.1 + _distanceKm,
    outsideTempC: 0,
    gear: _drive.gear,
    parkingBrake: _drive.gear == Gear.park,
    gearNumber:
        (_style == DashStyle.racing ||
            _style == DashStyle.motoFuelTft ||
            _style == DashStyle.motoFuelHybrid ||
            (_style.isBrand && !_style.isElectric))
        ? (_drive.speedKmh < 1 ? 1 : (_drive.speedKmh / 40).ceil().clamp(1, 6))
        : null,
    powerPercent: _power,
    leanAngleDeg: _lean,
    tirePressures: TirePressures(
      frontLeft: 2.9 + _tireHeat,
      frontRight: 2.8 + _tireHeat,
      rearLeft: 2.9 + _tireHeat * 1.1,
      rearRight: 2.9 + _tireHeat * 1.1,
    ),
  );

  // 随行驶变化的演示数据:电量/油量随里程下降,水温与胎压随车速升高。
  double get _battery => (99 - _distanceKm * 1.5).clamp(5.0, 100.0);
  double get _fuel => (62 - _distanceKm * 1.0).clamp(5.0, 100.0);
  double _coolant = 75;
  double _tireHeat = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _gearHintTimer?.cancel();
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _wakeSimulation() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    final previousSpeed = _drive.speedKmh;
    final previousRpm = _drive.rpm;
    _drive.tick(dt, accelerating: _accelerating, braking: _keyBraking);
    _distanceKm += _drive.speedKmh * dt / 3600;

    // 驱动 EV 功率条/回收与摩托倾角，让这些主题的指示也会动。
    _simTime += dt;
    final speedRatio = (_drive.speedKmh / _drive.maxSpeedKmh).clamp(0.0, 1.0);
    final double powerTarget;
    if (_keyBraking && _drive.speedKmh > 0) {
      powerTarget = -70;
    } else if (_accelerating && _drive.gear != Gear.park) {
      powerTarget = 90 - 40 * speedRatio;
    } else {
      powerTarget = _drive.speedKmh > 1 ? -12 : 0;
    }
    final leanTarget = _drive.speedKmh > 20
        ? math.sin(_simTime * 0.8) * 38 * speedRatio.clamp(0.2, 1.0)
        : 0.0;
    final k = (1 - math.exp(-6 * dt));
    final prevCoolant = _coolant;
    final prevHeat = _tireHeat;
    final prevBattery = _battery;
    _coolant += ((75 + 20 * speedRatio) - _coolant) * (1 - math.exp(-0.5 * dt));
    _tireHeat += (0.25 * speedRatio - _tireHeat) * (1 - math.exp(-0.3 * dt));
    // 接近目标时吸附,保证停车后能停止刷新。
    if ((_coolant - (75 + 20 * speedRatio)).abs() < 0.05) {
      _coolant = 75 + 20 * speedRatio;
    }
    if ((_tireHeat - 0.25 * speedRatio).abs() < 0.002) {
      _tireHeat = 0.25 * speedRatio;
    }
    final prevPower = _power;
    final prevLean = _lean;
    _power += (powerTarget - _power) * k;
    _lean += (leanTarget - _lean) * k;
    if (_power.abs() < 0.2 && powerTarget == 0) _power = 0;
    if (_lean.abs() < 0.2 && leanTarget == 0) _lean = 0;

    if (previousSpeed != _drive.speedKmh ||
        previousRpm != _drive.rpm ||
        prevPower != _power ||
        prevCoolant != _coolant ||
        prevHeat != _tireHeat ||
        prevBattery != _battery ||
        prevLean != _lean) {
      setState(() {});
    }
    if (!_accelerating &&
        !_keyBraking &&
        _drive.speedKmh == 0 &&
        _power == 0 &&
        _lean == 0 &&
        _coolant == 75 &&
        _tireHeat == 0 &&
        _drive.rpm == _drive.idleRpm) {
      _ticker.stop();
    }
  }

  void _tryGear(Gear gear) {
    _gearHintTimer?.cancel();
    final ok = _drive.trySetGear(gear);
    _wakeSimulation();
    setState(() {
      _gearHint = ok
          ? null
          : switch (gear) {
              Gear.park => '车速过高，无法挂 P',
              Gear.reverse => '请先减速再挂 R',
              _ => '无法切换到该档位',
            };
    });
    if (_gearHint != null) {
      _gearHintTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _gearHint != null) {
          setState(() => _gearHint = null);
        }
      });
    }
  }

  void _shiftGear(int delta) {
    final values = Gear.values;
    final next = (values.indexOf(_drive.gear) + delta).clamp(
      0,
      values.length - 1,
    );
    _tryGear(values[next]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isDown) _keyAccelerating = true;
      if (isUp) _keyAccelerating = false;
      _wakeSimulation();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isDown) _keyBraking = true;
      if (isUp) _keyBraking = false;
      _wakeSimulation();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        event is KeyDownEvent) {
      _shiftGear(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        event is KeyDownEvent) {
      _shiftGear(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    final gearHelp = switch (_drive.gear) {
      Gear.park => 'P 驻车：锁止，油门不走车',
      Gear.reverse => 'R 倒车：低速倒车',
      Gear.neutral => 'N 空档：只抬转速，不加速',
      Gear.drive => 'D 前进：正常加速',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onFocusChange: (focused) {
          if (!focused) {
            _keyAccelerating = false;
            _keyBraking = false;
            _pointerAccelerating = false;
          }
        },
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (_panelOpen || _suppressAccel) return;
                setState(() => _pointerAccelerating = true);
                _wakeSimulation();
              },
              onPointerUp: (_) => setState(() {
                _pointerAccelerating = false;
                _suppressAccel = false;
              }),
              onPointerCancel: (_) => setState(() {
                _pointerAccelerating = false;
                _suppressAccel = false;
              }),
              child: AutoMotoDashboard(
                telemetry: _telemetry,
                style: _style,
                weather: _weather,
                particleEffect: _particle,
                vehicleType: _category == DashCategory.car
                    ? VehicleType.car
                    : VehicleType.motorcycle,
                lightSpeedThresholdKmh: 80,
                showVehicleOutline:
                    _style.isDigitalHud && _category == DashCategory.car,
                rainbowSpeed: _rainbow,
                units: _imperial ? DashUnits.imperial : DashUnits.metric,
                onGearSelected: _tryGear,
                onGearPointerDown: () {
                  _suppressAccel = true;
                  _pointerAccelerating = false;
                },
              ),
            ),
            if (_panelOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closePanel,
                  behavior: HitTestBehavior.opaque,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _ControlPanel(
                  style: _style,
                  weather: _weather,
                  particle: _particle,
                  category: _category,
                  speed: _drive.speedKmh,
                  rpm: _drive.rpm,
                  gear: _drive.gear,
                  rainbow: _rainbow,
                  imperial: _imperial,
                  onImperial: (v) => setState(() => _imperial = v),
                  gearHelp: gearHelp,
                  onClose: _closePanel,
                  onStyle: (v) => setState(() => _style = v),
                  onWeather: (v) => setState(() => _weather = v),
                  onParticle: (v) => setState(() => _particle = v),
                  onCategory: (v) => setState(() {
                    _category = v;
                    _style = DashStyleX.defaultFor(v);
                  }),
                  onGear: _tryGear,
                  onRainbow: (v) => setState(() => _rainbow = v),
                ),
              ),
            ],
            Positioned(
              right: 12,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'panel',
                  backgroundColor: Colors.white12,
                  onPressed: () => setState(() => _panelOpen = !_panelOpen),
                  child: Icon(_panelOpen ? Icons.close : Icons.tune),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 16,
              child: SafeArea(
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '按住加速 · ↑↓油门/刹车 · ←→换档',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        gearHelp,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_gearHint != null)
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          _gearHint!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.style,
    required this.category,
    required this.weather,
    required this.particle,
    required this.speed,
    required this.rpm,
    required this.gear,
    required this.rainbow,
    required this.imperial,
    required this.onImperial,
    required this.gearHelp,
    required this.onClose,
    required this.onStyle,
    required this.onWeather,
    required this.onParticle,
    required this.onCategory,
    required this.onGear,
    required this.onRainbow,
  });

  final DashStyle style;
  final DashCategory category;
  final WeatherType? weather;
  final ParticleEffect? particle;
  final double speed;
  final double rpm;
  final Gear gear;
  final bool rainbow;
  final bool imperial;
  final ValueChanged<bool> onImperial;
  final String gearHelp;
  final VoidCallback onClose;
  final ValueChanged<DashStyle> onStyle;
  final ValueChanged<WeatherType?> onWeather;
  final ValueChanged<ParticleEffect?> onParticle;
  final ValueChanged<DashCategory> onCategory;
  final ValueChanged<Gear> onGear;
  final ValueChanged<bool> onRainbow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEE121212),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '车速 ${speed.round()} km/h'
                '${style.isAnalog ? ' · 转速 ${rpm.round()} rpm' : ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '长按加速；↑↓ 加减速；←→ 换档（P/R 需近乎停车）',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text('分类', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('汽车'),
                    selected: category == DashCategory.car,
                    onSelected: (_) => onCategory(DashCategory.car),
                  ),
                  ChoiceChip(
                    label: const Text('摩托车'),
                    selected: category == DashCategory.motorcycle,
                    onSelected: (_) => onCategory(DashCategory.motorcycle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DashStyleX.forCategory(category).map((s) {
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: style == s,
                    onSelected: (_) => onStyle(s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('粒子', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('无'),
                    selected: particle == null,
                    onSelected: (_) => onParticle(null),
                  ),
                  ...ParticleEffect.values.map((p) {
                    return ChoiceChip(
                      label: Text(p.label),
                      selected: particle == p,
                      onSelected: (_) => onParticle(p),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              const Text('天气', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('无'),
                    selected: weather == null,
                    onSelected: (_) => onWeather(null),
                  ),
                  ...WeatherType.values.map((w) {
                    return ChoiceChip(
                      label: Text(w.label),
                      selected: weather == w,
                      onSelected: (_) => onWeather(w),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              const Text('档位', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                gearHelp,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Gear.values.map((g) {
                  return ChoiceChip(
                    label: Text(g.label),
                    selected: gear == g,
                    onSelected: (_) => onGear(g),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (category == DashCategory.car)
                    FilterChip(
                      label: const Text('彩虹速度'),
                      selected: rainbow,
                      onSelected: onRainbow,
                    ),
                  FilterChip(
                    label: const Text('英制 (mph / mi / psi / °F)'),
                    selected: imperial,
                    onSelected: onImperial,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
