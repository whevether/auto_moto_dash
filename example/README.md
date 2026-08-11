# auto_moto_dash_example

演示 `auto_moto_dash` 仪表盘与 `DriveSimulation` 交互用法的示例应用。

[English](README_en.md)

## 运行

```bash
cd example
flutter pub get
flutter run
```

## 操作

| 操作 | 效果 |
|------|------|
| 按住仪表 | 加速；松手后滑行减速 |
| ↑ / ↓ | 加速 / 制动 |
| ← / → 或点击 P / R / N / D | 换档（行驶中过快时无法挂入 P / R） |
| 右下角控制面板 | 主题、天气、粒子、车型、彩虹速度、档位等 |

## 说明

遥测由 `DriveSimulation` 每帧 `tick` 产生，再组装为 `DashTelemetry` 传入仪表。换档走 `trySetGear`，被拒绝时界面档位不会跳变。

## Android 签名

示例 release 打包使用仓库内测试证书，见 [jks/README.md](jks/README.md)。Gradle 读取 `android/key.properties`。

## 依赖

通过 `path: ../` 引用本地 package，与仓库当前代码一致。
