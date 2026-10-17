import 'dart:math' as math;

/// Frame-rate independent smoothing that settles exactly at the target.
class SmoothedValue {
  SmoothedValue(this.value, {this.responsiveness = 12, this.precision = 0.001});

  double value;
  double responsiveness;
  final double precision;

  void tick(double target, double dt) {
    if (!dt.isFinite || dt <= 0 || !target.isFinite) return;
    if (!value.isFinite) {
      value = target;
      return;
    }
    final rate = responsiveness.isFinite && responsiveness > 0
        ? responsiveness
        : 12.0;
    value += (target - value) * (1 - math.exp(-rate * dt));
    if ((target - value).abs() <= precision) value = target;
  }
}
