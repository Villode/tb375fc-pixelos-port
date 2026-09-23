#!/bin/bash
cd /home/Villode/pixelos
source build/envsetup.sh
lunch custom_TB375FC-bp4a-userdebug
export LC_ALL=C CCACHE_DISABLE=1 USE_CCACHE=0
m nothing 2>&1 | tee /home/Villode/m-nothing-17.log
echo "M_EXIT_CODE=$?" >> /home/Villode/m-nothing-17.log
