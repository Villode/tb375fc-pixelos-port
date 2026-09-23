# 本地改动清单

重建这套移植需要重做的改动。**本文只写记录里确定的事实**：位置 + 做了什么。

关于来源与限度，先说清三件事：

1. 清单来自 2026-09-20 至 09-22 的排障记录（当时正在做 16→17 的移植）。**记录里没有逐条标注**
   某项是 Android 16 就需要、还是只有 17 才需要。
2. 记录里也没有保留每条的**报错原文**和**为什么这样改**的理由 —— 当时这些是写在源码注释里的，
   注释随源码树一起删了。所以下表凡涉及"原因"一栏，没有记录的就标 `未记录`，不做推测。
3. 这些改动**没有以 patch / diff 形式留存**，本表是重建线索，不是补丁。

## 1. device 树里属于我们自己的文件（内容已丢失，需重写）

位置：`device/lenovo/TB375FC/`（上游 = `LosSantosPro/android_device_lenovo_TB375FC`，
分支 `lineage-23.2`，这些文件不在上游仓库里）。

| 文件 | 作用 |
|---|---|
| `custom_TB375FC.mk` | 我们的 product 定义；`lunch custom_TB375FC-bp4a-userdebug` 的目标名来自它。与上游的 `lineage_TB375FC.mk` 并存 |
| `custom.dependencies` | PixelOS 侧的依赖声明（LineageOS 的对应物是 `lineage.dependencies`，格式是 JSON 数组 `[{"repository","target_path"}]`；PixelOS 这份还支持 `"remote":"gitlab"`） |
| `prebuilts/Android.bp`、`prebuilts/gen_bootanimation.sh`、`prebuilts/ba_build/`、`prebuilts/bootanimation-*.zip` | 自制开机动画的生成与安装 |
| `proprietary-files.txt` | blob 清单（清单本身属于设备树；blob 本体不可发布） |

记录中出现过的自有 commit —— SHA 与标题来自会话记录，**内容已不可取**：

| SHA | 标题 |
|---|---|
| `5a808ef` | TB375FC: Correct README specs and complete the build manifest |
| `f2f15a` | Add TB373FU ROW variant |
| `e0b697a` | 标题未记录 |
| `624dfe` | 标题未记录 |
| `aadb1c9` | 标题未记录 |

## 2. 改在上游项目里的本地改动（会被 `repo sync` 覆盖，必须手工重做）

| 位置 | 记录里的动作 | 报错 / 原因 | 归属代次 |
|---|---|---|---|
| vendor bp 里的 prebuilt `libmnl` | 重命名 | 未记录 | 未记录 |
| `hardware/mediatek` 某 HAL 的 `Android.bp` | 加 `soong_namespace` import（pixel-usb）+ `visibility` | 未记录 | 未记录 |
| 同一份 vendor bp | 删除 5 条 HIDL 依赖（记录称其为已失效依赖） | 未记录 | 未记录 |
| `prebuilts/module_sdk/{WebApp,Profiling,Telephony,UprobeStats}` | 整体移开，让源码模块接管（备份仍在盘上，见第 4 节） | 未记录 | 未记录 |
| `build/release/flag_values/bp4a/` | 把 `RELEASE_TELECOM_MAINLINE_MODULE`、`RELEASE_PACKAGE_PROFILING_MODULE`、`RELEASE_ANOMALY_DETECTOR`、`RELEASE_UPROBESTATS_*` 置 `true` | 走源码而非 prebuilt | **影响 Android 16 的 release config**（`bp4a` 即 16 的代号，与 16 的 lunch 目标同名） |
| device 树的 product 定义 | 补 21 条 `PRODUCT_APEX_SYSTEM_SERVER_JARS` | 未记录 | 未记录 |
| `vendor/custom`（bootanimation） | 加条件判断 | 未记录 | 未记录 |
| `packages/services/Telecomm` 的 `TelecomServiceResources` | 加 `//apex_available:platform` | 未记录 | 未记录 |
| dexpreopt 相关 mk | `DISABLE_DEXPREOPT_CHECK := true` | 未记录 | 未记录 |
| device 树 sepolicy 中 `/sys/class/typec` 的 `genfscon` | 注释掉 vendor 那条规则（记录注明：Android 17 平台已把该路径标为 `sysfs_typec`，两者冲突） | 平台标签冲突 | 记录发生在 17 侧；16 是否需要 **未记录** |
| device 树 `manifest.xml` | `<sepolicy><version>` 由 `202504` 抬到 `202604` | 未记录 | 未记录 |
| vendor mk 里 stock product 分区的 `NOTICE.xml.gz` 拷贝规则 | 删掉该条 | 记录：17 构建会自己生成一份，重复安装导致 `build_image` 崩 | 记录发生在 17 侧；16 是否需要 **未记录** |

## 3. `repo sync` 与 manifest 口径（重建时重新核实）

