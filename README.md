# claude_plugins

通用 Claude Code 研发工具集插件仓库。一个 `dev` 插件，打包 3 个 Skill + 4 个 Agent。

## 插件内容

| 组件 | 类型 | 说明 | 调用方式 |
|---|---|---|---|
| `dev-flow` | Skill | 完整研发流程：方案设计 → 实施 → 审查 → 测试 → 文档 | `/dev:dev-flow` |
| `solution-design` | Skill | 需求方案设计：分析需求、设计方案、输出步骤 | `/dev:solution-design` |
| `gen-commit` | Skill | 根据提交历史，生成符合项目规范的提交信息 | `/dev:gen-commit` |
| `code-reviewer` | Agent | 代码审查：正确性、安全性、可维护性 | dev-flow 自动调用 |
| `feature-developer` | Agent | 功能实施：按方案编写代码，遵循项目规范 | dev-flow 自动调用 |
| `test-reviewer` | Agent | 测试验证：代码走查、边界分析、回归评估 | dev-flow 自动调用 |
| `doc-maintainer` | Agent | 文档维护：增量更新 CLAUDE.md、rules、skills | dev-flow 自动调用 |

## 新项目接入（管理员配置一次）

在项目根目录创建 `.claude/settings.json`：

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

然后手动安装一次插件（仅首次）：

```
/plugin install dev@lui-tools --scope project
```

`--scope project` 会把安装记录写入 `.claude/settings.json`，这样 `git push` 后其他队友就能共享。

### 团队成员首次打开项目

1. 打开项目，信任目录 → `lui-tools` marketplace 自动注册
2. **仍需执行一次** `/plugin install dev@lui-tools`（`enabledPlugins` 只负责启用，不负责安装）
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

应该看到 `dev:dev-flow`、`dev:solution-design`、`dev:gen-commit` 三个 Skill。

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
│         gen-commit                 │
│  Agent: code-reviewer              │
│         feature-developer          │
│         test-reviewer              │
│         doc-maintainer             │
└────────────────────────────────────┘
```

- Plugin 层定义**检查什么**和服务流程
- 项目层定义**怎么检查**的具体规范
- Agent 读取 rules/ 来执行项目特定的审查和实施
