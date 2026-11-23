# 自定义车辆模型 / Custom vehicle models

把模型文件直接放进本目录，重新运行 / 重新构建即可，不用改代码。
Drop model files here and rebuild; no code changes needed.

支持格式 / Formats: `.glb`（推荐）、`.gltf`、`.obj`、`.stl`。
FBX / BLEND / DAE 请先用 Blender 导出为 glb（File → Export → glTF 2.0, 格式选 glb）。
Sketchfab 上直接点 Download → "glTF Binary (.glb)" 即可。

## 文件名决定用途 / The file name decides the use

| 文件名示例 | 用途 |
|---|---|
| `ego-sedan.glb` | 自车：轿车 |
| `ego-fastback.glb` | 自车：溜背轿车 |
| `ego-coupe.glb` / `ego-sportcoupe.glb` | 自车：运动轿跑 |
| `ego-suv.glb` | 自车：SUV |
| `ego-wagon.glb` / `ego-shootingbrake.glb` | 自车：猎装车 |
| `ego-pickup.glb` | 自车：皮卡 |
| `sedan-xxx.glb` / `car-xxx.glb` | 车流：轿车 |
| `suv-xxx.glb` | 车流：SUV |
| `pickup-xxx.glb` | 车流：皮卡 |
| `van-xxx.glb` | 车流：面包车 / MPV |
| `truck-xxx.glb` / `lorry-xxx.glb` | 车流：货车 |
| `bus-xxx.glb` | 车流：客车 |
| `motorcycle-xxx.glb` | 车流：摩托车 |

同一类可以放多个（`sedan-golf.glb`、`sedan-camry.glb`…），车流里会混着出现。
本目录里的模型会替换同类的内置模型。

## 内饰 / Interior

自车模型如果带内饰（部件名里有 seat / dashboard / interior 等），并且方向盘是单独的部件
（名字含 `SteeringWheel`），驾驶视角就会直接坐进这台车里：用它自己的座椅、仪表台、
A 柱和方向盘，方向盘跟着转向转动，实时仪表显示在方向盘后面。
没有内饰的模型继续用内置的主题座舱。

## 可选标记 / Optional tokens

- 车头朝向自动判断（长轴 + 前大灯 / 尾灯 / 方向盘位置）。判断错时在文件名里加
  `rot90`、`rot180` 或 `rot270`，例如 `sedan-golf-rot180.glb`。
- `zup`：Z 轴朝上的模型（部分 OBJ / CAD 导出），例如 `truck-zup.obj`。
- 尺寸按车型长度等比缩放，保持模型真实比例。

## 性能 / Performance

车流会同时出现二三十辆车。单个车流模型建议 5 万面以内（自车可以到 30 万面），
太大的模型在 Blender 里用 Decimate 修改器减面。超过 40 万面会在控制台打印提示。

## 授权 / Licence

请确认模型授权允许你的用途（CC-BY 需要在应用里署名作者）。
