#!/bin/bash
# ============================================================================
# PixelOS 17 (custom_TB375FC) 构建修复：一键重新应用
#
# 本脚本把 2026-09-22 排障得到的三处修复做成**幂等**操作。
# `repo sync` 会撤销其中的 1 和 3，同步后重跑本脚本即可。
#
#   bash reapply_fixes.sh            # 应用（默认）
#   bash reapply_fixes.sh --check    # 只检查状态，不修改任何文件
#
# 三处修复：
#   1. build/make/tools/releasetools/build_image.py 的 CopyInputDirectory 幂等化
#      —— file_list.txt 出现重复条目时 os.link() 抛 FileExistsError，镜像构建失败
#   2. vendor/pixel/gms 的 git-lfs 对象拉取（8 个 GMS APK，约 1.4GB）
#      —— 未拉取时是 134 字节指针，报 "Improper zip alignment"
#   3. 删除 prebuilts/abi-dumps/platform/36 下 4 个孤儿 ABI 转储
#      —— 否则 check-abi-dump-list 失败
# ============================================================================
set -u

TREE=${PIXELOS_TREE:-/home/Villode/pixelos}
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

BI_FILE="$TREE/build/make/tools/releasetools/build_image.py"
LFS_REPO="$TREE/vendor/pixel/gms"
LFS_REMOTE="gitlab"
ABI_DIR="$TREE/prebuilts/abi-dumps/platform/36"
ABI_NAME="libcom.android.tethering.dns_helper.so.lsdump"
ABI_BACKUP="/home/Villode/abidump-orphans-backup-20260922"

say()  { printf '%s\n' "$*"; }
head2() { printf '\n========== %s ==========\n' "$*"; }

if [ "$CHECK" -eq 1 ]; then say "模式: 仅检查（不会修改任何文件）"; else say "模式: 应用修复"; fi
say "源码树: $TREE"
[ -d "$TREE" ] || { say "错误: 源码树不存在"; exit 1; }

RC=0

# ---------------------------------------------------------------- 修复 1
head2 "修复 1/3: build_image.py CopyInputDirectory 幂等化"

if [ ! -f "$BI_FILE" ]; then
  say "  错误: 找不到 $BI_FILE"; RC=1
elif grep -q "os.path.lexists(full_dst)" "$BI_FILE"; then
  say "  状态: 已应用 ✓"
  grep -n "os.path.lexists(full_dst)" "$BI_FILE" | sed 's/^/    /'
  grep -n "if not line:" -A 1 "$BI_FILE" | sed 's/^/    /'
elif [ "$CHECK" -eq 1 ]; then
  say "  状态: 未应用 ✗（需要打补丁）"
else
  say "  状态: 未应用 → 正在打补丁"
  python3 - "$BI_FILE" <<'PYEOF'
import sys, os, shutil
p = sys.argv[1]
src = open(p, encoding='utf-8').read()
if "os.path.lexists(full_dst)" in src:
    print("    (已应用，跳过)"); sys.exit(0)

OLD_RETURN = """      if not line:
        return
      if line != os.path.normpath(line):
"""
NEW_RETURN = """      if not line:
        continue
      if line != os.path.normpath(line):
"""
OLD_LINK = """        os.makedirs(os.path.dirname(full_dst), exist_ok=True)
        os.link(full_src, full_dst, follow_symlinks=False)
"""
NEW_LINK = """        os.makedirs(os.path.dirname(full_dst), exist_ok=True)
        if os.path.lexists(full_dst):
          # Duplicate entry in the partition file list (e.g. a
          # PRODUCT_COPY_FILES destination that collides with a
          # Soong-installed module).  os.link() would raise
          # FileExistsError and abort the image build, so skip it.
          continue
        os.link(full_src, full_dst, follow_symlinks=False)
"""
n1, n2 = src.count(OLD_RETURN), src.count(OLD_LINK)
if n1 != 1 or n2 != 1:
    print("    错误: 锚点不唯一 (return=%d link=%d)，拒绝打补丁" % (n1, n2)); sys.exit(1)
bak = p + ".orig-dupfix"
if not os.path.exists(bak):
    shutil.copy2(p, bak); print("    备份 -> " + bak)
out = src.replace(OLD_RETURN, NEW_RETURN).replace(OLD_LINK, NEW_LINK)
open(p, "w", encoding="utf-8", newline="").write(out)
print("    已打补丁 ✓")
PYEOF
  if grep -q "os.path.lexists(full_dst)" "$BI_FILE"; then say "  验证: 补丁生效 ✓"; else say "  验证: 失败 ✗"; RC=1; fi
