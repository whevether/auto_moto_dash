import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../animation/smoothed_value.dart';
import '../../models/dash_style.dart';
import '../../models/dash_telemetry.dart';
import '../../models/dash_units.dart';
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
    this.units = DashUnits.metric,
    this.brandBadgeBuilder,
    this.semanticsLabel,
  });

  final DashTelemetry telemetry;
  final DashStyle style;
  final DashUnits units;
  final Widget Function(BuildContext context, DashStyle style)?
  brandBadgeBuilder;
  final String? semanticsLabel;
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
      final moving = widget.style.hasRoad && _speed.value > 0.05;
      if (moving) {
        // ~20 m per lane-divider cycle.
        _roadPhase =
            (_roadPhase + _speed.value / 3.6 * dt.clamp(0, 0.05) / 20) % 1.0;
      }
      if (moving || speed != _speed.value || rpm != _rpm.value) {
        setState(() {});
      }
      if (!_needsAnimation) _ticker.stop();
    });
  }

  double _roadPhase = 0;

  bool get _needsAnimation =>
      (widget.style.hasRoad && _speed.value > 0.05) ||
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
    final u = widget.units;
    final moto = widget.style.isMotorcycle;
    final badge = widget.style.isBrand
        ? widget.brandBadgeBuilder?.call(context, widget.style)
        : null;
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
                      widget.semanticsLabel ??
                      '${widget.style.label}，'
                          '${u.speedValue(t.speedKmh).round()} ${u.speedLabel}，'
                          '档位 ${t.gear.label}，$energy，'
                          '续航 ${u.distanceValue(t.rangeKm).round()} '
                          '${u.distanceLabel}，'
                          'ODO ${u.distanceValue(t.odometerKm).toStringAsFixed(1)} '
                          '${u.distanceLabel}',
                  child: AspectRatio(
                    aspectRatio: moto ? 900 / 520 : 1200 / 480,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: ProductionClusterPainter(
                              telemetry: t,
                              style: widget.style,
                              speed: _speed.value,
                              rpm: _rpm.value,
                              units: u,
                              roadPhase: _roadPhase,
                              showBrandWordmark: badge == null,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Align(
                            alignment:
                                widget.style.spec?.badgeAlignment ??
                                Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: FractionallySizedBox(
                                heightFactor: 0.12,
                                child: FittedBox(child: badge),
                              ),
                            ),
                          ),
                      ],
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
