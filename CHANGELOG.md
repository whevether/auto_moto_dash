## 0.7.0

* **First-person 3D cockpit** via the new library `package:auto_moto_dash/auto_moto_dash_3d.dart` (merged into the main package; no separate sub-package). Native platforms (Android, iOS, macOS, Windows, Linux) render with `flutter_scene ^0.24.3` (Flutter GPU / Impeller). The web renders with bundled three.js r187 (no CDN) through `dart:js_interop` and `HtmlElementView`. Both backends draw the same renderer-independent `SceneModel` (per-frame `SceneFrame` deltas) with the same meshes, ACES tone mapping and exposure.
* 3D world: road integrated from `RoadProfile` curvature and grade, lane markings, kerbs, guard rails, street lamps, trees, buildings and hills; city / highway / rural scenarios.
* `TrafficSimulation`: IDM car following, MOBIL lane changes, brake and turn signals, oncoming traffic and recycling. Hosts can supply `DashTelemetry.trafficVehicles` instead.
* Per-theme cockpits from `CockpitSpec` (yoke, flat-bottom or round wheel, binnacle / strip / wide-panel / centre-display clusters, HUD, mirrors, wipers and rain drops). Motorcycle themes use a rider view (handlebar, TFT, screen, tank) that leans with `leanAngleDeg`. The live cluster is captured at 30 Hz onto the cockpit screens.
* Driver camera: squat and dive, body roll, road bumps, looking into curves. Day, dusk and night; low and high beam (spot lights); wet roads, fog and rain.
* 3D chase view for the road area of road-view themes (`AutoMotoDash3D.roadViewBuilder`).
* Core package (still pure Dart): `DashViewMode`, `AutoMotoDashboard.viewMode` / `cockpitBuilder` / `roadViewBuilder`, `DashTelemetry.trajectory` / `trafficVehicles`, `VehicleTrajectory`, `TrafficVehicle`, `RoadProfile` / `RoadScenario`, `EgoVehicleModel`, `CockpitSpec` and `DashStyle.cockpit` / `egoVehicle` / `egoPaint`. `DriveSimulation.tick(..., steer:)` adds a bicycle-model lateral motion with lane-keep assist. `GearSelector` is exported.
* Example: cockpit view by default; A/D steer, Q/E indicators, H high beam, touch steering buttons; panel for view, road scenario, time of day, 3D quality and vehicle model. Flutter GPU is enabled on every platform and `web/index.html` maps `three` to the bundled module.
* Solid bodies: traffic treats every body (the ego included) as an obstacle by lateral overlap, pauses or abandons lane changes when someone is alongside and never overlaps another body. The ego stops at the bumper of slower traffic or stays beside a vehicle it steers into; `EgoContact` / `cockpitBuilder(onContact:)` lets the host adopt the corrected pose and speed.
* The driver display is placed by `fitClusterInWheel` so the straight steering wheel (rim, spokes, hub) never covers it; the binnacle is an open visor instead of a closed hood.
* More detailed procedural vehicles: wheel arches, sloping bonnet, raked glass, pillars, door seams, handles, mirrors, plates, high-mounted stop lamp, seats behind the glass, tyres with alloy rims; cab-and-box trucks, open pickup beds, five motorcycle styles with riders. `VehicleSignature` adds brand-neutral cues per theme (light bars, round or quad lamps, grille type, chrome, spoiler, roof rails) and variety in traffic.
* Vehicles and cockpits are procedural meshes shared by both backends. No third-party glb or HDR files are bundled yet; `VehicleLibrary.register` reserves a slot for licensed models.

## 0.6.0

* **26 brand-inspired themes** driven by the new `ClusterSpec` / `ClusterSpecs` (layout, colors, scale; 7 reusable templates). Combustion cars: Volkswagen, Toyota/Lexus, Mercedes-Benz MBUX, Audi, Porsche 911, Ford/Lincoln, Honda/Acura, Hyundai/Kia, Nissan, BMW iDrive. EV cars: BYD, XPeng, Xiaomi SU7, AITO, Zeekr, Porsche Taycan, Lucid, Rivian. Motorcycles: Harley-Davidson, Ducati, Yamaha, Kawasaki, Triumph, KTM, Royal Enfield, Zero (electric). The original 13 themes are unchanged.
* `AutoMotoDashboard.brandBadgeBuilder`: no brand artwork is bundled (trademarks); a text wordmark is drawn by default, and hosts can supply licensed logos through this slot.
* `DashUnits` (`units:`): km/h ↔ mph, km ↔ mi, bar/psi/kPa and °C/°F, applied to every theme. Telemetry stays metric.
* New telemetry: `absWarning`, `seatbeltWarning`, `doorOpen`, `batteryWarning`, `charging`, `cruiseActive`, `tractionControlOff`, `driveMode`, `leanAngleDeg`, `powerPercent`; `DashTelemetry.toString`; normalization clamps lean/power.
* `DashStyle.labelEn` and `AutoMotoDashboard.semanticsLabel` for localization; `DashStyleX.isBrand` / `spec`.
* Dependencies: `material_ui ^1.11.1`, Dart `^3.14.0` / Flutter `>=3.50.0`; Gradle 9.9.2 in the example. `material_color_utilities 0.13.0` and `test_api 0.7.14` remain pinned by the Flutter SDK.
* Tests for all themes with extreme telemetry, units, badge slot and semantics.

