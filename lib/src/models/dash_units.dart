/// Speed display unit. Telemetry is always supplied in km/h.
enum SpeedUnit { kmh, mph }

/// Distance display unit. Telemetry is always supplied in km.
enum DistanceUnit { km, mi }

/// Tire pressure display unit. Telemetry is always supplied in bar.
enum PressureUnit { bar, psi, kPa }

/// Temperature display unit. Telemetry is always supplied in degrees Celsius.
enum TemperatureUnit { celsius, fahrenheit }

/// Display units. Host telemetry stays metric; conversion happens at render.
class DashUnits {
  const DashUnits({
    this.speed = SpeedUnit.kmh,
    this.distance = DistanceUnit.km,
    this.pressure = PressureUnit.bar,
    this.temperature = TemperatureUnit.celsius,
  });

  /// km/h, km, bar, °C (default).
  static const metric = DashUnits();

  /// mph, mi, psi, °F.
  static const imperial = DashUnits(
    speed: SpeedUnit.mph,
    distance: DistanceUnit.mi,
    pressure: PressureUnit.psi,
    temperature: TemperatureUnit.fahrenheit,
  );

  final SpeedUnit speed;
  final DistanceUnit distance;
  final PressureUnit pressure;
  final TemperatureUnit temperature;

  static const _kmPerMile = 1.609344;

  double speedValue(double kmh) =>
      speed == SpeedUnit.kmh ? kmh : kmh / _kmPerMile;

  String get speedLabel => speed == SpeedUnit.kmh ? 'km/h' : 'mph';

  double distanceValue(double km) =>
      distance == DistanceUnit.km ? km : km / _kmPerMile;

  String get distanceLabel => distance == DistanceUnit.km ? 'km' : 'mi';

  double pressureValue(double bar) => switch (pressure) {
    PressureUnit.bar => bar,
    PressureUnit.psi => bar * 14.5037738,
    PressureUnit.kPa => bar * 100,
  };

  String get pressureLabel => switch (pressure) {
    PressureUnit.bar => 'bar',
    PressureUnit.psi => 'psi',
    PressureUnit.kPa => 'kPa',
  };

  /// Pressure with a precision suited to the unit.
  String pressureText(double bar) =>
      pressureValue(bar).toStringAsFixed(pressure == PressureUnit.bar ? 1 : 0);

  double temperatureValue(double celsius) =>
      temperature == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32;

  String get temperatureLabel =>
      temperature == TemperatureUnit.celsius ? '°C' : '°F';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashUnits &&
          speed == other.speed &&
          distance == other.distance &&
          pressure == other.pressure &&
          temperature == other.temperature;

  @override
  int get hashCode => Object.hash(speed, distance, pressure, temperature);
}
