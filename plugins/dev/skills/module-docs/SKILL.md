---
name: module-docs
description: 业务模块知识沉淀为领域 agent 文档：识别模块 → 生成 .claude/agents/<module>.md → 注入 module-docs 通用规则 → 更新 CLAUDE.md 索引
---

# 业务模块知识沉淀（Module Docs）

把"梳理某模块逻辑并沉淀为项目 Claude 文档"做成标准流程。产出物是 `.claude/agents/<module>.md` 领域 agent（参照 ai-eyes 先例），后续对话可直接调用该 agent 获取模块知识，避免重复探索。首次使用时还会把通用规则注入项目 `.claude/rules/module-docs.md`，之后自动生效。

## 何时用

- 用户要求"梳理 / 沉淀某模块逻辑，方便后续使用"
- 新增业务模块需要建立领域知识
- 模块结构 / 数据流大改后需要更新领域文档

## Step 1: 识别模块范围与关系

- 定位模块目录（`find` / `graphify query`）
- 识别模块内的**跨功能关系**（如 xpyInteract：新培优 = 上游产题，纸屏互动 = 下游答题，scheme 串联）
- 识别**独立入口**（scheme / deep link / intent-filter / 外部调用方）
- 梳理包结构、对外依赖、bizType / 页面枚举体系

## Step 2: 生成领域 agent 文档 `.claude/agents/<module>.md`

模板如下（frontmatter 的 `name` 用短横线小写，`description` 一句话概括覆盖范围）：

```markdown
---
name: <module>
description: <一句话：模块职责 + 覆盖的核心机制>
---

你是 <模块> 的领域专家，掌握该模块的完整架构和数据流。

## 触发方式

```
"<模块>这里怎么改"
"<核心机制>流程是什么"
```

## 模块位置

`<模块目录>`

## 包结构

| 包 | 职责 |
|---|---|
| ... | ... |

## 核心架构 / 数据流

<ASCII 图，标注上游/下游/独立入口/核心链路>

## 关键外部依赖

- <依赖> — 作用

## 常用改动落点

| 需求 | 落点 |
|---|---|
| ... | ... |

## 回复风格

- <涉及本模块改动时，提醒同步改哪些点>
```

## Step 3: 注入通用规则（仅首次）

检查项目 `.claude/rules/module-docs.md` 是否存在；不存在则创建（内容见下方「通用规则」），之后该规则对后续对话自动生效。

> **规则单源维护**：规则文本只维护本 SKILL.md 一份，由 agent 按需写入各项目（项目里的规则文件是快照）。**不要**再把规则文本复制进 setup 脚本 / 其他文件，避免多份副本漂移。

## Step 4: 更新 CLAUDE.md 索引

- agent 索引表加一行：`| Agent | \`<module>\`（项目） | <一句话职责> |`
- `.claude/` 目录树 `agents/{...}` 加入模块名

## Step 5: 交付清单

- 新增/修改的文件列表
- 数据流是否画了 ASCII 图
- 是否需要同步补充 CLAUDE.md 的"常见改动落点"

## 通用规则

注入到项目 `.claude/rules/module-docs.md` 的内容（如下）：

```markdown
# 模块文档沉淀规则

当用户要求"梳理 / 沉淀某模块逻辑为项目文档，方便后续使用"时，按此规则执行：

## 产出物
- 领域 agent 文档 `.claude/agents/<module>.md`（参照 ai-eyes / xpy-interact 先例）
- frontmatter 字段：name（短横线小写）、description（一句话，含覆盖范围）
- 同步在 CLAUDE.md 的 agent 索引表 + `.claude/` 目录树登记

## 文档结构
1. frontmatter → 2. 触发方式（示例提问）→ 3. 模块位置 → 4. 包结构表
5. 核心架构 / 数据流（ASCII 图，标注上游/下游/独立入口）
6. 关键外部依赖 → 7. 常用改动落点（需求 | 落点表，精确到类/方法）→ 8. 回复风格

## 内容要点
- 优先梳理模块内跨功能关系与独立入口（scheme / deep link）
- 数据流用 ASCII 图，不用纯文字
- 改动落点精确到类 / 方法，供后续直接定位
- 记录"容易踩坑"的约束（如 Channel 非合流、灰度开关、任务栈归并等）
- 文档写完后同步更新 CLAUDE.md 索引
```