fi

# ---------------------------------------------------------------- 修复 2
head2 "修复 2/3: vendor/pixel/gms 的 git-lfs 对象"

if [ ! -d "$LFS_REPO" ]; then
  say "  错误: 找不到 $LFS_REPO"; RC=1
else
  total=$(git -C "$LFS_REPO" lfs ls-files 2>/dev/null | wc -l)
  missing=0
  while read -r f; do
    [ -z "$f" ] && continue
    sz=$(stat -c %s "$LFS_REPO/$f" 2>/dev/null || echo 0)
    [ "$sz" -lt 1000 ] && missing=$((missing + 1))
  done < <(git -C "$LFS_REPO" lfs ls-files 2>/dev/null | awk '{print $3}')

  say "  LFS 跟踪文件: $total 个，未拉取(指针): $missing 个"
  if [ "$missing" -eq 0 ]; then
    say "  状态: 已拉取 ✓"
  elif [ "$CHECK" -eq 1 ]; then
    say "  状态: 有 $missing 个未拉取 ✗（需要 git lfs fetch/checkout）"
  else
    say "  状态: 有 $missing 个未拉取 → 正在拉取"
    remote=$(git -C "$LFS_REPO" remote | head -1)
    say "    远程名: ${remote:-<无>}（注意：裸跑 git lfs pull 默认找 origin，可能失败）"
    git -C "$LFS_REPO" lfs fetch "${remote:-$LFS_REMOTE}" 2>&1 | tail -5 | sed 's/^/    /'
    git -C "$LFS_REPO" lfs checkout 2>&1 | tail -5 | sed 's/^/    /'
    missing2=0
    while read -r f; do
      [ -z "$f" ] && continue
      sz=$(stat -c %s "$LFS_REPO/$f" 2>/dev/null || echo 0)
      [ "$sz" -lt 1000 ] && missing2=$((missing2 + 1))
    done < <(git -C "$LFS_REPO" lfs ls-files 2>/dev/null | awk '{print $3}')
    if [ "$missing2" -eq 0 ]; then say "  验证: 全部拉取完成 ✓"; else say "  验证: 仍有 $missing2 个未拉取 ✗"; RC=1; fi
  fi
fi

# ---------------------------------------------------------------- 修复 3
head2 "修复 3/3: 孤儿 ABI 参考转储"

if [ ! -d "$ABI_DIR" ]; then
  say "  跳过: 目录不存在 $ABI_DIR"
else
  n=$(find "$ABI_DIR" -name "$ABI_NAME" 2>/dev/null | wc -l)
  say "  匹配文件: $n 个 ($ABI_NAME)"
  if [ "$n" -eq 0 ]; then
    say "  状态: 已清理 ✓"
  elif [ "$CHECK" -eq 1 ]; then
    say "  状态: 存在 $n 个孤儿转储 ✗（需要删除）"
    find "$ABI_DIR" -name "$ABI_NAME" 2>/dev/null | sed 's/^/    /'
  else
    say "  状态: 存在 $n 个 → 备份后删除"
    mkdir -p "$ABI_BACKUP"
    while read -r f; do
      rel=${f#"$ABI_DIR"/}
      mkdir -p "$ABI_BACKUP/$(dirname "$rel")"
      cp -a "$f" "$ABI_BACKUP/$rel"
      say "    备份: $rel"
    done < <(find "$ABI_DIR" -name "$ABI_NAME" 2>/dev/null)
    find "$ABI_DIR" -name "$ABI_NAME" -delete
    n2=$(find "$ABI_DIR" -name "$ABI_NAME" 2>/dev/null | wc -l)
    if [ "$n2" -eq 0 ]; then
      say "  验证: 清理完成 ✓（备份在 $ABI_BACKUP）"
    else
      say "  验证: 仍有 $n2 个 ✗"; RC=1
    fi
  fi
fi

# ---------------------------------------------------------------- 汇总
head2 "汇总"
if [ "$CHECK" -eq 1 ]; then
  say "检查完成。要应用修复请不带 --check 运行。"
else
  if [ "$RC" -eq 0 ]; then
    say "三处修复均已就绪 ✓"
    say
    say "接下来可以构建："
    say "  tmux new-session -d -s build17 '/home/Villode/run_build17.sh; exec bash'"
    say "  tmux new-session -d -s ota17   '/home/Villode/run_otapackage.sh; exec bash'"
  else
    say "有修复未成功，请检查上面的 ✗ 项。"
  fi
fi
exit "$RC"
