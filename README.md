# claude_plugins

通用 Claude Code 研发工具集插件仓库。一个 `dev` 插件，打包 4 个 Skill + 4 个 Agent。

## 插件内容

| 组件 | 类型 | 说明 | 调用方式 |
|---|---|---|---|
| `dev-flow` | Skill | 完整研发流程：方案设计 → 实施 → 审查 → 测试 → 文档 | `/dev:dev-flow` |
| `solution-design` | Skill | 需求方案设计：分析需求、设计方案、输出步骤 | `/dev:solution-design` |
| `gen-commit` | Skill | 根据提交历史，生成符合项目规范的提交信息 | `/dev:gen-commit` |
| `graphify-search` | Skill | 一键接入 Graphify 代码图谱：安装→索引→git hook→注入搜索规则 | `/dev:graphify-search` |
| `code-reviewer` | Agent | 代码审查：正确性、安全性、可维护性 | dev-flow 自动调用 |
| `feature-developer` | Agent | 功能实施：按方案编写代码，遵循项目规范 | dev-flow 自动调用 |
| `test-reviewer` | Agent | 测试验证：代码走查、边界分析、回归评估 | dev-flow 自动调用 |
| `doc-maintainer` | Agent | 文档维护：增量更新 CLAUDE.md、rules、skills | dev-flow 自动调用 |

## 新项目接入（两行命令搞定）

### Step 1: 终端执行一键脚本（工具链 + 规则）

```bash
curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.sh | bash
```

脚本自动完成：安装 uv → 安装 graphify → 初始化代码图谱索引 → 绑定 git hook（自动增量更新） → 配置 .gitignore → 探测项目结构并生成搜索规则

### Step 2: Claude Code 中安装插件（激活 Skill + Agent）

```
/plugin install dev@lui-tools --scope project
```

`--scope project` 会把安装记录写入 `.claude/settings.json`，`git push` 后其他队友就能共享。

### 团队成员首次打开项目

1. 终端执行一次 `setup.sh`（安装工具链 + 索引）
2. Claude Code 中执行 `/plugin install dev@lui-tools`（激活插件）
3. 之后无需任何操作，`/plugin update` 自动拉取更新

### 更新插件

```
/plugin update
```

## 创建项目规范（按需）

插件 Agent 依赖 `rules/` 中的规范来指导审查和实施。建议最少创建以下文件：

**`.claude/rules/code-style.md`** — 告诉 Agent 你的项目用什么语言、什么日志工具、什么命名风格。

**`.claude/rules/architecture.md`** — 告诉 Agent 项目的模块边界和依赖方向。

然后创建 `CLAUDE.md`（`/init` 自动生成），补充项目特有的构建命令、架构概览、关键类。

如果项目需要架构设计 Agent（dev-flow 的方案设计阶段会用到），创建 `.claude/agents/system-architect.md`。

## 验证

```
/help
```

应该看到 `dev:dev-flow`、`dev:solution-design`、`dev:gen-commit`、`dev:graphify-search` 四个 Skill。

验证图谱是否正常工作：

```bash
graphify search "一个你知道存在的类名"
```

### 插件与项目的分工

```
┌────────────────────────────────────┐
│  项目层 (.claude/ 项目特有)         │
│  agents/system-architect.md        │
│  rules/code-style.md               │
│  rules/architecture.md             │
├────────────────────────────────────┤
│  Plugin 层 (dev@lui-tools)        │
│  Skill: dev-flow, solution-design  │
│         gen-commit, graphify-search│
│  Agent: code-reviewer              │
│         feature-developer          │
│         test-reviewer              │
│         doc-maintainer             │
└────────────────────────────────────┘
```

- Plugin 层定义**检查什么**和服务流程
- 项目层定义**怎么检查**的具体规范
- Agent 读取 rules/ 来执行项目特定的审查和实施
