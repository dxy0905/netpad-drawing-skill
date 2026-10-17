#!/usr/bin/env bash
# 画图.skill 发布同步脚本：真源目录 → GitHub 仓库 → 推送
# 用法:
#   bash scripts/sync-publish.sh                          # 用默认真源
#   bash scripts/sync-publish.sh "D:/path/to/画图.skill"   # 指定真源
#   bash scripts/sync-publish.sh --dry-run                # 只看差异不推送
set -euo pipefail

SKILL_NAME="画图.skill"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SRC="D:/邱数智方/教育部/灵动数图项目/$SKILL_NAME"

SRC="$DEFAULT_SRC"
DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1;;
    -h|--help) sed -n '2,8p' "$0"; exit 0;;
    *) SRC="$arg";;
  esac
done

# 路径规范化（MSYS /d/... 与 D:/... 互通）
[ -d "$SRC" ] || { echo "❌ 真源目录不存在: $SRC" >&2; exit 1; }
DST="$REPO_DIR/$SKILL_NAME"
[ -d "$REPO_DIR/.git" ] || { echo "❌ 不是 git 仓库: $REPO_DIR" >&2; exit 1; }

echo "真源: $SRC"
echo "仓库: $DST"
echo ""

# 差异预览（按文件 md5 比较）
diff_count=0
while IFS= read -r rel; do
  s="$SRC/$rel"; d="$DST/$rel"
  if [ ! -f "$d" ]; then echo "  + 新增 $rel"; diff_count=$((diff_count+1));
  elif ! cmp -s "$s" "$d"; then echo "  ~ 变更 $rel"; diff_count=$((diff_count+1)); fi
done < <(cd "$SRC" && find . -type f | sed 's|^\./||' | sort)
# 检测目标端多余文件
if [ -d "$DST" ]; then
  while IFS= read -r rel; do
    [ -f "$SRC/$rel" ] || { echo "  - 多余 $rel"; diff_count=$((diff_count+1)); }
  done < <(cd "$DST" && find . -type f | sed 's|^\./||' | sort)
fi

if [ "$diff_count" -eq 0 ]; then
  echo "✅ 真源与仓库完全一致，无需同步"
  exit 0
fi

echo ""
echo "共 $diff_count 处差异"
if [ "$DRY" -eq 1 ]; then
  echo "(--dry-run: 未做任何修改)"; exit 0
fi

# 同步：整目录镜像（删除仓库旧副本再复制，避免残留）
rm -rf "$DST"
mkdir -p "$DST"
cp -r "$SRC/." "$DST/"
echo "✅ 已同步真源 → 仓库"

cd "$REPO_DIR"
git add -A
if git diff --cached --quiet; then
  echo "无需提交"; exit 0
fi
STAMP="$(date '+%Y-%m-%d %H:%M')"
git commit -q -m "同步真源更新 ($STAMP)

源: $SRC
差异: $diff_count 处文件"
echo "✅ 已提交: $(git log --oneline -1)"

# 推送（大陆网络注意：DNS 常把 github.com 解析到被封IP，优先用 SSH 通道）
for i in 1 2 3; do
  err=$(git push origin main 2>&1) && {
    echo "✅ 已推送到 GitHub: https://github.com/dxy0905/netpad-drawing-skill"
    exit 0
  }
  echo "⚠ 第 $i 次推送失败: $(echo "$err" | tail -1)"
  # 连续两次失败就提示切 SSH（DNS污染/443重置的根治办法）
  if [ "$i" -eq 2 ]; then
    echo "  提示: 若为 DNS 污染/连接重置，执行:"
    echo "  git remote set-url origin ssh://git@ssh.github.com:443/dxy0905/netpad-drawing-skill.git"
  fi
  [ "$i" -lt 3 ] && sleep 5
done
echo "❌ 推送三次均失败（本地已提交，可稍后手动 git push）" >&2
exit 1
