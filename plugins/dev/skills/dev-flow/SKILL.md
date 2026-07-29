---
name: dev-flow
description: 完整的研发流程：方案设计 → 实施 → 审查 → 测试 → 修复 → 文档更新
---

# 研发流程

## 流程概览

```
需求描述 → 方案设计 → [审批] → 实施 → 代码审查 → 修复 → 测试验证 → 修复 → 文档更新
```

## 各阶段分工

### 1. 方案设计
调用项目提供的架构设计 agent（如 `system-architect`，需项目自行配置）进行分析：
- 分析需求，设计技术方案
- 输出：涉及文件、实现步骤、架构影响
- **此阶段结束后需要用户审批方案**

### 2. 实施（feature-developer）
- 按方案编写代码
- 严格遵循方案，不自行变更架构决策
- 遇到方案未覆盖的细节主动提出

### 3. 代码审查（code-reviewer + code-simplifier 并行）
- Bug Hunter（code-reviewer）：审查正确性、安全性、架构合规性
- Code Simplifier（code-simplifier）：审查重复代码、过度工程、死代码、抽象泄漏
- 两个 agent 并行执行，每个发现带置信度标注（High/Medium/Low）
- 输出：按严重度 + 置信度排序的合并问题列表

### 4. 测试验证（test-reviewer）
- 代码走查、对照需求验证、边界分析、回归风险评估
- 输出：风险/注意事项/通过列表 + 总体结论

### 5. 修复
- 针对审查和测试发现的问题修复
- 修复后重新走审查+测试，直到通过

### 6. 文档更新（doc-maintainer）
- 更新 CLAUDE.md、rules、skills 等配置
- 确保项目知识库保持最新

## 依赖说明

本流程依赖插件中的 `code-reviewer`、`feature-developer`、`test-reviewer`、`doc-maintainer` Agent。
此外需要项目提供一个架构设计 agent（如 `system-architect`），负责方案设计阶段的技术分析。
