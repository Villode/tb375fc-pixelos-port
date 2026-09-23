# `device/` —— 我们自己的设备树内容

这三个文件是 TB375FC 上跑 PixelOS 所必需的**我们那一层**，放到
`device/lenovo/TB375FC/` 下即可（与上游 `LosSantosPro/android_device_lenovo_TB375FC`
的 `lineage-23.2` 树同目录共存，设备实现全部由上游提供，我们不重复实现）：

| 文件 | 作用 |
|---|---|
| `custom_TB375FC.mk` | PixelOS 产品定义：继承上游 `lineage_TB375FC.mk`，只把 `PRODUCT_NAME` 改成 `custom_TB375FC`，于是 `lunch custom_TB375FC-bp4a-userdebug` 可用 |
| `custom.dependencies` | PixelOS 侧依赖声明（vendor / `-kernel` / `hardware/mediatek` 三条，`org/repo` 写法） |
| `AndroidProducts.mk` | 覆盖上游同名文件：在 `lineage_` 目标之外追加 `custom_TB375FC-bp4a-{userdebug,eng,user}` |

写法照 PixelOS 官方设备树 `PixelOS-Devices/android_device_xiaomi_davinci@sixteen`
（`custom_davinci.mk` + `custom.dependencies` + `AndroidProducts.mk`）。

## 用之前必须做两件事

1. **确认 GMS 层的配置文件名。** `custom_TB375FC.mk` 里两行 `inherit-product-if-exists`
   （`vendor/custom/config/…`、`vendor/pixel/config/…`）故意用"不存在就跳过"，同步完先
   `ls vendor/custom/config vendor/pixel/config`，把 tablet wifi-only 配置的真实文件名填准。
2. **这层没有编译过。** 原始 `~/pixelos` 树已删除，这几个文件是按上游树 + PixelOS 公开惯例
   重写出来的，不是从旧树恢复的。先 `lunch custom_TB375FC-bp4a-userdebug && m nothing` 过解析阶段。

## 仍然缺的（随旧树删除，尚未重做）

- 自制开机动画那组：`prebuilts/{Android.bp, gen_bootanimation.sh, ba_build/, bootanimation-*.zip}`
  以及 `vendor/custom` 里的安装条件判断。已核实上游 `prebuilts/` 不跟踪这些文件，所以是我们自己的。
- 12 处改在上游项目里的本地补丁：见 [`../docs/local-patches.md`](../docs/local-patches.md) 第 2 节，
  每次 `repo sync` 后都要重做。

## 与上游的关系

`LosSantosPro/android_device_lenovo_TB375FC` 的 6 个 commit（作者 Jamie Macgregor，2026-06）是**上游**，
不是我们的改动；本目录里的东西才是。设备型号、blob 清单、分区布局、sepolicy 主体、prebuilt 内核与
模块都由上游树提供。
