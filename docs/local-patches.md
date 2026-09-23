# 本地补丁清单

重建这套移植需要重做的**全部**改动。源码树删除时这些改动没有以 patch 形式留下，
本文是按排障过程记录整理的重建依据：每条给出位置、触发的报错、改法，以及
`repo sync` 会不会把它撤销。

`lunch` 目标：Android 16 = `custom_TB375FC-bp4a-userdebug`，Android 17 = `custom_TB375FC-cp2a-userdebug`。

---

## A. `reapply_fixes.sh` 已经自动化的 3 项

先跑 `bash scripts/reapply_fixes.sh`（幂等，`--check` 只查不改）。其中 1 和 3 会被 `repo sync` 撤销，
所以每次同步后都要重跑。

| # | 位置 | 症状 | 改法 | 被 sync 撤销 |
|---|---|---|---|---|
| 1 | `build/make/tools/releasetools/build_image.py` 的 `CopyInputDirectory` | `file_list.txt` 出现重复条目时 `os.link()` 抛 `FileExistsError`，镜像构建失败 | 幂等化：目标已存在且内容一致则跳过 | 是 |
| 2 | `vendor/pixel/gms` | 8 个 GMS APK（约 1.4 G）未拉 LFS 时是 134 字节指针，报 "Improper zip alignment" | 拉取 git-lfs 对象 | 否 |
| 3 | `prebuilts/abi-dumps/platform/36` | 4 个孤儿 ABI 转储使 `check-abi-dump-list` 失败 | 删除这 4 个（原件备份在 WSL `~/abidump-orphans-backup-20260922`，72 K） | 是 |

---

## B. 改在上游项目里的本地补丁（**会被 `repo sync` 覆盖**，重建时必须手工重做）

| 位置 | 症状 / 原因 | 改法 |
|---|---|---|
| `hardware/mediatek/**`（vendor bp）里的 prebuilt `libmnl` | 与 17 平台自带的 `libmnl` 重复定义 | 给 vendor 侧 prebuilt 改名，避免与平台模块同名冲突 |
| `hardware/mediatek` 某个 HAL 的 `Android.bp` | 17 把 usb 相关实现挪成了 `hardware/google/pixel` 里的 soong namespace，MTK HAL 引不到 | 补 `soong_namespace` import + 相应 `visibility` |
| 同一份 vendor bp | 5 个 HIDL 依赖在 17 已不存在，链接阶段报错 | 删除这 5 条死依赖 |
| `prebuilts/module_sdk/{WebApp,Profiling,Telephony,UprobeStats}` | 这 4 组 module-SDK prebuilts 与源码模块同时存在会重复安装 | 整体移开（WSL `~/sdk-prebuilt-backup`，1.9 M，仍在盘上），让源码模块接管 |
| `build/release/flag_values/bp4a/` | 相关 mainline 模块走 prebuilt 路径时行为不对 | 将 `RELEASE_TELECOM_MAINLINE_MODULE`、`RELEASE_PACKAGE_PROFILING_MODULE`、`RELEASE_ANOMALY_DETECTOR`、`RELEASE_UPROBESTATS_*` 置为 `true`（走源码） |
| device 树的 `device.mk` / product 定义 | 17 的 APEX system server 需要显式声明 jars | 补 21 条 `PRODUCT_APEX_SYSTEM_SERVER_JARS` |
| `vendor/custom`（bootanimation） | 与 AOSP 的 bootanimation 安装冲突 | 加条件判断，只装一个 |
| `packages/services/Telecomm` 的 `TelecomServiceResources` | APEX 可见性检查失败 | 给 `//apex_available:platform` |
| dexpreopt 相关 mk | vendor 侧镜像检查过严 | `DISABLE_DEXPREOPT_CHECK := true` |
| device 树 sepolicy：`/sys/class/typec` 的 `genfscon` | 17 平台已经把该路径标为 `sysfs_typec`，vendor 规则与之冲突 | 注释掉 vendor 那条规则 |
| device 树 `manifest.xml` | sepolicy 版本不匹配 | `<sepolicy><version>` 由 `202504` 抬到 `202604` |
| vendor mk 里 stock product 分区的 `NOTICE.xml.gz` 拷贝规则 | 17 构建自己会生成一份，重复安装直接把 `build_image` 崩掉 | 删掉 vendor mk 里那条拷贝规则 |

