#!/bin/bash
# Build super.img (dynamic partition super image) for custom_TB375FC.
# `droid` / `otapackage` do NOT build it because BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT
# is unset in the device tree -- super.img is only wired to droidcore-unbundled when
# that flag is true. `m superimage` builds it explicitly (Makefile:7765).
cd /home/Villode/pixelos
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export SOONG_INCREMENTAL_ANALYSIS=true

m superimage 2>&1 | tee /home/Villode/pixelos17-cp2a-super.log
rc=${PIPESTATUS[0]}
if [ "$rc" -eq 0 ]; then
  echo "BUILD_DONE rc=0" >> /home/Villode/pixelos17-cp2a-super.log
else
  echo "BUILD_FAILED rc=$rc" >> /home/Villode/pixelos17-cp2a-super.log
fi
