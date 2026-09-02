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
