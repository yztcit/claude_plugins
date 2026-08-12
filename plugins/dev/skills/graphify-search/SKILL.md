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

在项目的 `.claude/rules/` 目录创建 `search.md`。`paths` 必须根据 6.1 的扫描结果填写，以下为模板：

```markdown
---
paths:
  - "<探测到的源码目录>/**/*.<扩展名1>"
  - "<探测到的源码目录>/**/*.<扩展名2>"
---

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

- 搜索从多轮盲搜变为一次精准定位（代码 + 文档 + 规则）
- 减少 Agent 探索轮次，每次少一轮 = 少一次 API 请求 = 少一整个 context window 的 input token
- 修复循环场景下，收益被轮次数放大
