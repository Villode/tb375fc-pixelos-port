#!/bin/bash
# Rebuild only the images that carry the vendor .ko files, after the vermagic
# rewrite (6.1.138 -> 6.1.159). boot.img was already rebuilt with the AOSP A17 GKI.
cd /home/Villode/pixelos || exit 1
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

# NOTE: the real ninja target names use underscores differently:
#   vendor_dlkmimage / system_dlkmimage / vendorbootimage
# ("vendordlkmimage" / "systemdlkmimage" / "vendor_bootimage" are unknown targets).
m -j10 vendor_dlkmimage system_dlkmimage vendorbootimage
rc=$?
echo "DLKM_RC=$rc"

OUT=out/target/product/TB375FC
echo "=== 新镜像里的内核版本字符串（不应再出现 6.1.138） ==="
for img in vendor_dlkm.img system_dlkm.img vendor_boot.img; do
    [ -f "$OUT/$img" ] || continue
    printf "%-18s " "$img"
    old=$(strings "$OUT/$img" 2>/dev/null | grep -c "6\.1\.138-android14-11")
    new=$(strings "$OUT/$img" 2>/dev/null | grep -oE "6\.1\.159-android14-11-g[0-9a-f]+-ab[0-9]+" | head -1)
    echo "old138=$old new159=${new:-none}"
done
echo "=== 时间戳 ==="
ls -la --time-style=long-iso "$OUT"/vendor_dlkm.img "$OUT"/system_dlkm.img "$OUT"/vendor_boot.img "$OUT"/boot.img 2>/dev/null
