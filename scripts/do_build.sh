#!/bin/bash
#
# 编译 OrangeFox for Lenovo TB375FC
# 注意：source build/envsetup.sh 不能接管道，否则函数会丢在子 shell 里
#
cd /home/Villode/fox_14.1 || exit 1

# AOSP 14 的构建沙箱只允许写 out/，ccache 的缓存目录在源码树外会被判为
# "Read-only file system" 而中断编译。这里直接关掉 ccache。
# （.bashrc 里默认 export USE_CCACHE=1，必须在这里覆盖）
unset CCACHE_DIR
unset CCACHE_EXEC
export USE_CCACHE=0
export CCACHE_DISABLE=1

export LC_ALL=C
export FOX_BUILD_DEVICE=tb375fc

echo "=== [1/3] source build/envsetup.sh ==="
source build/envsetup.sh

echo "=== [2/3] lunch twrp_tb375fc-ap2a-eng ==="
lunch twrp_tb375fc-ap2a-eng
echo "--- TARGET_PRODUCT=$TARGET_PRODUCT  TARGET_DEVICE=$TARGET_DEVICE  OUT=$OUT ---"

if [ -z "$TARGET_PRODUCT" ]; then
    echo "!! FATAL: lunch 失败"
    exit 2
fi

echo "=== [3/3] mka vendorbootimage ==="
mka vendorbootimage
rc=$?
echo "=== mka 退出码 = $rc ==="

echo "=== 产物 ==="
ls -la out/target/product/tb375fc/ 2>/dev/null | grep -iE "OrangeFox|vendor_boot|recovery|\.zip" 
echo "=== done ==="
