# auto_moto_dash

摩托车 / 汽车仪表盘 **Flutter 纯 Dart 包**：数字 HUD、科技风宝马 / 法拉利指针集群、天气背景与多种粒子动效。无平台 Channel，可直接嵌入任意 Flutter 应用。

[English](README.md)

## 特性

- 13 套互斥主题：4 套数字 HUD + 宝马双圆表 + 法拉利主转速表 + 特斯拉/蔚来/理想电车 + 4 款摩托车表盘（2 燃油 + 2 电动）
- 可选天气背景（晴雨雪雾霾等，基于内嵌 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)）
- 5 种互斥粒子动效，流速随车速惯性变化（加速跟得快、减速缓落）
- `DriveSimulation`：演示用 PRND 驾驶模型（档位互锁、滑行、倒车限速）
- 汽车主题统一法拉利风格超速警告（`speedLimitKmh` 触发换挡灯 + 红色脉冲）
- 全部主题显示总里程（ODO）与剩余续航（rangeKm）；电车主题显示电量

## 安装

```yaml
dependencies:
  auto_moto_dash:
    path: ../auto_moto_dash   # 或 git / pub
```

包已声明天气资源 `assets/weather_bg/`，宿主应用**无需**再手动注册这些资源。

```dart
import 'package:auto_moto_dash/auto_moto_dash.dart';
```

## 快速使用

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
  onGearSelected: (g) { /* 建议配合 DriveSimulation.trySetGear */ },
)
```

叠层顺序（自下而上）：`背景色` → `天气` → `粒子` → `仪表主体`。道路赛道等地平线以上区域保持透明，天气可完整透出。

## `AutoMotoDashboard` 参数

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `telemetry` | `DashTelemetry` | 必填 | 宿主遥测（车速、转速、电量等） |
| `style` | `DashStyle` | `hud` | 视觉主题（互斥） |
| `weather` | `WeatherType?` | `null` | 天气；`null` 关闭 |
| `particleEffect` | `ParticleEffect?` | `windRush` | 粒子；传 `null` 关闭 |
| `vehicleType` | `VehicleType` | `car` | 轿车 / 摩托轮廓 |
| `lightSpeedThresholdKmh` | `double` | `80` | 粒子「全速」参考车速 |
| `showGearSelector` | `bool` | `true` | 显示 P/R/N/D |
| `showVehicleOutline` | `bool` | `true` | 显示车辆轮廓（数字主题） |
| `rainbowSpeed` | `bool` | `false` | 速度彩虹着色 |
| `backgroundColor` | `Color` | `Colors.black` | 底层底色 |
| `onGearSelected` | `ValueChanged<Gear>?` | — | 点击档位回调 |
| `onGearPointerDown` | `VoidCallback?` | — | 档位按下（可拦截手势） |

## 遥测 `DashTelemetry`

常用字段：`speedKmh`、`rpm`、`maxRpm`、`redlineRpm`、`batteryPercent`、`fuelPercent`、`coolantTempC`、`rangeKm`、`odometerKm`、`tripKm`、`outsideTempC`、`speedLimitKmh`（汽车超速阈值，默认 120，0 关闭）、`gear`、`gearNumber`（手动 1–6，赛车主题优先）、`tirePressures`（四轮胎压 bar）。全部字段均可 `copyWith` 更新。

## 分类与主题（互斥）

汽车与摩托车主题通过 `DashCategory` 分离，使用 `DashStyleX.forCategory(DashCategory.car)` 获取对应列表。

| DashStyle | 分类 | 说明 |
|---|---|---|
| `techNeon` | 汽车 | 多边形霓虹科技感 |
| `hud` | 汽车 | 透明悬浮 HUD |
| `performance` | 汽车 | 高刷新流畅过渡 |
| `pulseBreath` | 汽车 | 脉冲呼吸光效 |
| `classic` | 汽车 | 宝马科技风双圆仪表 |
| `racing` | 汽车 | 法拉利赛博风主转速表 |
| `carEvTesla` | 汽车 | 特斯拉电车（电量 + 续航） |
| `carEvNio` | 汽车 | 蔚来电车（环形电量） |
| `carEvLi` | 汽车 | 理想电车（宽屏 HUD） |
| `motoFuelTft` | 摩托 | 燃油摩托全 TFT |
| `motoFuelHybrid` | 摩托 | 燃油摩托指针 + TFT |
| `motoEvNiu` | 摩托 | 小牛电动（电量） |
| `motoEvYadea` | 摩托 | 雅迪电动（电量） |

`style.isDigital` / `style.isAnalog` / `style.isElectric` / `style.label` 可直接用于 UI 文案。

## 粒子效果（互斥；可 `null` 关闭）

| ParticleEffect | 说明 |
|---|---|
| `windRush` | 车外风驰（默认） |
| `blackHole` | 黑洞穿越 |
| `starTunnel` | 星门隧道 |
| `roadTrack` | 道路赛道（透视路面 + 路缘 / 中线，天空透明） |
| `ionStorm` | 离子风暴 |

粒子流速由当前车速相对 `lightSpeedThresholdKmh` 驱动，并带惯性：目标升高时快速跟上，降低时缓慢衰减。可用 `particleEffect.label` 取中文名。

## 天气

| WeatherType | 说明 |
|---|---|
| `sunny` | 晴 |
| `cloudy` | 多云 |
| `overcast` | 阴 |
| `lightRain` / `mediumRain` / `heavyRain` | 小 / 中 / 大雨 |
| `thunderstorm` | 雷阵雨 |
| `lightSnow` / `mediumSnow` / `heavySnow` | 小 / 中 / 大雪 |
| `sunnySnow` | 下雪晴 |
| `fog` / `haze` / `dust` | 雾 / 霾 / 浮尘 |

天气背景基于 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)（MIT）内嵌改编。许可见 [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt)。

## 驾驶模拟 `DriveSimulation`

示例与联调可用的自动档模型，规则近似真实 PRND。

| 档位 | 行为 |
|---|---|
| **P** | 传动锁止，油门不加车速；车速过高时禁止挂入 |
| **R** | 倒车，低速上限；车速过高时禁止挂入 |
| **N** | 空档滑行，油门只拉转速 |
| **D** | 正常前进加速 |

```dart
final sim = DriveSimulation();

