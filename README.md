# auto_moto_dash

摩托车 / 汽车仪表盘 Flutter 纯 Dart 包：数字 HUD 主题、传统/赛车指针集群，以及可选天气背景动画。

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
  vehicleType: VehicleType.car,
  lightSpeedThresholdKmh: 80,
)
```

## 主题（互斥）

| DashStyle | 说明 |
|---|---|
| `techNeon` | 多边形霓虹科技感 |
| `hud` | 透明悬浮 HUD |
| `performance` | 高刷新流畅过渡 |
| `pulseBreath` | 脉冲呼吸光效 |
| `classic` | 传统双圆汽车仪表 |
| `racing` | 赛车红区 / 换挡灯 |

## 天气

`WeatherType`：晴、多云、阴、小/中/大雨、雷阵雨、小/中/大雪、下雪晴、雾、霾、浮尘。传 `null` 关闭天气层。

天气背景基于 [flutter_weather_bg](https://github.com/xiaweizi/flutter_weather_bg)（MIT）源码与资源内嵌改编，不额外引入 pub 依赖。许可见 [THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt](THIRD_PARTY_LICENSES/flutter_weather_bg_MIT.txt)。

## 演示

```bash
cd example
flutter run
```

- 按住仪表区域加速，松手减速
- 键盘 `↑`/`↓` 加减速，`←`/`→` 切换档位
- 右下角按钮打开控制面板（主题 / 天气 / 档位等）
