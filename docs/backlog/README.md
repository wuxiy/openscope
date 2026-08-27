# Backlog

## Purpose

Use this file to list candidate work AI may inspect or execute.

The backlog is not a replacement for requirements, owner docs, or plans. It only helps select the next slice.

## Work Items

| Priority | Item            | Requirement                | Owner Doc            | Plan                        | Status              | AI Autonomy | Blocker                              | Last Checked   |
| -------- | --------------- | -------------------------- | -------------------- | --------------------------- | ------------------- | ----------- | ------------------------------------ | -------------- |
| P0       | V0.1 standalone 发行版（三信号闭环 + 基础 Dashboard + 最小 CLI） | `docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md` | `docs/architecture/v0.1-standalone-contract.md` | `docs/plans/2026-08-27-1937-v0.1-standalone-distribution-plan.md` | `in-progress` | `plan-first` | human draft review；开发机 Registry/manifest 路径；Phase 0 解析 digest | 2026-08-28 |
| P1       | Central 拓扑与跨网络安全 | 待 V0.1 验收后综合 | `OpenScope-技术架构.md` §14.2/§17 | none | `idea` | `ask-first` | 依赖 P0 关闭；认证/TLS/租户合同未建立 | 2026-08-27 |
| P2       | Spring Boot Starter 与自研 Java 模块 | 待 V0.1 验收和真实 Agent 缺口后综合 | `docs/architecture/module-boundaries.md` java/* | none | `idea` | `plan-first` | 依赖 P0 关闭与真实需求证据 | 2026-08-27 |

后续切片从《OpenScope-项目架构》§15 演进路线推导；V0.2/V0.3 内容在 V0.1 验收后再行分解。

## Readiness Invariants

`ready` means all of these are true:

- requirement path exists and has testable acceptance criteria
- owner doc path exists and is not known stale for this slice
- verification commands in `docs/context/project-context.md` are real
- blocking open questions are absent or explicitly non-blocking
- protected areas are configured in `docs/context/ai-autonomy-policy.md`
- planning triggers were checked

`Plan: none` is valid only when the item clearly qualifies for the no-plan path in `docs/plans/00-plan-authoring-and-execution-guide.md`. If a plan is required, set AI autonomy to `plan-first` until the plan audit passes.

Agents may downgrade stale rows from `ready` to `needs-*` or `blocked` with evidence. Agents must not upgrade rows to `ready`, change autonomy to `implement`, or clear blockers without human confirmation or human-approved owner-doc evidence.

Example ready row after setup:

```md
| P0 | User Management first slice | `docs/requirements/2026-05-21-0900-user-management.md` | `docs/design/app-overview.md` | `docs/plans/2026-05-21-1000-user-management-plan.md` | `ready` | `plan-first` | `none` | `2026-05-21` |
```

## Status Values

- `idea` - not ready for implementation
- `needs-requirement` - raw input exists but no implementation-ready requirement exists
- `needs-design` - requirement exists but owner doc is missing or stale
- `ready` - AI may proceed according to the autonomy label
- `in-progress` - currently being implemented or planned
- `blocked` - cannot proceed until the blocker is resolved
- `done` - completed and verified

## AI Autonomy Values

Use the values from `docs/context/ai-autonomy-policy.md`:

- `implement`
- `plan-first`
- `ask-first`
- `research-only`
- `blocked`

## Selection Rule

When asked to continue without a named task, choose the highest-priority `ready` item whose `AI Autonomy` is `implement` and whose `Blocker` is `none`.

Before implementation, confirm the linked requirement, owner doc, plan field, autonomy policy, and planning triggers are still valid. Do not infer readiness from chat alone.

If the table is stale, downgrade the row or ask before implementation.
