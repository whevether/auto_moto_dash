# auto_moto_dash

**中文：** 摩托车 / 汽车仪表盘 **Flutter 纯 Dart 包**：数字 HUD、科技风宝马 / 法拉利指针集群、天气背景与多种粒子动效。无平台 Channel，可直接嵌入任意 Flutter 应用。

**English:** A pure-Dart Flutter package for motorcycle / car dashboards: digital HUD, tech BMW / Ferrari-style analog clusters, weather backgrounds, and particle effects. No platform channels — drop into any Flutter app.

## 特性 / Features

- **中文：** 6 套互斥主题：4 套数字 HUD + 宝马双圆表 + 法拉利主转速表  
  **English:** 6 mutually exclusive themes: 4 digital HUDs + BMW dual gauges + Ferrari-style tach cluster
- **中文：** 可选天气背景（晴雨雪雾霾等，基于内嵌 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)）  
  **English:** Optional weather (sun / rain / snow / fog / haze, etc.), based on vendored [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)
- **中文：** 5 种互斥粒子动效，流速随车速惯性变化（加速跟得快、减速缓落）  
  **English:** 5 mutually exclusive particle effects with inertial flow (fast ramp-up, slow coast-down)
- **中文：** `DriveSimulation`：演示用 PRND 驾驶模型（档位互锁、滑行、倒车限速）  
  **English:** `DriveSimulation`: demo PRND model (shift interlocks, coasting, reverse speed cap)
- **中文：** 车型轮廓（轿车 / 摩托）、档位条、彩虹速度数字等可开关选项  
  **English:** Optional vehicle outline (car / motorcycle), gear strip, rainbow speed digits

## 安装 / Installation

```yaml
dependencies:
  auto_moto_dash:
    path: ../auto_moto_dash   # or git / pub
```

**中文：** 包已声明天气资源 `assets/weather_bg/`，宿主应用**无需**再手动注册这些资源。  
**English:** Weather assets under `assets/weather_bg/` are declared by the package; the host app does **not** need to register them again.

```dart
import 'package:auto_moto_dash/auto_moto_dash.dart';
```

## 快速使用 / Quick start

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

**中文：** 叠层顺序（自下而上）：`背景色` → `天气` → `粒子` → `仪表主体`。道路赛道等地平线以上区域保持透明，天气可完整透出。  
**English:** Layer order (bottom → top): `backgroundColor` → weather → particles → cluster body. Effects like `roadTrack` keep the sky region transparent so weather shows through.

## `AutoMotoDashboard` 参数 / Parameters

| 参数 / Param | 类型 / Type | 默认 / Default | 说明 / Description |
|---|---|---|---|
| `telemetry` | `DashTelemetry` | required | 宿主遥测 / Host telemetry (speed, RPM, battery, …) |
| `style` | `DashStyle` | `hud` | 视觉主题（互斥） / Visual theme (exclusive) |
| `weather` | `WeatherType?` | `null` | 天气；`null` 关闭 / Weather; `null` disables |
| `particleEffect` | `ParticleEffect?` | `windRush` | 粒子；传 `null` 关闭 / Particles; `null` disables |
| `vehicleType` | `VehicleType` | `car` | 轿车 / 摩托轮廓 / Car or motorcycle outline |
| `lightSpeedThresholdKmh` | `double` | `80` | 粒子「全速」参考车速 / Speed (km/h) for full particle flow |
| `showGearSelector` | `bool` | `true` | 显示 P/R/N/D / Show P/R/N/D strip |
| `showVehicleOutline` | `bool` | `true` | 显示车辆轮廓（数字主题） / Vehicle outline (digital themes) |
| `rainbowSpeed` | `bool` | `false` | 速度彩虹着色 / Rainbow speed digits |
| `backgroundColor` | `Color` | `Colors.black` | 底层底色 / Bottom fill color |
| `onGearSelected` | `ValueChanged<Gear>?` | — | 点击档位回调 / Gear tap callback |
| `onGearPointerDown` | `VoidCallback?` | — | 档位按下（可拦截手势） / Gear pointer-down (gesture claim) |

## 遥测 / Telemetry `DashTelemetry`

**中文：** 常用字段：`speedKmh`、`rpm`、`maxRpm`、`redlineRpm`、`batteryPercent`、`fuelPercent`、`coolantTempC`、`rangeKm`、`odometerKm`、`tripKm`、`outsideTempC`、`gear`、`gearNumber`（手动 1–6，赛车主题优先）、`tirePressures`（四轮胎压 bar）。全部字段均可 `copyWith` 更新。

**English:** Common fields: `speedKmh`, `rpm`, `maxRpm`, `redlineRpm`, `batteryPercent`, `fuelPercent`, `coolantTempC`, `rangeKm`, `odometerKm`, `tripKm`, `outsideTempC`, `gear`, `gearNumber` (manual 1–6; preferred by racing theme), `tirePressures` (bar). All fields support `copyWith`.

## 主题 / Themes（互斥 / exclusive）

