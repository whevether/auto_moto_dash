/// Automatic gear selector positions.
enum Gear {
  park,
  reverse,
  neutral,
  drive,
}

extension GearX on Gear {
  String get label => switch (this) {
        Gear.park => 'P',
        Gear.reverse => 'R',
        Gear.neutral => 'N',
        Gear.drive => 'D',
      };
}