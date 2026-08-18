---
name: graphify-search
description: 一键接入 Graphify 图谱：安装工具、初始化索引、绑定 git hook、注入搜索规则
---

# Graphify 图谱接入

为项目接入 AST 图谱索引（代码 + 文档 + 规则），让 Agent 搜索时精准定位而非盲搜关键词，节省约 20% token 消耗。

## 前置检查

1. 检查 `graphify` 是否已安装：`graphify --version`
2. 检查索引是否已建：`ls graphify-out/` 目录是否存在

如果都已就绪，跳到「注入规则」步骤。

## Step 1: 安装 uv（如未安装）

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

安装后验证：`uv --version`

## Step 2: 安装 graphify

```bash
uv tool install graphifyy
```

安装后验证：`graphify --version`

## Step 3: 初始化索引

```bash
graphify extract . --code-only
```

在项目根目录生成 `graphify-out/` 目录，包含 AST 索引数据。`--code-only` 只索引代码文件（纯本地 AST，无需 API key）。如需对文档/图片做语义分析，去掉 `--code-only` 并设置对应的 LLM API key。

## Step 4: 绑定 Git Hook（增量更新）

```bash
graphify hook install
```

绑定 `post-commit` + `post-checkout`，commit 后自动增量更新图谱，checkout 后自动切换分支图谱。

## Step 5: 配置 .gitignore

确保 `.gitignore` 包含：

```
# Graphify 图谱索引（自动生成，不提交）
graphify-out/
```

## Step 6: 注入搜索规则

### 6.1 生成规则文件

把与本 SKILL.md 同目录的 `search-rule.md`（规则唯一维护源）内容**原样**写入项目 `.claude/rules/search.md`（不存在才创建）：

1. `mkdir -p .claude/rules`
2. 用 Read 读取本 skill 目录下的 `search-rule.md`
3. 把其内容写入 `.claude/rules/search.md`

> **规则单源维护**：搜索规则全文只维护 `search-rule.md` 一份（`setup.sh` / `setup.ps1` 也是通过下载同一个文件生成规则，不内嵌副本）。**不要**在本 SKILL.md 或脚本里再复制全文，改规则只改 `search-rule.md`。

## Step 7: 配置 Claude Code 插件 marketplace

在 `.claude/settings.json` 中添加 marketplace 配置（如已有则合并，不覆盖）：

```json
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
```

然后在 Claude Code 中执行一次 `/plugin install dev@lui-tools --scope project`。

## 验证

执行 `graphify query "一个你知道存在的类名"`，应返回包含该类的文件列表。

## 效果

- 搜索从多轮盲搜变为一次精准定位（代码 + 文档 + 规则）
- 减少 Agent 探索轮次，每次少一轮 = 少一次 API 请求 = 少一整个 context window 的 input token
- 修复循环场景下，收益被轮次数放大
