# auto_moto_dash 示例 / Example

**中文：** 演示包内 `AutoMotoDashboard` 与 `DriveSimulation` 的交互用法。  
**English:** Interactive demo of `AutoMotoDashboard` and `DriveSimulation`.

## 运行 / Run

```bash
cd example
flutter run
```

## 操作 / Controls

- **按住仪表 / Hold cluster：** 加速；松手后滑行减速 / Accelerate; release to coast
- **↑ / ↓：** 加速 / 制动 / Accel / brake
- **← / →** 或点击 **P / R / N / D**：**换档**（行驶中过快时无法挂入 P / R） / **Shift** (P / R blocked when moving too fast)
- **右下角控制面板 / Control panel：** 主题、天气、粒子、车型、彩虹速度、档位等 / Theme, weather, particles, vehicle type, rainbow speed, gear, …

## 说明 / Notes

**中文：** 遥测由 `DriveSimulation` 每帧 `tick` 产生，再组装为 `DashTelemetry` 传入仪表。换档走 `trySetGear`，被拒绝时界面档位不会跳变。

**English:** Telemetry is produced each frame by `DriveSimulation.tick`, then mapped into `DashTelemetry`. Shifts use `trySetGear`; rejected shifts do not change the on-screen gear.
