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
