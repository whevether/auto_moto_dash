import 'dart:math' as math;

/// Exponential smoothing helper for needles and speed digits.
class SmoothedValue {
  SmoothedValue(this.value, {this.responsiveness = 12});

  double value;
  double responsiveness;

  void tick(double target, double dt) {
    if (dt <= 0) return;
    final t = 1 - math.exp(-responsiveness * dt);
    value += (target - value) * t;
  }
}