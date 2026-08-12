#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# claude_plugins 一键接入脚本
# 用法: curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.sh | bash
# 在项目根目录执行，自动完成: uv + graphify + 索引 + git hook + 规则注入
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# --- 前置检查 ---
info "检查项目环境..."

# OS 检测
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
  Darwin) info "检测到系统: macOS" ;;
  Linux)  info "检测到系统: Linux" ;;
  MINGW*|MSYS*|CYGWIN*)
    echo ""
    echo "Windows 请使用 PowerShell 一键脚本："
    echo ""
    echo "  irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.ps1 | iex"
    echo ""
    exit 0
    ;;
  *) warn "未识别的系统: $OS_TYPE，尝试继续..." ;;
esac

if [ ! -d ".git" ]; then
  fail "当前目录不是 git 仓库，请在项目根目录执行此脚本"
fi

# 检测项目根目录
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if [ "$(pwd)" != "$PROJECT_ROOT" ]; then
  warn "当前目录不是 git 根目录，建议在 $PROJECT_ROOT 执行"
fi

echo ""
echo "========================================"
echo "  claude_plugins 一键接入"
echo "========================================"
echo ""

# --- Step 1: 安装 uv ---
info "Step 1/7: 检查 uv..."

if command -v uv &>/dev/null; then
  ok "uv 已安装 ($(uv --version))"
else
  info "安装 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # 加载 PATH（uv 默认装到 ~/.local/bin 或 ~/.cargo/bin）
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if command -v uv &>/dev/null; then
    ok "uv 安装成功 ($(uv --version))"
  else
    fail "uv 安装失败，请手动安装: https://docs.astral.sh/uv/getting-started/installation/"
  fi
fi

# --- Step 2: 安装 graphify ---
info "Step 2/7: 检查 graphify..."

if command -v graphify &>/dev/null; then
  ok "graphify 已安装"
else
  info "安装 graphify..."
  uv tool install graphifyy
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if command -v graphify &>/dev/null; then
    ok "graphify 安装成功"
  else
    fail "graphify 安装失败"
  fi
fi

# --- Step 3: 初始化索引 ---
info "Step 3/7: 初始化代码图谱索引..."

if [ -d "graphify-out" ] && [ "$(ls -A graphify-out/ 2>/dev/null)" ]; then
  ok "图谱索引已存在，跳过初始化"
else
  info "首次索引可能需要几分钟..."
  graphify extract . --code-only
  ok "图谱索引完成"
fi

# --- Step 4: 绑定 Git Hook ---
info "Step 4/7: 绑定 Git Hook (post-commit + post-checkout)..."

graphify hook install
ok "Git Hook 绑定完成"

# --- Step 5: 配置 .git/info/exclude ---
info "Step 5/7: 配置 .git/info/exclude..."
EXCLUDE_FILE=".git/info/exclude"
EXCLUDE_MODE="${CLAUDE_EXCLUDE_MODE:-minimal}"

mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"

add_exclude_entry() {
  local entry="$1"
  if ! grep -qxF "$entry" "$EXCLUDE_FILE" 2>/dev/null; then
    echo "$entry" >> "$EXCLUDE_FILE"
    return 0
  fi
  return 1
}

EXCLUDE_ADDED=0

# 始终添加：自动生成产物
if ! grep -qxF "# Graphify 图谱索引（自动生成，不提交）" "$EXCLUDE_FILE" 2>/dev/null; then
  echo "# Graphify 图谱索引（自动生成，不提交）" >> "$EXCLUDE_FILE"
fi
if add_exclude_entry "graphify-out/"; then ((EXCLUDE_ADDED++)) || true; fi
if add_exclude_entry ".gitattributes"; then ((EXCLUDE_ADDED++)) || true; fi

if [ "$EXCLUDE_ADDED" -gt 0 ]; then
  ok "已添加 graphify-out/ 和 .gitattributes 到 .git/info/exclude"
else
  ok ".git/info/exclude 已包含自动生成产物排除规则"
fi

# 可选：排除 .claude/ 和 CLAUDE.md
if [ "$EXCLUDE_MODE" = "all" ]; then
  OPT_ADDED=0
  if add_exclude_entry ".claude/"; then ((OPT_ADDED++)) || true; fi
  if add_exclude_entry "CLAUDE.md"; then ((OPT_ADDED++)) || true; fi
  if [ "$OPT_ADDED" -gt 0 ]; then
    ok "已添加 .claude/ 和 CLAUDE.md 到 .git/info/exclude"
  else
    ok ".git/info/exclude 已包含 .claude/ 和 CLAUDE.md"
  fi
  info "提示: 如需团队共享插件配置，可移除 .claude/ 的 exclude 条目"
else
  info "如需同时忽略 .claude/ 和 CLAUDE.md，设置 CLAUDE_EXCLUDE_MODE=all 重新运行"
fi

# --- Step 6: 生成搜索规则 ---
info "Step 6/7: 生成搜索规则..."

RULES_DIR=".claude/rules"
RULE_FILE="$RULES_DIR/search.md"

mkdir -p "$RULES_DIR"

