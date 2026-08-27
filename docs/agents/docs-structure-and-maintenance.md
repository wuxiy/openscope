# Docs Structure & Maintenance

> 目录职责归属、变更后的文档维护义务、verification 基线与经验沉淀阶梯。

## Documentation Ownership

| 目录 | 职责 |
|---|---|
| `docs/context/` | 强制 AI context、source-of-truth precedence、项目级 conventions |
| `docs/agents/` | agent 执行规则层（路由/工作流/planning/维护），本目录 |
| `docs/backlog/` | 候选工作优先级与 AI-ready next actions |
| `docs/input/` | 原始外部输入（PM notes、原型参考等） |
| `docs/discussions/` | 需求澄清记录与未决问题 |
| `docs/requirements/` | implementation-ready requirement 综合 |
| `docs/design/` | 稳定的应用层业务/feature 设计 |
| `docs/architecture/` | 跨模块技术基线与 module boundaries |
| `docs/plans/` | 执行计划与 closure criteria |
| `docs/audits/` | 审计方法与审计记录 |
| `docs/skills/` | 可复用 prompts、review playbooks、audit 模板 |
| `docs/logs/` | 日期化实现记忆（`YYYY/MM-DD.md`） |
| `docs/testing/` | 手动/探索性测试记录 |
| `docs/bugs/` | 非显而易见的缺陷历史与回归笔记 |
| `docs/analysis/` | 调研、tradeoff 分析、被否决方向 |
| `docs/lessons/` | 从 bugs/audits/retrospectives 提炼的持久教训 |
| `docs/retrospectives/` | 交付后差距分析与流程改进 |
| `docs/archive/` | 人工决定归档的非活跃文档 |

## Change Maintenance

完成有意义的代码变更后 MUST：

1. 更新当日 dev log：`docs/logs/{year}/{month}-{day}.md`（append-only，当天不存在则创建）；
2. 变更影响 app-layer 行为或技术结构时，同步更新 `docs/design/` 或 `docs/architecture/` 对应 owner doc。

Verification 完全通过（full green）时：在 log entry 和 git commit message 中记录 verification 状态，为未来 debugging 提供可靠 known-good baseline。非显而易见的回归写入 `docs/bugs/`。

## Verification Baseline

- 一律使用 `docs/context/project-context.md` 里的**真实命令**；本仓库当前有效命令为 mission-driver 相关命令
- 命令为空或仍是占位符时，stop——填实之后才允许报告 verification 成功

## 经验沉淀阶梯

同一错误模式反复出现时，按顺序升级处置，不许停留在 prose 教训：

1. **沉淀审计资产**：提升为 reusable audit prompt / checklist / review playbook（进 `docs/skills/` 或 `docs/audits/`）
2. **机械化拦截**：仍然复发则评估 heuristic script、static check、lint rule、CI guard、codemod，按项目真实约定调整误报容忍度

## Archive Rule

引用的文件在预期路径找不到时，先查 `docs/archive/`（保留原相对路径命名）再判定不存在。未经 human approval 不得移动文件进 archive。
