# Codebase Map

## Purpose

This file gives AI agents a compact map of the live repository so they do not rediscover the structure by repeatedly searching imports and directories.

Keep it current enough to route common work. Do not turn it into a full architecture document.

## Entry Points

**V0.1 已实施并于 2026-08-29 验收 accepted。**设计权威在前，实现路径在后。

| Area         | Path | Notes | Last Verified  | Confidence |
| ------------ | -------- | --------- | -------------- | ------ |
| 产品定位与目标   | `README.md`, `OpenScope-项目架构.md` | 拓扑模型/Dashboard 模型/演进路线 | 2026-08-28 | high |
| 技术基线权威     | `OpenScope-技术架构.md` | 选型/BOM §20/仓库结构 §22/管线 §10 | 2026-08-28 | high |
| V0.1 合同/验收   | `docs/architecture/v0.1-standalone-contract.md`, `docs/testing/v0.1-acceptance-checklist.md` | AC-01..AC-16 accepted；完整证据见 `docs/testing/2026/08-29.md` | 2026-08-29 | high |
| Compose 栈      | `distribution/standalone/docker-compose.yml` + `config/{collector,prometheus,tempo,loki}/` | 五组件栈，BOM digest pin，无浮动 tag | 2026-08-28 | high |
| 版本权威        | `distribution/bom.yaml` | 唯一版本源（tag+digest+来源+日期） | 2026-08-28 | high |
| CLI            | `cli/openscope` | start/stop/status/doctor/version，BOM 注入 + C5 密码 gate | 2026-08-28 | high |
| 示例应用        | `examples/springboot-simple/` | Java 21 + OTel Java Agent 接入，ok/fail/sensitive 三端点 | 2026-08-28 | high |
| Grafana 资产    | `grafana/provisioning/{datasources,dashboards}/` + `grafana/dashboards/` | 三 datasource UID 固定 + OpenScope Overview | 2026-08-28 | high |
| 验证工具链      | `tools/{verify-docs,resolve-bom,verify-v0.1,verify-v0.1-remote}.sh` | 静态/BOM/三信号独立脱敏/RED+Grafana/远端隔离验收 | 2026-08-29 | high |
| 引擎入口       | `tools/mission-driver.sh` | AGE mission 执行引擎 shim | 2026-08-27 | high |
| Mission 定义    | `missions/{base,demo,onboarding}.json` | extends 关系：onboarding→base | 2026-08-27 | high |

## Common Change Routes

| Task Type           | Start Here | Then Check | Verification | Last Verified  | Confidence |
| ------------------- | ---------- | ---------- | ------------ | -------------- | ------ |
| 调整组件版本策略      | `distribution/bom.yaml` | 技术架构 §20（下限/策略）、项目架构 §13 | `./tools/resolve-bom.sh --check` + `./tools/verify-docs.sh` | 2026-08-28 | high |
| 调整 Collector 管线  | `distribution/standalone/config/collector/collector.yaml` | 技术架构 §10 + V0.1 contract Signal Contracts | `docker run ... validate` + `./tools/verify-v0.1.sh` | 2026-08-28 | high |
| 改动 Compose/端口/卷 | `distribution/standalone/docker-compose.yml` | `.env.example` 同步、C4 端口边界（只用 127.0.0.1） | `docker compose config --quiet` | 2026-08-28 | high |
| 改 Grafana 资产      | `grafana/provisioning/**` | UID 与 contract 一致、dashboard JSON | `./tools/verify-docs.sh` + doctor | 2026-08-28 | high |
| Java 示例/埋点        | `examples/springboot-simple/` | `-Dotel.*` 参数（含 `metric.export.interval`、resource.attributes） | `./mvnw -q -pl examples/springboot-simple -am verify` | 2026-08-28 | high |
| CLI 行为            | `cli/openscope` | BOM 注入、C5 密码 gate、fail-closed | `bash -n` + 远端 doctor | 2026-08-28 | high |
| 修订安全/脱敏设计    | 技术架构 §12 | 项目架构 §11.1 三道防线、collector redaction processors | application non-capture + direct OTLP trace/metric/log controls（`verify-v0.1.sh` E 段） | 2026-08-29 | high |
| AGE 文档操作         | `AGENTS.md` → `docs/index.md` | 对应 owner doc | `./tools/mission-driver.sh list` | 2026-08-27 | high |

## Large Or Fragile Files

| Path | Risk     | Preferred Approach |
| -------- | -------- | ------------------ |
| `OpenScope-技术架构.md` | 全局权威，段落间强耦合（§20 BOM ↔ §10 管线 ↔ §4 接入模式） | 改前先通读相关联章节，避免局部改出矛盾 |
| `OpenScope-项目架构.md` | 与技术架构互为镜像引用，易漂移 | 结构性内容只改技术架构侧并保持引用指针 |
| `distribution/standalone/docker-compose.yml` | digest 变量拼接（`@${...DIGEST}` 前缀）易错 | 改后必跑 `docker compose config` 校验渲染结果 |
| `tools/verify-v0.1.sh` | 36 项验收逻辑 + 时序轮询（Tempo 索引延迟/首导出窗口） | 改动后 `bash -n` + 远端完整重跑 |

## Project-Specific Search Hints

- Use content anchors: `One Official Backend`、`BOM`、`模式 A`、`Tail Sampling`、`三道防线`、`metric.export.interval`
- 检查双文档漂移：对同一关键词分别在两份根文档中 grep 对比
- Avoid editing generated files: `docs/plans/*/`（引擎运行时产物）、`.env`（gitignored 真实秘密）

## Update Rule

Update this file when a change creates a new major entry point, moves common code, adds a new test location, or repeatedly causes agents to rediscover the same path.

If a listed path is missing, placeholders remain, or live imports contradict this map, do not treat the map as authority. Verify with the live repo, then update the map or mark the row low confidence before implementation.

后续新增（central/distributed 拓扑、openscope-spring-boot-starter 代码、V0.2 示例扩展）落地时同步更新本表。
