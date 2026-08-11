# auto_moto_dash_example

Interactive demo of `AutoMotoDashboard` and `DriveSimulation`.

[中文](README.md)

## Run

```bash
cd example
flutter pub get
flutter run
```

## Controls

| Action | Effect |
|--------|--------|
| Hold cluster | Accelerate; release to coast |
| ↑ / ↓ | Accel / brake |
| ← / → or tap P / R / N / D | Shift (P / R blocked when moving too fast) |
| Control panel (bottom-right) | Theme, weather, particles, vehicle type, rainbow speed, gear, … |

## Notes

Telemetry is produced each frame by `DriveSimulation.tick`, then mapped into `DashTelemetry`. Shifts use `trySetGear`; rejected shifts do not change the on-screen gear.

## Android signing

Release builds use the committed test keystore — see [jks/README.md](jks/README.md). Gradle loads `android/key.properties`.

## Dependencies

Local package via `path: ../`, matching the current repo sources.
