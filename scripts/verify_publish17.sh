#!/bin/bash
# Post-build gate for the Android 17 (cp2a) package.
# Refuses to publish anything unless the images provably report Android 17.
# Also reports whether the super.img size still fits the SP Flash Tool scatter
# (partition layout comes from the vendor scatter, not from AOSP).

SRC=/home/Villode/pixelos
OUT=$SRC/out/target/product/TB375FC
FLASH=/mnt/d/Android/pixelos-flash-17
# Android 16 参考刷机包已由用户搬到 C:\PixelOS16（原 D:\Android\pixelos-flash 已不存在）。
# 只从此处取 AOSP 不构建的固件侧文件（lk / DA / scatter / flash.xml / userdata）；
# vbmeta* 与 vendor_boot 必须用 17 自己构建的，不能沿用 16 的。
REF=/mnt/c/PixelOS16

cd "$SRC" || exit 1

echo "=== 1. 版本证据 ==="
grep -hE "^ro\.(system\.)?build\.version\.(release|sdk|security_patch)=" "$OUT/system/build.prop"
cat "$OUT/build_fingerprint-custom_TB375FC.txt"

rel=$(grep -hE "^ro\.system\.build\.version\.release=" "$OUT/system/build.prop" | cut -d= -f2)
sdk=$(grep -hE "^ro\.system\.build\.version\.sdk=" "$OUT/system/build.prop" | cut -d= -f2)
fp=$(cat "$OUT/build_fingerprint-custom_TB375FC.txt")

if [ "$rel" != "17" ] || [ "$sdk" != "37" ]; then
    echo "REFUSE: not Android 17 (rel=$rel sdk=$sdk) -- nothing published."
    exit 1
fi
case "$fp" in
    *":17/"*) ;;
    *) echo "REFUSE: fingerprint does not start with release 17: $fp"; exit 1 ;;
esac

echo
echo "=== 2. 必要镜像 ==="
MISSING=0
for f in boot.img dtbo.img init_boot.img vendor_boot.img super.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
    if [ -f "$OUT/$f" ]; then
        printf "OK    %-20s %s\n" "$f" "$(stat -c%s "$OUT/$f")"
    else
        printf "MISS  %-20s\n" "$f"
        MISSING=1
    fi
done
[ "$MISSING" -eq 1 ] && { echo "REFUSE: missing images -- nothing published."; exit 2; }

echo
echo "=== 3. super.img 与 scatter 分区容量核对 ==="
export OUT REF
python3 - <<'PY'
import os, re, xml.etree.ElementTree as ET
out = os.environ.get("OUT", "/home/Villode/pixelos/out/target/product/TB375FC")
ref = os.environ.get("REF", "/mnt/c/PixelOS16/MT6897_PixelOS_scatter.xml")
size = os.path.getsize(os.path.join(out, "super.img"))
print("super.img 实际大小 :", size, "bytes (%.2f GB)" % (size/1024**3))
try:
    root = ET.parse(ref).getroot()
except Exception as e:
    print("scatter 解析失败:", e); raise SystemExit(0)
for p in root.iter():
    name = (p.findtext("partition_name") or "").strip() if p.find("partition_name") is not None else None
    if not name:
        # scatter schema varies; fall back to attribute style
        name = p.attrib.get("partition_name")
    if not name:
        continue
    idx = p.findtext("partition_index")
    if name.lower() == "super":
        # linear_start/physical_start + partition_size define the slot
        size_txt = p.findtext("partition_size")
        start_txt = p.findtext("linear_start") or p.findtext("physical_start")
        print("scatter super 分区: size=%s start=%s" % (size_txt, start_txt))
        try:
            cap = int(size_txt, 0) if size_txt and size_txt.startswith("0x") else int(size_txt)
            print("scatter super 容量 :", cap, "bytes (%.2f GB)" % (cap/1024**3))
            print("结论:", "OK - 装得下，余量 %.2f GB" % ((cap-size)/1024**3) if size <= cap else "!!! 超出分区容量，必须改 BOARD_SUPER_PARTITION_SIZE 或 scatter")
        except Exception as e:
            print("容量解析失败:", e)
PY

echo
echo "=== 4. 发布到 $FLASH ==="
mkdir -p "$FLASH"
for f in boot.img dtbo.img init_boot.img vendor_boot.img super.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
    cp -v "$OUT/$f" "$FLASH/"
done
for f in lk.img DA_BR.bin da.auth userdata.img MT6897_PixelOS_scatter.xml 2-flash.xml flash.xsd; do
    [ -f "$REF/$f" ] && cp -v "$REF/$f" "$FLASH/"
done
cp -v "$OUT/system/build.prop" "$FLASH/system-build.prop.txt"
{
  echo "PixelOS Android 17 (cp2a) for TB375FC"
  echo "generated: $(date +%F\ %T)"
  echo "release : $rel"
  echo "sdk     : $sdk"
  echo "fingerprint: $fp"
} > "$FLASH/VERSION.txt"
cat "$FLASH/VERSION.txt"

echo
echo "PUBLISH_DONE"
ls -la "$FLASH"
