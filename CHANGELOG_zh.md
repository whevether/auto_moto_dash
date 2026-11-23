## 0.7.0

* **新增驾驶员第一人称 3D 座舱**，通过新入口 `package:auto_moto_dash/auto_moto_dash_3d.dart` 提供（已合并进主包，不再有独立子包）。原生平台（Android、iOS、macOS、Windows、Linux）使用 `flutter_scene ^0.24.3`（Flutter GPU / Impeller）渲染；Web 使用随包打包的 three.js r187（不依赖 CDN），通过 `dart:js_interop` 和 `HtmlElementView` 接入。两端绘制同一份与渲染器无关的 `SceneModel`（每帧只传 `SceneFrame` 增量），网格、ACES 色调映射和曝光一致。
* 3D 世界：道路按 `RoadProfile` 的曲率和坡度积分生成，含车道线、路缘、护栏、路灯、树木、楼宇和远山；提供城市、高速、乡道三种场景。
* `TrafficSimulation`：IDM 跟车、MOBIL 变道、刹车灯与转向灯、对向车流、出视野回收。宿主也可通过 `DashTelemetry.trafficVehicles` 传入车辆。
* 按主题的 `CockpitSpec` 座舱：Yoke、平底或圆形方向盘，仪表罩、窄条、贯穿联屏、中控显示，HUD、后视镜、雨刷和雨滴。摩托主题为骑手视角（车把、TFT、风挡、油箱），随 `leanAngleDeg` 倾斜。实时仪表画面以 30 Hz 截取并贴到座舱屏幕上。
* 驾驶员相机：加速抬头、刹车点头、车身侧倾、路面颠簸、过弯视线偏转。白天、黄昏、夜晚；近光和远光（聚光灯）；湿滑路面、雾和雨。
* 带道路视图的主题可用 3D 跟车视角（`AutoMotoDash3D.roadViewBuilder`）。
* 核心包（仍为纯 Dart）：新增 `DashViewMode`，`AutoMotoDashboard.viewMode` / `cockpitBuilder` / `roadViewBuilder`，`DashTelemetry.trajectory` / `trafficVehicles`，`VehicleTrajectory`、`TrafficVehicle`、`RoadProfile` / `RoadScenario`、`EgoVehicleModel`、`CockpitSpec`，以及 `DashStyle.cockpit` / `egoVehicle` / `egoPaint`。`DriveSimulation.tick(..., steer:)` 增加自行车模型横向运动和车道保持。导出 `GearSelector`。
* 示例：默认座舱视角；A/D 转向、Q/E 转向灯、H 远光，另有触屏转向按钮；面板可切换视角、道路场景、时间、3D 画质和车型。各平台已开启 Flutter GPU，`web/index.html` 把 `three` 映射到随包模块。
* 车辆和座舱为两端共用的程序化网格。暂未附带第三方 glb 或 HDR 文件；`VehicleLibrary.register` 预留了替换为授权车模的入口。

## 0.6.0

* **新增 26 套品牌风格主题**，由新增的 `ClusterSpec` / `ClusterSpecs` 数据驱动（布局、配色、量程；7 个可复用绘制模板）。燃油车：大众、丰田/雷克萨斯、奔驰 MBUX、奥迪、保时捷 911、福特/林肯、本田/讴歌、现代/起亚、日产、宝马 iDrive。电车：比亚迪、小鹏、小米 SU7、问界、极氪、保时捷 Taycan、Lucid、Rivian。摩托：Harley-Davidson、Ducati、Yamaha、Kawasaki、Triumph、KTM、Royal Enfield、Zero（电摩）。原有 13 套主题保持不变。
* 新增 `AutoMotoDashboard.brandBadgeBuilder`：包内不附带品牌素材（受商标保护），默认绘制文字字标；宿主可通过该插槽放入已获授权的 Logo。
* 新增 `DashUnits`（`units:` 参数）：km/h ↔ mph、km ↔ mi、bar/psi/kPa、°C/°F，对所有主题生效；遥测仍为公制。
* 新增遥测字段：`absWarning`、`seatbeltWarning`、`doorOpen`、`batteryWarning`、`charging`、`cruiseActive`、`tractionControlOff`、`driveMode`、`leanAngleDeg`、`powerPercent`；新增 `DashTelemetry.toString`；规范化时限制倾角和功率范围。
* 新增 `DashStyle.labelEn` 与 `AutoMotoDashboard.semanticsLabel` 用于本地化；新增 `DashStyleX.isBrand` / `spec`。
* 依赖：`material_ui ^1.11.1`，Dart `^3.14.0` / Flutter `>=3.50.0`；示例 Gradle 升至 9.9.2。`material_color_utilities 0.13.0` 与 `test_api 0.7.14` 由 Flutter SDK 固定。
* 新增覆盖全部主题极值遥测、单位、徽标插槽与语义标签的测试。

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
