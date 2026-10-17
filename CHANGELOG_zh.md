## 0.5.0

* 重绘 9 套量产风格仪表，默认使用经典双表，天气和粒子默认关闭。
* `material_ui` 更新为 `^1.7.0`，`flutter_lints ^6.0.0` 已为最新。SDK 下限更新为 Dart 3.13 / Flutter 3.47。`material_color_utilities 0.13.0` 与 `test_api 0.7.12` 由 Flutter SDK 固定，未使用依赖覆盖。
* Android 示例更新至 AGP 9.4.1、Gradle 9.8.1（官方下载并校验 SHA-256）、Kotlin 2.4.21、NDK r30（30.0.16248370）。启用内置 Kotlin，移除重复的全局 Android 配置及未使用的 Maven 仓库。
* 删除 7 个已无引用的旧仪表及绘制器文件，拆分量产仪表绘制与组件生命周期、输入逻辑。
* 在仪表入口规范化非有限、越界遥测；遥测和胎压支持值相等判断；新增 `copyWith(clearGearNumber: true)` 清除手动档位。
* 静止仪表和未触发警告时停止计时器；平滑值精确收敛；复用不可变粒子参数；修复颜色改变不重绘的问题。
* 释放图片解码器和临时文字布局，清理部分加载失败的图片，处理异步天气资源加载与销毁、屏幕旋转；雨雪星空按经过时间推进，不再依赖绘制次数。
* 修复倒车经空档切前进档绕过互锁、无效时间步长及低转速配置问题。示例累加行驶里程、失焦清除按键状态、驻车时休眠模拟循环。
* 增加异常传感器、静止帧调度、换档互锁、天气加载/旋转/销毁、粒子边界和示例键盘驾驶回归测试。
* 示例恢复 `cupertino_icons ^2.0.0`，补齐自适应 Material 控件使用的字体资源，消除构建中的缺字警告。
* 示例应用版本更新为 1.1.0+2。

## 0.4.0

* **汽车 / 摩托车分类**：新增 `DashCategory`；`DashStyle` 扩展 7 款主题（摩托 4 + 电车汽车 3），`DashStyleX.forCategory` / `defaultFor` 按分类筛选。
* **摩托车仪表盘**：`motoFuelTft`、`motoFuelHybrid`（燃油）、`motoEvNiu`、`motoEvYadea`（电动，含电量显示）。
* **电车汽车仪表盘**：`carEvTesla`、`carEvNio`、`carEvLi`，均显示电量与续航。
* **超速警告**：所有汽车主题接入法拉利风格换挡灯 + 红色脉冲，由 `DashTelemetry.speedLimitKmh` 触发。
* **里程 / 续航**：全部主题统一显示 `ODO` 与剩余续航 `rangeKm`。
* 新增 `OverspeedShiftLights`、`OverspeedWarningLayer`、`MileageRangeStrip` 等共享组件。
* 摩托车 / 电车仪表盘 UI 按参考图重绘；`ClusterSurface` 在开启天气时半透明，汽车与摩托车均可透出天气背景。

## 0.3.0

* 依赖 `material_ui`（^1.0.1），Material 相关导入由 `package:flutter/material.dart` 改为 `package:material_ui/material_ui.dart`。
* Flutter SDK 约束提升至 `>=3.44.0`。
* Analyzer：在包与示例中排除 `build/**` 及平台目录（`android` / `ios` / `web` / 桌面端）。
* 示例：移除未使用的 `cupertino_icons` 依赖。

## 0.2.0

* 粒子绘制：将活跃粒子数限制在列表长度内（`starTunnel` / `ionStorm` / `windRush`），修复高 `flowSpeed` 下的 `RangeError`。

# 0.1.0

* 首发：数字 HUD（`techNeon` / `hud` / `performance` / `pulseBreath`）与科技风模拟集群（`classic` 宝马双圆、`racing` 法拉利主转速表）。
* 天气层：内嵌改编 flutter_weather_bg（MIT），支持晴雨雪雾霾等 `WeatherType`。
* 粒子层：`windRush`、`blackHole`、`starTunnel`、`roadTrack`、`ionStorm`；流速随车速惯性变化；`roadTrack` 地平线以上透明以透出天气。
* `DriveSimulation`：PRND 互锁、空档只拉转速、倒车限速；示例支持按住加速、方向键与档位条。
* 示例控制面板：主题 / 天气 / 粒子 / 车型 / 彩虹速度；面板关闭手势修复。
* 文档：中英文 README / CHANGELOG 分册（`README.md` + `README_zh.md`，`CHANGELOG.md` + `CHANGELOG_zh.md`）。
* 示例 Android：release 使用仓库内测试证书（`example/jks/`）完整签名配置。
