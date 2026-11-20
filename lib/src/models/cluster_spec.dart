import 'package:material_ui/material_ui.dart';

import 'dash_style.dart';

/// Drawing template used by a brand theme.
enum ClusterLayout {
  /// Two round gauges flanking a center information display.
  twinDial,

  /// One large central tachometer with side information panels.
  centerDial,

  /// Two ring gauges around a center map / road area (widescreen digital).
  virtualCockpit,

  /// EV: speed, center road illustration, trip and tire information.
  evSplit,

  /// EV: power bar on top, large central speed, energy strip below.
  evStrip,

  /// Motorcycle TFT with an arc revolution bar.
  motoTft,

  /// Motorcycle large round speedometer with an LCD.
  motoSpeedo,

  /// Electric motorcycle TFT with a power gauge.
  motoEvTft,
}

/// Visual configuration of a brand theme. Colors, scale and layout only;
/// no brand artwork is included. Hosts may supply licensed logos through
/// `AutoMotoDashboard.brandBadgeBuilder`.
@immutable
class ClusterSpec {
  const ClusterSpec({
    required this.layout,
    required this.brand,
    required this.accent,
    this.model = '',
    this.screen = const Color(0xFF080A0C),
    this.faceDark = const Color(0xFF202327),
    this.faceLight = const Color(0xFF090B0D),
    this.ink = const Color(0xFFF0F2F3),
    this.needle = const Color(0xFFF3483C),
    this.rim = const Color(0xFF73777B),
    this.speedMax = 260,
    this.speedDivisions = 13,
    this.brandSpacing = 4,
    this.brandWeight = FontWeight.w600,
    this.badgeAlignment = Alignment.topCenter,
  });

  final ClusterLayout layout;

  /// Text wordmark drawn when no custom badge is supplied.
  final String brand;

  /// Optional model / sub-label shown beside the wordmark.
  final String model;

  /// Highlight color for bars, rings and active elements.
  final Color accent;

  /// Cluster screen background.
  final Color screen;

  /// Dial face gradient start / end.
  final Color faceDark;
  final Color faceLight;

  /// Dial numerals and ticks.
  final Color ink;
  final Color needle;
  final Color rim;

  /// Full-scale speed in km/h and its major divisions.
  final double speedMax;
  final int speedDivisions;

  final double brandSpacing;
  final FontWeight brandWeight;

  /// Where a host-supplied badge is placed on the cluster.
  final Alignment badgeAlignment;

  bool get isMotorcycle => switch (layout) {
    ClusterLayout.motoTft ||
    ClusterLayout.motoSpeedo ||
    ClusterLayout.motoEvTft => true,
    _ => false,
  };
}

/// Brand configurations for the data-driven themes.
abstract final class ClusterSpecs {
  static ClusterSpec? of(DashStyle style) => switch (style) {
    DashStyle.carVw => _vw,
    DashStyle.carToyota => _toyota,
    DashStyle.carMercedes => _mercedes,
    DashStyle.carAudi => _audi,
    DashStyle.carPorsche => _porsche,
    DashStyle.carFord => _ford,
    DashStyle.carHonda => _honda,
    DashStyle.carHyundai => _hyundai,
    DashStyle.carNissan => _nissan,
    DashStyle.carBmwIdrive => _bmw,
    DashStyle.carEvByd => _byd,
    DashStyle.carEvXpeng => _xpeng,
    DashStyle.carEvXiaomi => _xiaomi,
    DashStyle.carEvAito => _aito,
    DashStyle.carEvZeekr => _zeekr,
    DashStyle.carEvTaycan => _taycan,
    DashStyle.carEvLucid => _lucid,
    DashStyle.carEvRivian => _rivian,
    DashStyle.motoHarley => _harley,
    DashStyle.motoDucati => _ducati,
    DashStyle.motoYamaha => _yamaha,
    DashStyle.motoKawasaki => _kawasaki,
    DashStyle.motoTriumph => _triumph,
    DashStyle.motoKtm => _ktm,
    DashStyle.motoRoyalEnfield => _royalEnfield,
    DashStyle.motoEvZero => _zero,
    _ => null,
  };

