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
