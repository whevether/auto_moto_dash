import 'dart:ui' show Color;

import 'dash_style.dart';

/// Parametric body style of the ego vehicle drawn by 3D road / cockpit views.
///
/// Shapes are generic proportions (length, wheelbase, roof line, ground
/// clearance), not replicas of any manufacturer's design.
enum EgoVehicleModel {
  sedan,
  fastback,
  sportCoupe,
  suv,
  shootingBrake,
  pickup,
  sportBike,
  adventureBike,
  cruiserBike,
  scooter;

  bool get isMotorcycle => switch (this) {
    EgoVehicleModel.sportBike ||
    EgoVehicleModel.adventureBike ||
    EgoVehicleModel.cruiserBike ||
    EgoVehicleModel.scooter => true,
    _ => false,
  };

  String get label => switch (this) {
    EgoVehicleModel.sedan => '轿车',
    EgoVehicleModel.fastback => '溜背轿车',
    EgoVehicleModel.sportCoupe => '运动轿跑',
    EgoVehicleModel.suv => 'SUV',
    EgoVehicleModel.shootingBrake => '猎装车',
    EgoVehicleModel.pickup => '皮卡',
    EgoVehicleModel.sportBike => '运动摩托',
    EgoVehicleModel.adventureBike => 'ADV 摩托',
    EgoVehicleModel.cruiserBike => '巡航摩托',
    EgoVehicleModel.scooter => '踏板车',
  };
}

/// Theme → ego vehicle mapping.
extension DashStyleEgoVehicle on DashStyle {
  /// Body style drawn for this theme (overridable per [ClusterSpec]).
  EgoVehicleModel get egoVehicle =>
      spec?.egoModel ??
      switch (this) {
        DashStyle.carEvTesla => EgoVehicleModel.fastback,
        DashStyle.carEvNio ||
        DashStyle.carEvLucid ||
        DashStyle.carEvXpeng ||
        DashStyle.carEvByd => EgoVehicleModel.sedan,
        DashStyle.carEvXiaomi ||
        DashStyle.carEvTaycan ||
        DashStyle.racing ||
        DashStyle.carPorsche => EgoVehicleModel.sportCoupe,
        DashStyle.carEvLi || DashStyle.carEvAito => EgoVehicleModel.suv,
        DashStyle.carEvZeekr => EgoVehicleModel.shootingBrake,
        DashStyle.carEvRivian || DashStyle.carFord => EgoVehicleModel.pickup,
        DashStyle.carToyota || DashStyle.carHonda => EgoVehicleModel.sedan,
        DashStyle.carAudi ||
        DashStyle.carMercedes ||
        DashStyle.carBmwIdrive ||
        DashStyle.classic => EgoVehicleModel.sedan,
        DashStyle.carVw ||
        DashStyle.carHyundai ||
        DashStyle.carNissan => EgoVehicleModel.suv,
        DashStyle.motoFuelTft ||
        DashStyle.motoKtm ||
        DashStyle.motoTriumph => EgoVehicleModel.adventureBike,
        DashStyle.motoDucati ||
        DashStyle.motoYamaha ||
        DashStyle.motoKawasaki ||
        DashStyle.motoEvZero ||
        DashStyle.motoFuelHybrid => EgoVehicleModel.sportBike,
        DashStyle.motoHarley ||
        DashStyle.motoRoyalEnfield => EgoVehicleModel.cruiserBike,
        DashStyle.motoEvNiu || DashStyle.motoEvYadea => EgoVehicleModel.scooter,
        _ => EgoVehicleModel.sedan,
      };

  /// Default body paint for this theme.
  Color get egoPaint =>
      spec?.egoPaint ??
      switch (this) {
        DashStyle.carEvTesla => const Color(0xFFB71C1C),
        DashStyle.carEvNio => const Color(0xFF263238),
        DashStyle.carEvLi => const Color(0xFF5D6B73),
        DashStyle.racing => const Color(0xFFD50000),
        DashStyle.carEvXiaomi => const Color(0xFF1E5D8C),
        DashStyle.carPorsche || DashStyle.carEvTaycan => const Color(0xFFE0E3E5),
        DashStyle.classic || DashStyle.carBmwIdrive => const Color(0xFF1A3A6B),
        DashStyle.motoDucati => const Color(0xFFC62828),
        DashStyle.motoKawasaki => const Color(0xFF43A047),
        DashStyle.motoKtm => const Color(0xFFFF6D00),
        DashStyle.motoYamaha => const Color(0xFF1565C0),
        DashStyle.motoHarley => const Color(0xFF212121),
        _ => spec?.accent ?? const Color(0xFF9EA7AD),
      };
}
