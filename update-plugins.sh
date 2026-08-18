#!/usr/bin/env bash
# ============================================================
# claude_plugins 一键更新插件脚本
# 用法（在项目根目录执行）:
#   ./update-plugins.sh
#   或免下载: curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.sh | bash
# 作用: 刷新 lui-tools marketplace 缓存 → 更新 dev@lui-tools 插件 → 提示重启
#
# 背景: /plugin update 本身不会刷新 marketplace 元数据，必须先
#       claude plugin marketplace update 拉取远程最新，再更新插件。
# ============================================================

set -euo pipefail

echo "========================================"
echo "  claude_plugins 插件更新"
echo "========================================"

# Step 1: 刷新 marketplace 缓存到远程最新
echo "[INFO] Step 1/2: 刷新 lui-tools marketplace..."
if claude plugin marketplace update lui-tools; then
  echo "[OK] marketplace 已刷新到最新"
else
  echo "[WARN] marketplace 刷新失败，继续尝试更新插件"
fi

# Step 2: 更新已安装插件（project + user scope 都试；未安装的 scope 会提示无插件，忽略）
echo "[INFO] Step 2/2: 更新 dev@lui-tools 插件..."
claude plugin update dev@lui-tools -s project || true
claude plugin update dev@lui-tools -s user || true

echo ""
echo "========================================"
echo "  更新完成!"
echo "========================================"
echo ""
echo "请重启 Claude Code 会话，使新 skill/agent 生效。"
echo "验证: claude plugin list --json | grep dev@lui-tools"
