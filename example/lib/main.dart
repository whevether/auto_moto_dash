import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/material.dart';
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
  static const double _maxSpeed = 260;
  static const double _accelRate = 55; // km/h per second
  static const double _brakeRate = 70;
  static const double _coastRate = 28;

  final FocusNode _focusNode = FocusNode();

  DashStyle _style = DashStyle.hud;
  WeatherType? _weather = WeatherType.cloudy;
  VehicleType _vehicleType = VehicleType.car;
  double _speed = 0;
  double _rpm = 800;
  Gear _gear = Gear.park;
  bool _panelOpen = false;
  bool _rainbow = false;

  bool _pointerAccelerating = false;
  bool _keyAccelerating = false;
  bool _keyBraking = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  bool get _accelerating => _pointerAccelerating || _keyAccelerating;

  DashTelemetry get _telemetry => DashTelemetry(
        speedKmh: _speed,
        rpm: _rpm,
        maxRpm: 8000,
        redlineRpm: 7000,
        batteryPercent: 99,
        fuelPercent: 62,
        coolantTempC: 90,
        rangeKm: 462,
        odometerKm: 12345.6,
        tripKm: 31.1,
        outsideTempC: 0,
        gear: _gear,
        gearNumber: _style == DashStyle.racing
            ? (_speed < 1 ? 1 : (_speed / 40).ceil().clamp(1, 6))
            : null,
        tirePressures: const TirePressures(
          frontLeft: 2.9,
          frontRight: 2.8,
          rearLeft: 2.9,
          rearRight: 2.9,
        ),
      );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    var next = _speed;
    if (_keyBraking) {
      next -= _brakeRate * dt;
    } else if (_accelerating) {
      next += _accelRate * dt;
    } else {
      next -= _coastRate * dt;
    }
    next = next.clamp(0, _maxSpeed);

    final gearFactor = switch (_gear) {
      Gear.park || Gear.neutral => 0.15,
      Gear.reverse => 0.55,
      Gear.drive => 1.0,
    };
    final targetRpm = _accelerating
        ? (900 + next * 28 * gearFactor).clamp(800, 8000)
        : (800 + next * 18 * gearFactor).clamp(800, 7500);

    if ((next - _speed).abs() > 0.01 || (targetRpm - _rpm).abs() > 1) {
      setState(() {
        _speed = next;
        final t = (12 * dt).clamp(0.0, 1.0);
        _rpm += (targetRpm - _rpm) * t;
      });
    }
  }

  void _shiftGear(int delta) {
    final values = Gear.values;
    final i = (values.indexOf(_gear) + delta).clamp(0, values.length - 1);
    setState(() => _gear = values[i]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isDown) _keyAccelerating = true;
      if (isUp) _keyAccelerating = false;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isDown) _keyBraking = true;
      if (isUp) _keyBraking = false;
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (_panelOpen) return;
                setState(() => _pointerAccelerating = true);
              },
              onPointerUp: (_) =>
                  setState(() => _pointerAccelerating = false),
              onPointerCancel: (_) =>
                  setState(() => _pointerAccelerating = false),
              child: AutoMotoDashboard(
                telemetry: _telemetry,
                style: _style,
                weather: _weather,
                vehicleType: _vehicleType,
                lightSpeedThresholdKmh: 80,
                rainbowSpeed: _rainbow,
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
                  vehicleType: _vehicleType,
                  speed: _speed,
                  rpm: _rpm,
                  gear: _gear,
                  rainbow: _rainbow,
                  onClose: _closePanel,
                  onStyle: (v) => setState(() => _style = v),
                  onWeather: (v) => setState(() => _weather = v),
                  onVehicle: (v) => setState(() => _vehicleType = v),
                  onGear: (v) => setState(() => _gear = v),
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
                  child: Text(
                    '按住加速 · ↑↓加减速 · ←→换档 · ${_speed.round()} km/h',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
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
    required this.weather,
    required this.vehicleType,
    required this.speed,
    required this.rpm,
    required this.gear,
    required this.rainbow,
    required this.onClose,
    required this.onStyle,
    required this.onWeather,
    required this.onVehicle,
    required this.onGear,
    required this.onRainbow,
  });

  final DashStyle style;
  final WeatherType? weather;
  final VehicleType vehicleType;
  final double speed;
  final double rpm;
  final Gear gear;
  final bool rainbow;
  final VoidCallback onClose;
  final ValueChanged<DashStyle> onStyle;
  final ValueChanged<WeatherType?> onWeather;
  final ValueChanged<VehicleType> onVehicle;
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
                '长按仪表加速，松手减速；键盘 ↑↓ 加减速，←→ 换档',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DashStyle.values.map((s) {
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: style == s,
                    onSelected: (_) => onStyle(s),
                  );
                }).toList(),
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
                  ChoiceChip(
                    label: const Text('汽车'),
                    selected: vehicleType == VehicleType.car,
                    onSelected: (_) => onVehicle(VehicleType.car),
                  ),
                  ChoiceChip(
                    label: const Text('摩托'),
                    selected: vehicleType == VehicleType.motorcycle,
                    onSelected: (_) => onVehicle(VehicleType.motorcycle),
                  ),
                  FilterChip(
                    label: const Text('彩虹速度'),
                    selected: rainbow,
                    onSelected: onRainbow,
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