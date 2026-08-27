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
- Backend stack: 规划中——V0.1 使用 Java 21 / Spring Boot + OTel Java Agent；后续再评估自研 Java 模块；数据平面 opentelemetry-collector-contrib；后端 Prometheus ≥3.0 + Grafana Tempo + Loki ≥3.0 + Grafana
- Database/model source: none（不自研存储；组件版本权威 = Distribution BOM，见《OpenScope-技术架构》§20；仓库结构权威 = 《OpenScope-技术架构》§22）

## Verification Commands

当前 pre-code 阶段只有文档与 AGE 脚手架命令真实存在。V0.1 plan 通过 human draft review 后，Phase 0 是唯一允许的 bootstrap implementation；它必须先创建并验证 Maven Wrapper、BOM 解析和产品验证入口，之后才可进入产品装配。

| Current Purpose | Command |
| --- | --- |
| AGE scaffold smoke（非产品 E2E） | `./tools/mission-driver.sh list` |
| Documentation check | `./tools/verify-docs.sh` |

Plan 激活后按阶段建立的命令：

| Planned Purpose | Owning Phase And Command |
| --- | --- |
| Java build/test（Phase 0 创建） | `./mvnw -q verify` |
| BOM integrity（Phase 0 创建） | `./tools/resolve-bom.sh --check` |
| Compose static check（Phase 1 起可执行） | `docker compose --env-file distribution/standalone/.env.example -f distribution/standalone/docker-compose.yml config --quiet` |
| V0.1 product integration（Phase 0 创建入口，Phase 2 起逐步实现） | `./tools/verify-v0.1.sh` |
| Runtime doctor（Phase 4 创建） | `./cli/openscope doctor` |

`mission-driver.sh run demo` 只能验证 AGE 流程，不得作为 V0.1 产品通过证据。

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
