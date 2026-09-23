# Lenovo Xiaoxin Pad Pro 12.7 (2025) - TB375FC

PixelOS (Android 16) for the Lenovo Xiaoxin Pad Pro 12.7, `TB375FC`, PRC Wi-Fi variant.
Built on the LineageOS device tree published at `LosSantosPro/android_device_lenovo_TB375FC`
(`lineage-23.2`); this repo holds our product definition, the local patches a rebuild needs,
and prebuilt images.

## Specifications

| Component | Detail |
|-----------|--------|
| SoC / GPU | MediaTek Dimensity 8300 (MT6897) / Mali-G615 |
| RAM / Storage | 8-12 GB / 128-256 GB UFS |
| Display | 12.7" 2944x1840 IPS LCD, 120 Hz |
| Battery | ~10200 mAh |
| Connectivity | Wi-Fi 6E + BT 5.4 (MediaTek connsys), no cellular |
| Stylus | Lenovo Tab Pen Plus |

## Build

```
repo init -u https://github.com/PixelOS-AOSP/manifest -b sixteen
```

Add the manifest below as `.repo/local_manifests/pixelos_TB375FC.xml`, then:

```
repo sync -c --depth=1
source build/envsetup.sh
lunch custom_TB375FC-bp4a-userdebug
m otapackage
m superimage
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="LosSantosPro/android_device_lenovo_TB375FC" path="device/lenovo/TB375FC" remote="github" revision="lineage-23.2" />
  <project name="LosSantosPro/android_vendor_lenovo_TB375FC"    path="vendor/lenovo/TB375FC"  remote="github" revision="lineage-23.2" />
  <project name="LosSantosPro/android_device_lenovo_TB375FC-kernel" path="device/lenovo/TB375FC-kernel" remote="github" revision="lineage-23.2" />
</manifest>
```

`m superimage` is required: the tree leaves `BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT` unset, so
`otapackage` does not produce `super.img`. `--depth=1` on the first sync is not optional either;
an undepthed `prebuilts/tools` fetch pulls full history.

Our side of the port is three things: `custom_TB375FC.mk` + `custom.dependencies` (the
`custom_` lunch target and its dependency list), a generated bootanimation installed through
`vendor/custom`, and the patches listed in [`docs/local-patches.md`](docs/local-patches.md).
The last group lives inside upstream projects, so every `repo sync` undoes it.

## Images

Release [`pixelos-16-20260920`](https://github.com/Villode/tb375fc-pixelos-port/releases/tag/pixelos-16-20260920)
carries a build from 2026-09-20 that boots and is usable day to day: `boot`, `vendor_boot`,
`init_boot`, `dtbo`, `vbmeta` x3, `SHA256SUMS.txt`, and `super.img` in three parts (GitHub caps a
release asset at 2 GiB):

```
cat super.img.part-00 super.img.part-01 super.img.part-02 > super.img
sha256sum super.img    # 8bbb445af978243c367248094a15bc3fe4eb89e847697d47ee715fa3ab3ecf5f
```

Flash with SP Flash Tool against the stock scatter: `vbmeta` x3, `lk`, `boot`, `vendor_boot`,
`init_boot`, `dtbo`, `super`, `userdata`. Unlocked bootloader required. `lk.img`, `DA_BR.bin`,
`da.auth` and a wipe `userdata.img` come from your own stock firmware and are not redistributed
here.

## Notes

**Prebuilt kernel.** The device runs the GKI 6.1 prebuilt shipped in the device tree
(`6.1.173-android14-11`); the 487 vendor `.ko` load against it. An Android-version bump does not
change the kernel, so KMI is not a gate here. Source for rebuilding it:
`kquieter-debug/Android_kernel_source_TB375FC` (6.1.138).

**No blobs, no device tree source.** `proprietary-files.txt` lists what `extract-files.py` pulls
from a stock device; the blobs themselves, and Lenovo/MediaTek firmware, stay off this repo. The
device tree edits listed above were never pushed while the tree existed, so the docs are a rebuild
guide rather than a patch set.

**GMS.** This build carries `vendor/pixel/gms` (8 APKs, ~1.4 GB, LFS), which means the `super.img`
above contains Google proprietary binaries. Take that into account before redistributing it.

**Signing.** Public AOSP test keys. Nothing in this repo holds a release key.

## Machine

Built in WSL2, 14 cores / 30 GB RAM + 32 GB swap, ~239k actions and ~14 h for a full build.
`LC_ALL=C`, ccache off, long runs under `tmux`, and the host disk to watch is the one holding the
vhdx. Details in [`docs/build-notes.md`](docs/build-notes.md).

## Credits

`LosSantosPro` for the TB375FC device and vendor trees, PixelOS and LineageOS for the platform,
`kquieter-debug` for the kernel source. Mainline Linux for this same tablet is a separate line:
`Villode/tb375fc-linux`.

## License

Apache-2.0 for the scripts and docs here. Upstream trees keep their own licenses.
UNOFFICIAL - not affiliated with PixelOS, LineageOS, Lenovo or MediaTek. Study it, flash at your
own risk.
