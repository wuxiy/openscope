# Project Context

## Purpose

The shortest static baseline an AI agent needs before doing useful work: identity, documentation freshness, technical stack, and verification commands.

Update it in place. Do not create dated copies.

This file intentionally does **not** track "what is being worked on right now". That is found by scanning unfinished plans in `docs/plans/`. Keeping high-churn active-work state here makes the file hard to maintain and prone to staleness.

## Companion Context Files

This file is the AI entry point. The following `docs/context/` companions are read on demand — most mission-driver flow steps load this file first, then route to them:

| File | When to read |
|---|---|
| `ai-autonomy-policy.md` | Before any task that changes code, model, or product behavior — autonomy levels, Protected Areas, reviewer availability |
| `codebase-map.md` | When locating code, making cross-module changes, or entering an unfamiliar area — entry points, common change routes, fragile files |
| `source-of-truth-and-precedence.md` | When facts conflict or it is unclear which doc is authoritative |

## Project Identity

- Project name: OpenScope
- Product type: 可观测性发行版/框架（OTel-native observability distribution），当前为 pre-code 设计阶段仓库
- Primary users: cywu 个人自研项目（Family-OS/Health-OS/Teacher-OS/Everglow/XiangLiZhi）、公司内部（Data-OS 等）、政务/医疗交付项目
- Documentation freshness: `fresh`（两份根目录架构文档 2026-08-27 完成评审与修订，AGE 上下文同日建立）

**Freshness gating:**

- If freshness is `stale` or `unknown`, agents may research, audit, and draft alignment docs, but must not implement product behavior until the baseline is re-established or a human confirms intended behavior.
- If freshness is `partially stale`, agents may implement only slices whose requirement, owner doc, codebase-map route, and touched code area have been verified fresh; otherwise treat the slice as `plan-first` or `research-only`.
- AI may not mark stale docs fresh without human confirmation or human-approved owner-doc evidence.

## Current Technical Baseline

- Frontend stack: none（V1 无自研前端，可视化统一走 Grafana Provisioning）
- Backend stack: 规划中——Java / Spring Boot（`openscope-api`、`openscope-spring-boot-autoconfigure`、`openscope-spring-boot-starter`、`openscope-logback`）；数据平面 opentelemetry-collector-contrib；后端 Prometheus >3.x + Grafana Tempo + Loki ≥3.0 + Grafana
- Database/model source: none（不自研存储；组件版本权威 = Distribution BOM，见《OpenScope-技术架构》§20；仓库结构权威 = 《OpenScope-技术架构》§22）

## Verification Commands

Replace every placeholder before implementation work starts.

| Purpose                   | Command                                        |
| ------------------------- | ---------------------------------------------- |
| Install dependencies      | `<none until V0.1 code exists>`                |
| Run app locally           | `<docker compose up 后补充>`                    |
| Typecheck / compile check | `<none>`                                       |
| Build                     | `<none>`                                       |
| Lint / static check       | `<none>`                                       |
| Unit tests                | `<none>`                                       |
| E2E / integration tests   | `./tools/mission-driver.sh list && ./tools/mission-driver.sh run demo` |
| 文档占位符检查             | `grep -rn "<fill\|<path>" docs/ || true`        |

注意：出现 Java 代码后，本表必须先补齐 Maven 构建与测试命令，再开始 implementation work。

## Optional Layers Currently In Use

Mark only the optional layers this project actually maintains.

- [ ] `docs/discussions/`
- [x] `docs/audits/`
- [x] `docs/testing/`
- [ ] `docs/skills/`
- [ ] `docs/analysis/`
- [ ] `docs/retrospectives/`
- [ ] `docs/lessons/`

## AI Block Conditions

AI MUST stop and wait for human input before proceeding when:

- verification commands are all placeholders and cannot be inferred from the project（当前文档层工作不受此限，见上表有效命令）
- any change touches payment or data-deletion paths with no existing test coverage and no owner doc describing expected behavior
- no requirement or owner doc describes the intended behavior of the change — do not implement into a vacuum

These are project-specific hard stops in addition to `AGENTS.md`, `docs/context/ai-autonomy-policy.md`, source-of-truth conflict rules, and required plan/closure audit rules.

For ambiguity that does not affect user-visible behavior, contracts, protected areas, or closure evidence, resolve by writing assumptions into the relevant doc and proceed according to the autonomy policy. Mark uncertain assumptions explicitly so humans can review later.

### 本项目特定红线

- 不得修改组件版本下限（Prometheus >3.x、Loki ≥3.0）或绕过 BOM 单一版本策略，除非 cywu 明确确认
- 不得让《项目架构》与《技术架构》两份根文档内容漂移：结构性结论只允许在一处定义（技术架构 §22 仓库结构），另一处引用
- 政务/医疗相关设计不得削弱"脱敏三道防线"中的第一道（应用侧不采集敏感属性）

## Notes For AI Agents

- If this file is empty or stale, ask for or create a context update before large implementation work.
- 根目录的《OpenScope-项目架构.md》与《OpenScope-技术架构.md》是本项目的两份核心设计输入，任何架构相关工作先读它们，再读本 docs/ 层。