- ROM：`github.com/PixelOS-AOSP/manifest`，16 用 `sixteen-qpr2`；AOSP 基线 `android-16.0.0_r4`。
- AOSP 走清华 TUNA 镜像：git `insteadOf` 把 `https://android.googlesource.com/` 映射到
  `https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/`。路径必须带 **`/git/AOSP/`** 前缀，
  写成 `/AOSP/` 或 `/aosp/` 会 404。USTC 在 `-j14` 下返回 429，别换回去；BFSU
  （`mirrors.bfsu.edu.cn/git/AOSP/`）是 TUNA 的镜像可作 fallback。
- **必须全局浅同步** `repo init --depth=1`。教训：一次未加 depth 的 `prebuilts/tools` 抓取拉了全量
  tag 历史，单个 project-objects 目录就吃掉 271 G，把 D: 撑到剩 24 M 导致发行版起不来。
  当时的处置是 `rm -rf .repo/project-objects/platform/prebuilts/tools.git`
  `.repo/projects/prebuilts/tools.git` 再单独重同步该项目（291 M）。
- 若清单把某些项目改指向新 remote，`repo` 会报 "hooks is different … --force-sync not enabled"；
  处置是删掉对应 `.repo/projects/<path>.git` 再同步（2026-09-20 有 21 个这样的项目）。
- GitHub 侧在重负载抓取时会被 TLS 阻断（`GnuTLS recv error (-110)`，gitlab 与 TUNA 不受影响），
  开代理可解，不要据此判断网络故障。
- 本地清单：`.repo/local_manifests/pixelos_tb375fc.xml`、`TB375FC.xml`，把
  `LosSantosPro/android_device_lenovo_TB375FC` → `device/lenovo/TB375FC`、
  `...-kernel` → `device/lenovo/TB375FC-kernel`、
  `LosSantosPro/android_vendor_lenovo_TB375FC` → `vendor/lenovo/TB375FC`，
  固定 `lineage-23.2`。
- ⚠️ 未核实项：当时 17 那侧记录的 manifest 口径是 `seventeen` + device 基线 `lineage-24.0`，
  但今天核对 `PixelOS-AOSP/manifest` 的分支列表里没有 `seventeen`，`LosSantosPro` 的设备树也只有
  `lineage-23.2`。这一条只影响已放弃的 17，重建 16 用不到，留此备忘。
- 2026-09-23 另外核对（都返回 404，即仓库不存在）：`PixelOS-Devices/android_device_lenovo_TB375FC`、
  `LosSantosPro/platform_manifests`。也就是说 **TB375FC 不在 PixelOS 官方支持机型之列**，
  公开可得的本设备基线只有 `LosSantosPro/android_device_lenovo_TB375FC` 的 `lineage-23.2` 一支；
  本仓库引用的设备型号、构建步骤均以我们自己实测为准。
- ⚠️ WSL 里那个 `~/sync-wait.sh`（等 GitHub 恢复后自动 `repo sync`）内容已损坏：
  创建时被外层 shell 当场展开了 `$(seq 1 180)`，日志路径变成空重定向，且把
  `REPO_SYNC_RC=0` 硬编码进了日志。因此**没有收录**，需要同步脚本请重写。

## 4. 仍然在盘上的实物备份（重建时可直接用）

| 路径（WSL） | 内容 | 大小 |
|---|---|---|
| `~/sdk-prebuilt-backup/` | 被移开的 `Profiling-current`、`Telephony-current`、`UprobeStats-current`（第 2 节第 4 条） | 1.9 M |
| `~/abidump-orphans-backup-20260922/` | 从 `prebuilts/abi-dumps/platform/36` 删掉的 4 个孤儿 ABI 转储 | 72 K |
| `~/webapp-sdk-import.bak/` | WebApp module-SDK 的导入备份 | 164 K |
| `~/reapply_fixes.sh` | 幂等重放当时三处修复的脚本（面向 17，未收录进本仓库） | 7 K |
| `~/run_*.sh`、`~/verify_publish17.sh`、`~/mon_build.sh` | 17 的构建 / 校验 / 监控脚本（未收录） | — |

## 5. 附录：只服务于已放弃的 Android 17 的记录

以下条目在 17 移植期间得到，随 17 一起停止跟进，仅留档：

- `build/make/tools/releasetools/build_image.py` 的 `CopyInputDirectory` 幂等化
  （`file_list.txt` 出现重复条目时 `os.link()` 抛 `FileExistsError`）。`repo sync` 会撤销。
- 删除 `prebuilts/abi-dumps/platform/36` 下 4 个孤儿 ABI 转储（否则 `check-abi-dump-list` 失败）。
  `repo sync` 会撤销。
- `vendor/pixel/gms` 需拉 Git LFS 对象，否则 8 个 APK 是 134 字节指针并报 "Improper zip alignment"。
- 把 pinned 的 6.1.138 内核换成 AOSP 17 的 GKI prebuilt 6.1.159（起因是 17 用户态在旧内核上
  `rt_mutex_adjust_prio_chain` / `_raw_spin_trylock` 处 Oops），以及为抓串口日志改
  `BOARD_KERNEL_CMDLINE` 加 `console=` / `earlycon` 的诊断脚本。这些改动**只存在于已删除的树里**，
  刷机包 `C:\PixelOS16` 是 16 的镜像，不含这些。
