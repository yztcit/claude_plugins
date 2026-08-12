# ============================================================
# claude_plugins 一键接入脚本 (Windows PowerShell)
# 用法: irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.ps1 | iex
# 在项目根目录执行，自动完成: uv + graphify + 索引 + git hook + 规则注入
# ============================================================

$ErrorActionPreference = "Stop"

function Write-Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red; exit 1 }

# --- 前置检查 ---
Write-Info "检查项目环境..."

if (-not (Test-Path ".git")) {
    Write-Fail "当前目录不是 git 仓库，请在项目根目录执行此脚本"
}

Write-Host ""
Write-Host "========================================"
Write-Host "  claude_plugins 一键接入 (Windows)"
Write-Host "========================================"
Write-Host ""

# --- Step 1: 安装 uv ---
Write-Info "Step 1/7: 检查 uv..."

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $uvVersion = uv --version
    Write-Ok "uv 已安装 ($uvVersion)"
} else {
    Write-Info "安装 uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    # 刷新 PATH
    $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $uvVersion = uv --version
        Write-Ok "uv 安装成功 ($uvVersion)"
    } else {
        Write-Fail "uv 安装失败，请手动安装: https://docs.astral.sh/uv/getting-started/installation/"
    }
}

# --- Step 2: 安装 graphify ---
Write-Info "Step 2/7: 检查 graphify..."

if (Get-Command graphify -ErrorAction SilentlyContinue) {
    Write-Ok "graphify 已安装"
} else {
    Write-Info "安装 graphify..."
    uv tool install graphifyy
    $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
    if (Get-Command graphify -ErrorAction SilentlyContinue) {
        Write-Ok "graphify 安装成功"
    } else {
        Write-Fail "graphify 安装失败"
    }
}

# --- Step 3: 初始化索引 ---
Write-Info "Step 3/7: 初始化图谱索引..."

if ((Test-Path "graphify-out") -and (Get-ChildItem "graphify-out" -ErrorAction SilentlyContinue)) {
    Write-Ok "图谱索引已存在，跳过初始化"
} else {
    Write-Info "首次索引可能需要几分钟..."
    graphify extract . --code-only
    Write-Ok "图谱索引完成"
}

# --- Step 4: 绑定 Git Hook ---
Write-Info "Step 4/7: 绑定 Git Hook (post-commit + post-checkout)..."

graphify hook install
Write-Ok "Git Hook 绑定完成"

# --- Step 5: 配置 .git/info/exclude ---
Write-Info "Step 5/7: 配置 .git/info/exclude..."
$excludePath = ".git\info\exclude"
$excludeMode = if ($env:CLAUDE_EXCLUDE_MODE) { $env:CLAUDE_EXCLUDE_MODE } else { "minimal" }

$excludeDir = Split-Path $excludePath -Parent
if (-not (Test-Path $excludeDir)) {
    New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null
}
if (-not (Test-Path $excludePath)) {
    New-Item -ItemType File -Path $excludePath -Force | Out-Null
}

function Add-ExcludeEntry {
    param([string]$Entry)
    $content = Get-Content $excludePath -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -contains $Entry) {
        return $false
    }
    Add-Content -Path $excludePath -Value $Entry -Encoding UTF8
    return $true
}

$excludeAdded = 0

# 始终添加：自动生成产物
$comment = "# Graphify 图谱索引（自动生成，不提交）"
Add-ExcludeEntry $comment | Out-Null
if (Add-ExcludeEntry "graphify-out/") { $excludeAdded++ }
if (Add-ExcludeEntry ".gitattributes") { $excludeAdded++ }

if ($excludeAdded -gt 0) {
    Write-Ok "已添加 graphify-out/ 和 .gitattributes 到 .git/info/exclude"
} else {
    Write-Ok ".git/info/exclude 已包含自动生成产物排除规则"
}

# 可选：排除 .claude/ 和 CLAUDE.md
if ($excludeMode -eq "all") {
    $optAdded = 0
    if (Add-ExcludeEntry ".claude/") { $optAdded++ }
    if (Add-ExcludeEntry "CLAUDE.md") { $optAdded++ }
    if ($optAdded -gt 0) {
        Write-Ok "已添加 .claude/ 和 CLAUDE.md 到 .git/info/exclude"
    } else {
        Write-Ok ".git/info/exclude 已包含 .claude/ 和 CLAUDE.md"
    }
    Write-Info "提示: 如需团队共享插件配置，可移除 .claude/ 的 exclude 条目"
} else {
    Write-Info "如需同时忽略 .claude/ 和 CLAUDE.md，设置 `$env:CLAUDE_EXCLUDE_MODE='all' 重新运行"
}

# --- Step 6: 生成搜索规则 ---
Write-Info "Step 6/7: 生成搜索规则..."

$rulesDir = ".claude\rules"
$ruleFile = "$rulesDir\search.md"

if (-not (Test-Path $rulesDir)) {
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
}

if (Test-Path $ruleFile) {
    Write-Ok "规则文件已存在，跳过生成"
} else {
    $ruleContent = @"
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
"@

    Set-Content -Path $ruleFile -Value $ruleContent -Encoding UTF8
    Write-Ok "规则文件已生成: $ruleFile"
}

# --- Step 7: 配置 Claude Code 插件 ---
Write-Info "Step 7/7: 配置 Claude Code 插件 marketplace..."

$settingsDir = ".claude"
$settingsFile = "$settingsDir\settings.json"

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

if (Test-Path $settingsFile) {
    $cfg = Get-Content $settingsFile -Raw | ConvertFrom-Json

    # 添加 marketplace
    if (-not $cfg.extraKnownMarketplaces) {
        $cfg | Add-Member -NotePropertyName "extraKnownMarketplaces" -NotePropertyValue @{} -Force
    }
    $cfg.extraKnownMarketplaces | Add-Member -NotePropertyName "lui-tools" -NotePropertyValue @{
        source = @{ source = "github"; repo = "yztcit/claude_plugins" }
    } -Force

    # 添加 enabledPlugins
    if (-not $cfg.enabledPlugins) {
        $cfg | Add-Member -NotePropertyName "enabledPlugins" -NotePropertyValue @{} -Force
    }
    $cfg.enabledPlugins | Add-Member -NotePropertyName "dev@lui-tools" -NotePropertyValue $true -Force

    $cfg | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Ok "settings.json 已更新（marketplace + enabledPlugins）"
} else {
    $settingsContent = @'
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
'@
    Set-Content -Path $settingsFile -Value $settingsContent -Encoding UTF8
    Write-Ok "settings.json 已创建"
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================"
Write-Host "  接入完成!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "已完成的配置:"
Write-Host "  ✓ uv 包管理器"
Write-Host "  ✓ graphify 图谱"
Write-Host "  ✓ AST 索引 (graphify-out/)"
Write-Host "  ✓ Git Hook (自动增量更新)"
Write-Host "  ✓ .git/info/exclude (排除自动生成产物)"
Write-Host "  ✓ 搜索规则 (.claude/rules/search.md)"
Write-Host "  ✓ Claude Code 插件 marketplace"
Write-Host ""
Write-Host "还需要在 Claude Code 中执行一次（仅首次）:"
Write-Host "  /plugin install dev@lui-tools --scope project"
Write-Host ""
Write-Host "之后搜索时会自动优先使用图谱（代码 + 文档 + 规则）。"
Write-Host ""
