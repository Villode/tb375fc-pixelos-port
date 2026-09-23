# PixelOS on Lenovo TB375FC（MT6897）

联想小新 Pad Pro 12.7（TB375FC / MT6897 / Dimensity 8300）上的 PixelOS / Android 16：
构建这套包所需的本地改动清单、出包与刷机要点，以及可直接刷入的镜像。

`lunch` 目标：`custom_TB375FC-bp4a-userdebug`。

## 状态

| 项 | 状态 |
|---|---|
| Android 16 镜像 | ✅ 编译通过、可刷入、日常可用 —— 下方 Release 里就是这一套 |
| 源码树 | ❌ `~/pixelos`（浅同步后约 518 G）因磁盘容量已删除。device 树的自有 commit 与改在上游项目里的本地改动**都没有以 patch 留存**。本仓库是重建依据，不是可直接 `repo sync` 的完整源。 |

## 已发布的二进制

Release [`pixelos-16-20260920`](https://github.com/Villode/tb375fc-pixelos-port/releases/tag/pixelos-16-20260920)
挂着 2026-09-20 生成、当天实测可刷入并日常使用的镜像，共 11 个附件：

- `super.img.part-00` / `-01` / `-02`（1.50 G / 1.50 G / 0.83 G）—— 同一份 `super.img` 的分卷，
  因为 GitHub 单个 Release 附件上限是 2 GiB。取回后：
  `cat super.img.part-00 super.img.part-01 super.img.part-02 > super.img`，
  期望 `sha256 = 8bbb445af978243c367248094a15bc3fe4eb89e847697d47ee715fa3ab3ecf5f`
- `boot.img`、`vendor_boot.img`、`init_boot.img`、`dtbo.img`、`vbmeta.img`、
  `vbmeta_system.img`、`vbmeta_vendor.img`
- `SHA256SUMS.txt`

`lk.img`、`DA_BR.bin`、`da.auth`、stock `userdata.img`、原厂 scatter **不在发布范围内**，
需从自己的 stock 固件包取，理由见下一节。

## 目录

- `docs/local-patches.md` —— 重建本包所需的本地改动清单，以及 `repo sync` / manifest 口径
- `docs/build-notes.md` —— 机器与内存、镜像与同步的坑、构建判定、一个可刷包由哪些镜像组成
- `scripts/run_mnothing.sh` —— 唯一留下来的当时脚本（`m nothing` 试探）。日常构建当时是手工
  `source build/envsetup.sh && lunch custom_TB375FC-bp4a-userdebug && m`，没有包装脚本

## 上游与归属：哪些是我们自己的

- ROM 平台：PixelOS（`github.com/PixelOS-AOSP`，AOSP + Google 服务），AOSP 基线 `android-16.0.0_r4`。
- device / vendor 树上游：`github.com/LosSantosPro/android_device_lenovo_TB375FC`（含 `-kernel`
  与 `android_vendor_lenovo_TB375FC`），**固定在 `lineage-23.2` 分支**（2026-09-23 核对：该仓库只有
  这一个分支，最后推送 2026-06-10，约 35 MB），通过 `.repo/local_manifests/pixelos_tb375fc.xml` 引入。
- 2026-09-23 另外核对（都返回 404，即仓库不存在）：`PixelOS-Devices/android_device_lenovo_TB375FC`、
  `LosSantosPro/platform_manifests`。也就是说 **TB375FC 不在 PixelOS 官方支持机型之列**，公开可得的
  本设备基线只有上面那一个仓库；本仓库的设备参数与构建步骤均以我们自己的实测为准。
- **我们自己的**部分：
  - device 树里的自有文件 —— `custom_TB375FC.mk`（`lunch` 目标名由此而来，与上游的
    `lineage_TB375FC.mk` 并存）、`custom.dependencies`、自制开机动画那组
    （`prebuilts/Android.bp`、`gen_bootanimation.sh`、`ba_build/`、`bootanimation-*.zip`）、
    以及 `TB373FU` ROW 变体的支持
  - `docs/local-patches.md` 列出的、改在上游项目里的本地补丁
  - 记录中出现过的自有 commit：`5a808ef`（Correct README specs and complete the build manifest）、
    `f2f15a`（Add TB373FU ROW variant）、`e0b697a`、`624dfe`、`aadb1c9`
    —— SHA 与标题来自会话记录，**内容已随树删除**，重建时只能按上面对照重做
- 内核：设备跑 prebuilt GKI 6.1（`prebuilts/Image.gz`，`6.1.173-android14-11`），487 个 vendor `.ko`
  对它加载，KMI 不是这里的阻塞项。厂商内核源码参考：
  `github.com/kquieter-debug/Android_kernel_source_TB375FC`（6.1.138，vermagic 与设备树的模块集对齐）。
- PixelOS 官方、LineageOS 官方、LosSantosPro 都不对本仓库和这套包负责；本仓库不与它们合并，
  也不等待它们更新。
- 同一台设备的主线内核（Linux 7.2 / MT6897）是另一条完全独立的线：
  `Villode/tb375fc-linux`、`Villode/tb375fc-linux-utils`，与本仓库没有共同历史。

## 不会（也不该）出现在这里的东西

- **Lenovo / MediaTek 固件侧文件**：`DA_BR.bin`、`da.auth`（下载代理与鉴权文件）、`lk.img`、
  stock `userdata.img`、原厂 scatter。这些在 MTK / Lenovo 授权范围内，不能公开再分发；
  刷机时需要的这几个文件必须由使用者从自己的 stock 固件目录取。
- **Google 专有组件**：构建包含 `vendor/pixel/gms`（8 个 GMS APK，约 1.4 G，需拉 Git LFS 对象，
  否则是 134 字节指针并报 "Improper zip alignment"）。也就是说 Release 里的 `super.img` 含 Google
  专有二进制 —— 这属于明知再分发 Google 专有软件，获取与分发风险由使用者自行承担。
- **任何密钥**：构建与刷机包用 AOSP test-keys；release key 与平台密钥不在本仓库，也不会出现。
- **凭据**：脚本已扫描，不含任何 token、密码或主机凭据。

## 一个可刷的包由哪些东西组成

AOSP 构建、必须与本代镜像配套：`boot.img`、`dtbo.img`、`init_boot.img`、`vendor_boot.img`、
`super.img`、`vbmeta.img`、`vbmeta_system.img`、`vbmeta_vendor.img`。

设备是 MTK，用 SP Flash Tool 按 scatter 刷（vbmeta×3、lk、boot、vendor_boot、init_boot、dtbo、
super、userdata），需要已解锁 bootloader；`lk` / `DA_BR` / `da.auth` / `userdata` 属固件侧，
见上一节。`super.img` 的实际大小要与**厂商 scatter** 里 super 分区的容量核对 —— 分区布局来自
scatter，不是 AOSP。细节见 `docs/build-notes.md`。

## Disclaimer

UNOFFICIAL，与 PixelOS、LineageOS、MediaTek、Lenovo 均无关联。仅供学习研究。
刷写有风险，可能使设备无法使用，后果自负。

## License

Apache-2.0（本仓库的脚本与文档）。AOSP / PixelOS / LineageOS / 上游 device 树各自保留其原有许可证。