  // Combustion cars.
  static const _vw = ClusterSpec(
    layout: ClusterLayout.virtualCockpit,
    brand: 'VOLKSWAGEN',
    accent: Color(0xFF4FA3E0),
    screen: Color(0xFF080D12),
  );
  static const _toyota = ClusterSpec(
    layout: ClusterLayout.twinDial,
    brand: 'TOYOTA',
    accent: Color(0xFFEB0A1E),
    faceDark: Color(0xFF1B1F23),
    needle: Color(0xFFFF6A00),
    speedMax: 220,
    speedDivisions: 11,
  );
  static const _mercedes = ClusterSpec(
    layout: ClusterLayout.virtualCockpit,
    brand: 'MERCEDES-BENZ',
    accent: Color(0xFF3DD6D0),
    screen: Color(0xFF05080B),
    brandSpacing: 3,
    speedMax: 280,
    speedDivisions: 14,
  );
  static const _audi = ClusterSpec(
    layout: ClusterLayout.virtualCockpit,
    brand: 'AUDI',
    accent: Color(0xFFBB0A30),
    screen: Color(0xFF070707),
    speedMax: 300,
    speedDivisions: 15,
  );
  static const _porsche = ClusterSpec(
    layout: ClusterLayout.centerDial,
    brand: 'PORSCHE',
    accent: Color(0xFFD5001C),
    faceDark: Color(0xFF15171A),
    faceLight: Color(0xFF050607),
    needle: Color(0xFFF2F2F2),
    rim: Color(0xFFB9BDC1),
    speedMax: 330,
    speedDivisions: 11,
    brandSpacing: 6,
  );
  static const _ford = ClusterSpec(
    layout: ClusterLayout.twinDial,
    brand: 'FORD',
    accent: Color(0xFF2F6FDB),
    faceDark: Color(0xFF1C2229),
    needle: Color(0xFFFFFFFF),
    speedMax: 240,
    speedDivisions: 12,
  );
  static const _honda = ClusterSpec(
    layout: ClusterLayout.twinDial,
    brand: 'HONDA',
    accent: Color(0xFFE40521),
    faceDark: Color(0xFF14181C),
    needle: Color(0xFFFF3B30),
    speedMax: 240,
    speedDivisions: 12,
  );
  static const _hyundai = ClusterSpec(
    layout: ClusterLayout.virtualCockpit,
    brand: 'HYUNDAI',
    accent: Color(0xFF00A3E0),
    screen: Color(0xFF070B10),
  );
  static const _nissan = ClusterSpec(
    layout: ClusterLayout.twinDial,
    brand: 'NISSAN',
    accent: Color(0xFFC3002F),
    faceDark: Color(0xFF1A2027),
    faceLight: Color(0xFF0A0D12),
    needle: Color(0xFFFF5A36),
    speedMax: 240,
    speedDivisions: 12,
  );
  static const _bmw = ClusterSpec(
    layout: ClusterLayout.virtualCockpit,
    brand: 'BMW',
    accent: Color(0xFF1C69D4),
    screen: Color(0xFF05070A),
    brandSpacing: 8,
  );