if [ -f "$RULE_FILE" ]; then
  ok "规则文件已存在，跳过生成"
else
  cat > "$RULE_FILE" << 'RULEEOF'
# 搜索策略：图谱优先，按查询类型分派

> Graphify 图谱索引代码 + 文档 + 规则，用 AST + 语义索引替代盲搜。

## 核心命令

- `graphify query "问题"` → 自然语言查询，定位相关代码/文档/规则
- `graphify affected "X"` → 反向遍历，找出受 X 影响的所有节点
- `graphify explain "X"` → 解释某节点及其邻居关系
- `graphify path "A" "B"` → 两个节点间的最短路径
- `graphify god-nodes` → 列出连接最多的架构枢纽
- `graphify update .` → 增量更新图谱（无需 LLM）
- `graphify extract .` → 全量重建图谱（需 LLM API key）

## 搜索方式选择（按查询类型分派）

**不要无条件先查图谱。** 工具取决于查询类型：

| 查询类型 | 首选工具 | 何时用 |
|---------|---------|--------|
| 发现型（目标未知/模糊） | `graphify query "问题"` | 不知道符号/文件在哪，或找相关文档/规则 |
| 验证型（目标确切） | `grep -rn "symbol" <源码目录>/` | 已知符号名/文件名/字符串，精确确认位置 |
| 影响分析（改代码前） | `graphify affected "文件/符号"` | 改动前查上下游，避免改一处漏一片 |
| 依赖/调用关系 | `graphify explain "X"` / `path "A" "B"` | 理解调用链、依赖方向 |
| 读文件内容 | Read tool | 已锁定目标后读内容 |

`graphify query` 输出是节点列表，会占用上下文 token，仅用于模糊定位。注意窄化：
- `--budget` 控制输出 token 预算，防止截断漏掉答案
- `context_filter=['call']` 收窄遍历范围
- `get_node <符号>` 精确取单个节点，避免整列表倾倒

## 搜索流程

1. 目标不明确 → 先 `graphify query` 锁定文件，再 Read
2. 目标明确 → 直接 grep 定位或 Read，不需要先查图谱
3. 改代码前 → `graphify affected` 查影响范围，避免改一处漏一片

## 适用场景

- 修改前定位受影响的文件范围
- 理解模块间的依赖链路
- 查找 symbol / class / function 定义位置
- 新需求开发前的代码探索
- 查找项目文档、规则、设计决策

## 图谱不可用时

若 `graphify` 命令不存在或索引未建，按传统方式搜索（find/grep → read）。

## 禁止事项

- ❌ 目标不明确时跳过图谱，做多轮关键词盲搜（先 `graphify query` 一次定位）
- ❌ 不将 `graphify-out/` 目录提交到 git
- ⚠️ 目标已明确时仍先 `graphify` 再 grep，是仪式性前置，浪费 token
RULEEOF

  ok "规则文件已生成: $RULE_FILE"
fi

# --- Step 7: 配置 Claude Code 插件 ---
info "Step 7/7: 配置 Claude Code 插件 marketplace..."

SETTINGS_FILE=".claude/settings.json"
mkdir -p ".claude"

if [ -f "$SETTINGS_FILE" ]; then
  # 用 python3 合并 JSON，保留已有配置
  python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    cfg = json.load(f)

# 添加 marketplace
cfg.setdefault('extraKnownMarketplaces', {})
cfg['extraKnownMarketplaces']['lui-tools'] = {
    'source': {'source': 'github', 'repo': 'yztcit/claude_plugins'}
}

# 添加 enabledPlugins
cfg.setdefault('enabledPlugins', {})
cfg['enabledPlugins']['dev@lui-tools'] = True

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
" 2>/dev/null
  if [ $? -eq 0 ]; then
    ok "settings.json 已更新（marketplace + enabledPlugins）"
  else
    warn "settings.json 更新失败，请手动添加 marketplace 配置"
  fi
else
  cat > "$SETTINGS_FILE" << 'SETTINGSEOF'
{
  "extraKnownMarketplaces": {
    "lui-tools": {
      "source": {
        "source": "github",
        "repo": "yztcit/claude_plugins"
      }
    }
  },
  "enabledPlugins": {
    "dev@lui-tools": true
  }
}
SETTINGSEOF
  ok "settings.json 已创建"
fi

# --- 完成 ---
echo ""
echo "========================================"
echo -e "  ${GREEN}接入完成!${NC}"
echo "========================================"
echo ""
echo "已完成的配置:"
echo "  ✓ uv 包管理器"
echo "  ✓ graphify 代码图谱"
echo "  ✓ AST 索引 (graphify-out/)"
echo "  ✓ Git Hook (自动增量更新)"
echo "  ✓ .git/info/exclude (排除自动生成产物)"
echo "  ✓ 搜索规则 (.claude/rules/search.md)"
echo "  ✓ Claude Code 插件 marketplace"
echo ""
echo "还需要在 Claude Code 中执行一次（仅首次）:"
echo "  /plugin install dev@lui-tools --scope project"
echo ""
echo "之后搜索代码时会自动优先使用图谱（代码 + 文档 + 规则）。"
echo ""
