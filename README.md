# auto_moto_dash

A pure-Dart Flutter package for motorcycle / car dashboards: digital HUD and production-inspired analog/LCD clusters, weather backgrounds, and particle effects. No platform channels — drop into any Flutter app.

[中文文档](README_zh.md)

## Features

- 39 mutually exclusive themes: 4 digital HUDs + BMW + Ferrari + Tesla/NIO/Li EV + 4 motorcycle clusters (2 fuel + 2 electric) + 26 brand-inspired themes (VW, Toyota, Mercedes, Audi, Porsche, Ford, Honda, Hyundai, Nissan, BMW iDrive, BYD, XPeng, Xiaomi SU7, AITO, Zeekr, Taycan, Lucid, Rivian, Harley-Davidson, Ducati, Yamaha, Kawasaki, Triumph, KTM, Royal Enfield, Zero)
- `units: DashUnits.imperial` switches to mph / mi / psi / °F. Brand themes draw a text wordmark only; pass `brandBadgeBuilder` to show your own licensed logo. Brand themes interpret each maker's design language (layout, colors, scale) and are not pixel-exact copies.
- Optional weather (sun / rain / snow / fog / haze, etc.), based on vendored [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)
- 5 mutually exclusive particle effects with inertial flow (fast ramp-up, slow coast-down)
- `DriveSimulation`: demo PRND model (shift interlocks, coasting, reverse speed cap)
- Production speed readouts turn red on overspeed; racing shift LEDs follow RPM; digital HUDs retain animated overspeed warnings
- ODO + remaining range on every theme; SOC on electric themes

## Production-inspired instruments

The default is now `DashStyle.classic`, with weather and particles off. Nine vehicle themes use opaque displays at fixed aspect ratios: BMW 3 Series twin dials, Ferrari 458 yellow tachometer, Tesla Model S, NIO ET7, Li Auto L9, BMW Motorrad Pure Ride, Honda-style analog/LCD, NIU-style negative LCD and Yadea-style positive LCD. Four original digital HUD themes remain available. Landscape is recommended; portrait preserves the instrument proportions.

These are independent interpretations, not pixel-exact OEM replicas. The EV road illustration is decorative and does not imply active driver assistance.

Host-controlled telltales: `leftIndicator`, `rightIndicator`, `highBeam`, `parkingBrake`, `engineWarning` (default `false`, supported by `copyWith`). Production speed digits turn red above `speedLimitKmh`; racing shift LEDs respond to RPM. Also `absWarning`, `seatbeltWarning`, `doorOpen`, `batteryWarning`, `charging`, `cruiseActive`, `tractionControlOff`, `driveMode`, `leanAngleDeg` and `powerPercent`. Manual `gearNumber` applies only to racing, fuel motorcycle and non-electric brand themes in D; EVs display PRND.

## Dependencies and validation

Version **0.6.0** requires **Dart 3.14+ / Flutter 3.50+** and `material_ui ^1.11.1`. The example is version `1.1.0+2`. Flutter SDK dependencies remain SDK-managed; `material_color_utilities 0.13.0` and `test_api 0.7.14` cannot be independently upgraded without an SDK update.

`AutoMotoDashboard` normalizes nonfinite telemetry, clamps levels to 0–100%, displays negative speed as a magnitude, and uses a 1,000–30,000 RPM scale. Raw host data remains unchanged. Call `normalized()` explicitly to inspect renderable values. Use `copyWith(clearGearNumber: true)` to clear a manual gear.

Run `flutter analyze` and `flutter test --coverage` in the package, then `flutter test` in `example/`. Android uses AGP 9.4.1, Gradle 9.9.2, built-in Kotlin 2.4.21 and NDK 30.0.16248370.

## Installation

```yaml
dependencies:
  auto_moto_dash:
    path: ../auto_moto_dash   # or git / pub
```

Weather assets under `assets/weather_bg/` are declared by the package; the host app does **not** need to register them again.

```dart
import 'package:auto_moto_dash/auto_moto_dash.dart';
```

## Quick start

```dart
AutoMotoDashboard(
  telemetry: const DashTelemetry(
    speedKmh: 120,
    rpm: 3500,
    batteryPercent: 99,
    rangeKm: 462,
    gear: Gear.drive,
  ),
  style: DashStyle.classic,
  vehicleType: VehicleType.car,
  lightSpeedThresholdKmh: 80,
  onGearSelected: (g) { /* prefer DriveSimulation.trySetGear */ },
)
```

Layer order (bottom → top): `backgroundColor` → weather → particles → cluster body. Effects like `roadTrack` keep the sky region transparent so weather shows through.

## `AutoMotoDashboard` parameters

| Param | Type | Default | Description |
|---|---|---|---|
| `telemetry` | `DashTelemetry` | required | Host telemetry (speed, RPM, battery, …) |
| `style` | `DashStyle` | `classic` | Visual theme (exclusive) |
| `weather` | `WeatherType?` | `null` | Weather; `null` disables |
| `particleEffect` | `ParticleEffect?` | `null` | Particles; `null` disables |
| `vehicleType` | `VehicleType` | `car` | Car or motorcycle outline |
| `lightSpeedThresholdKmh` | `double` | `80` | Speed (km/h) for full particle flow |
| `showGearSelector` | `bool` | `true` | Show P/R/N/D strip |
| `showVehicleOutline` | `bool` | `true` | Vehicle outline (digital themes) |
| `rainbowSpeed` | `bool` | `false` | Rainbow speed digits |
| `backgroundColor` | `Color` | `Colors.black` | Bottom fill color |
| `onGearSelected` | `ValueChanged<Gear>?` | — | Gear tap callback |
| `onGearPointerDown` | `VoidCallback?` | — | Gear pointer-down (gesture claim) |

