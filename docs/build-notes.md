# 构建环境笔记

## 机器

WSL2 Ubuntu 24.04（宿主 Windows 10 19045），给构建分配 **14 核 / 30 G 内存 + 32 G swap**。

- 内存是瓶颈而不是核数：soong 分析阶段能把 30 G 打满并开始抖 swap。需要压并发
  （`GOMEMLIMIT=20GiB`、`GOMAXPROCS=8`、`-j` 控制在 10 左右）。
- 换原生 Linux 大约快 10–20 %（真实内存 + 少一层 vhdx/NTFS），只有频繁出包才值得。
- 耗时：Android 16 那次全量的耗时**没有记录**；后来 17 那次是约 239k actions、单次约 14 h，
  同一台机器的量级可以参考它。

## 必须的环境设置

```sh
export LC_ALL=C                        # 否则 soong 输出解析会因 locale 出错
export USE_CCACHE=0 CCACHE_DISABLE=1   # 构建沙箱只允许写 out/，ccache 目录在树外会被判
unset CCACHE_DIR CCACHE_EXEC           #   "Read-only file system" 中断编译；~/.bashrc 里默认开
```

长构建一律放 `tmux` 里 —— 2026-09-08 有一次全量被 SIGHUP 打死。

## 判定"构建成功"这件事不能靠感觉

- `m ... | tee log` 之后 `$?` 是 `tee` 的退出码，不是构建的。取真实结果必须用 `${PIPESTATUS[0]}`
  或 `set -o pipefail`。
- 当时的构建脚本是**无条件**在日志尾部追加 `BUILD_DONE` 的，所以日志里有 `BUILD_DONE`
  并不代表成功。可靠的判据是：标记存在 **且** 找不到失败特征串，并且 `build.prop` 的版本三项
  对得上（见下节）。
- `source build/envsetup.sh` 不能接管道 —— 函数会丢在子 shell 里，后面 `lunch` 直接空。
- 判断 `repo sync` 是否卡住别看日志（stdout 非 TTY 时输出是全缓冲的），看磁盘增长、
  活跃 `git fetch` 进程数、`FETCH_HEAD` 时间戳。

## 出包

`super.img` 必须显式 `m superimage`：device 树没有置 `BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT`，
`droid` / `otapackage` 都不会顺带产出它。

发布前核对版本三重证据（`ro.build.version.release` / `.sdk` / fingerprint），
16 侧的具体期望值当时没有留下记录，以 `out/target/product/TB375FC/system/build.prop` 实测为准：

```sh
grep -hE "^ro\.(system\.)?build\.version\.(release|sdk|security_patch)=" \
     out/target/product/TB375FC/system/build.prop
cat out/target/product/TB375FC/build_fingerprint-custom_TB375FC.txt
```

## 一个可刷的包由哪些东西组成

**AOSP 构建、必须与目标代次配套**（不能沿用上一代）：
`boot.img`、`dtbo.img`、`init_boot.img`、`vendor_boot.img`、`super.img`、
`vbmeta.img`、`vbmeta_system.img`、`vbmeta_vendor.img`。
其中 `vbmeta*` 与 `vendor_boot` 尤其不能拿上一代凑 —— AVB 链和 ramdisk 都得与当代镜像一致。

**固件侧、AOSP 不构建、只能从自己的 stock 刷机目录取**（授权原因不可公开再分发）：
`lk.img`、`DA_BR.bin`、`da.auth`、`userdata.img`、scatter XML、`2-flash.xml`、`flash.xsd`。

设备是 MTK，用 SP Flash Tool 按 scatter 刷：vbmeta×3、lk、boot、vendor_boot、init_boot、dtbo、
super、userdata。

`super.img` 的实际大小要与**厂商 scatter** 里 super 分区的容量核对 —— 分区布局来自 scatter，
不是 AOSP；容量不够时改的是 `BOARD_SUPER_PARTITION_SIZE` 或 scatter，不是镜像本身。

## 磁盘：这台机器真正出过事的地方

- WSL 根文件系统是 `D:/wsl/Ubuntu2404/ext4.vhdx`，而 D: 上同时放着 `/d/Android`。
  **盯 D: 的剩余空间，不是 C:**。
- 事故记录：一次未加 `--depth=1` 的同步把 vhdx 撑到约 927 G、D: 只剩 14 M，ext4 开始返回 EIO，
  发行版拒绝启动（`getpwnam failed`、`CreateInstance/E_FAIL`、`fopen(/etc/default/locale) failed 5`）。
  腾出约 10 G 后得以启动并完成 journal 重放。第二次是 271 G 的 `prebuilts/tools` 把 vhdx 顶到
  938 G、D: 剩 24 M，光腾空间不够，必须 `wsl --shutdown` 冷启动才解开。
- **vhdx 只增不减**：删掉整棵 518 G 的树不会把空间还给 Windows。`fstrim -av` 只在客户机内生效，
  宿主收缩要 `diskpart` compact vdisk（需管理员）或 `wsl --manage --set-sparse true`。
  实际可行的做法是：把 ext4 用量长期压在 vhdx 已物化的尺寸以下，让宿主永远不需要再扩。
- 浅同步后的体积参考：整树约 518 G（`.repo` 405 G、`prebuilts` 250 G、`out` 131 G；有重叠计入）。
  `.repo` 的绝大部分是工具链二进制，`git gc` 收不回多少 —— 唯一的杠杆是整棵树级别的删除。
