# claude_plugins

通用 Claude Code 研发工具集插件仓库。

## 插件列表

| 插件 | 类型 | 说明 |
|---|---|---|
| `dev-flow` | Skill | 完整研发流程：方案设计 → 实施 → 审查 → 测试 → 修复 → 文档更新 |
| `solution-design` | Skill | 需求方案设计：分析需求、设计技术方案、输出实施步骤 |
| `gen-commit` | Skill | 根据项目提交历史，生成符合规范的提交信息 |
| `code-reviewer` | Agent | 代码审查：正确性、安全性、可维护性 |
| `feature-developer` | Agent | 功能实施：按方案编写代码，遵循项目规范 |
| `test-reviewer` | Agent | 测试验证：代码走查、边界分析、回归风险评估 |
| `doc-maintainer` | Agent | 文档维护：增量更新 CLAUDE.md、rules、skills |

## 安装

```bash
# 1. 添加 marketplace
/plugin marketplace add yztcit/claude_plugins

# 2. 安装所需插件
/plugin install dev-flow@lui-tools
/plugin install code-reviewer@lui-tools
# ... 按需安装
```

## 在项目中自动配置

在 `.claude/settings.json` 中添加：

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
    "dev-flow@lui-tools": true,
    "gen-commit@lui-tools": true
  }
}
```

## 新项目接入指南

### 第一步：创建项目配置文件

在新项目根目录创建 `.claude/settings.json`：

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
    "dev-flow@lui-tools": true,
    "solution-design@lui-tools": true,
    "gen-commit@lui-tools": true,
    "code-reviewer@lui-tools": true,
    "feature-developer@lui-tools": true,
    "test-reviewer@lui-tools": true,
    "doc-maintainer@lui-tools": true
  }
}
```

### 第二步：创建项目规范（最少配置）

Agent 依赖 `rules/` 中的规范来指导审查和实施。最少需要以下文件：

**`.claude/rules/code-style.md`**

告诉 agent 你的项目用什么语言、什么日志工具、什么命名风格。例如：

```markdown
# 代码风格

## 语言
- 新代码使用 Kotlin

## 日志
- 使用 VLogger 打印日志
- 每个类定义 `private val TAG = XxxClass::class.java.simpleName`

## 命名
- Activity：XxxActivity
- Controller：XxxController

## 空安全
- 不使用 !! 强制解包，优先使用 ?.let {} 或 ?:
```

**`.claude/rules/architecture.md`**

告诉 agent 项目的模块边界和依赖方向：

```markdown
# 架构规则

## 模块依赖方向
business_aiLib ← service_voice_intent ← service_voice_intermediate ← lui_view_component ← lui_business
- 只能上层依赖下层，不可反向

## 新功能放置
- 新增 Skill 引擎 → service_voice_intent/engine/skill/
- 新增 UI 组件 → lui_view_component/ability/
- 新增业务页面 → lui_business/ui/activity/
```

### 第三步：创建 CLAUDE.md

`/init` 自动生成，然后补充项目特有的构建命令、架构概览、关键类等。

### 第四步：创建项目特有 Agent（按需）

如果项目需要架构设计 Agent，参考现有模板创建 `.claude/agents/system-architect.md`。项目特有 Agent 放在 `.claude/agents/` 中，与 Plugin 提供的 Agent 共存。

### 第五步：验证

打开 Claude Code，确认 Plugin 已加载：

```
/help
```

应该看到 `dev-flow@lui-tools`、`code-reviewer@lui-tools` 等命令可用。

### 插件与项目的分工

```
┌────────────────────────────────────┐
│  项目层 (.claude/ 项目特有)         │
│  agents/system-architect.md        │
│  skills/debug-voice-flow/          │
│  rules/code-style.md               │
│  rules/architecture.md             │
├────────────────────────────────────┤
│  Plugin 层 (lui-tools，自动安装)   │
│  code-reviewer, feature-developer  │
│  test-reviewer, doc-maintainer     │
│  dev-flow, solution-design         │
│  gen-commit                        │
└────────────────────────────────────┘
```

- Plugin 层定义**检查什么**（通用流程）
- 项目层定义**怎么检查**（具体规范）
- 两者协作：Agent 读取 rules/ 来执行项目特定的审查和实施
