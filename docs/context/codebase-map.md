# Codebase Map

## Purpose

This file gives AI agents a compact map of the live repository so they do not rediscover the structure by repeatedly searching imports and directories.

Keep it current enough to route common work. Do not turn it into a full architecture document.

## Entry Points

项目当前为 pre-code 设计阶段，"入口"即文档与脚手架。

| Area         | Path | Notes | Last Verified  | Confidence |
| ------------ | -------- | --------- | -------------- | ------ |
| 产品定位与目标   | `README.md`, `OpenScope-项目架构.md` | 拓扑模型/Dashboard 模型/演进路线 | 2026-08-27 | high |
| 技术基线权威     | `OpenScope-技术架构.md` | 选型/BOM §20/仓库结构 §22/管线 §10 | 2026-08-27 | high |
| V0.1 实施输入     | `docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md`, `docs/architecture/v0.1-standalone-contract.md` | standalone 范围、候选 BOM、信号/安全/SSH 开发机合同 | 2026-08-28 | high |
| V0.1 执行与验收   | `docs/plans/2026-08-27-1937-v0.1-standalone-distribution-plan.md`, `docs/testing/v0.1-acceptance-checklist.md` | plan 仍为 draft，实施前需 human review | 2026-08-28 | high |
| 引擎入口       | `tools/mission-driver.sh` | AGE mission 执行引擎 shim | 2026-08-27 | high |
| Mission 定义    | `missions/{base,demo,onboarding}.json` | extends 关系：onboarding→base | 2026-08-27 | high |

## Common Change Routes

| Task Type           | Start Here | Then Check | Verification | Last Verified  | Confidence |
| ------------------- | ---------- | ---------- | ------------ | -------------- | ------ |
| 调整组件版本策略      | `OpenScope-技术架构.md` §20 | `OpenScope-项目架构.md` §13、V0.1 owner contract | `./tools/verify-docs.sh` + BOM check | 2026-08-27 | high |
| 调整 Collector 管线  | 技术架构 §10 | V0.1 owner contract Signal Contracts | `./tools/verify-docs.sh`；出码后执行上游配置校验 | 2026-08-27 | high |
| 新增模块/目录规划     | 技术架构 §22（单一权威） | 项目架构 §14 只引用不复列 | `./tools/verify-docs.sh` | 2026-08-27 | high |
| 修订安全/脱敏设计    | 技术架构 §12 | 项目架构 §11.1 三道防线 | 交叉引用检查 | 2026-08-27 | high |
| AGE 文档操作         | `AGENTS.md` → `docs/index.md` | 对应 owner doc | `./tools/mission-driver.sh list` | 2026-08-27 | high |

## Large Or Fragile Files

| Path | Risk     | Preferred Approach |
| -------- | -------- | ------------------ |
| `OpenScope-技术架构.md` | 全局权威，段落间强耦合（§20 BOM ↔ §10 管线 ↔ §4 接入模式） | 改前先通读相关联章节，避免局部改出矛盾 |
| `OpenScope-项目架构.md` | 与技术架构互为镜像引用，易漂移 | 结构性内容只改技术架构侧并保持引用指针 |

## Project-Specific Search Hints

- Use content anchors: `One Official Backend`、`BOM`、`模式 A`、`Tail Sampling`、`三道防线`
- 检查双文档漂移：对同一关键词分别在两份根文档中 grep 对比
- Avoid editing generated files: `docs/plans/*/`(引擎运行时生成)、`.env`

## Update Rule

Update this file when a change creates a new major entry point, moves common code, adds a new test location, or repeatedly causes agents to rediscover the same path.

If a listed path is missing, placeholders remain, or live imports contradict this map, do not treat the map as authority. Verify with the live repo, then update the map or mark the row low confidence before implementation.

V0.1 Phase 0/1 出现代码后必须重写本文件：用真实 Maven、distribution、grafana、cli、examples 与验证入口替换规划期路由。
