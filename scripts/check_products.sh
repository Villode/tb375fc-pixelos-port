#!/bin/bash
cd /home/Villode/fox_14.1 || exit 1
export LC_ALL=C
export FOX_BUILD_DEVICE=tb375fc
source build/envsetup.sh

echo "=== 产品列表(含 twrp/omni/fox) ==="
print_lunch_menu 2>/dev/null | grep -iE "twrp|omni|fox|tb375" | head -20

echo ""
echo "=== 前 15 项 ==="
print_lunch_menu 2>/dev/null | head -15

echo ""
echo "=== 搜索 AndroidProducts.mk ==="
find device -maxdepth 3 -name "AndroidProducts.mk" 2>/dev/null | head
echo "=== 我们的 AndroidProducts.mk 内容 ==="
cat device/lenovo/tb375fc/AndroidProducts.mk
