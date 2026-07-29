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

# --- Step 5: 配置 .gitignore ---
Write-Info "Step 5/7: 配置 .gitignore..."

$gitignorePath = ".gitignore"
$graphifyEntry = "graphify-out/"

if ((Test-Path $gitignorePath) -and (Select-String -Path $gitignorePath -Pattern $graphifyEntry -SimpleMatch -Quiet)) {
    Write-Ok ".gitignore 已包含 graphify-out/ 排除规则"
} else {
    Add-Content -Path $gitignorePath -Value ""
    Add-Content -Path $gitignorePath -Value "# Graphify 图谱索引（自动生成，不提交）"
    Add-Content -Path $gitignorePath -Value $graphifyEntry
    Write-Ok "已添加 graphify-out/ 到 .gitignore"
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
    Write-Info "探测项目结构..."

    # 扫描源码文件
    $excludeDirs = @("node_modules", ".git", "dist", "build", "graphify-out", ".claude", "vendor", "__pycache__", ".venv", "target", "bin", "obj")
    $extensions = @("*.ts", "*.tsx", "*.vue", "*.js", "*.jsx", "*.py", "*.go", "*.java", "*.rs", "*.swift", "*.rb", "*.php", "*.cs", "*.kt", "*.scala")

    $sourceFiles = Get-ChildItem -Path . -Include $extensions -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $path = $_.FullName
            -not ($excludeDirs | Where-Object { $path -like "*\$_\*" -or $path -like "*/$_/*" })
        } |
        Select-Object -First 200

    if (-not $sourceFiles -or $sourceFiles.Count -eq 0) {
        Write-Warn "未检测到源码文件，使用通用路径配置"
        $paths = @('  - "src/**/*"', '  - "lib/**/*"')
    } else {
        $pathSet = @{}
        foreach ($file in $sourceFiles) {
            $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1).Replace("\", "/")
            $parts = $relativePath.Split("/")
            $dir = if ($parts.Count -gt 1) { $parts[0] } else { "." }
            $ext = $file.Extension.TrimStart(".")
            if ($ext) {
                $key = "$dir $ext"
                $pathSet[$key] = $true
            }
        }
        $paths = $pathSet.Keys | Sort-Object | Select-Object -First 10 | ForEach-Object {
            $d, $e = $_.Split(" ")
            if ($d -eq ".") { "  - `"**/*.$e`"" } else { "  - `"$d/**/*.$e`"" }
        }
    }

    $pathsStr = $paths -join "`n"

    $ruleContent = @"
---
paths:
$pathsStr
---

# Agent 搜索策略：图谱优先

> Graphify 图谱索引代码 + 文档 + 规则，用 AST + 语义索引替代盲搜。

## 搜索优先级

| 优先级 | 方式 | 适用场景 | 命令示例 |
|--------|------|---------|---------|
| 1 | 图谱 | 找文件/符号/依赖/影响范围/文档/规则 | ``graphify query "UserService 在哪里定义"`` |
| 2 | 结构化搜索 | 图谱无结果时的精确查找 | ``grep -rn "symbol" <源码目录>/`` |
| 3 | Read 文件 | 已锁定目标后读内容 | Read tool |

## 搜索流程

1. **先查图谱锁定文件** — ``graphify query "<问题>"`` 获取相关文件列表和关系
2. **再 Read 目标文件** — 只读图谱锁定的文件，不做盲搜式多轮 read
3. **查影响范围** — ``graphify affected "<改动的文件/符号>"`` 了解上下游，避免改一处漏一片

## 适用场景

- 修改前定位受影响的文件范围
- 理解模块间的依赖链路
- 查找 symbol / class / function 定义位置
- 新需求开发前的代码探索
- 查找项目文档、规则、设计决策（如 ``graphify query "P1 数据隔离原则"``）

## 图谱不可用时

若 ``graphify`` 命令不存在或索引未建，按传统方式搜索（find/grep → read）。

## 禁止事项

- 图谱可用时不做多轮关键词盲搜
- 不将 ``graphify-out/`` 目录提交到 git
"@

    Set-Content -Path $ruleFile -Value $ruleContent -Encoding UTF8
    Write-Ok "规则文件已生成: $ruleFile"
    Write-Info "生成的 paths 配置:"
    $paths | ForEach-Object { Write-Host "  $_" }
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
Write-Host "  ✓ .gitignore (排除索引目录)"
Write-Host "  ✓ 搜索规则 (.claude/rules/search.md)"
Write-Host "  ✓ Claude Code 插件 marketplace"
Write-Host ""
Write-Host "还需要在 Claude Code 中执行一次（仅首次）:"
Write-Host "  /plugin install dev@lui-tools --scope project"
Write-Host ""
Write-Host "之后 Agent 搜索时会自动优先使用图谱（代码 + 文档 + 规则）。"
Write-Host ""
