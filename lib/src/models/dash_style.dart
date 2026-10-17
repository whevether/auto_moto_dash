/// Vehicle category for dashboard themes.
enum DashCategory { car, motorcycle }

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

  /// Tesla-inspired EV cluster.
  carEvTesla,

  /// NIO-inspired EV cluster.
  carEvNio,

  /// Li Auto-inspired EV cluster.
  carEvLi,

  /// BMW Motorrad Pure Ride-inspired fuel motorcycle TFT.
  motoFuelTft,

  /// Honda-inspired analog tachometer and LCD combination.
  motoFuelHybrid,

  /// NIU-inspired negative LCD scooter cluster.
  motoEvNiu,

  /// Yadea-inspired positive LCD scooter cluster.
  motoEvYadea,
}

extension DashStyleX on DashStyle {
  bool get isMotorcycle => category == DashCategory.motorcycle;

  DashCategory get category => switch (this) {
    DashStyle.motoFuelTft ||
    DashStyle.motoFuelHybrid ||
    DashStyle.motoEvNiu ||
    DashStyle.motoEvYadea => DashCategory.motorcycle,
    _ => DashCategory.car,
  };

  bool get isElectric => switch (this) {
    DashStyle.carEvTesla ||
    DashStyle.carEvNio ||
    DashStyle.carEvLi ||
    DashStyle.motoEvNiu ||
    DashStyle.motoEvYadea => true,
    _ => false,
  };

  bool get isCarEv => switch (this) {
    DashStyle.carEvTesla || DashStyle.carEvNio || DashStyle.carEvLi => true,
    _ => false,
  };

  bool get isDigitalHud => switch (this) {
    DashStyle.techNeon ||
    DashStyle.hud ||
    DashStyle.performance ||
    DashStyle.pulseBreath => true,
    _ => false,
  };

  bool get isDigital =>
      isDigitalHud ||
      isCarEv ||
      isMotorcycle && this != DashStyle.motoFuelHybrid;

  bool get isAnalog =>
      this == DashStyle.classic ||
      this == DashStyle.racing ||
      this == DashStyle.motoFuelHybrid;

  static List<DashStyle> forCategory(DashCategory category) {
    return DashStyle.values.where((s) => s.category == category).toList();
  }

  static DashStyle defaultFor(DashCategory category) => switch (category) {
    DashCategory.car => DashStyle.classic,
    DashCategory.motorcycle => DashStyle.motoFuelTft,
  };

  String get label => switch (this) {
    DashStyle.techNeon => '科技霓虹',
    DashStyle.hud => 'HUD',
    DashStyle.performance => '高性能',
    DashStyle.pulseBreath => '脉冲呼吸',
    DashStyle.classic => 'BMW 3系 · 机械双表',
    DashStyle.racing => 'Ferrari 458 · 中央黄表',
    DashStyle.carEvTesla => 'Tesla Model S · 宽屏',
    DashStyle.carEvNio => 'NIO ET7 · 极简仪表',
    DashStyle.carEvLi => '理想 L9 · 信息宽屏',
    DashStyle.motoFuelTft => 'BMW Motorrad · Pure Ride',
    DashStyle.motoFuelHybrid => 'Honda 风格 · 指针＋LCD',
    DashStyle.motoEvNiu => 'NIU 风格 · 负显液晶',
    DashStyle.motoEvYadea => '雅迪风格 · 正显液晶',
  };
}