// 每帧
sim.tick(dt, accelerating: accelHeld, braking: brakeHeld);

// 换档可能被拒绝
if (!sim.trySetGear(Gear.drive)) { /* 请先减速 */ }

AutoMotoDashboard(
  telemetry: DashTelemetry(
    speedKmh: sim.speedKmh,
    rpm: sim.rpm,
    gear: sim.gear,
  ),
  onGearSelected: (g) => setState(() => sim.trySetGear(g)),
);
```

## 示例应用

```bash
cd example
flutter pub get
flutter run
```

| 操作 | 效果 |
|---|---|
| 按住仪表 | 加速；松手滑行减速 |
| `↑` / `↓` | 加速 / 制动 |
| `←` / `→` 或点 P/R/N/D | 换档（受互锁约束） |
| 控制面板 | 主题、天气、粒子、车型、彩虹速度等 |

更多说明见 [example/README.md](example/README.md)。Android release 签名使用仓库内测试证书 `example/jks/`（详见该目录 README）。

## 公开导出

入口：`package:auto_moto_dash/auto_moto_dash.dart`

- `AutoMotoDashboard`
- `DashStyle` / `DashCategory` / `DashTelemetry` / `TirePressures`
- `OverspeedShiftLights` / `OverspeedWarningLayer`
- `Gear` / `VehicleType`
- `WeatherType` / `ParticleEffect`
- `DriveSimulation`

## 修改日志

见 [CHANGELOG_zh.md](CHANGELOG_zh.md) / [CHANGELOG.md](CHANGELOG.md)。

## 许可

本包采用 [MIT](LICENSE)。第三方天气资源许可见 [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/)。
