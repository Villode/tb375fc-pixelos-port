#
# Copyright (C) 2026 Villode
#
# SPDX-License-Identifier: Apache-2.0
#
# PixelOS product for the Lenovo Xiaoxin Pad Pro 12.7 (TB375FC).
#
# This file is the only product layer PixelOS needs: it reuses the LineageOS
# device tree wholesale (AOSP base + Lineage common + device.mk + vendor blobs +
# tablet wifi-only config, all already resolved in lineage_TB375FC.mk) and then
# re-brands the product as `custom_TB375FC` so `lunch custom_TB375FC-bp4a-userdebug`
# exists inside a PixelOS manifest. Structure follows PixelOS's own convention,
# e.g. PixelOS-Devices/android_device_xiaomi_davinci@sixteen/custom_davinci.mk
# (inherit the device product, then override PRODUCT_NAME to custom_<device>).

$(call inherit-product, device/lenovo/TB375FC/lineage_TB375FC.mk)

# PixelOS / GMS layer.
#
# NOTE: verify the exact config file name against the synced tree before trusting
# this line -- use `ls vendor/custom/config` and `ls vendor/pixel/config`.
# inherit-product-if-exists is used deliberately: a wrong name must not break the
# build, it just means no GMS got pulled in. davinci's own product makefile uses
# vendor/custom/config/common_full_phone.mk for the same purpose.
$(call inherit-product-if-exists, vendor/custom/config/common_full_tablet_wifionly.mk)
$(call inherit-product-if-exists, vendor/pixel/config/common_full_tablet_wifionly.mk)

PRODUCT_NAME := custom_TB375FC
PRODUCT_DEVICE := TB375FC
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := TB375FC
PRODUCT_MANUFACTURER := Lenovo
PRODUCT_CHARACTERISTICS := tablet

# Setting PRODUCT_NAME above is what makes the fingerprint read
# Lenovo/custom_TB375FC/TB375FC:16/..., so no PRODUCT_BUILD_PROP_OVERRIDES are
# needed here.

# The stock-derived props (ro.vendor.config.lgsi.*) and PRODUCT_GMS_CLIENTID_BASE
# are inherited from lineage_TB375FC.mk on purpose; do not restate them here.
