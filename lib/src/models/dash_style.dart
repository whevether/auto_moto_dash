/// Vehicle category for dashboard themes.
enum DashCategory {
  car,
  motorcycle,
}

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

  /// Fuel motorcycle full TFT (reference image 1).
  motoFuelTft,

  /// Fuel motorcycle analog tach + digital TFT (reference image 2).
  motoFuelHybrid,

  /// NIU NXT electric scooter cluster (reference image 3).
  motoEvNiu,

  /// Yadea E9 electric cluster (reference image 4).
  motoEvYadea,
}

extension DashStyleX on DashStyle {
  bool get isMotorcycle => category == DashCategory.motorcycle;

  DashCategory get category => switch (this) {
        DashStyle.motoFuelTft ||
        DashStyle.motoFuelHybrid ||
        DashStyle.motoEvNiu ||
        DashStyle.motoEvYadea =>
          DashCategory.motorcycle,
        _ => DashCategory.car,
      };

  bool get isElectric => switch (this) {
        DashStyle.carEvTesla ||
        DashStyle.carEvNio ||
        DashStyle.carEvLi ||
        DashStyle.motoEvNiu ||
        DashStyle.motoEvYadea =>
          true,
        _ => false,
      };

  bool get isCarEv => switch (this) {
        DashStyle.carEvTesla ||
        DashStyle.carEvNio ||
        DashStyle.carEvLi =>
          true,
        _ => false,
      };

  bool get isDigitalHud => switch (this) {
        DashStyle.techNeon ||
        DashStyle.hud ||
        DashStyle.performance ||
        DashStyle.pulseBreath =>
          true,
        _ => false,
      };

  bool get isDigital =>
      isDigitalHud || isCarEv || isMotorcycle && this != DashStyle.motoFuelHybrid;

  bool get isAnalog =>
      this == DashStyle.classic ||
      this == DashStyle.racing ||
      this == DashStyle.motoFuelHybrid;

  static List<DashStyle> forCategory(DashCategory category) {
    return DashStyle.values.where((s) => s.category == category).toList();
  }

  static DashStyle defaultFor(DashCategory category) => switch (category) {
        DashCategory.car => DashStyle.hud,
        DashCategory.motorcycle => DashStyle.motoFuelTft,
      };

  String get label => switch (this) {
        DashStyle.techNeon => '科技霓虹',
        DashStyle.hud => 'HUD',
        DashStyle.performance => '高性能',
        DashStyle.pulseBreath => '脉冲呼吸',
        DashStyle.classic => '宝马风格',
        DashStyle.racing => '法拉利风格',
        DashStyle.carEvTesla => '特斯拉',
        DashStyle.carEvNio => '蔚来',
        DashStyle.carEvLi => '理想',
        DashStyle.motoFuelTft => '燃油摩托 TFT',
        DashStyle.motoFuelHybrid => '燃油摩托混合',
        DashStyle.motoEvNiu => '小牛电动',
        DashStyle.motoEvYadea => '雅迪电动',
      };
}
