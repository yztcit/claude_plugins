#!/usr/bin/env bash
# ============================================================
# 存量迁移：marketplace 名 lui-tools → tal-tools
# 用法:
#   ./migrate-lui-tools.sh --dry-run   # 只打印计划，不改任何东西
#   ./migrate-lui-tools.sh             # 执行
#
# 为什么需要这个脚本:
#   官方 marketplace.json 的 `renames` 字段只覆盖**插件改名**（同一 marketplace
#   内的插件重命名），覆盖不了 **marketplace 自身改名**。2026-09 本仓库把
#   marketplace 从 lui-tools 改名为 tal-tools 时没有官方迁移通道，存量用户会卡在
#   半迁移态：settings 里写着新名但从未真正注册（目录不存在），插件仍挂在旧名下。
#
# 本脚本做的事（等于手工迁移的标准动作）:
#   备份配置 → 移除旧注册 → 注册新名 → 逐项目重装插件 → 改写项目 settings
#
# 注意: `claude plugin marketplace remove` 会**连带卸载**该 marketplace 下的插件
#       并删除其目录（不只是解注册），所以必须先枚举受影响项目，再移除、再重装。
# ============================================================

set -uo pipefail

OLD=lui-tools
NEW=tal-tools
REPO=yztcit/claude_plugins
PLUGIN=dev
DRY=0

[ "${1:-}" = "--dry-run" ] && DRY=1

CLAUDE_DIR="$HOME/.claude"
KNOWN="$CLAUDE_DIR/plugins/known_marketplaces.json"
INSTALLED="$CLAUDE_DIR/plugins/installed_plugins.json"
USER_SETTINGS="$CLAUDE_DIR/settings.json"

echo "========================================"
echo "  marketplace 迁移：$OLD → $NEW"
[ "$DRY" = "1" ] && echo "  （dry-run：只打印计划，不做改动）"
echo "========================================"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] 需要 python3（用于读写配置 JSON）"; exit 1
fi

# ---- 1. 判断是否真的需要迁移 ----
if ! python3 -c "
import json,sys
try: d=json.load(open('$KNOWN'))
except Exception: sys.exit(1)
sys.exit(0 if '$OLD' in d else 1)"; then
  echo "[OK] 未注册 $OLD，无需迁移。"
  exit 0
fi
echo "[INFO] 检测到旧注册 $OLD"

# ---- 2. 枚举受影响项目 ----
PROJECTS=$(python3 - <<EOF
import json
try:
    d = json.load(open("$INSTALLED"))
except Exception:
    d = {}
paths = sorted({e.get("projectPath") for e in d.get("plugins", {}).get("$PLUGIN@$OLD", []) if e.get("projectPath")})
print("\n".join(paths))
EOF
)

echo "[INFO] 受影响项目："
if [ -z "$PROJECTS" ]; then
  echo "       （无 —— 只迁移 marketplace 注册本身）"
else
  echo "$PROJECTS" | sed 's/^/       - /'
fi

# ---- 3. 备份 ----
STAMP=$(date +%Y%m%d%H%M%S)
BACKUP="$CLAUDE_DIR/plugins/_migrate-backup-$STAMP"
if [ "$DRY" = "1" ]; then
  echo "[PLAN] 备份配置到 $BACKUP"
else
  mkdir -p "$BACKUP"
  cp "$KNOWN" "$BACKUP/known_marketplaces.json" 2>/dev/null || true
  cp "$INSTALLED" "$BACKUP/installed_plugins.json" 2>/dev/null || true
  cp "$USER_SETTINGS" "$BACKUP/user-settings.json" 2>/dev/null || true
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -f "$p/.claude/settings.json" ] || continue
    cp "$p/.claude/settings.json" "$BACKUP/$(echo "$p" | tr '/' '_')-settings.json" 2>/dev/null || true
  done <<< "$PROJECTS"
  echo "[OK] 已备份到 $BACKUP"
fi

# ---- 4. 移除旧注册 / 5. 注册新名 ----
if [ "$DRY" = "1" ]; then
  echo "[PLAN] claude plugin marketplace remove $OLD   # 会连带卸载其下插件"
  echo "[PLAN] claude plugin marketplace add $REPO --scope user"
else
  claude plugin marketplace remove "$OLD" || true
  claude plugin marketplace add "$REPO" --scope user || true
fi

# ---- 6. 逐项目重装 + 改写 settings ----
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -d "$p" ] || { echo "[WARN] 项目不存在，跳过：$p"; continue; }
  if [ "$DRY" = "1" ]; then
    echo "[PLAN] ($p) 重装 $PLUGIN@$NEW -s project + 改写 settings"
    continue
  fi
  ( cd "$p" && claude plugin install "$PLUGIN@$NEW" -s project >/dev/null 2>&1 ) \
    && echo "[OK] 已重装：$p" || echo "[WARN] 重装失败，请手动处理：$p"
  python3 - "$p" "$OLD" "$NEW" "$REPO" <<'EOF'
import json, pathlib, sys
proj, old, new, repo = sys.argv[1:5]
f = pathlib.Path(proj) / ".claude" / "settings.json"
if not f.exists():
    sys.exit(0)
cfg = json.loads(f.read_text())
ep = {k: v for k, v in cfg.get("enabledPlugins", {}).items() if k != f"dev@{old}"}
ep[f"dev@{new}"] = True
cfg["enabledPlugins"] = ep
em = {k: v for k, v in cfg.get("extraKnownMarketplaces", {}).items() if k != old}
em[new] = {"source": {"source": "github", "repo": repo}}
cfg["extraKnownMarketplaces"] = em
f.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
EOF
done <<< "$PROJECTS"

echo ""
if [ "$DRY" = "1" ]; then
  echo "以上为计划。去掉 --dry-run 执行。"
else
  echo "迁移完成。请重启 Claude Code 会话生效。"
  echo "验证: claude plugin list"
  echo "备份: $BACKUP（确认无误后可删）"
fi
