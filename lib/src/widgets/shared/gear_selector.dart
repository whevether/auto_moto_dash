import 'package:flutter/material.dart';

import '../../models/gear.dart';

class GearSelector extends StatelessWidget {
  const GearSelector({
    super.key,
    required this.gear,
    this.accent = const Color(0xFF4FC3F7),
  });

  final Gear gear;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: Gear.values.map((g) {
        final active = g == gear;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
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
          ),
        );
      }).toList(),
    );
  }
}