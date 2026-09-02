import 'package:material_ui/material_ui.dart';

import '../../models/dash_telemetry.dart';

/// Unified odometer + range readout for all dashboard themes.
class MileageRangeStrip extends StatelessWidget {
  const MileageRangeStrip({
    super.key,
    required this.telemetry,
    this.fontSize = 11,
    this.secondaryFontSize = 10,
    this.color,
    this.secondaryColor,
    this.showTrip = false,
    this.showBattery = false,
    this.showFuel = false,
    this.compact = false,
  });

  final DashTelemetry telemetry;
  final double fontSize;
  final double secondaryFontSize;
  final Color? color;
  final Color? secondaryColor;
  final bool showTrip;
  final bool showBattery;
  final bool showFuel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Colors.white.withValues(alpha: 0.55);
    final secondary = secondaryColor ?? Colors.white.withValues(alpha: 0.4);
    final odo = telemetry.odometerKm.round();
    final range = telemetry.rangeKm.round();

    if (compact) {
      return Text(
        'ODO $odo km · 续航 $range km',
        textAlign: TextAlign.center,
        style: TextStyle(color: primary, fontSize: fontSize, letterSpacing: 0.4),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBattery || showFuel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBattery) ...[
                  Icon(
                    Icons.battery_charging_full,
                    size: fontSize + 4,
                    color: _batteryColor(telemetry.batteryPercent),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${telemetry.batteryPercent.round()}%',
                    style: TextStyle(
                      color: primary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (showBattery && showFuel)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (showFuel) ...[
                  Icon(
                    Icons.local_gas_station,
                    size: fontSize + 2,
                    color: const Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${telemetry.fuelPercent.round()}%',
                    style: TextStyle(color: primary, fontSize: fontSize),
                  ),
                ],
              ],
            ),
          ),
        Text(
          'ODO $odo km  ·  续航 $range km',
          textAlign: TextAlign.center,
          style: TextStyle(color: primary, fontSize: fontSize, letterSpacing: 0.4),
        ),
        if (showTrip) ...[
          const SizedBox(height: 2),
          Text(
            'TRIP ${telemetry.tripKm.toStringAsFixed(1)} km',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: secondaryFontSize),
          ),
        ],
      ],
    );
  }

  Color _batteryColor(double percent) {
    if (percent <= 15) return const Color(0xFFFF5252);
    if (percent <= 30) return const Color(0xFFFFB74D);
    return const Color(0xFF69F0AE);
  }
}
