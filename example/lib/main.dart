import 'package:auto_moto_dash/auto_moto_dash.dart';
import 'package:flutter/material.dart';
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

class _DashDemoPageState extends State<DashDemoPage> {
  DashStyle _style = DashStyle.hud;
  WeatherType? _weather = WeatherType.cloudy;
  VehicleType _vehicleType = VehicleType.car;
  double _speed = 0;
  double _rpm = 800;
  Gear _gear = Gear.park;
  bool _panelOpen = false;
  bool _rainbow = false;

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
            ? (_speed < 1
                ? 1
                : (_speed / 40).ceil().clamp(1, 6))
            : null,
        tirePressures: const TirePressures(
          frontLeft: 2.9,
          frontRight: 2.8,
          rearLeft: 2.9,
          rearRight: 2.9,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AutoMotoDashboard(
            telemetry: _telemetry,
            style: _style,
            weather: _weather,
            vehicleType: _vehicleType,
            lightSpeedThresholdKmh: 80,
            rainbowSpeed: _rainbow,
          ),
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
          if (_panelOpen)
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
                onStyle: (v) => setState(() => _style = v),
                onWeather: (v) => setState(() => _weather = v),
                onVehicle: (v) => setState(() => _vehicleType = v),
                onSpeed: (v) => setState(() {
                  _speed = v;
                  if (v > 1 && _gear == Gear.park) _gear = Gear.drive;
                  if (v < 1 && _gear == Gear.drive) _gear = Gear.park;
                  // Couple rpm roughly to speed for demo feel.
                  if (_style.isAnalog) {
                    _rpm = (800 + v * 28).clamp(0, 8000);
                  }
                }),
                onRpm: (v) => setState(() => _rpm = v),
                onGear: (v) => setState(() => _gear = v),
                onRainbow: (v) => setState(() => _rainbow = v),
              ),
            ),
        ],
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
    required this.onStyle,
    required this.onWeather,
    required this.onVehicle,
    required this.onSpeed,
    required this.onRpm,
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
  final ValueChanged<DashStyle> onStyle;
  final ValueChanged<WeatherType?> onWeather;
  final ValueChanged<VehicleType> onVehicle;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onRpm;
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
              Text('车速 ${speed.round()} km/h'),
              Slider(
                value: speed,
                max: 260,
                onChanged: onSpeed,
              ),
              if (style.isAnalog) ...[
                Text('转速 ${rpm.round()} rpm'),
                Slider(
                  value: rpm,
                  max: 8000,
                  onChanged: onRpm,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('档位'),
                  const SizedBox(width: 12),
                  ...Gear.values.map((g) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(g.label),
                        selected: gear == g,
                        onSelected: (_) => onGear(g),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('汽车'),
                    selected: vehicleType == VehicleType.car,
                    onSelected: (_) => onVehicle(VehicleType.car),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('摩托'),
                    selected: vehicleType == VehicleType.motorcycle,
                    onSelected: (_) => onVehicle(VehicleType.motorcycle),
                  ),
                  const Spacer(),
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