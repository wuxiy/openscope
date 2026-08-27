# Workflow

> OpenScope 的默认开发工作流。原则一句话：repo 是 durable truth，chat 只是临时工作面——重要结论必须落文件。

## File-in / File-out

- 重要输入先写入文件再动手：原始输入进 `docs/input/`；
- 重要产出写回仓库而非只留在 chat；
- 输入含糊时，先在 `docs/discussions/` 或 `docs/requirements/` 创建/更新文件，再继续。

## Default Workflow

1. 原始材料收入 `docs/input/`
2. 需要时在 `docs/discussions/` 澄清歧义
3. 在 `docs/requirements/` 综合出 implementation-ready requirement
4. 稳定设计分流：应用层 → `docs/design/`，技术层 → `docs/architecture/`，两侧互相引用
5. 路由任务并挑选候选 reusable skills（见 `task-routing.md`）
6. 触发 planning 条件时编写/更新 plan（判定见 `planning-and-audit.md`）
7. implementation 前 audit plan
8. 实现最小完整切片
9. 运行 verification
10. created plan 做 closure audit
11. 写 logs 和必要的 bug notes

原型与实现出现实质性分歧时，把原因记入 `docs/retrospectives/`，不允许悄悄翻篇。

## Optional Workflow Layers

按复杂度启用；created plan 的 plan/closure audit 是强制的：

- `docs/audits/` — 文档审计与重要审计记录
- `docs/testing/` — 手动/探索性验证证据
- `docs/retrospectives/` — 要求/原型重大缺口复盘
- `docs/skills/` — 反复失败后沉淀可复用 prompts
- `docs/lessons/` — 反复失败或重要恢复后的持久教训

两个通用审计 prompt 的用途：`multi-dimensional-audit-prompt.md` 用于多维度同时质询；`open-ended-audit-prompt.md` 用于标准 checklist 可能漏掉隐藏风险时。二者是通用默认，复制后 MUST 按本项目真实 owner docs、protected areas、verification model 定制。
