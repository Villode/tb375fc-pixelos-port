#!/bin/bash
# 自检 vendorsetup.sh 的开关是否按预期导出
DT="${1:-/tmp/ofox_tb375fc}"
cd "$DT" || exit 1
source ./vendorsetup.sh tb375fc

echo "FOX_BUILD_DEVICE          = $FOX_BUILD_DEVICE"
echo "FOX_VENDOR_BOOT_RECOVERY  = $FOX_VENDOR_BOOT_RECOVERY"
echo "FOX_AB_DEVICE             = $FOX_AB_DEVICE"
echo "FOX_VIRTUAL_AB_DEVICE     = $FOX_VIRTUAL_AB_DEVICE"
echo "FOX_REFERENCE_VENDOR_BOOT_IMAGE = $FOX_REFERENCE_VENDOR_BOOT_IMAGE"
echo "---- Magisk ----"
if [ -z "$FOX_DELETE_MAGISK_ADDON" ]; then
    echo "Magisk 内置 = 是"
else
    echo "Magisk 内置 = 否 (FOX_DELETE_MAGISK_ADDON=$FOX_DELETE_MAGISK_ADDON)"
fi
echo "指定 Magisk zip = ${FOX_USE_SPECIFIC_MAGISK_ZIP:-<用内置 v30.6>}"
echo "---- KernelSU ----"
echo "KernelSU(官方) = ${FOX_ENABLE_KERNELSU_SUPPORT:-未设置}"
echo "KernelSU Next  = ${FOX_ENABLE_KERNELSU_NEXT_SUPPORT:-未设置}"
echo "SukiSU         = ${FOX_ENABLE_SUKISU_SUPPORT:-未设置}"
echo "---- 其他 ----"
echo "TW_DEFAULT_LANGUAGE = $TW_DEFAULT_LANGUAGE"
echo "OF_DEFAULT_KEYMASTER_VERSION = $OF_DEFAULT_KEYMASTER_VERSION"
