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
info "Step 1/6: 检查 uv..."

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
info "Step 2/6: 检查 graphify..."

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
info "Step 3/6: 初始化代码图谱索引..."

if [ -d "graphify" ] && [ "$(ls -A graphify/ 2>/dev/null)" ]; then
  ok "图谱索引已存在，跳过初始化"
else
  info "首次索引可能需要几分钟..."
  graphify init
  ok "图谱索引完成"
fi

# --- Step 4: 绑定 Git Hook ---
info "Step 4/6: 绑定 Git Hook (post-commit + post-checkout)..."

graphify hook install
ok "Git Hook 绑定完成"

# --- Step 5: 配置 .gitignore ---
info "Step 5/6: 配置 .gitignore..."

GITIGNORE=".gitignore"
GRAPHIFY_ENTRY="graphify/"

if [ -f "$GITIGNORE" ] && grep -qF "$GRAPHIFY_ENTRY" "$GITIGNORE" 2>/dev/null; then
  ok ".gitignore 已包含 graphify/ 排除规则"
else
  {
    echo ""
    echo "# Graphify 代码图谱索引（自动生成，不提交）"
    echo "$GRAPHIFY_ENTRY"
  } >> "$GITIGNORE"
  ok "已添加 graphify/ 到 .gitignore"
fi

# --- Step 6: 生成搜索规则 ---
info "Step 6/6: 生成代码搜索规则..."

RULES_DIR=".claude/rules"
RULE_FILE="$RULES_DIR/code-search.md"

mkdir -p "$RULES_DIR"

if [ -f "$RULE_FILE" ]; then
  ok "规则文件已存在，跳过生成"
else
  # 探测项目源码结构
  info "探测项目结构..."

  PATHS=""

  # 扫描各目录的源码文件，统计目录+扩展名
  # 排除常见非源码目录
  EXCLUDE_DIRS="node_modules|\.git|dist|build|graphify|\.claude|vendor|__pycache__|\.venv|target|bin|obj"

  # 找源码文件，统计 top 目录 + 扩展名组合
  SCAN_RESULT=$(find . -type f \( \
    -name "*.ts" -o -name "*.tsx" -o -name "*.vue" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.rs" -o -name "*.swift" \
    -o -name "*.rb" -o -name "*.php" -o -name "*.cs" -o -name "*.kt" -o -name "*.scala" \
  \) -not -path "*/node_modules/*" \
     -not -path "*/.git/*" \
     -not -path "*/dist/*" \
     -not -path "*/build/*" \
     -not -path "*/graphify/*" \
     -not -path "*/.claude/*" \
     -not -path "*/vendor/*" \
     -not -path "*/__pycache__/*" \
     -not -path "*/.venv/*" \
     -not -path "*/target/*" \
     -not -path "*/bin/*" \
     -not -path "*/obj/*" \
    2>/dev/null | head -200)

  if [ -z "$SCAN_RESULT" ]; then
    warn "未检测到源码文件，使用通用路径配置"
    PATHS='  - "src/**/*"\n  - "lib/**/*"'
  else
    # 提取一级目录 + 扩展名，去重
    PATHS=$(echo "$SCAN_RESULT" | \
      sed 's|^\./||' | \
      awk -F'/' '{
        if (NF > 1) dir = $1; else dir = ".";
        n = split($NF, a, ".");
        if (n > 1) ext = a[n]; else ext = "";
        if (ext != "") print dir " " ext
      }' | \
      sort -u | \
      awk '{
        if ($1 == ".") printf "  - \"**/*." $2 "\"\n";
        else printf "  - \"" $1 "/**/*." $2 "\"\n";
      }' | \
      sort -u | \
      head -10)
  fi

  cat > "$RULE_FILE" << RULEEOF
---
paths:
$(echo -e "$PATHS")
---

# Agent 搜索策略：代码图谱优先

## 搜索优先级

| 优先级 | 方式 | 适用场景 | 命令示例 |
|--------|------|---------|---------|
| 1 | 代码图谱 | 找文件/符号/依赖关系 | \`graphify search "UserService"\` |
| 2 | 结构化搜索 | 图谱无结果时的精确查找 | \`grep -rn "symbol" <源码目录>/\` |
| 3 | Read 文件 | 已锁定目标后读内容 | Read tool |

## 搜索流程

1. **先查图谱锁定文件** — \`graphify search "<关键词>"\` 获取相关文件列表和依赖关系
2. **再 Read 目标文件** — 只读图谱锁定的文件，不做盲搜式多轮 read
3. **查依赖关系** — \`graphify deps <file>\` 了解上下游引用，避免改一处漏一片

## 适用场景

- 修改前定位受影响的文件范围
- 理解模块间的依赖链路
- 查找 symbol / class / function 定义位置
- 新需求开发前的代码探索

## 图谱不可用时

若 \`graphify\` 命令不存在或索引未建，按传统方式搜索（find/grep → read）。

## 禁止事项

- 图谱可用时不做多轮关键词盲搜
- 不将 \`graphify/\` 目录提交到 git
RULEEOF

  ok "规则文件已生成: $RULE_FILE"
  info "生成的 paths 配置:"
  echo -e "$PATHS" | sed 's/^/  /'
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
echo "  ✓ AST 索引 (graphify/)"
echo "  ✓ Git Hook (自动增量更新)"
echo "  ✓ .gitignore (排除索引目录)"
echo "  ✓ 搜索规则 (.claude/rules/code-search.md)"
echo ""
echo "还需要在 Claude Code 中执行:"
echo "  /plugin install dev@lui-tools"
echo ""
echo "之后 Agent 搜索代码时会自动优先使用图谱。"
echo ""
