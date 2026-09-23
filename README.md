# TB375FC × PixelOS 移植：脚本与排障笔记

联想小新 Pad Pro 12.7（Lenovo TB375FC，MT6897 / Dimensity 8300）上跑 PixelOS 的移植记录。

本仓库**不含** device tree，也不含整棵 ROM 源码。它装的是移植过程中产出的构建 / 打包 /
校验脚本，以及"重建这套移植必须重做的全部本地改动"清单。

## 现在的状态

| 目标 | 状态 |
|---|---|
| PixelOS / Android 16（`custom_TB375FC-bp4a-userdebug`） | ✅ 编译通过、可刷入、日常可用 —— 这是已知可用的基线 |
| PixelOS / Android 17（`custom_TB375FC-cp2a-userdebug`） | ⚠️ 编译通过（约 239k actions、单次全量约 14 h），但刷入后**卡在一屏、无 adb**。二分结果：17 的 `super.img` + 其余全部沿用 16 的镜像同样卡住 → 故障在 17 的 system 侧，不在启动链。已逐项排除：内核 / dtb / cmdline（与可用的 16 逐字节相同）、ramdisk 模块列表 + fstab + 文件清单、EROFS 特性（同为 LZ4_0PADDING）、super 分区容量（与 scatter 相符）、SELinux 策略版本（17 策略 v30 ≤ 内核上限 35）、AVB（解锁状态，16-vbmeta 配 17-system 仍能挂载）。**未解决。** |
| 源码树本身 | ❌ `~/pixelos`（约 518 G）与 17 的产物目录在 2026-09-23 之前已从磁盘删除。device tree 的自有 commit、以及改在上游项目里的那些本地改动**没有以 patch 形式留存**，本仓库 docs 是按排障过程记录整理的重建依据。 |

## 目录

- `scripts/` —— 构建 / 打包 / 校验 / 监控脚本，见下节逐一说明
- `docs/local-patches.md` —— 全部自有补丁清单（重建必读，最重要的一份）
- `docs/build-notes.md` —— 机器配置、`repo sync` 口径、分阶段构建与耗时、踩过的坑

## 脚本清单

| 脚本 | 作用 |
|---|---|
| `run_full17.sh` | 分三阶段跑完整 17 构建：`m nothing`（只做 Soong/Kati 分析，最吃内存的一步单独隔离）→ `m otapackage` → `m superimage`；每阶段取真实退出码，结尾强制断言镜像确实报告 release 17 / sdk 37，否则一个文件都不发布 |
| `run_build17.sh` | 不分阶段的整棵 `m`（17） |
| `run_analyze17.sh` | 只跑 `m nothing`，用于把分析阶段的内存问题与编译阶段分开 |
| `run_otapackage.sh` | 只跑 `m otapackage`，独立日志，避免覆盖已成功的那次构建日志 |
| `run_superimage.sh` | 只跑 `m superimage` —— device 树没有置 `BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT`，所以 `droid`/`otapackage` 不会自动产出 `super.img`，必须显式构建 |
| `run_mnothing.sh` | 16 时代最初的 `m nothing` 试探 |
| `verify_publish17.sh` | 构建后的发布闸门：核对版本三重证据（release / sdk / fingerprint）、8 个必要镜像是否齐全、`super.img` 实测大小与厂商 scatter 里 super 分区容量的差值，全部通过才拷进发布目录，并写 `VERSION.txt` + 留一份 `system/build.prop` |
| `mon_build.sh` | 只读监控：按进程判断当前处于 Soong 分析 / Kati / ninja 哪个阶段。注释里记录了为什么不能只看 `BUILD_DONE`（见"坑"） |
| `reapply_fixes.sh` | 幂等重放三处修复（`--check` 只查不改），`repo sync` 会撤销其中两处，同步后重跑即可 |
| `do_build.sh` / `check_products.sh` / `check_vars.sh` / `sync_retry.sh` | 16 时代的构建入口与 product/变量核对、失败重试 |
| `make_boot6159.sh` / `make_boot_console.sh` / `rebuild_dlkm.sh` | 打包 `boot.img` / `dlkm` 的辅助脚本（主线内核那条线也在用，路径指向这棵 ROM 树） |

## 上游与归属：哪部分是我们自己的

- ROM 平台：PixelOS（`github.com/PixelOS-AOSP`，AOSP + Google 服务）。Android 17 侧的 AOSP 基线是 `android-17.0.0_r1`。
- 本设备的 device / vendor 树上游：`github.com/LosSantosPro/android_device_lenovo_TB375FC`。
  截至 2026-09-23，该仓库**只有 `lineage-23.2` 一个分支**（最后推送 2026-06-10，约 35 MB）；
  16 这一代是直接用它的树，17 这一代把 device 基线切到 `lineage-24.0` 口径 —— 而 24.0 侧
  上游并没有对应分支可查，重建时这一段需要重新核实。
- **我们自己的**是：`docs/local-patches.md` 里列出的全部条目（设备树里的自有文件与 commit、
  改在上游项目里的本地补丁）。PixelOS 官方、LineageOS 官方、LosSantosPro 都不对本仓库
  或这套移植负责；本仓库也不与它们合并、不等待它们更新。
- 内核：设备跑的是 prebuilt GKI 6.1（`prebuilts/Image.gz`，`6.1.173-android14-11`），
  487 个 vendor `.ko` 对它加载；Android 版本跳变不换内核，所以 KMI 不构成阻塞。
  厂商内核源码：`github.com/kquieter-debug/Android_kernel_source_TB375FC`（6.1.138）。
- 同一台设备的主线内核移植在另外的仓库：`Villode/tb375fc-linux`、`Villode/tb375fc-linux-utils`，
  与本仓库没有共同历史。

## 不会（也不该）出现在这里的东西

- **Lenovo / MediaTek 固件侧文件**：`DA_BR.bin`、`da.auth`、`lk.img`、stock `userdata.img`、
  原厂 scatter。这些在 MTK / Lenovo 授权范围内，不能公开再分发；`verify_publish17.sh` 只是
  从**你自己本地已有的** stock 刷机目录里把它们拷进发布目录。
- **Google 专有组件**：这套构建里 `vendor/pixel/gms` 含 8 个 GMS APK（约 1.4 G，需拉 Git LFS
  对象，否则是 134 字节指针并报 "Improper zip alignment"）。也就是说编出来的 `super.img`
  里含 Google 专有二进制 —— 公开分发镜像前请自行评估风险。
- **签名材料**：构建用 AOSP test-keys；release key、平台密钥不在本仓库。

## 坑（已经付过学费的）

- `m` 的输出被 `tee` 接管后，`$?` 拿到的是 `tee` 的退出码，不是构建的 —— 必须用 `PIPESTATUS`；
  `run_build17.sh` 更是无条件追加 `BUILD_DONE`，所以日志里有 `BUILD_DONE` 不代表成功。
  `mon_build.sh` 里那套"标记存在且无失败特征才算成功"的判断就是为此。
- 长构建必须放在 `tmux` 里跑：一次 2026-09-08 的全量被 SIGHUP 打死过。
- ccache 要关（`CCACHE_DISABLE=1 USE_CCACHE=0`）：AOSP 沙箱的只读限制与 ccache 冲突。
- `LC_ALL=C`，否则 soong 解析输出会因 locale 出问题。

## Disclaimer / UNOFFICIAL

非官方移植。仅供学习研究。刷写有风险，可能导致设备无法使用，后果自负。

## License

Apache-2.0（本仓库的脚本与文档）。上游 AOSP / PixelOS / LineageOS 各自保留其原有许可证。