| DashStyle | 中文 | English |
|---|---|---|
| `techNeon` | 多边形霓虹科技感 | Polygonal neon tech cluster |
| `hud` | 透明悬浮 HUD | Floating transparent HUD |
| `performance` | 高刷新流畅过渡 | High-refresh smooth digital cluster |
| `pulseBreath` | 脉冲呼吸光效 | Breathing / pulse light readout |
| `classic` | 宝马科技风双圆仪表 | BMW-style dual analog gauges |
| `racing` | 法拉利赛博风主转速表 | Ferrari-style cyber tach cluster |

**中文：** `style.isDigital` / `style.isAnalog`、`style.label` 可直接用于 UI 文案。  
**English:** Use `style.isDigital` / `style.isAnalog` and `style.label` for UI copy.

## 粒子效果 / Particle effects（互斥；可 `null` 关闭 / exclusive; `null` disables）

| ParticleEffect | 中文 | English |
|---|---|---|
| `windRush` | 车外风驰（默认） | Exterior wind rush (default) |
| `blackHole` | 黑洞穿越 | Black-hole / wormhole transit |
| `starTunnel` | 星门隧道 | Star gate tunnel |
| `roadTrack` | 道路赛道（透视路面 + 路缘 / 中线，天空透明） | Perspective road / track (sky transparent) |
| `ionStorm` | 离子风暴 | Colored ion sparks |

**中文：** 粒子流速由当前车速相对 `lightSpeedThresholdKmh` 驱动，并带惯性：目标升高时快速跟上，降低时缓慢衰减。可用 `particleEffect.label` 取中文名。  
**English:** Flow speed tracks `speedKmh / lightSpeedThresholdKmh` with inertia (fast up, slow down). Use `particleEffect.label` for the Chinese display name.

## 天气 / Weather

| WeatherType | 中文 | English |
|---|---|---|
| `sunny` | 晴 | Sunny |
| `cloudy` | 多云 | Cloudy |
| `overcast` | 阴 | Overcast |
| `lightRain` / `mediumRain` / `heavyRain` | 小 / 中 / 大雨 | Light / medium / heavy rain |
| `thunderstorm` | 雷阵雨 | Thunderstorm |
| `lightSnow` / `mediumSnow` / `heavySnow` | 小 / 中 / 大雪 | Light / medium / heavy snow |
| `sunnySnow` | 下雪晴 | Sunny snow |
| `fog` / `haze` / `dust` | 雾 / 霾 / 浮尘 | Fog / haze / dust |

**中文：** 天气背景基于 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)（MIT）内嵌改编。许可见 [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt)。  
**English:** Weather is a vendored adaptation of [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg) (MIT). See [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt).

## 驾驶模拟 / Drive simulation `DriveSimulation`

**中文：** 示例与联调可用的自动档模型，规则近似真实 PRND。  
**English:** Automatic-transmission helper for demos / mock telemetry, approximating real PRND rules.

| 档位 / Gear | 中文 | English |
|---|---|---|
| **P** | 传动锁止，油门不加车速；车速过高时禁止挂入 | Drivetrain locked; throttle does not add speed; blocked when moving too fast |
| **R** | 倒车，低速上限；车速过高时禁止挂入 | Reverse with low top speed; blocked when moving too fast |
| **N** | 空档滑行，油门只拉转速 | Coast; throttle revs engine only |
| **D** | 正常前进加速 | Normal forward drive |

```dart
final sim = DriveSimulation();

// each frame / 每帧
sim.tick(dt, accelerating: accelHeld, braking: brakeHeld);

// shift may be rejected / 换档可能被拒绝
if (!sim.trySetGear(Gear.drive)) { /* slow down first / 请先减速 */ }

AutoMotoDashboard(
  telemetry: DashTelemetry(
    speedKmh: sim.speedKmh,
    rpm: sim.rpm,
    gear: sim.gear,
  ),
  onGearSelected: (g) => setState(() => sim.trySetGear(g)),
);
```

## 演示应用 / Example app

```bash
cd example
flutter run
```

| 操作 / Action | 效果 / Effect |
|---|---|
| 按住仪表 / Hold cluster | 加速；松手滑行减速 / Accelerate; release to coast |
| `↑` / `↓` | 加速 / 制动 / Accel / brake |
| `←` / `→` 或点 P/R/N/D / or tap P/R/N/D | 换档（受互锁约束） / Shift (interlocks apply) |
| 控制面板 / Control panel | 主题、天气、粒子、车型、彩虹速度等 / Theme, weather, particles, vehicle, rainbow speed |

**中文：** 更多说明见 [example/README.md](example/README.md)。  
**English:** See [example/README.md](example/README.md) for more.

## 公开导出 / Public exports

**中文：** 入口 `package:auto_moto_dash/auto_moto_dash.dart`  
**English:** Entry point: `package:auto_moto_dash/auto_moto_dash.dart`

- `AutoMotoDashboard`
- `DashStyle` / `DashTelemetry` / `TirePressures`
- `Gear` / `VehicleType`
- `WeatherType` / `ParticleEffect`
- `DriveSimulation`

## 许可 / License

**中文：** 本包采用 [MIT](LICENSE)。第三方天气资源许可见 [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/)。  
**English:** This package is [MIT](LICENSE)-licensed. Third-party weather licenses: [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/).
