#!/bin/bash
# Phase 1 for the Android 17 (cp2a) build: run the Soong/Kati ANALYSIS only.
# `m nothing` performs the full blueprint/soong analysis and ninja generation
# without compiling, so a memory blow-up during analysis is isolated here and
# cannot corrupt the rest of the build. Once this passes, `m otapackage` reuses
# the cached analysis and goes straight to compiling.
cd /home/Villode/pixelos
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
export GOMEMLIMIT=20GiB
export GOMAXPROCS=8
export SOONG_INCREMENTAL_ANALYSIS=true

m -j10 nothing 2>&1 | tee /home/Villode/pixelos17-cp2a-analyze.log
rc=${PIPESTATUS[0]}
if [ "$rc" -eq 0 ]; then
  echo "ANALYZE_DONE rc=0" >> /home/Villode/pixelos17-cp2a-analyze.log
else
  echo "ANALYZE_FAILED rc=$rc" >> /home/Villode/pixelos17-cp2a-analyze.log
fi
