import 'cluster_spec.dart';

/// Vehicle category for dashboard themes.
enum DashCategory { car, motorcycle }

/// Mutually exclusive dashboard visual styles.
///
/// Brand themes are independently drawn interpretations of each maker's
/// instrument design language; no brand artwork is bundled. Use
/// `AutoMotoDashboard.brandBadgeBuilder` to supply licensed logos.
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

  // ---- Combustion cars -------------------------------------------------

  /// Volkswagen Digital Cockpit-inspired.
  carVw,

  /// Toyota / Lexus-inspired twin dial.
  carToyota,

  /// Mercedes-Benz MBUX-inspired widescreen.
  carMercedes,

  /// Audi Virtual Cockpit-inspired.
  carAudi,

  /// Porsche 911-inspired central tachometer.
  carPorsche,

  /// Ford / Lincoln-inspired twin dial.
  carFord,

  /// Honda / Acura-inspired twin dial.
  carHonda,

  /// Hyundai / Kia-inspired digital cluster.
  carHyundai,

  /// Nissan-inspired twin dial.
  carNissan,

  /// BMW iDrive curved display-inspired.
  carBmwIdrive,

  // ---- Electric cars ---------------------------------------------------

  /// BYD-inspired EV cluster.
  carEvByd,

  /// XPeng-inspired EV cluster.
  carEvXpeng,

  /// Xiaomi SU7-inspired EV cluster.
  carEvXiaomi,

  /// AITO / HIMA (Huawei)-inspired EV cluster.
  carEvAito,

  /// Zeekr-inspired EV cluster.
  carEvZeekr,

  /// Porsche Taycan-inspired EV cluster.
  carEvTaycan,

  /// Lucid-inspired EV cluster.
  carEvLucid,

  /// Rivian-inspired EV cluster.
  carEvRivian,

  // ---- Motorcycles -----------------------------------------------------

  /// Harley-Davidson-inspired analog speedometer.
  motoHarley,

  /// Ducati-inspired TFT.
  motoDucati,

  /// Yamaha-inspired TFT.
  motoYamaha,

  /// Kawasaki-inspired TFT.
  motoKawasaki,

  /// Triumph-inspired analog speedometer with LCD.
  motoTriumph,

  /// KTM-inspired TFT.
  motoKtm,

  /// Royal Enfield-inspired classic analog speedometer.
  motoRoyalEnfield,

  /// Zero Motorcycles-inspired electric TFT.
  motoEvZero,
}

extension DashStyleX on DashStyle {
  /// Data-driven brand configuration; `null` for the original 13 themes.
  ClusterSpec? get spec => ClusterSpecs.of(this);

  bool get isMotorcycle => category == DashCategory.motorcycle;

  DashCategory get category => switch (this) {
    DashStyle.motoFuelTft ||
    DashStyle.motoFuelHybrid ||
    DashStyle.motoEvNiu ||
    DashStyle.motoEvYadea ||
    DashStyle.motoHarley ||
    DashStyle.motoDucati ||
    DashStyle.motoYamaha ||
    DashStyle.motoKawasaki ||
    DashStyle.motoTriumph ||
    DashStyle.motoKtm ||
    DashStyle.motoRoyalEnfield ||
    DashStyle.motoEvZero => DashCategory.motorcycle,
    _ => DashCategory.car,
  };

  bool get isElectric => switch (this) {
    DashStyle.carEvTesla ||
    DashStyle.carEvNio ||
    DashStyle.carEvLi ||
    DashStyle.carEvByd ||
    DashStyle.carEvXpeng ||
    DashStyle.carEvXiaomi ||
    DashStyle.carEvAito ||
    DashStyle.carEvZeekr ||
    DashStyle.carEvTaycan ||
    DashStyle.carEvLucid ||
    DashStyle.carEvRivian ||
    DashStyle.motoEvNiu ||
    DashStyle.motoEvYadea ||
    DashStyle.motoEvZero => true,
    _ => false,
  };

  bool get isCarEv => isElectric && !isMotorcycle;

  bool get isDigitalHud => switch (this) {
    DashStyle.techNeon ||
    DashStyle.hud ||
    DashStyle.performance ||
    DashStyle.pulseBreath => true,
    _ => false,
  };

  bool get isAnalog => switch (this) {
    DashStyle.classic || DashStyle.racing || DashStyle.motoFuelHybrid => true,
    _ => switch (spec?.layout) {
      ClusterLayout.twinDial ||
      ClusterLayout.centerDial ||
      ClusterLayout.motoSpeedo => true,
      _ => false,
    },
  };

  bool get isDigital => !isAnalog;

  /// Whether the theme draws a road view whose lane markings scroll with speed.
  bool get hasRoad => switch (this) {
    DashStyle.carEvTesla || DashStyle.carEvNio || DashStyle.carEvLi => true,
    _ =>
      spec?.layout == ClusterLayout.virtualCockpit ||
          spec?.layout == ClusterLayout.evSplit,
  };

