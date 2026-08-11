# auto_moto_dash

A pure-Dart Flutter package for motorcycle / car dashboards: digital HUD, tech BMW / Ferrari-style analog clusters, weather backgrounds, and particle effects. No platform channels — drop into any Flutter app.

[中文文档](README_zh.md)

## Features

- 6 mutually exclusive themes: 4 digital HUDs + BMW dual gauges + Ferrari-style tach cluster
- Optional weather (sun / rain / snow / fog / haze, etc.), based on vendored [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)
- 5 mutually exclusive particle effects with inertial flow (fast ramp-up, slow coast-down)
- `DriveSimulation`: demo PRND model (shift interlocks, coasting, reverse speed cap)
- Optional vehicle outline (car / motorcycle), gear strip, rainbow speed digits

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
  style: DashStyle.hud,
  weather: WeatherType.heavyRain,
  particleEffect: ParticleEffect.windRush,
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
| `style` | `DashStyle` | `hud` | Visual theme (exclusive) |
| `weather` | `WeatherType?` | `null` | Weather; `null` disables |
| `particleEffect` | `ParticleEffect?` | `windRush` | Particles; `null` disables |
| `vehicleType` | `VehicleType` | `car` | Car or motorcycle outline |
| `lightSpeedThresholdKmh` | `double` | `80` | Speed (km/h) for full particle flow |
| `showGearSelector` | `bool` | `true` | Show P/R/N/D strip |
| `showVehicleOutline` | `bool` | `true` | Vehicle outline (digital themes) |
| `rainbowSpeed` | `bool` | `false` | Rainbow speed digits |
| `backgroundColor` | `Color` | `Colors.black` | Bottom fill color |
| `onGearSelected` | `ValueChanged<Gear>?` | — | Gear tap callback |
| `onGearPointerDown` | `VoidCallback?` | — | Gear pointer-down (gesture claim) |

## Telemetry `DashTelemetry`

Common fields: `speedKmh`, `rpm`, `maxRpm`, `redlineRpm`, `batteryPercent`, `fuelPercent`, `coolantTempC`, `rangeKm`, `odometerKm`, `tripKm`, `outsideTempC`, `gear`, `gearNumber` (manual 1–6; preferred by racing theme), `tirePressures` (bar). All fields support `copyWith`.

## Themes (exclusive)

| DashStyle | Description |
|---|---|
| `techNeon` | Polygonal neon tech cluster |
| `hud` | Floating transparent HUD |
| `performance` | High-refresh smooth digital cluster |
| `pulseBreath` | Breathing / pulse light readout |
| `classic` | BMW-style dual analog gauges |
| `racing` | Ferrari-style cyber tach cluster |

Use `style.isDigital` / `style.isAnalog` and `style.label` for UI copy.

## Particle effects (exclusive; `null` disables)

| ParticleEffect | Description |
|---|---|
| `windRush` | Exterior wind rush (default) |
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
- `DashStyle` / `DashTelemetry` / `TirePressures`
- `Gear` / `VehicleType`
- `WeatherType` / `ParticleEffect`
- `DriveSimulation`

## Changelog

See [CHANGELOG.md](CHANGELOG.md) / [CHANGELOG_zh.md](CHANGELOG_zh.md).

## License

This package is [MIT](LICENSE)-licensed. Third-party weather licenses: [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/).
