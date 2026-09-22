#!/usr/bin/env bash
# ============================================================
# claude_plugins 一键更新插件脚本
# 用法（在项目根目录执行）:
#   ./update-plugins.sh
#   或免下载: curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.sh | bash
# 作用: 刷新 tal-tools marketplace 缓存 → 更新 dev@tal-tools 插件 → 提示重启
#
# 背景（两条，都踩过）:
#   1. /plugin update 本身不会刷新 marketplace 元数据，必须先
#      `claude plugin marketplace update` 拉取远程最新，再更新插件。
#   2. `claude plugin update` 按 plugin.json 的 version 判「是否最新」。
#      上游改内容时若忘了 bump version，update 会判「已是最新」而静默空转，
#      缓存里留着的还是旧内容，且没有任何报错。
#      故本脚本先比对「源目录 vs 缓存目录」的内容指纹：版本号相同但内容不同
#      → 走卸载重装强制刷新，不依赖上游的版本纪律。
# ============================================================

set -uo pipefail

MKT=tal-tools
PLUGIN=dev
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/$MKT"
SRC="$MARKETPLACE_DIR/plugins/$PLUGIN"
CACHE_ROOT="$HOME/.claude/plugins/cache/$MKT/$PLUGIN"

echo "========================================"
echo "  claude_plugins 插件更新"
echo "========================================"

# 载荷比对：以「源」为准，逐文件校验缓存里是否存在且内容一致。
# 输出差异描述（空 = 一致）。
#
# 为什么以源为准、而不是对两个目录各取一次摘要：缓存目录里会有 Claude Code 的
# 运行时产物（如 .in_use/ 进程标记目录），源里没有 → 各取摘要必然不等 →
# 每次都被判「内容已变」而强制重装。以源为准遍历则天然忽略缓存侧的额外文件。
payload_diff() {
  local src="$1" cache="$2" list
  [ -d "$cache" ] || { echo "缓存目录不存在"; return; }
  list=$(cd "$src" && find . -type f -not -path "./.git/*" | LC_ALL=C sort)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ ! -f "$cache/$f" ]; then
      echo "缺失 $f"
    elif [ "$(shasum -a 256 "$src/$f" | cut -d' ' -f1)" \
       != "$(shasum -a 256 "$cache/$f" | cut -d' ' -f1)" ]; then
      echo "内容不同 $f"
    fi
  done <<< "$list"
}

read_version() {
  local d="$1"
  [ -f "$d/.claude-plugin/plugin.json" ] || { echo ""; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" \
      "$d/.claude-plugin/plugin.json" 2>/dev/null && return
  fi
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$d/.claude-plugin/plugin.json" | head -1
}

# 只处理「已安装」的 scope。强制重装走 install，若对未安装的 scope 执行，
# 会凭空把它装到该 scope（如 user 级 = 所有项目生效），绕过项目级 opt-in。
installed_scopes() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, os, sys
p = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
try:
    d = json.load(open(p))
    scopes = {e.get('scope') for e in d.get('plugins', {}).get(sys.argv[1], [])}
except Exception:
    scopes = set()
print(' '.join(sorted(s for s in scopes if s)) or 'project')" "$PLUGIN@$MKT" 2>/dev/null && return
  fi
  echo "project"
}

# Step 1: 刷新 marketplace 缓存到远程最新
echo "[INFO] Step 1/3: 刷新 $MKT marketplace..."
if claude plugin marketplace update "$MKT"; then
  echo "[OK] marketplace 已刷新到最新"
else
  echo "[WARN] marketplace 刷新失败，继续尝试更新插件"
fi

# Step 2: 判断是否需要强制刷新（版本号没变但内容变了）
FORCE=0
SRC_VER=$(read_version "$SRC")
if [ -n "$SRC_VER" ] && [ -d "$CACHE_ROOT/$SRC_VER" ]; then
  DIFF=$(payload_diff "$SRC" "$CACHE_ROOT/$SRC_VER")
  if [ -n "$DIFF" ]; then
    FORCE=1
    echo "[WARN] 版本号仍为 $SRC_VER 但内容已变（上游未 bump 版本）"
    echo "       常规 update 会判「已是最新」而静默空转 → 改走强制重装"
    echo "$DIFF" | head -5 | sed 's/^/       /'
  else
    echo "[OK] 缓存内容与源一致（版本 $SRC_VER）"
  fi
fi

# Step 3: 更新/强制重装（只动已安装的 scope）
SCOPES=$(installed_scopes)
echo "[INFO] Step 3/3: 更新 $PLUGIN@$MKT（scope: $SCOPES）..."
for scope in $SCOPES; do
  if [ "$FORCE" = "1" ]; then
    claude plugin uninstall "$PLUGIN@$MKT" -s "$scope" >/dev/null 2>&1 || true
    claude plugin install "$PLUGIN@$MKT" -s "$scope" 2>&1 | tail -1 || true
  else
    claude plugin update "$PLUGIN@$MKT" -s "$scope" 2>&1 | tail -1 || true
  fi
done

echo ""
echo "========================================"
echo "  更新完成!"
echo "========================================"
echo ""
echo "请重启 Claude Code 会话，使新 skill/agent 生效。"
echo "验证: claude plugin list --json | grep $PLUGIN@$MKT"
