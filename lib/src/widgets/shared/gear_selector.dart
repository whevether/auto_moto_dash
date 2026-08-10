import 'package:flutter/material.dart';

import '../../models/gear.dart';

class GearSelector extends StatelessWidget {
  const GearSelector({
    super.key,
    required this.gear,
    this.accent = const Color(0xFF4FC3F7),
    this.onGearSelected,
    this.onGearPointerDown,
  });

  final Gear gear;
  final Color accent;
  final ValueChanged<Gear>? onGearSelected;

  /// Fired on pointer down before selection — host can suppress accel gestures.
  final VoidCallback? onGearPointerDown;

  @override
  Widget build(BuildContext context) {
    final interactive = onGearSelected != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: Gear.values.map((g) {
        final active = g == gear;
        final label = Text(
          g.label,
          style: TextStyle(
            color: active ? accent : Colors.white.withValues(alpha: 0.85),
            fontSize: active ? 28 : 22,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            shadows: active
                ? [
                    Shadow(
                      color: accent.withValues(alpha: 0.9),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
        );

        if (!interactive) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: label,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onGearSelected!(g),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onGearPointerDown?.call(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: label,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}