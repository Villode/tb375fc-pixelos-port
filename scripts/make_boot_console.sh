#!/bin/bash
# Rebuild boot.img with a serial console on the kernel cmdline, so the boot log
# can be captured over UART (COM6) while the device hangs on the vendor logo.
# This is diagnostic-only: it does not change whether the system boots.
cd /home/Villode/pixelos || exit 1

BC=device/lenovo/TB375FC/BoardConfig.mk
cp -n "$BC" "$BC.bak-before-console"

# Keep the original MTK args, append console + earlycon last.
sed -i 's#^BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 firmware_class.path=/vendor/firmware#BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 firmware_class.path=/vendor/firmware console=ttyS0,921600 console=ttyMT0,921600 earlycon#' "$BC"

echo "=== 修改后的 cmdline ==="
grep -n "BOARD_KERNEL_CMDLINE :=" "$BC"

source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

m -j10 bootimage
rc=$?
echo "BOOTIMAGE_CONSOLE_RC=$rc"
if [ "$rc" -eq 0 ]; then
    mkdir -p /home/Villode/diag
    cp -v out/target/product/TB375FC/boot.img /home/Villode/diag/boot-6159-console.img
    cp -v out/target/product/TB375FC/boot.img /mnt/d/Android/pixelos-flash-17/boot-6.1.159-console.img
fi
