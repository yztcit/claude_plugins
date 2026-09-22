# claude_plugins

通用 Claude Code 研发工具集插件仓库。一个 `dev` 插件，打包 6 个 Skill + 5 个 Agent。

## 插件内容

| 组件 | 类型 | 说明 | 调用方式 |
|---|---|---|---|
| `dev-flow` | Skill | 完整研发流程：方案设计 → 实施 → 审查 → 测试 → 文档 | `/dev:dev-flow` |
| `solution-design` | Skill | 需求方案设计：分析需求、设计方案、输出步骤 | `/dev:solution-design` |
| `gen-commit` | Skill | 根据提交历史，生成符合项目规范的提交信息 | `/dev:gen-commit` |
| `graphify-search` | Skill | 一键接入 Graphify 代码图谱：安装→索引→git hook→注入搜索规则 | `/dev:graphify-search` |
| `code-review` | Skill | 并行代码审查（bug 猎手 + 简化专家），带置信度分级 | `/dev:code-review` |
| `module-docs` | Skill | 业务模块知识沉淀为领域 agent 文档，并注入通用规则 | `/dev:module-docs` |
| `code-reviewer` | Agent | Bug 猎手：正确性、安全性、可维护性、架构合规 | dev-flow / code-review 调用 |
| `code-simplifier` | Agent | 简化专家：重复代码、过度工程、死代码、抽象泄漏 | code-review 调用 |
| `feature-developer` | Agent | 功能实施：按方案编写代码，遵循项目规范 | dev-flow 自动调用 |
| `test-reviewer` | Agent | 测试验证：代码走查、边界分析、回归评估 | dev-flow 自动调用 |
| `doc-maintainer` | Agent | 文档维护：增量更新 CLAUDE.md、rules、skills | dev-flow 自动调用 |

## 新项目接入（两行命令搞定）

### Step 1: 终端执行一键脚本（工具链 + 规则）

**macOS / Linux：**
```bash
curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.sh | bash
```

**Windows (PowerShell)：**
```powershell
irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.ps1 | iex
```

脚本自动完成：安装 uv → 安装 graphify → 初始化代码图谱索引 → 绑定 git hook（自动增量更新） → 配置 .git/info/exclude → 下载搜索规则（图谱优先，规则单源 `search-rule.md`） → 配置 Claude Code 插件 marketplace

#### .git/info/exclude 配置

脚本默认将自动生成产物添加到 `.git/info/exclude`（不影响 `.gitignore`，不提交到仓库）：

```
# Graphify 图谱索引（自动生成，不提交）
graphify-out/
.gitattributes
```

如需同时忽略 `.claude/` 和 `CLAUDE.md`（个人配置，不共享给团队），设置环境变量后运行：

**macOS / Linux：**
```bash
CLAUDE_EXCLUDE_MODE=all curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.sh | bash
```

**Windows (PowerShell)：**
```powershell
$env:CLAUDE_EXCLUDE_MODE="all"; irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/setup.ps1 | iex
```

> 默认 `CLAUDE_EXCLUDE_MODE=minimal`，仅忽略自动生成产物。设为 `all` 会额外忽略 `.claude/`（插件配置目录）和 `CLAUDE.md`（项目记忆文件）。如需团队共享插件配置，保持默认即可。

> **网络超时？** 安装 uv 和 graphify 需要从 GitHub 下载，国内网络可能超时。执行脚本前先配置终端代理（一次性，关闭终端即失效）：
>
> **macOS / Linux：**
> ```bash
> export https_proxy=http://127.0.0.1:你的代理端口
> export http_proxy=http://127.0.0.1:你的代理端口
> ```
>
> **Windows (PowerShell)：**
> ```powershell
> $env:HTTPS_PROXY="http://127.0.0.1:你的代理端口"
> $env:HTTP_PROXY="http://127.0.0.1:你的代理端口"
> ```
>
> 常见代理端口：Clash 7890、V2Ray 10809、Shadowsocks 1080。端口号在代理软件设置中查看。

### Step 2: Claude Code 中安装插件（激活 Skill + Agent）

```
/plugin install dev@tal-tools --scope project
```

`--scope project` 会把安装记录写入 `.claude/settings.json`，`git push` 后其他队友就能共享。

### 团队成员首次打开项目

1. 终端执行一次 `setup.sh`（安装工具链 + 索引）
2. Claude Code 中执行 `/plugin install dev@tal-tools`（激活插件）

### 更新插件

插件更新分两步：**先刷新 marketplace 缓存，再更新插件**。只执行 `/plugin update` 不会刷新 marketplace 元数据，会一直读到旧版本。

```bash
# 1. 刷新 tal-tools marketplace 缓存到远程最新
claude plugin marketplace update tal-tools

# 2. 更新已安装插件到最新版本（project scope；user scope 用 -s user）
claude plugin update dev@tal-tools -s project
```

然后**重启 Claude Code 会话**使新 skill/agent 生效。

或用一键脚本（免下载执行，推荐）：

**macOS / Linux：**
```bash
curl -LsSf https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.sh | bash
```

**Windows (PowerShell)：**
```powershell
irm https://raw.githubusercontent.com/yztcit/claude_plugins/main/update-plugins.ps1 | iex
```

> **为什么还需要脚本**：`claude plugin update` 是按 `plugin.json` 的 `version` 判「是否最新」的。上游改内容时若忘了 bump version，update 会判「已是最新」而**静默空转**，缓存里留着旧内容且没有任何报错（2026-09 实际发生过一次）。脚本会先比对「源目录 vs 缓存目录」的内容指纹，版本号相同但内容不同就走卸载重装强制刷新，不依赖上游的版本纪律。脚本只动**已安装**的 scope——不对未安装的 scope 执行 install，避免把插件凭空装到 user 级、绕过项目级 opt-in。

### 存量迁移：marketplace 曾叫 `lui-tools`

2026-09 本仓库的 marketplace 由 `lui-tools` 改名为 `tal-tools`。官方 `marketplace.json` 的 `renames` 字段只覆盖**插件改名**，覆盖不了 **marketplace 自身改名**，所以存量环境会卡在半迁移态（settings 写着新名但从未真正注册，插件仍挂旧名）。

如果你的机器仍注册着 `lui-tools`，执行：

```bash
./migrate-lui-tools.sh --dry-run   # 先看计划
./migrate-lui-tools.sh             # 执行（自动备份配置）
```

脚本会枚举受影响项目 → 备份配置 → 移除旧注册 → 注册新名 → 逐项目重装并改写 settings。

> 注意 `claude plugin marketplace remove` 会**连带卸载**该 marketplace 下的所有插件并删除目录，不只是解注册——所以顺序不能颠倒，脚本已按正确顺序处理。

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

应该看到 `dev:dev-flow`、`dev:solution-design`、`dev:gen-commit`、`dev:graphify-search`、`dev:code-review`、`dev:module-docs` 六个 Skill。

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
│  Plugin 层 (dev@tal-tools)        │
│  Skill: dev-flow, solution-design  │
│         gen-commit, graphify-search│
│         code-review, module-docs   │
│  Agent: code-reviewer (bug hunter) │
│         code-simplifier (simplifier)│
│         feature-developer          │
│         test-reviewer              │
│         doc-maintainer             │
└────────────────────────────────────┘
```

- Plugin 层定义**检查什么**和服务流程
- 项目层定义**怎么检查**的具体规范
- Agent 读取 rules/ 来执行项目特定的审查和实施