  /// Whether this theme is a brand-inspired theme from [ClusterSpecs].
  bool get isBrand => spec != null;

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
    DashStyle.carVw => '大众 · Digital Cockpit',
    DashStyle.carToyota => '丰田/雷克萨斯 · 双圆表',
    DashStyle.carMercedes => '奔驰 · MBUX 超联屏',
    DashStyle.carAudi => '奥迪 · Virtual Cockpit',
    DashStyle.carPorsche => '保时捷 911 · 中央转速表',
    DashStyle.carFord => '福特/林肯 · 双圆表',
    DashStyle.carHonda => '本田/讴歌 · 双圆表',
    DashStyle.carHyundai => '现代/起亚 · 数字仪表',
    DashStyle.carNissan => '日产 · 双圆表',
    DashStyle.carBmwIdrive => '宝马 · iDrive 曲面屏',
    DashStyle.carEvByd => '比亚迪 · 电车仪表',
    DashStyle.carEvXpeng => '小鹏 · 电车仪表',
    DashStyle.carEvXiaomi => '小米 SU7 · 电车仪表',
    DashStyle.carEvAito => '问界 · 电车仪表',
    DashStyle.carEvZeekr => '极氪 · 电车仪表',
    DashStyle.carEvTaycan => '保时捷 Taycan · 电车仪表',
    DashStyle.carEvLucid => 'Lucid · 电车仪表',
    DashStyle.carEvRivian => 'Rivian · 电车仪表',
    DashStyle.motoHarley => 'Harley-Davidson · 指针表',
    DashStyle.motoDucati => 'Ducati · TFT',
    DashStyle.motoYamaha => 'Yamaha · TFT',
    DashStyle.motoKawasaki => 'Kawasaki · TFT',
    DashStyle.motoTriumph => 'Triumph · 指针＋LCD',
    DashStyle.motoKtm => 'KTM · TFT',
    DashStyle.motoRoyalEnfield => 'Royal Enfield · 经典指针',
    DashStyle.motoEvZero => 'Zero · 电摩 TFT',
  };

  /// English display name, for non-Chinese UIs.
  String get labelEn => switch (this) {
    DashStyle.techNeon => 'Tech Neon',
    DashStyle.hud => 'HUD',
    DashStyle.performance => 'Performance',
    DashStyle.pulseBreath => 'Pulse Breath',
    DashStyle.classic => 'BMW 3 Series · Twin Dial',
    DashStyle.racing => 'Ferrari 458 · Center Dial',
    DashStyle.carEvTesla => 'Tesla Model S · Wide',
    DashStyle.carEvNio => 'NIO ET7 · Minimal',
    DashStyle.carEvLi => 'Li Auto L9 · Info Wide',
    DashStyle.motoFuelTft => 'BMW Motorrad · Pure Ride',
    DashStyle.motoFuelHybrid => 'Honda · Analog + LCD',
    DashStyle.motoEvNiu => 'NIU · Negative LCD',
    DashStyle.motoEvYadea => 'Yadea · Positive LCD',
    DashStyle.carVw => 'Volkswagen · Digital Cockpit',
    DashStyle.carToyota => 'Toyota / Lexus · Twin Dial',
    DashStyle.carMercedes => 'Mercedes-Benz · MBUX Hyperscreen',
    DashStyle.carAudi => 'Audi · Virtual Cockpit',
    DashStyle.carPorsche => 'Porsche 911 · Center Tach',
    DashStyle.carFord => 'Ford / Lincoln · Twin Dial',
    DashStyle.carHonda => 'Honda / Acura · Twin Dial',
    DashStyle.carHyundai => 'Hyundai / Kia · Digital',
    DashStyle.carNissan => 'Nissan · Twin Dial',
    DashStyle.carBmwIdrive => 'BMW · iDrive Curved Display',
    DashStyle.carEvByd => 'BYD · EV Cluster',
    DashStyle.carEvXpeng => 'XPeng · EV Cluster',
    DashStyle.carEvXiaomi => 'Xiaomi SU7 · EV Cluster',
    DashStyle.carEvAito => 'AITO · EV Cluster',
    DashStyle.carEvZeekr => 'Zeekr · EV Cluster',
    DashStyle.carEvTaycan => 'Porsche Taycan · EV Cluster',
    DashStyle.carEvLucid => 'Lucid · EV Cluster',
    DashStyle.carEvRivian => 'Rivian · EV Cluster',
    DashStyle.motoHarley => 'Harley-Davidson · Analog',
    DashStyle.motoDucati => 'Ducati · TFT',
    DashStyle.motoYamaha => 'Yamaha · TFT',
    DashStyle.motoKawasaki => 'Kawasaki · TFT',
    DashStyle.motoTriumph => 'Triumph · Analog + LCD',
    DashStyle.motoKtm => 'KTM · TFT',
    DashStyle.motoRoyalEnfield => 'Royal Enfield · Classic Analog',
    DashStyle.motoEvZero => 'Zero · Electric TFT',
  };
}
