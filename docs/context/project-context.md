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
- Product type: 可观测性发行版/框架（OTel-native observability distribution）；**V0.1 standalone 已实施并验收**（2026-08-28）
- Primary users: cywu 个人自研项目（Family-OS/Health-OS/Teacher-OS/Everglow/XiangLiZhi）、公司内部（Data-OS 等）、政务/医疗交付项目
- Documentation freshness: `fresh`（两份根目录架构文档 2026-08-27 完成评审与修订，AGE 上下文同日建立）

**Freshness gating:**

- If freshness is `stale` or `unknown`, agents may research, audit, and draft alignment docs, but must not implement product behavior until the baseline is re-established or a human confirms intended behavior.
- If freshness is `partially stale`, agents may implement only slices whose requirement, owner doc, codebase-map route, and touched code area have been verified fresh; otherwise treat the slice as `plan-first` or `research-only`.
- AI may not mark stale docs fresh without human confirmation or human-approved owner-doc evidence.

## Current Technical Baseline

- Frontend stack: none（V1 无自研前端，可视化统一走 Grafana Provisioning）
- Backend stack: **V0.1 已实施**（2026-08-28 验收通过）——Java 21 / Spring Boot 示例（examples/springboot-simple）+ OTel Java Agent 2.31.1（零侵入接入）；数据平面 opentelemetry-collector-contrib 0.159.0；后端 Prometheus v3.14.0（原生 OTLP Receiver）+ Grafana Tempo 3.0.3 + Loki 3.7.6（原生 OTLP 端点）+ Grafana 13.2.0；部署 standalone docker-compose
- Database/model source: none（不自研存储；组件版本权威 = Distribution BOM `distribution/bom.yaml`，见《OpenScope-技术架构》§20；仓库结构权威 = 《OpenScope-技术架构》§22）
- 自研件：`examples/springboot-simple`（ProbeController ok/fail/sensitive 三端点）、`cli/openscope`（start/stop/status/doctor/version）、`tools/{resolve-bom,verify-docs,verify-v0.1,verify-v0.1-remote}.sh`、`distribution/standalone`（compose+config+env 模板）、`grafana/provisioning`（三 datasource + dashboard）

## Verification Commands

**真实命令（V0.1 验收用过，全部有效）**。`mission-driver.sh run demo` 只能验证 AGE 流程，不得作为 V0.1 产品通过证据。

| Purpose | Command |
| --- | --- |
| Java build/test | `./mvnw -q -pl examples/springboot-simple -am verify`（exit 0, Java 21） |
| BOM integrity | `./tools/resolve-bom.sh --check` |
| Documentation check | `./tools/verify-docs.sh` |
| Compose static check | `docker compose --env-file distribution/standalone/.env -f distribution/standalone/docker-compose.yml config --quiet` |
| V0.1 product integration（25 项信号/安全/相关性检查） | `AGENT_JAR=dependencies/opentelemetry-javaagent.jar ./tools/verify-v0.1.sh`（验收时 25/25 PASSED ×2） |
| Remote acceptance runner | `./tools/verify-v0.1-remote.sh`（SSH 到 172.16.65.59 全流程） |
| Runtime doctor | `./cli/openscope doctor` |
| start/stop/status/version | `./cli/openscope start|stop|status|version` |
| AGE scaffold smoke | `./tools/mission-driver.sh list` |

## Development Validation Environment

- Required V0.1 runtime validation host: `ssh root@172.16.65.59`（SSH key 由操作者环境管理，仓库不保存密码、私钥或 key path）。
- SSH safety options: `BatchMode=yes`、`StrictHostKeyChecking=yes`、`ForwardAgent=no`；自动验证不得关闭 host-key 校验。
- 2026-08-28 只读探测：CentOS Stream 9 / `x86_64` / 16 vCPU / 62 GiB RAM / Java 21.0.11 / Docker 29.5.3 / Compose 5.1.4 / Buildx 0.34.1。
- 该主机是共享开发环境，探测时有 33 个运行容器；V0.1 必须使用独立工作目录 `/root/workspace/openscope-v0.1`、依赖目录 `/root/workspace/openscope-v0.1/dependencies` 和 Compose project `openscope-v01`，不得把依赖散落在 `/root` 或 `/root/workspace` 根层，也不得停止、重建、清理或修改非 OpenScope 资源。
- `127.0.0.1:3000` 和 `0.0.0.0:13000` 已占用；开发验证 profile 使用 `127.0.0.1:13001` 暴露 Grafana，OTLP 保持 `127.0.0.1:4317/4318`。每次运行前必须重新探测，冲突时 fail closed，不得抢占端口。
- 根文件系统探测时剩余约 14 GiB、使用率 83%、无 swap；远端 preflight 必须阻止低空间启动，不得自动执行 `docker system prune` 或删除既有镜像/volume。
- Maven Central 可访问；Docker Hub Registry 直连超时，Buildx manifest inspect 同样超时。Phase 0 必须先建立可审计的镜像获取/manifest 解析路径，否则远端运行保持 blocked。

以上为时间敏感环境事实，实施和验收必须重新采集并在 `docs/testing/` 记录，不得从本段直接推断当次环境通过。

## Optional Layers Currently In Use

Mark only the optional layers this project actually maintains.

- [ ] `docs/discussions/`
- [x] `docs/audits/`
- [x] `docs/testing/`
- [x] `docs/skills/`
- [ ] `docs/analysis/`
- [ ] `docs/retrospectives/`
- [ ] `docs/lessons/`

## AI Block Conditions

AI MUST stop and wait for human input before proceeding when:

- 除已通过 human draft review 的 Phase 0 bootstrap 外，Maven/BOM/product verification 入口尚未创建、与实情不符或不能 fail-closed；文档层工作不受此限
- any change touches payment or data-deletion paths with no existing test coverage and no owner doc describing expected behavior
- no requirement or owner doc describes the intended behavior of the change — do not implement into a vacuum

These are project-specific hard stops in addition to `AGENTS.md`, `docs/context/ai-autonomy-policy.md`, source-of-truth conflict rules, and required plan/closure audit rules.

For ambiguity that does not affect user-visible behavior, contracts, protected areas, or closure evidence, resolve by writing assumptions into the relevant doc and proceed according to the autonomy policy. Mark uncertain assumptions explicitly so humans can review later.

### 本项目特定红线

- 不得修改组件版本下限（Prometheus ≥3.0、Loki ≥3.0）或绕过 BOM 单一版本策略，除非 cywu 明确确认
- 不得让《项目架构》与《技术架构》两份根文档内容漂移：结构性结论只允许在一处定义（技术架构 §22 仓库结构），另一处引用
- 政务/医疗相关设计不得削弱"脱敏三道防线"中的第一道（应用侧不采集敏感属性）

## Notes For AI Agents

- If this file is empty or stale, ask for or create a context update before large implementation work.
- 根目录的《OpenScope-项目架构.md》与《OpenScope-技术架构.md》是本项目的两份核心设计输入，任何架构相关工作先读它们，再读本 docs/ 层。