## 0.5.0

* Rebuild nine production-inspired instrument themes; default to the classic cluster with optional effects disabled.
* Upgrade `material_ui` to `^1.7.0`; retain latest `flutter_lints ^6.0.0`. Require Dart 3.13 / Flutter 3.47 for the new Material library. `material_color_utilities 0.13.0` and `test_api 0.7.12` remain pinned by the Flutter SDK; no dependency overrides.
* Upgrade the Android example to AGP 9.4.1, Gradle 9.8.1 (official download with SHA-256 verification), Kotlin 2.4.21 and NDK r30 (30.0.16248370). Enable built-in Kotlin and remove duplicate global Android configuration and unused Maven repositories.
* Remove seven unreachable legacy cluster/painter files; separate production instrument painting from widget lifecycle and input handling.
* Normalize nonfinite/out-of-range telemetry at the dashboard boundary; add value equality for telemetry and tire pressures, plus `copyWith(clearGearNumber: true)`.
* Stop instrument and warning tickers when static; settle smoothing exactly; reuse immutable particle geometry and repaint when accent colors change.
* Dispose image codecs and temporary text layouts; clean up partial image batches, guard asynchronous weather loading, resize weather systems, and advance rain/snow/stars by elapsed time instead of paint count.
* Fix reverse-to-forward interlocks through neutral, invalid simulation timing and low-RPM limits. Demo mileage now accumulates, focus loss clears held input, and the simulation sleeps when parked.
* Extend regression coverage for sensor failures, idle scheduling, gear interlocks, weather loading/resize/disposal, particle limits and demo keyboard driving.
* Restore `cupertino_icons ^2.0.0` in the example to supply the font used by adaptive Material controls.
* Example application version: 1.1.0+2.

## 0.4.0

* **Car / motorcycle categories**: new `DashCategory`; `DashStyle` adds 7 themes (4 motorcycle + 3 EV car); filter via `DashStyleX.forCategory` / `defaultFor`.
* **Motorcycle clusters**: `motoFuelTft`, `motoFuelHybrid` (fuel), `motoEvNiu`, `motoEvYadea` (electric with SOC).
* **EV car clusters**: `carEvTesla`, `carEvNio`, `carEvLi` with battery and range.
* **Overspeed warning**: Ferrari-style shift lights + red pulse on all car themes when `speedKmh` exceeds `DashTelemetry.speedLimitKmh`.
* **Mileage / range**: unified ODO + `rangeKm` on every theme.
* Shared widgets: `OverspeedShiftLights`, `OverspeedWarningLayer`, `MileageRangeStrip`.

## 0.3.0

* Depend on `material_ui` (^1.0.1) and switch Material imports from `package:flutter/material.dart` to `package:material_ui/material_ui.dart`.
* Raise Flutter SDK constraint to `>=3.44.0`.
* Analyzer: exclude `build/**` and platform folders (`android` / `ios` / `web` / desktop) in package and example.
* Example: drop unused `cupertino_icons` dependency.

## 0.2.0

* Particle painters: clamp active particle count to list length (`starTunnel` / `ionStorm` / `windRush`), fixing `RangeError` at high `flowSpeed`.

# 0.1.0

* Initial release: digital HUD styles (`techNeon` / `hud` / `performance` / `pulseBreath`) and tech analog clusters (`classic` BMW dual gauges, `racing` Ferrari-style tach).
* Weather layer: vendored flutter_weather_bg (MIT) with sunny / rain / snow / fog / haze `WeatherType`s.
* Particle layer: `windRush`, `blackHole`, `starTunnel`, `roadTrack`, `ionStorm`; inertial speed-linked flow; `roadTrack` keeps sky transparent over weather.
* `DriveSimulation`: PRND interlocks, neutral rev-only, reverse speed cap; example supports hold-to-accel, arrow keys, and gear strip.
* Example control panel: theme / weather / particles / vehicle / rainbow speed; panel dismiss gesture fixed.
* Docs: bilingual README / CHANGELOG (`README.md` + `README_zh.md`, `CHANGELOG.md` + `CHANGELOG_zh.md`).
* Example Android: release signing with committed test keystore under `example/jks/`.
