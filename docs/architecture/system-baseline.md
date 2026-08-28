# System Baseline

> 中文为本文档工作语言（见 docs/context/conventions.md Language Rule）。
> 权威来源：根目录《OpenScope-技术架构》。本文件是简明摘要，冲突时以根文档为准。

## Runtime Shape（当前）

**V0.1 standalone 已实施**（2026-08-28 验收通过）。实现路径 `distribution/standalone/`：

```text
standalone   docker-compose（project: openscope-v01）
             collector(4317/4318) + prometheus(9090) + tempo(3200) + loki(3100) + grafana(13001/3000)
             后端端口仅容器内网，host 只 publish grafana + OTLP，默认绑 127.0.0.1
```

central / distributed 仍为设计阶段（见《OpenScope-项目架构》§7）。

## Current Stack（已实现，BOM 锁定 `distribution/bom.yaml`）

| 层 | 选型（tag @ digest） | 版本下限 |
|---|---|---|
| Telemetry 标准 | OpenTelemetry | 最新稳定 |
| 协议 | OTLP gRPC / HTTP | — |
| Java 自动埋点 | 模式 A javaagent 2.31.1（`examples/springboot-simple` 验证） | 最新稳定 |
| Data Plane | opentelemetry-collector-contrib 0.159.0（otlphttp exporter，无 filelog/stdout 通路） | 最新稳定版 |
| Metrics | Prometheus v3.14.0（`--web.enable-otlp-receiver`） | > 3.x |
| Traces | Grafana Tempo 3.0.3 | 最新稳定 |
| Logs | Grafana Loki 3.7.6（原生 `/otlp/v1/logs`，TSDB schema v13） | ≥ 3.0 |
| UI / Alert | Grafana 13.2.0 Provisioning（datasource UID `openscope-{prometheus,tempo,loki}` + OpenScope Overview dashboard） | 最新稳定 |
| 部署/运维 | Docker Compose + `cli/openscope`（start/stop/status/doctor/version） | — |

## Key Decisions（2026-08-27 锁定）

- Metrics 管线 `otlphttp/prometheus` 直推原生 OTLP Receiver，弃 `prometheusremotewrite`
- Agent 与 Starter 双模式并存但互斥；doctor 检测叠加冲突
- Micrometer 存量项目允许 Prometheus 直接 scrape actuator（不必绕 Collector）
- Tail Sampling 在 V1.x 于 Gateway 引入；此前 Local 默认 100% 上传
- SLO 最小实现 = Recording Rule + burn rate 告警（V1.0）
- V0.1 owner contract = `docs/architecture/v0.1-standalone-contract.md`；只实施 standalone + Java Agent + OTLP 三信号 + 基础关联 Dashboard + 最小 CLI
- V0.1 日志唯一通路 = Java Agent Logback instrumentation → OTLP LogRecord → Collector → Loki；stdout/filelog 延后

## Testing Stack（已实现）

V0.1 已配套产品级验证链：

- **静态**：`verify-docs.sh`（结构+占位符+敏感扫描）、`resolve-bom.sh --check`、上游配置官方校验（collector `validate` / `promtool check config` / loki `-verify-config`）、`bash -n` 全脚本
- **构建**：`./mvnw -q -pl examples/springboot-simple -am verify`（Java 21）
- **集成（25 项）**：`verify-v0.1.sh` → Tempo trace（成功/失败/资源属性）、Prometheus target_info+RED+六标签、Loki OTLP 日志、trace_id 关联、canary 三路脱敏——验收 25/25 PASSED ×2
- **Distribution**：`verify-v0.1-remote.sh`（远端隔离 workdir + Compose project 全流程，含 H/G 持久化与 doctor 失败注入）

后续规划：Unit（Starter/config/redaction 规则）→ Integration 扩展（springboot-postgresql/-redis/-kafka）→ Distribution Test（upgrade/backup）。

V0.1 完整 runtime/distribution acceptance 已在 `root@172.16.65.59` 的隔离 workdir 与 Compose project 中执行；共享主机保护与环境事实以 `docs/architecture/v0.1-standalone-contract.md` 为准。

## Stable Rules

- 依赖方向：Application → OTel → Convention(Starter) → OTLP → Collector → Backends；禁止 Application 直连任何 Backend 私有协议/API
- 所有 Backend/Grafana 配置必须 Git 管理 + Provisioning 发布，禁止生产环境 UI 手工维护关键配置
- 仓库结构唯一权威：技术架构 §22；模块边界见 `module-boundaries.md`

## Update Rule

When the supported baseline changes, update this file in the same change.
