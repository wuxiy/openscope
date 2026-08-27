# System Baseline

> 中文为本文档工作语言（见 docs/context/conventions.md Language Rule）。
> 权威来源：根目录《OpenScope-技术架构》。本文件是简明摘要，冲突时以根文档为准。

## Runtime Shape（当前）

Pre-code 设计阶段。规划三拓扑：

```text
standalone   单机 docker-compose：collector + prometheus + tempo + loki + grafana
central      多应用 → Central Collector → 同一套后端
distributed  Local Collector(persistent queue) → Gateway Collector(routing/redaction) → Backends
```

## Planned Stack

| 层 | 选型 | 版本下限 |
|---|---|---|
| Telemetry 标准 | OpenTelemetry | 最新稳定 |
| 协议 | OTLP gRPC / HTTP | — |
| Java 自动埋点 | 模式 A javaagent / 模式 B openscope-spring-boot-starter（二选一） | 最新稳定 |
| Data Plane | opentelemetry-collector-contrib | 最新稳定版 |
| Metrics | Prometheus（原生 OTLP Receiver） | > 3.x |
| Traces | Grafana Tempo | 最新稳定 |
| Logs | Grafana Loki（原生 `/otlp/v1/logs`，TSDB schema v13） | ≥ 3.0 |
| UI / Alert | Grafana Provisioning + Managed Alerts | 最新稳定 |
| 部署 | Docker Compose（K8s/Helm 为 V2） | — |

## Key Decisions（2026-08-27 锁定）

- Metrics 管线 `otlphttp/prometheus` 直推原生 OTLP Receiver，弃 `prometheusremotewrite`
- Agent 与 Starter 双模式并存但互斥；doctor 检测叠加冲突
- Micrometer 存量项目允许 Prometheus 直接 scrape actuator（不必绕 Collector）
- Tail Sampling 在 V1.x 于 Gateway 引入；此前 Local 默认 100% 上传
- SLO 最小实现 = Recording Rule + burn rate 告警（V1.0）

## Testing Stack（规划）

Unit（Starter/config/redaction 规则）→ Integration（springboot-simple/-postgresql/-redis/-kafka 示例验证端到端落库）→ Distribution Test（standalone 安装/升级/备份为必测最低集）。

## Stable Rules

- 依赖方向：Application → OTel → Convention(Starter) → OTLP → Collector → Backends；禁止 Application 直连任何 Backend 私有协议/API
- 所有 Backend/Grafana 配置必须 Git 管理 + Provisioning 发布，禁止生产环境 UI 手工维护关键配置
- 仓库结构唯一权威：技术架构 §22；模块边界见 `module-boundaries.md`

## Update Rule

When the supported baseline changes, update this file in the same change（V0.1 出现代码后重写 Runtime Shape 与 Testing Stack）。
