import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/gear.dart';
import '../../painters/production_cluster_painter.dart';
import '../shared/gear_selector.dart';

/// Production-inspired instruments drawn in their own physical display ratio.
/// The display remains opaque, even when environmental effects are enabled.
class ProductionClusterBody extends StatefulWidget {
  const ProductionClusterBody({
    super.key,
    required this.telemetry,
    required this.style,
    this.showGearSelector = true,
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final bool showGearSelector;
  final ValueChanged<Gear>? onGearSelected;
  final VoidCallback? onGearPointerDown;

  @override
  State<ProductionClusterBody> createState() => _ProductionClusterBodyState();
}

class _ProductionClusterBodyState extends State<ProductionClusterBody>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SmoothedValue _speed;
  late final SmoothedValue _rpm;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _speed = SmoothedValue(
      widget.telemetry.speedKmh,
      responsiveness: 12,
      precision: 0.01,
    );
    _rpm = SmoothedValue(
      widget.telemetry.rpm,
      responsiveness: 18,
      precision: 0.5,
    );
    _ticker = createTicker((elapsed) {
      final dt = _last == Duration.zero
          ? 1 / 60
          : (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      final speed = _speed.value;
      final rpm = _rpm.value;
      _speed.tick(widget.telemetry.speedKmh, dt.clamp(0, 0.05));
      _rpm.tick(widget.telemetry.rpm, dt.clamp(0, 0.05));
      if (speed != _speed.value || rpm != _rpm.value) setState(() {});
      if (!_needsAnimation) _ticker.stop();
    });
  }

  bool get _needsAnimation =>
      _speed.value != widget.telemetry.speedKmh ||
      (!widget.style.isElectric && _rpm.value != widget.telemetry.rpm);

  @override
  void didUpdateWidget(covariant ProductionClusterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_needsAnimation && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final moto = widget.style.isMotorcycle;
    final energy = widget.style.isElectric
        ? '电量 ${t.batteryPercent.round()}%'
        : '燃油 ${t.fuelPercent.round()}%';
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(moto ? 20 : 12),
              child: Center(
                child: Semantics(
                  label:
                      '${widget.style.label}，${t.speedKmh.round()} km/h，'
                      '档位 ${t.gear.label}，$energy，续航 ${t.rangeKm.round()} km，'
                      'ODO ${t.odometerKm.toStringAsFixed(1)} km',
                  child: AspectRatio(
                    aspectRatio: moto ? 900 / 520 : 1200 / 480,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: ProductionClusterPainter(
                          telemetry: t,
                          style: widget.style,
                          speed: _speed.value,
                          rpm: _rpm.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showGearSelector && widget.onGearSelected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: GearSelector(
                gear: t.gear,
                accent: const Color(0xFFE3E6E8),
                onGearSelected: widget.onGearSelected,
                onGearPointerDown: widget.onGearPointerDown,
              ),
            ),
        ],
      ),
    );
  }
}
