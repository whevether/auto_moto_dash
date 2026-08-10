# auto_moto_dash

摩托车 / 汽车仪表盘 Flutter 纯 Dart 包：数字 HUD、科技风宝马/法拉利指针集群、天气背景与多种粒子动效。

## 安装

```yaml
dependencies:
  auto_moto_dash:
    path: ../auto_moto_dash
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
  onGearSelected: (g) { /* DriveSimulation.trySetGear */ },
)
```

## 主题（互斥）

| DashStyle | 说明 |
|---|---|
| `techNeon` | 多边形霓虹科技感 |
| `hud` | 透明悬浮 HUD |
| `performance` | 高刷新流畅过渡 |
| `pulseBreath` | 脉冲呼吸光效 |
| `classic` | 宝马科技风双圆仪表 |
| `racing` | 法拉利赛博风主转速表 |

## 粒子效果（互斥，可 `null` 关闭）

| ParticleEffect | 说明 |
|---|---|
| `windRush` | 车外风驰（默认） |
| `blackHole` | 黑洞穿越 |
| `starTunnel` | 星门隧道 |
| `cyberGrid` | 科技网格 |
| `ionStorm` | 离子风暴 |

## 天气

`WeatherType`：晴、多云、阴、小/中/大雨、雷阵雨、小/中/大雪、下雪晴、雾、霾、浮尘。

天气背景基于 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)（MIT）内嵌改编。许可见 [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt)。

## 演示

```bash
cd example
flutter run
```

- 按住仪表加速，松手减速；`↑↓` 加减速，`←→` 或点击 P/R/N/D 换档
- 控制面板可切换主题、粒子、天气
