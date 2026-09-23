#!/bin/bash
# Full Android 17 (cp2a) build for TB375FC, staged so a failure is isolated:
#   phase 1: m nothing      -> Soong/Kati analysis only (the memory-heavy step)
#   phase 2: m otapackage   -> system/vendor/product images + OTA zip
#   phase 3: m superimage   -> super.img (dynamic partition image)
# Each phase checks the real exit code via PIPESTATUS.
# Ends with an explicit version assertion: the images must report release 17 / sdk 37,
# otherwise nothing is published to the flash directory.

SRC=/home/Villode/pixelos
OUT=$SRC/out/target/product/TB375FC
FLASH=/mnt/d/Android/pixelos-flash-17
REF=/mnt/d/Android/pixelos-flash
LOG=/home/Villode/pixelos17-full-build.log

exec > >(tee "$LOG") 2>&1

cd "$SRC" || exit 1
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

echo "### PHASE 1: analysis (m nothing) $(date +%F\ %T)"
m -j10 nothing
rc1=$?
echo "PHASE1_RC=$rc1"

if [ "$rc1" -ne 0 ]; then
    echo "BUILD_ABORTED at analysis"
    exit 1
fi

echo "### PHASE 2: otapackage $(date +%F\ %T)"
m -j10 otapackage
rc2=$?
echo "PHASE2_RC=$rc2"

if [ "$rc2" -ne 0 ]; then
    echo "BUILD_ABORTED at otapackage"
    exit 2
fi

echo "### PHASE 3: superimage $(date +%F\ %T)"
m -j10 superimage
rc3=$?
echo "PHASE3_RC=$rc3"

echo "### VERSION ASSERTION"
grep -hE "^ro\.(system\.)?build\.version\.(release|sdk)=" "$OUT/system/build.prop"
cat "$OUT/build_fingerprint-custom_TB375FC.txt"
ls -la "$OUT/super.img"

rel=$(grep -hE "^ro\.system\.build\.version\.release=" "$OUT/system/build.prop" | cut -d= -f2)
sdk=$(grep -hE "^ro\.system\.build\.version\.sdk=" "$OUT/system/build.prop" | cut -d= -f2)

if [ "$rc3" -ne 0 ] || [ "$rel" != "17" ] || [ "$sdk" != "37" ] || [ ! -f "$OUT/super.img" ]; then
    echo "PUBLISH_ABORTED: rel=$rel sdk=$sdk superimg=$([ -f "$OUT/super.img" ] && echo yes || echo no)"
    exit 3
fi

echo "### PUBLISH to $FLASH"
mkdir -p "$FLASH"
for f in boot.img dtbo.img init_boot.img vendor_boot.img super.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
    [ -f "$OUT/$f" ] && cp -v "$OUT/$f" "$FLASH/"
done
# Firmware-side files that AOSP does not build: reuse the verified Android 16 set.
for f in lk.img DA_BR.bin da.auth userdata.img MT6897_PixelOS_scatter.xml 2-flash.xml flash.xsd; do
    [ -f "$REF/$f" ] && cp -v "$REF/$f" "$FLASH/"
done
echo "PUBLISH_DONE $(date +%F\ %T)"
ls -la "$FLASH"
