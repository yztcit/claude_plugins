---
name: code-review
description: /dev:code-review — 并行代码审查（bug 猎手 + 简化专家），带置信度分级
---

# /dev:code-review — 并行代码审查

当用户输入 `/dev:code-review` 时，并行派发两个 agent 审查当前变更。

## 触发

- 如果用户指定了范围（如 `/dev:code-review src/services/`），审查该范围内的文件
- 如果没有指定范围，用 `git diff --name-only` 获取当前变更文件
- 用户可以通过 `--full` 强制完整文件审查，`--diff-only` 强制仅 diff 审查

## 执行流程

### Step 0: 确定审查范围

```
如果没有指定范围:
  files = `git diff --name-only`（仅 src/ 下的 .ts/.tsx/.vue/.js 文件）
  如果为空 → 提示用户"没有检测到变更"
```

### Step 1: 上下文自适应

```
if 变更文件 ≤ 3 个 或 用户指定 --full:
  模式 = full-file（送完整文件上下文，更准确）
else 或 用户指定 --diff-only:
  模式 = diff-only（只送 diff，节省 token）
```

获取 diff: `git diff` 或 `git diff -- <files>`

### Step 2: 并行派发两个 Agent

用 `parallel()` 同时派发：

1. **Bug Hunter** — `Agent(subagent_type="code-reviewer", ...)`
   - prompt 包含变更 diff + 审查文件
   - 专注：正确性 + 安全性 + 可维护性 + 架构合规

2. **Code Simplifier** — `Agent(subagent_type="code-simplifier", ...)`
   - prompt 包含变更 diff + 审查文件
   - 专注：重复代码 + 过度工程 + 死代码 + 抽象泄漏 + 效率

### Step 3: 合并输出

两个 agent 完成后，合并输出，按 P0 → P1 → P2 排序。重复发现合并为一条（保留双方视角）。

## 输出格式

```markdown
# 代码审查报告

## Bug Hunter 发现

### 🔴 P0 阻塞
- **[High Confidence]** file_path:Lxx — 问题描述。建议: ...

### 🟡 P1 重要
- **[Medium Confidence]** file_path:Lxx — 问题描述。建议: ...

### 🔵 P2 建议
- **[Low Confidence]** file_path:Lxx — 问题描述。建议: ...

## Code Simplifier 发现

### 🔴 P0 阻塞
- **[High Confidence]** file_path:Lxx — 问题描述。建议: ...

### 🟡 P1 重要
...

### 🔵 P2 建议
...

## 统计
- Bug Hunter: X 个发现 (Y P0, Z P1, W P2)
- Code Simplifier: X 个发现 (Y P0, Z P1, W P2)
- 审查耗时: ~Xs（并行执行）
```

如果两个 agent 都没有发现 → 输出"✅ 无问题"

## 置信度说明

| 级别 | 含义 |
|------|------|
| High Confidence | 非常确信有问题，应立即处理 |
| Medium Confidence | 较可能有问题，需人工确认 |
| Low Confidence | 不确定，仅供人工复核 |