  // Electric cars.
  static const _byd = ClusterSpec(
    layout: ClusterLayout.evSplit,
    brand: 'BYD',
    accent: Color(0xFF1FC6B0),
    brandSpacing: 8,
  );
  static const _xpeng = ClusterSpec(
    layout: ClusterLayout.evStrip,
    brand: 'XPENG',
    accent: Color(0xFF00C58E),
    brandSpacing: 6,
  );
  static const _xiaomi = ClusterSpec(
    layout: ClusterLayout.evSplit,
    brand: 'XIAOMI',
    model: 'SU7',
    accent: Color(0xFFFF6900),
    brandSpacing: 5,
  );
  static const _aito = ClusterSpec(
    layout: ClusterLayout.evSplit,
    brand: 'AITO',
    accent: Color(0xFFC6A664),
    screen: Color(0xFF06080C),
    brandSpacing: 7,
  );
  static const _zeekr = ClusterSpec(
    layout: ClusterLayout.evStrip,
    brand: 'ZEEKR',
    accent: Color(0xFF9BE15D),
    brandSpacing: 6,
  );
  static const _taycan = ClusterSpec(
    layout: ClusterLayout.evStrip,
    brand: 'PORSCHE',
    model: 'TAYCAN',
    accent: Color(0xFFD5001C),
    screen: Color(0xFF050607),
    brandSpacing: 6,
  );
  static const _lucid = ClusterSpec(
    layout: ClusterLayout.evStrip,
    brand: 'LUCID',
    accent: Color(0xFFE8E2D6),
    screen: Color(0xFF07080A),
    brandSpacing: 8,
    brandWeight: FontWeight.w300,
  );
  static const _rivian = ClusterSpec(
    layout: ClusterLayout.evSplit,
    brand: 'RIVIAN',
    accent: Color(0xFFF6C324),
    screen: Color(0xFF0A0B0C),
    brandSpacing: 5,
  );

  // Motorcycles.
  static const _harley = ClusterSpec(
    layout: ClusterLayout.motoSpeedo,
    brand: 'HARLEY-DAVIDSON',
    accent: Color(0xFFFF6A00),
    faceDark: Color(0xFF1E1D1B),
    faceLight: Color(0xFF080807),
    rim: Color(0xFFB8B2A6),
    needle: Color(0xFFFF6A00),
    speedMax: 200,
    speedDivisions: 10,
    brandSpacing: 3,
  );
  static const _ducati = ClusterSpec(
    layout: ClusterLayout.motoTft,
    brand: 'DUCATI',
    accent: Color(0xFFD2161E),
    brandSpacing: 6,
  );
  static const _yamaha = ClusterSpec(
    layout: ClusterLayout.motoTft,
    brand: 'YAMAHA',
    accent: Color(0xFF3F7CFF),
    brandSpacing: 5,
  );
  static const _kawasaki = ClusterSpec(
    layout: ClusterLayout.motoTft,
    brand: 'KAWASAKI',
    accent: Color(0xFF6BBE45),
    brandSpacing: 4,
  );
  static const _triumph = ClusterSpec(
    layout: ClusterLayout.motoSpeedo,
    brand: 'TRIUMPH',
    accent: Color(0xFFD9DCDF),
    faceDark: Color(0xFF191B1D),
    rim: Color(0xFFC4C8CC),
    needle: Color(0xFFE4E7EA),
    speedMax: 240,
    speedDivisions: 12,
    brandSpacing: 5,
  );
  static const _ktm = ClusterSpec(
    layout: ClusterLayout.motoTft,
    brand: 'KTM',
    accent: Color(0xFFFF6600),
    brandSpacing: 8,
    brandWeight: FontWeight.w800,
  );
  static const _royalEnfield = ClusterSpec(
    layout: ClusterLayout.motoSpeedo,
    brand: 'ROYAL ENFIELD',
    accent: Color(0xFFC9A24A),
    screen: Color(0xFF0B0B0A),
    faceDark: Color(0xFFEFE5CB),
    faceLight: Color(0xFFD9CCA8),
    ink: Color(0xFF2A2518),
    needle: Color(0xFFB02A1E),
    rim: Color(0xFFC9A24A),
    speedMax: 160,
    speedDivisions: 8,
    brandSpacing: 3,
  );
  static const _zero = ClusterSpec(
    layout: ClusterLayout.motoEvTft,
    brand: 'ZERO',
    accent: Color(0xFFB5E61D),
    brandSpacing: 8,
  );
}
