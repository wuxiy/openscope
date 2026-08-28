# AGENTS.md

> OpenScope —— OpenTelemetry-native observability distribution/framework（OTel Native + Collector Centric + One Official Backend + Multiple Topologies）。V0.1 standalone 已实施（2026-08-28 验收 accepted）。本项目使用 Attractor-Guided Engineering（AGE）工作流进行 AI 辅助开发。

## 每次任务必读（最小集）

1. `docs/context/project-context.md` — 项目身份、技术基线、验证命令、红线
2. `docs/context/ai-autonomy-policy.md` — 自主级别、Protected Areas、reviewer 可用性
3. `docs/context/codebase-map.md` — 仓库地图与常见变更路由

事实冲突或不确定归属时，读 `docs/context/source-of-truth-and-precedence.md`。

**当前活跃工作**从 未完成 plans（`docs/plans/`）+ `docs/backlog/README.md` 查找——不要在 project-context 里找这个字段，它故意不存在。

## 环境事实

- 包管理器/构建：**Maven**（Java，非 npm）；构建命令 `./mvnw -q -pl examples/springboot-simple -am verify`
- 验证命令：`./tools/verify-docs.sh`、`./tools/resolve-bom.sh --check`、`./cli/openscope doctor`、`./tools/verify-v0.1.sh`（25 项集成验收）；完整命令表见 project-context
- 引擎：AGE mission-driver（missions/{base,demo,onboarding}.json）

## 行为硬规则

- 先做任务分类与路由，再动手 → 见 [task-routing](docs/agents/task-routing.md)
- Protected Area 默认 ask-first；Loosening autonomy 需 human confirmation
- 两份根架构文档（《OpenScope-项目架构》《OpenScope-技术架构》）不允许漂移：结构性结论单一权威、另一处引用
- 变更完成后必须更新 dev log 与 owner doc → 见 [docs-maintenance](docs/agents/docs-structure-and-maintenance.md)
- 重要结论落文件，不留在 chat

## 执行规则层（按需加载）

| 文件 | 内容 | 何时读 |
|---|---|---|
| [docs/agents/task-routing.md](docs/agents/task-routing.md) | 任务分类、路由步骤、Skill Usage Rule | 每个编码任务开始前 |
| [docs/agents/workflow.md](docs/agents/workflow.md) | Default Workflow、File-in/File-out、Optional Layers | 执行工作流或遇到歧义输入时 |
| [docs/agents/planning-and-audit.md](docs/agents/planning-and-audit.md) | Planning Triggers、No-Plan Path、cold replay、audit 规则 | 判断是否需要 plan / plan 审计时 |
| [docs/agents/docs-structure-and-maintenance.md](docs/agents/docs-structure-and-maintenance.md) | 目录职责表、Change Maintenance、经验沉淀阶梯 | 完成变更后 / 归属不明时 |

其余详细路由（哪个问题读哪份文档）见 `docs/index.md`。
