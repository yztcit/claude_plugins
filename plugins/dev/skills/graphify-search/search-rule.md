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
