/// Mutually exclusive dashboard visual styles.
enum DashStyle {
  /// Polygonal neon / tech glow digital cluster.
  techNeon,

  /// Transparent floating HUD (closest to reference video).
  hud,

  /// High-refresh smooth digital cluster.
  performance,

  /// Breathing / pulse light speed readout.
  pulseBreath,

  /// Traditional dual-circle automotive gauges.
  classic,

  /// Racing cluster with redline and shift lights.
  racing,
}

extension DashStyleX on DashStyle {
  bool get isDigital =>
      this == DashStyle.techNeon ||
      this == DashStyle.hud ||
      this == DashStyle.performance ||
      this == DashStyle.pulseBreath;

  bool get isAnalog => this == DashStyle.classic || this == DashStyle.racing;

  String get label => switch (this) {
        DashStyle.techNeon => '科技霓虹',
        DashStyle.hud => 'HUD',
        DashStyle.performance => '高性能',
        DashStyle.pulseBreath => '脉冲呼吸',
        DashStyle.classic => '传统汽车',
        DashStyle.racing => '赛车',
      };
}