## Telemetry `DashTelemetry`

Common fields: `speedKmh`, `rpm`, `maxRpm`, `redlineRpm`, `batteryPercent`, `fuelPercent`, `coolantTempC`, `rangeKm`, `odometerKm`, `tripKm`, `outsideTempC`, `speedLimitKmh` (car overspeed threshold, default 120; 0 disables), `gear`, `gearNumber` (manual 1–6; preferred by racing theme), `tirePressures` (bar). All fields support `copyWith`.

## Categories & themes (exclusive)

Car and motorcycle themes are separated via `DashCategory`. Use `DashStyleX.forCategory(DashCategory.car)` to list styles for a category.

| DashStyle | Category | Description |
|---|---|---|
| `techNeon` | car | Polygonal neon tech cluster |
| `hud` | car | Floating transparent HUD |
| `performance` | car | High-refresh smooth digital cluster |
| `pulseBreath` | car | Breathing / pulse light readout |
| `classic` | car | BMW-style dual analog gauges |
| `racing` | car | Ferrari 458 yellow central tachometer |
| `carEvTesla` | car | Tesla EV (SOC + range) |
| `carEvNio` | car | NIO EV (ring SOC) |
| `carEvLi` | car | Li Auto EV (wide HUD) |
| `motoFuelTft` | motorcycle | Fuel TFT cluster |
| `motoFuelHybrid` | motorcycle | Fuel analog tach + TFT |
| `motoEvNiu` | motorcycle | NIU electric (SOC) |
| `motoEvYadea` | motorcycle | Yadea electric (SOC) |

Use `style.isDigital` / `style.isAnalog` / `style.isElectric` and `style.label` for UI copy.

## Particle effects (exclusive; `null` disables)

| ParticleEffect | Description |
|---|---|
| `windRush` | Exterior wind rush (optional) |
| `blackHole` | Black-hole / wormhole transit |
| `starTunnel` | Star gate tunnel |
| `roadTrack` | Perspective road / track (sky transparent) |
| `ionStorm` | Colored ion sparks |

Flow speed tracks `speedKmh / lightSpeedThresholdKmh` with inertia (fast up, slow down). Use `particleEffect.label` for the Chinese display name.

## Weather

| WeatherType | Description |
|---|---|
| `sunny` | Sunny |
| `cloudy` | Cloudy |
| `overcast` | Overcast |
| `lightRain` / `mediumRain` / `heavyRain` | Light / medium / heavy rain |
| `thunderstorm` | Thunderstorm |
| `lightSnow` / `mediumSnow` / `heavySnow` | Light / medium / heavy snow |
| `sunnySnow` | Sunny snow |
| `fog` / `haze` / `dust` | Fog / haze / dust |

Weather is a vendored adaptation of [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg) (MIT). See [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt).

## Drive simulation `DriveSimulation`

Automatic-transmission helper for demos / mock telemetry, approximating real PRND rules.

| Gear | Behavior |
|---|---|
| **P** | Drivetrain locked; throttle does not add speed; blocked when moving too fast |
| **R** | Reverse with low top speed; blocked when moving too fast |
| **N** | Coast; throttle revs engine only |
| **D** | Normal forward drive |

```dart
final sim = DriveSimulation();

// each frame
sim.tick(dt, accelerating: accelHeld, braking: brakeHeld);

// shift may be rejected
if (!sim.trySetGear(Gear.drive)) { /* slow down first */ }

AutoMotoDashboard(
  telemetry: DashTelemetry(
    speedKmh: sim.speedKmh,
    rpm: sim.rpm,
    gear: sim.gear,
  ),
  onGearSelected: (g) => setState(() => sim.trySetGear(g)),
);
```

## Example app

```bash
cd example
flutter pub get
flutter run
```

| Action | Effect |
|---|---|
| Hold cluster | Accelerate; release to coast |
| `↑` / `↓` | Accel / brake |
| `←` / `→` or tap P/R/N/D | Shift (interlocks apply) |
| Control panel | Theme, weather, particles, vehicle, rainbow speed |

See [example/README.md](example/README.md) for more. Android release signing uses the committed test keystore under `example/jks/` (see that folder’s README).

## Public exports

Entry point: `package:auto_moto_dash/auto_moto_dash.dart`

- `AutoMotoDashboard`
- `DashStyle` / `DashCategory` / `DashTelemetry` / `TirePressures`
- `OverspeedShiftLights` / `OverspeedWarningLayer`
- `Gear` / `VehicleType`
- `WeatherType` / `ParticleEffect`
- `DriveSimulation`

## Changelog

See [CHANGELOG.md](CHANGELOG.md) / [CHANGELOG_zh.md](CHANGELOG_zh.md).

## License

This package is [MIT](LICENSE)-licensed. Third-party weather licenses: [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/).
