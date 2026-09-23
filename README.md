# TB375FC × PixelOS 移植记录（Android 16）

联想小新 Pad Pro 12.7（Lenovo TB375FC，MT6897 / Dimensity 8300）上跑 PixelOS 的移植记录。

维护口径只有一条：**PixelOS / Android 16**（manifest `sixteen-qpr2`，
`lunch custom_TB375FC-bp4a-userdebug`）。

## 状态

| 目标 | 状态 |
|---|---|
| Android 16（`custom_TB375FC-bp4a-userdebug`） | ✅ 编译通过、可刷入、日常可用 |
| Android 17（`custom_TB375FC-cp2a-userdebug`） | ⛔ 曾完整编译通过并刷入，但**卡在一屏、无 adb**；二分证明故障在 17 的 system 侧（17 的 `super.img` + 其余全部沿用 16 的镜像同样卡住），内核 / dtb / cmdline / ramdisk 模块表 / fstab / EROFS 特性 / super 容量 / SELinux 策略版本 / AVB 状态已逐项排除。**已放弃，不再跟进。** |
| 源码树 | ❌ `~/pixelos`（浅同步后约 518 G）因磁盘容量已被删除。device 树的自有 commit 与改在上游项目里的本地改动**都没有以 patch 留存**。本仓库是重建依据，不是可直接 `repo sync` 的完整源。 |

## 目录

- `docs/local-patches.md` —— 移植所需的本地改动清单；17 专属的部分放在文末附录（留档，已放弃）
- `docs/build-notes.md` —— 机器与内存、`repo sync` 口径与镜像、构建判定的坑、一个可刷包由哪些镜像组成
- `scripts/run_mnothing.sh` —— 唯一留下来的当时脚本（16 的 `m nothing` 试探）。日常构建当时是手工
  `source build/envsetup.sh && lunch custom_TB375FC-bp4a-userdebug && m`，没有包装脚本

## 上游与归属：哪些是我们自己的

- ROM 平台：PixelOS（`github.com/PixelOS-AOSP`，AOSP + Google 服务），AOSP 基线 `android-16.0.0_r4`。
- device / vendor 树上游：`github.com/LosSantosPro/android_device_lenovo_TB375FC`（含 `-kernel`
  与 `android_vendor_lenovo_TB375FC`），**固定在 `lineage-23.2` 分支**（今天核对：该仓库只有这一个
  分支，最后推送 2026-06-10，约 35 MB），通过 `.repo/local_manifests/pixelos_tb375fc.xml` 引入。
- **我们自己的**部分：
  - device 树里的自有文件 —— `custom_TB375FC.mk`（`lunch` 目标名由此而来，与上游的
    `lineage_TB375FC.mk` 并存）、`custom.dependencies`、自制开机动画那组
    （`prebuilts/Android.bp`、`gen_bootanimation.sh`、`ba_build/`、`bootanimation-*.zip`）、
    以及 `TB373FU` ROW 变体的支持
  - `docs/local-patches.md` 正文列出的、16 也需要的那些补丁
  - 记录中出现过的自有 commit：`5a808ef`（Correct README specs and complete the build manifest）、
    `f2f15a`（Add TB373FU ROW variant）、`e0b697a`、`624dfe`、`aadb1c9`
    —— SHA 与标题来自会话记录，**内容已随树删除**，重建时只能按上面对照重做
- 内核：设备跑 prebuilt GKI 6.1（`prebuilts/Image.gz`，`6.1.173-android14-11`），487 个 vendor `.ko`
  对它加载；Android 版本变化不换内核，KMI 不构成阻塞。厂商内核源码参考：
  `github.com/kquieter-debug/Android_kernel_source_TB375FC`（6.1.138，vermagic 与设备树的模块集对齐）。
- PixelOS 官方、LineageOS 官方、LosSantosPro 都不对本仓库和这套移植负责；本仓库不与它们合并，
  也不等待它们更新。
- 同一台设备的主线内核（Linux 7.2 / MT6897）移植是完全独立的一条线：
  `Villode/tb375fc-linux`、`Villode/tb375fc-linux-utils`，与本仓库没有共同历史。

## 不会（也不该）出现在这里的东西

- **Lenovo / MediaTek 固件侧文件**：`DA_BR.bin`、`da.auth`（下载代理与鉴权文件）、`lk.img`、
  stock `userdata.img`、原厂 scatter。这些在 MTK / Lenovo 授权范围内，不能公开再分发；
  刷机包里的这些文件必须由使用者从自己的 stock 固件目录取。
- **Google 专有组件**：构建包含 `vendor/pixel/gms`（8 个 GMS APK，约 1.4 G，需拉 Git LFS 对象，
  否则是 134 字节指针并报 "Improper zip alignment"）。也就是说编出来的 `super.img` 内含 Google
  专有二进制，公开分发镜像属于再分发 Google 专有软件，风险自担。
- **任何密钥**：构建与刷机包用 AOSP test-keys；release key 与平台密钥不在本仓库，也不会出现。
- **本机的绝对路径与主机名**：脚本里的 `/home/Villode/pixelos` 等路径是当时的实际路径，
  重建时按需改；文档不隐藏任何凭据（脚本已扫描，无凭据）。

## 刷机包构成（16 已验证可用）

AOSP 构建、必须与本代镜像配套：`boot.img`、`dtbo.img`、`init_boot.img`、`vendor_boot.img`、
`super.img`、`vbmeta.img`、`vbmeta_system.img`、`vbmeta_vendor.img`。

设备是 MTK，用 SP Flash Tool 按 scatter 刷（vbmeta×3、lk、boot、vendor_boot、init_boot、dtbo、
super、userdata）；`lk` / `DA_BR` / `da.auth` / `userdata` 属固件侧，见上一节。

## Disclaimer

UNOFFICIAL。仅供学习研究。刷写有风险，可能导致设备无法使用，后果自负。

## License

Apache-2.0（本仓库的脚本与文档）。AOSP / PixelOS / LineageOS / 上游 device 树各自保留其原有许可证。
