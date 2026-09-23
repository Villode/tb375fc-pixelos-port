# 构建环境笔记

## 机器

WSL2 Ubuntu 24.04（宿主 Windows 10 19045），给构建分配 **14 核 / 30 G 内存 + 32 G swap**。

- 全量构建约 **239k actions、单次约 14 h**；瓶颈是内存而不是核数 —— soong 分析阶段会把
  30 G 打满并开始抖 swap，所以 `run_full17.sh` 显式设 `GOMEMLIMIT=20GiB`、`GOMAXPROCS=8`
  并把 `-j` 压到 10。
- 换原生 Linux 大约快 10–20 %（真实内存 + 少一层 vhdx/NTFS），只有频繁出包才值得。
- 磁盘：整树浅同步后约 518 G（`.repo` 405 G、`prebuilts` 250 G、`out` 12 G，有重叠计入），
  放 `ext4.vhdx` 里。**注意 vhdx 只增不减**，删树不会把空间还给 Windows，需要
  `wsl --shutdown` 后 `Optimize-VHD`/`wsl --manage --set-sparse true` 才回收。

## 必须的环境设置

```sh
export LC_ALL=C                 # 否则 soong 输出解析会因 locale 出错
export CCACHE_DISABLE=1 USE_CCACHE=0   # AOSP 沙箱只读限制与 ccache 冲突
```

长构建一律放 `tmux` 里 —— 2026-09-08 有一次全量被 SIGHUP 打死。

## 退出码这一类坑

- `m ... | tee log` 之后 `$?` 是 `tee` 的退出码。取构建真实结果必须用 `${PIPESTATUS[0]}`，
  或者 `set -o pipefail`。
- `run_build17.sh` 是无条件在日志尾部追加 `BUILD_DONE` 的，所以**看到 `BUILD_DONE` 不等于成功**。
  `mon_build.sh` 的判定方式是"标记存在 **且** 找不到失败特征串"，并且按 `soong_build` /
  `ckati` / `siso` 哪个进程活着来判断当前处在分析、Make 还是编译阶段。
- 判断同步是否卡住别看日志（stdout 非 TTY 时 `repo sync` 是全缓冲的），看磁盘增长、
  活跃 `git fetch` 进程数、`FETCH_HEAD` 时间戳。

## 分阶段出包（推荐路径）

```sh
bash scripts/run_full17.sh        # 分析 → otapackage → superimage，带版本断言
# 或者手工三步，各自独立日志：
bash scripts/run_analyze17.sh     # m nothing，把内存问题隔离在分析阶段
bash scripts/run_otapackage.sh    # m otapackage
bash scripts/run_superimage.sh    # m superimage
bash scripts/verify_publish17.sh  # 发布闸门
```

`super.img` 必须单独 `m superimage`：device 树没有置
`BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT`，`droid` / `otapackage` 都不会顺带产出它。

## 一个可刷的包由哪些东西组成

`verify_publish17.sh` 把两类文件分开处理，这个区分很重要：

**AOSP 自己构建、必须与目标 Android 版本配套**（不能沿用上一代的）：
`boot.img`、`dtbo.img`、`init_boot.img`、`vendor_boot.img`、`super.img`、
`vbmeta.img`、`vbmeta_system.img`、`vbmeta_vendor.img`。

**固件侧、AOSP 不构建、只能从自己的 stock 刷机包里取**（授权原因不可公开再分发）：
`lk.img`、`DA_BR.bin`、`da.auth`、`userdata.img`、scatter XML、`2-flash.xml`、`flash.xsd`。
其中 `vbmeta*` 与 `vendor_boot` 尤其不能拿上一代的凑 —— AVB 链和 ramdisk 都得与当代镜像一致。
（设备是 MTK，用 SP Flash Tool 按 scatter 刷：vbmeta×3、lk、boot、vendor_boot、init_boot、
dtbo、super、userdata。）

`super.img` 的实际大小要与**厂商 scatter** 里 super 分区的容量核对 —— 分区布局来自 scatter，
不是 AOSP；`verify_publish17.sh` 里那段 Python 就是解析 scatter 做这个比对的。

## 发布前的版本三重证据

```sh
grep -hE "^ro\.(system\.)?build\.version\.(release|sdk|security_patch)=" out/.../system/build.prop
cat out/.../build_fingerprint-custom_TB375FC.txt     # fingerprint 必须以目标代开头
```

17 的判据是 `release=17`、`sdk=37`、fingerprint 含 `:17/`。三条任一不符就不发布任何文件。

## 内核这一层为什么不用管 KMI

设备跑的是 prebuilt GKI 6.1（`prebuilts/Image.gz`，`6.1.173-android14-11`），
487 个 vendor `.ko` 是对这个内核加载的，Android 从 16 跳到 17 不换内核，所以 KMI
不构成移植阻塞项 —— 只有主动换内核才会变成问题。厂商内核源码参考：
`github.com/kquieter-debug/Android_kernel_source_TB375FC`（6.1.138）。
同一台设备的主线内核（7.2 / MT6897）移植是另一条线，见 `Villode/tb375fc-linux`，
那条线的产物不能直接拿来给这套 ROM 用。
