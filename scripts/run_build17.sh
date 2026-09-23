#!/bin/bash
cd /home/Villode/pixelos
source build/envsetup.sh
lunch custom_TB375FC-cp2a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
m 2>&1 | tee /home/Villode/pixelos17-cp2a-build.log
echo "BUILD_DONE" >> /home/Villode/pixelos17-cp2a-build.log
