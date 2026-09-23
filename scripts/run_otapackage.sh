#!/bin/bash
# Produce the OTA package for custom_TB375FC.
# Separate from run_build17.sh so the successful build log is preserved.
cd /home/Villode/pixelos
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

# `m` 的退出码必须通过 PIPESTATUS 取，不能用 $?（那是 tee 的）。
m -j10 otapackage 2>&1 | tee /home/Villode/pixelos17-cp2a-ota.log
rc=${PIPESTATUS[0]}
if [ "$rc" -eq 0 ]; then
  echo "BUILD_DONE rc=0" >> /home/Villode/pixelos17-cp2a-ota.log
else
  echo "BUILD_FAILED rc=$rc" >> /home/Villode/pixelos17-cp2a-ota.log
fi
