# Task Routing

> Agent 执行任何编码前必须完成的分类与路由流程。根入口见 `AGENTS.md`。

## 1. 任务分类

Agent MUST 先将任务归入以下类型之一，再动手：

| 类型 | 说明 |
|---|---|
| requirement clarification | 需求澄清 |
| app-layer design change | 应用层设计变更 |
| architecture change | 架构变更 |
| implementation-only change | 纯实现变更 |
| bug investigation | 缺陷排查 |
| verification / audit | 验证或审计工作 |

## 2. 路由步骤

1. 按 `docs/index.md` 找到该任务类型的 owner docs 并阅读；
2. 检查 `docs/skills/README.md` 是否有可复用 skill；
3. non-trivial 工作：在计划中记录所选路由和计划使用的 skill，再开始实现。

除非 active requirement 和 owner doc 已经让路由显而易见，否则禁止从 feature 请求直接跳到代码。

当前活跃工作从 **未完成 plans（`docs/plans/`）+ `docs/backlog/README.md`** 查找；`project-context.md` 故意不维护此信息。

## 3. Skill Usage Rule

使用可复用 skill 前确认：

- 任务类型与路由已从 requirement 和 owner doc 明确；
- skill 匹配的是**工作方法**而非相似的业务标签；
- `docs/skills/README.md` 列出的所需输入已就绪；
- 预期输出已知，且有正确的 docs 存放位置。

Non-trivial plan 中每个依赖 skill 的 phase/item 应记录 `Skill: <name>` 或 `Skill: none`。

Skills 是方法选择器，不能替代 requirements、design、architecture owner docs——业务知识永远先进 owner doc。
