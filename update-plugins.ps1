# ============================================================
# claude_plugins 一键更新插件脚本 (Windows PowerShell)
# 用法（在项目根目录执行）:
#   ./update-plugins.ps1
#   或免下载: irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.ps1 | iex
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
#
# 注：本脚本与 update-plugins.sh 逻辑等价；指纹计算失败时降级为原有的
#     「直接 update」行为（宁可不修，不可报错中断）。
# ============================================================

$ErrorActionPreference = "Continue"

$Mkt = "tal-tools"
$Plugin = "dev"
$MarketplaceDir = Join-Path $HOME ".claude/plugins/marketplaces/$Mkt"
$Src = Join-Path $MarketplaceDir "plugins/$Plugin"
$CacheRoot = Join-Path $HOME ".claude/plugins/cache/$Mkt/$Plugin"

Write-Host "========================================"
Write-Host "  claude_plugins 插件更新"
Write-Host "========================================"

# 载荷比对：以「源」为准，逐文件校验缓存里是否存在且内容一致。
# 输出差异描述（空 = 一致）。
#
# 为什么以源为准、而不是对两个目录各取一次摘要：缓存目录里会有 Claude Code 的
# 运行时产物（如 .in_use 进程标记），源里没有 → 各取摘要必然不等 →
# 每次都被判「内容已变」而强制重装。以源为准遍历则天然忽略缓存侧的额外文件。
function Get-PayloadDiff {
    param([string]$Src, [string]$Cache)
    if (-not (Test-Path $Cache)) { return "缓存目录不存在" }
    try {
        $files = Get-ChildItem -Path $Src -Recurse -File |
                 Where-Object { $_.FullName -notmatch "\\\.git\\" }
        $diffs = foreach ($f in $files) {
            $rel = $f.FullName.Substring($Src.Length).TrimStart("\", "/")
            $target = Join-Path $Cache $rel
            if (-not (Test-Path $target -PathType Leaf)) {
                "缺失 $rel"
            } elseif ((Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash -ne
                      (Get-FileHash -Path $target -Algorithm SHA256).Hash) {
                "内容不同 $rel"
            }
        }
        return (($diffs | Where-Object { $_ }) -join "; ")
    } catch {
        return ""
    }
}

function Get-PluginVersion {
    param([string]$Dir)
    $manifest = Join-Path $Dir ".claude-plugin/plugin.json"
    if (-not (Test-Path $manifest)) { return "" }
    try {
        return (Get-Content $manifest -Raw | ConvertFrom-Json).version
    } catch {
        return ""
    }
}

function Get-InstalledScopes {
    param([string]$Key)
    $path = Join-Path $HOME ".claude/plugins/installed_plugins.json"
    if (-not (Test-Path $path)) { return @("project") }
    try {
        $data = Get-Content $path -Raw | ConvertFrom-Json
        $entry = $data.plugins.$Key
        if (-not $entry) { return @("project") }
        $scopes = @($entry | ForEach-Object { $_.scope } | Where-Object { $_ } | Sort-Object -Unique)
        if ($scopes.Count -eq 0) { return @("project") }
        return $scopes
    } catch {
        return @("project")
    }
}

# Step 1: 刷新 marketplace 缓存到远程最新
Write-Host "[INFO] Step 1/3: 刷新 $Mkt marketplace..."
try {
    claude plugin marketplace update $Mkt
    Write-Host "[OK] marketplace 已刷新到最新"
} catch {
    Write-Host "[WARN] marketplace 刷新失败，继续尝试更新插件"
}

# Step 2: 判断是否需要强制刷新（版本号没变但内容变了）
$Force = $false
$SrcVer = Get-PluginVersion $Src
$CacheVerDir = Join-Path $CacheRoot $SrcVer
if ($SrcVer -and (Test-Path $CacheVerDir)) {
    $diff = Get-PayloadDiff $Src $CacheVerDir
    if ($diff) {
        $Force = $true
        Write-Host "[WARN] 版本号仍为 $SrcVer 但内容已变（上游未 bump 版本）"
        Write-Host "       常规 update 会判「已是最新」而静默空转 → 改走强制重装"
        Write-Host "       $diff"
    } else {
        Write-Host "[OK] 缓存内容与源一致（版本 $SrcVer）"
    }
}

# Step 3: 更新/强制重装（只动已安装的 scope）
$scopes = Get-InstalledScopes "$Plugin@$Mkt"
Write-Host "[INFO] Step 3/3: 更新 $Plugin@$Mkt（scope: $($scopes -join ' ')）..."
foreach ($scope in $scopes) {
    if ($Force) {
        claude plugin uninstall "$Plugin@$Mkt" -s $scope 2>$null | Out-Null
        claude plugin install "$Plugin@$Mkt" -s $scope
    } else {
        claude plugin update "$Plugin@$Mkt" -s $scope
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "  更新完成!"
Write-Host "========================================"
Write-Host ""
Write-Host "请重启 Claude Code 会话，使新 skill/agent 生效。"
Write-Host "验证: claude plugin list --json | Select-String $Plugin@$Mkt"