> 每条改动当时都带了解释性注释，注释本身也随树一起没了 —— 重做时请把"为什么"再写回代码里。

---

## C. device 树里属于我们自己的文件（未保留，需重写）

`device/lenovo/TB375FC/` 下这些是自有新增，不在上游仓库里：

- `custom_TB375FC.mk` —— 我们的 product 定义（`lunch` 目标名即由此而来），与上游的
  `lineage_TB375FC.mk` 并存
- `custom.dependencies` —— PixelOS 侧的依赖声明文件（LineageOS 的对应物是 `lineage.dependencies`，
  JSON 数组 `[{"repository","target_path"}]`；PixelOS 这份还能带 `"remote":"gitlab"`）
- `prebuilts/Android.bp`、`prebuilts/gen_bootanimation.sh`、`prebuilts/ba_build/`、
  `prebuilts/bootanimation-*.zip` —— 自制开机动画的生成与安装
- `proprietary-files.txt` —— blob 清单（属于设备树，不是 Google/MTK 二进制本体）

## D. 记录里出现过、但内容没留下的 device 树 commit

这些 SHA / 标题来自当时的会话记录，树删掉后**内容已不可取**，重建时只能按标题与上文对照重做：

| SHA | 标题 |
|---|---|
| `5a808ef` | TB375FC: Correct README specs and complete the build manifest |
| `e0b697a` | （未记录标题） |
| `f2f15a` | Add TB373FU ROW variant |
| `624dfe` | （未记录标题） |
| `aadb1c9` | （未记录标题） |

## E. manifest / 同步层（重建时必须重新确认，以下是当时的口径）

- 上游 ROM：`github.com/PixelOS-AOSP/manifest`，16 用 `sixteen-qpr2`。
  ⚠️ 截至 2026-09-23 核对该仓库分支列表：`eleven`、`eleven-plus`、`twelve`、`thirteen*`、
  `fourteen`、`fifteen`、`sixteen` —— **没有 `seventeen`**。当时 17 用的 `seventeen`
  口径是怎么来的（改名分支？别的仓库？tag？）需要重新核实，这是重建的第一个未知项。
- AOSP 基线走清华 TUNA 镜像（`insteadOf` 指到 `mirrors.tuna.tsinghua.edu.cn/git/AOSP/`），
  `refs/tags/android-17.0.0_r1`；GitHub 侧必须经代理。
- `repo init --depth=1`（浅同步，为了省下几百 G）。
- 本地清单：`.repo/local_manifests/pixelos_tb375fc.xml`、`TB375FC.xml`，把
  `LosSantosPro/android_device_lenovo_TB375FC` → `device/lenovo/TB375FC`、
  `LosSantosPro/android_device_lenovo_TB375FC-kernel` → `device/lenovo/TB375FC-kernel`、
  `LosSantosPro/android_vendor_lenovo_TB375FC` → `vendor/lenovo/TB375FC`。
- ⚠️ `LosSantosPro/android_device_lenovo_TB375FC` 今天只有 `lineage-23.2` 一个分支
  （最后推送 2026-06-10，约 35 MB）。17 那侧当时按 `lineage-24.0` 基线走，上游并无对应分支，
  这是第二个未知项。
- ⚠️ 仓库里那个 `sync-wait.sh`（等 GitHub 恢复后自动 `repo sync`）在 2026-09-20 被外层 shell
  吃掉变量后**内容损坏**（`$(seq 1 180)` 被当场展开、日志路径变成空重定向、
  `REPO_SYNC_RC=0` 被硬编码）。因此本仓库**没有收录它**，重建同步脚本时请从零写。
