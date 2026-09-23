#!/bin/bash
# Swap the pinned Android 14-era kernel (6.1.138-android14-11-g151cf2b6bfbe-ab13719792)
# for the AOSP Android 17 GKI prebuilt 6.1 (6.1.159-android14-11-gedbe3e111301-ab14867025).
# Rationale: the A17 userspace Oopses inside rt_mutex_adjust_prio_chain/_raw_spin_trylock
# on the old kernel; AOSP's Android 17 compatibility matrix still supports android14-6.1,
# and the bundled 6.1.159 build carries 21 LTS releases of fixes over 6.1.138.
#
# Only `m bootimage` is run - no full rebuild, nothing is flashed.
cd /home/Villode/pixelos || exit 1

BC=device/lenovo/TB375FC/BoardConfig.mk
cp -n "$BC" "$BC.bak-6.1.138"

sed -i 's#^TARGET_PREBUILT_KERNEL  := $(DEVICE_PATH)/prebuilts/Image.gz#TARGET_PREBUILT_KERNEL  := kernel/prebuilts/6.1/arm64/kernel-6.1-gz#' "$BC"

echo "=== 修改后的内核指定 ==="
grep -n "TARGET_PREBUILT_KERNEL" "$BC"

source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

m -j10 bootimage
rc=$?
echo "BOOTIMAGE_RC=$rc"
if [ "$rc" -eq 0 ]; then
    ls -la out/target/product/TB375FC/boot.img
    echo "=== 新 boot.img 的内核版本 ==="
    strings out/target/product/TB375FC/boot.img | grep -oE "6\.1\.[0-9]+-android[0-9]+-[0-9]+-g[0-9a-f]+-ab[0-9]+" | sort -u | head -3
else
    echo "BOOTIMAGE_FAILED rc=$rc"
fi
