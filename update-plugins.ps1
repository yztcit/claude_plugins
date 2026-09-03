# ============================================================
# claude_plugins 一键更新插件脚本 (Windows PowerShell)
# 用法（在项目根目录执行）:
#   ./update-plugins.ps1
#   或免下载: irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.ps1 | iex
# 作用: 刷新 tal-tools marketplace 缓存 → 更新 dev@tal-tools 插件 → 提示重启
#
# 背景: /plugin update 本身不会刷新 marketplace 元数据，必须先
#       claude plugin marketplace update 拉取远程最新，再更新插件。
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  claude_plugins 插件更新"
Write-Host "========================================"

# Step 1: 刷新 marketplace 缓存到远程最新
Write-Host "[INFO] Step 1/2: 刷新 tal-tools marketplace..."
try {
    claude plugin marketplace update tal-tools
    Write-Host "[OK] marketplace 已刷新到最新"
} catch {
    Write-Host "[WARN] marketplace 刷新失败，继续尝试更新插件"
}

# Step 2: 更新已安装插件（project + user scope 都试；未安装的 scope 会提示无插件，忽略）
Write-Host "[INFO] Step 2/2: 更新 dev@tal-tools 插件..."
claude plugin update dev@tal-tools -s project
claude plugin update dev@tal-tools -s user

Write-Host ""
Write-Host "========================================"
Write-Host "  更新完成!"
Write-Host "========================================"
Write-Host ""
Write-Host "请重启 Claude Code 会话，使新 skill/agent 生效。"
Write-Host "验证: claude plugin list --json | Select-String dev@tal-tools"
