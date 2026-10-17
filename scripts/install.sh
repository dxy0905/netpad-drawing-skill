#!/usr/bin/env bash
# 画图.skill 一键安装脚本 (Linux / macOS / Windows git-bash 通用)
# 用法:
#   ./install.sh                      # 自动探测本机所有 Agent 并安装(链接模式)
#   ./install.sh --agent claude       # 只装到 Claude Code
#   ./install.sh --agent all          # 装到所有探测到的 Agent
#   ./install.sh --dest /path/skills  # 自定义目标 skills 目录
#   ./install.sh --copy               # 复制模式(不跟随源更新)
#   ./install.sh --uninstall          # 卸载(仅删除链接/副本,不删源)
set -euo pipefail

SKILL_NAME="画图.skill"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="link"
DEST=""
AGENT=""
SRC_OVERRIDE=""
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) MODE="copy"; shift;;
    --link) MODE="link"; shift;;
    --dest) DEST="$2"; shift 2;;
    --agent) AGENT="$2"; shift 2;;
    --source) SRC_OVERRIDE="$2"; shift 2;;
    --uninstall) UNINSTALL=1; shift;;
    -h|--help) sed -n '2,12p' "$0"; exit 0;;
    *) echo "未知参数: $1" >&2; exit 1;;
  esac
done

# 源目录: --source 显式指定 > 仓库根下 > 脚本同级
if [ -n "$SRC_OVERRIDE" ]; then
  [ -d "$SRC_OVERRIDE" ] || { echo "❌ 指定的源目录不存在: $SRC_OVERRIDE" >&2; exit 1; }
  SRC="$(cd "$SRC_OVERRIDE" && pwd)"
elif [ -d "$SCRIPT_DIR/../$SKILL_NAME" ]; then
  SRC="$(cd "$SCRIPT_DIR/.." && pwd)/$SKILL_NAME"
elif [ -d "$SCRIPT_DIR/$SKILL_NAME" ]; then
  SRC="$SCRIPT_DIR/$SKILL_NAME"
else
  echo "❌ 找不到 $SKILL_NAME 源目录（脚本应位于仓库内，或用 --source 指定）" >&2; exit 1
fi

# 探测各 Agent 的 skills 目录
detect_dirs() {
  local dirs=()
  [ -d "$HOME/.claude/skills" ] && dirs+=("$HOME/.claude/skills")
  [ -d "$HOME/.cursor/skills" ] && dirs+=("$HOME/.cursor/skills")
  [ -d "$HOME/.codex/skills" ] && dirs+=("$HOME/.codex/skills")
  [ -n "${CODEX_HOME:-}" ] && [ -d "$CODEX_HOME/skills" ] && dirs+=("$CODEX_HOME/skills")
  # Hermes (Windows / Linux)
  [ -d "$HOME/AppData/Local/hermes/skills" ] && dirs+=("$HOME/AppData/Local/hermes/skills")
  [ -d "$HOME/.local/share/hermes/skills" ] && dirs+=("$HOME/.local/share/hermes/skills")
  [ -d "$HOME/.hermes/skills" ] && dirs+=("$HOME/.hermes/skills")
  printf '%s\n' "${dirs[@]}"
}

resolve_agent_dir() {
  case "$1" in
    claude) echo "$HOME/.claude/skills";;
    cursor) echo "$HOME/.cursor/skills";;
    codex)  if [ -n "${CODEX_HOME:-}" ]; then echo "$CODEX_HOME/skills"; else echo "$HOME/.codex/skills"; fi;;
    hermes) if [ -d "$HOME/AppData/Local/hermes/skills" ]; then echo "$HOME/AppData/Local/hermes/skills"; else echo "$HOME/.hermes/skills"; fi;;
    *) echo "";;
  esac
}

TARGETS=()
if [ -n "$DEST" ]; then
  TARGETS=("$DEST")
elif [ -n "$AGENT" ] && [ "$AGENT" != "all" ]; then
  d="$(resolve_agent_dir "$AGENT")"
  [ -z "$d" ] && { echo "❌ 未知 agent: $AGENT (可选 claude|cursor|codex|hermes|all)" >&2; exit 1; }
  TARGETS=("$d")
else
  while IFS= read -r line; do [ -n "$line" ] && TARGETS+=("$line"); done < <(detect_dirs)
fi

[ ${#TARGETS[@]} -eq 0 ] && { echo "❌ 未探测到任何 Agent skills 目录，请用 --dest 指定" >&2; exit 1; }

echo "源目录: $SRC"
echo "模式: $MODE"
echo ""

IS_MSYS=0
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*) IS_MSYS=1;;
esac

# Windows 下建 junction（无需管理员），类 Unix 用 ln -s
make_link() {
  local src="$1" dst="$2"
  if [ "$IS_MSYS" -eq 1 ] && command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$dst' -Target '$src' | Out-Null" >/dev/null 2>&1 && return 0
  fi
  ln -s "$src" "$dst" 2>/dev/null && return 0
  return 1
}

for t in "${TARGETS[@]}"; do
  link="$t/$SKILL_NAME"
  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -e "$link" ] || [ -L "$link" ]; then
      rm -rf "$link" && echo "🗑  已卸载: $link"
    else
      echo "⏭  无需卸载(不存在): $link"
    fi
    continue
  fi

  if [ ! -d "$t" ]; then
    echo "⚠  跳过(目录不存在): $t"
    continue
  fi

  if [ -e "$link" ] || [ -L "$link" ]; then
    echo "↻  已存在，删除旧版本: $link"
    rm -rf "$link"
  fi

  if [ "$MODE" = "copy" ]; then
    cp -r "$SRC" "$link" && echo "✅ 已复制安装: $link"
  else
    if make_link "$SRC" "$link"; then
      echo "✅ 已链接安装: $link -> $SRC"
    else
      cp -r "$SRC" "$link" && echo "⚠  链接失败，已改为复制安装: $link"
    fi
  fi
done

echo ""
if [ "$UNINSTALL" -eq 1 ]; then
  echo "卸载完成（源目录未删除: $SRC）"
else
  echo "安装完成。触发词: 网络画板 / NetPad / 动态几何课件 / 函数图象 / 3D立体几何 / 课件编号"
  echo "提示: 链接模式下更新源目录即四端同步生效；--copy 模式需手动重装。"
fi
