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
