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

## 使用方式

- Agent/ Skill 是通用的，它们的职责是定义**检查什么**
- 具体的**检查标准**由项目 `.claude/rules/` 提供
- 项目特有的 Agent/Skill（如 system-architect、debug-voice-flow）留在项目 `.claude/` 中
