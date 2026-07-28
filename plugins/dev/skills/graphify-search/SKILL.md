---
name: graphify-search
description: 一键接入 Graphify 代码图谱：安装工具、初始化索引、绑定 git hook、注入搜索规则
---

# Graphify 代码图谱接入

为项目接入 AST 代码图谱索引，让 Agent 搜代码时精准定位而非盲搜关键词，节省约 20% token 消耗。

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
# Graphify 代码图谱索引（自动生成，不提交）
graphify-out/
```

## Step 6: 注入搜索规则

### 6.1 探测项目结构

先扫描项目，确定源码目录和文件扩展名：

```bash
# 找到源码目录（排除 node_modules, .git, build 产物等）
find . -type f \( -name "*.ts" -o -name "*.vue" -o -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.rs" -o -name "*.swift" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/graphify-out/*" \
  | head -20
```

根据扫描结果确定：
- **源码根目录**：`src/`、`lib/`、`app/`、`packages/*/src/`、或项目根目录
- **主要扩展名**：`.ts`、`.py`、`.go` 等
- **是否需要多条 paths**：monorepo 可能需要多条

### 6.2 生成规则文件

在项目的 `.claude/rules/` 目录创建 `code-search.md`。`paths` 必须根据 6.1 的扫描结果填写，以下为模板：

```markdown
---
paths:
  - "<探测到的源码目录>/**/*.<扩展名1>"
  - "<探测到的源码目录>/**/*.<扩展名2>"
---

# Agent 搜索策略：代码图谱优先

## 搜索优先级

| 优先级 | 方式 | 适用场景 | 命令示例 |
|--------|------|---------|---------|
| 1 | 代码图谱 | 找文件/符号/依赖/影响范围 | `graphify query "UserService 在哪里定义"` |
| 2 | 结构化搜索 | 图谱无结果时的精确查找 | `grep -rn "symbol" <源码目录>/` |
| 3 | Read 文件 | 已锁定目标后读内容 | Read tool |

## 搜索流程

1. **先查图谱锁定文件** — `graphify query "<问题>"` 获取相关文件列表和关系
2. **再 Read 目标文件** — 只读图谱锁定的文件，不做盲搜式多轮 read
3. **查影响范围** — `graphify affected "<改动的文件/符号>"` 了解上下游，避免改一处漏一片

## 适用场景

- 修改前定位受影响的文件范围
- 理解模块间的依赖链路
- 查找 symbol / class / function 定义位置
- 新需求开发前的代码探索

## 前置检查（强制）

**在执行任何 `grep`/`find`/`Read` 搜索之前，必须先尝试 `graphify query`。**

判断流程：
1. 需要定位代码 → 先 `graphify query "问题"`
2. 图谱返回了相关文件 → 直接 Read，不走 grep
3. 图谱无结果或结果不相关 → 降级到 grep/find
4. 需要了解改动影响 → `graphify affected "文件/符号"`

⚠️ 如果第一个搜索命令是 `grep` 而非 `graphify`，说明跳过了前置检查。

## 图谱不可用时

若 `graphify` 命令不存在或索引未建，按传统方式搜索（find/grep → read）。

## 禁止事项

- ❌ 图谱可用时第一个搜索命令就用 `grep`/`find`（必须先 `graphify query`）
- ❌ 图谱可用时不做多轮关键词盲搜
- ❌ 不将 `graphify-out/` 目录提交到 git
```

### 6.3 示例

不同项目的 paths 示例：

| 项目类型 | paths 配置 |
|---------|-----------|
| Vue/TS 项目 (`src/`) | `"src/**/*.ts"`, `"src/**/*.vue"` |
| Python 项目 (`app/`) | `"app/**/*.py"` |
| Go 项目 (根目录) | `"*.go"`, `"internal/**/*.go"`, `"pkg/**/*.go"` |
| Monorepo | `"packages/*/src/**/*.ts"` |
| Java 项目 | `"src/main/java/**/*.java"` |

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

- 代码搜索从多轮盲搜变为一次精准定位
- 减少 Agent 探索轮次，每次少一轮 = 少一次 API 请求 = 少一整个 context window 的 input token
- 修复循环场景下，收益被轮次数放大
