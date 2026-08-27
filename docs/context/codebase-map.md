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
| 引擎入口       | `tools/mission-driver.sh` | AGE mission 执行引擎 shim | 2026-08-27 | high |
| Mission 定义    | `missions/{base,demo,onboarding}.json` | extends 关系：onboarding→base | 2026-08-27 | high |

## Common Change Routes

| Task Type           | Start Here | Then Check | Verification | Last Verified  | Confidence |
| ------------------- | ---------- | ---------- | ------------ | -------------- | ------ |
| 调整组件版本策略      | `OpenScope-技术架构.md` §20 | `OpenScope-项目架构.md` §13 | `grep -n "minVersion\|3.x\|3.0"` 两份同步 | 2026-08-27 | high |
| 调整 Collector 管线  | 技术架构 §10 | §3.4/§3.5 版本前提 | 人工 review（无 CI） | 2026-08-27 | high |
| 新增模块/目录规划     | 技术架构 §22（单一权威） | 项目架构 §14 只引用不复列 | 占位符 grep | 2026-08-27 | high |
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

V0.1 出现代码后必须重写本文件：补充 java/、distribution/、grafana/、cli/ 等真实路径。
