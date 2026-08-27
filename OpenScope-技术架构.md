# OpenScope 技术架构文档

> OpenScope Technical Architecture

## 1. 技术目标

OpenScope 技术架构以“轻量、标准、稳定、易部署、可扩展”为原则。

核心技术决策：

- OpenTelemetry 作为统一 Telemetry 标准；
- OTLP 作为统一数据传输协议；
- OpenTelemetry Collector 作为统一数据平面；
- OpenTelemetry Java Agent 与 Spring Boot Starter 双模式并存（同一 JVM 二选一）；
- Metrics 使用 Prometheus；
- Traces 使用 Grafana Tempo；
- Logs 使用 Grafana Loki；
- Visualization 使用 Grafana；
- V1 不正式维护 SkyWalking / SigNoz / OpenObserve 多套后端；
- 所有部署拓扑共用同一套核心技术栈。

---

## 2. 技术选型

| 层 | 技术 |
|---|---|
| Telemetry Standard | OpenTelemetry |
| Protocol | OTLP gRPC / OTLP HTTP |
| Java Auto Instrumentation | OpenTelemetry Java Agent |
| Java Embedded | OpenTelemetry Spring Boot Starter |
| Business Instrumentation | OpenTelemetry API |
| OpenScope Java Integration | 自研轻量 Starter |
| Data Plane | OpenTelemetry Collector Contrib |
| Metrics | Prometheus |
| Traces | Grafana Tempo |
| Logs | Grafana Loki |
| Visualization | Grafana |
| Alert | Grafana Alerting / Alertmanager |
| Deployment | Docker Compose 优先 |
| Kubernetes | 后期支持 Helm |
| Scale-out Metrics | Mimir，后期 |
| Profiling | Pyroscope，后期 |
| Auto Instrumentation | Odigos，后期 |

---

## 3. 技术选型原则

### 3.1 为什么选择 OpenTelemetry

OpenTelemetry 解决跨语言 Telemetry 标准化问题。

统一：

- Trace；
- Metric；
- Log；
- Resource；
- Context；
- Baggage；
- Semantic Conventions；
- OTLP。

避免 OpenScope 自定义私有协议和私有数据模型。

---

### 3.2 为什么 Collector 是 Core

Collector 提供稳定的数据平面。

应用：

```text
Application
    ↓
OTLP
    ↓
Collector
```

而不是：

```text
Application
    ↓
Prometheus / Loki / Tempo
```

这样后端替换不会影响应用。

Collector 统一处理：

- Receiver；
- Processor；
- Connector；
- Exporter；
- Retry；
- Queue；
- Storage；
- Sampling；
- Routing。

---

### 3.3 为什么 Trace 选择 Tempo

Tempo 适合作为 OpenTelemetry Trace Backend：

- OTLP 兼容；
- 与 Grafana 集成；
- 与 Prometheus Metrics 关联；
- 与 Loki Logs 关联；
- 支持 TraceQL；
- 架构简单；
- 支持对象存储；
- 可从小规模演进到大规模。

V1 不使用 Jaeger 作为默认 Trace Backend。

---

### 3.4 为什么 Metrics 选择 Prometheus

Prometheus 作为 V1 指标数据库：

- 生态成熟；
- PromQL 事实标准；
- Spring Boot / Micrometer 生态成熟；
- Grafana 支持成熟；
- 单机足够覆盖当前规模。

OpenScope 锁定 **Prometheus ≥ 3.0**：Metrics 通过原生 OTLP Receiver（`--web.enable-otlp-receiver`）直接接收 Collector 的 OTLP 推送，与应用侧 Trace/Log 链路完全统一，不再依赖 `prometheusremotewrite` exporter。

Mimir 仅在真正出现以下需求时考虑：

- 长期 Metrics Retention；
- 高可用；
- 多租户；
- 单 Prometheus 容量瓶颈；
- 超大 active series。

---

### 3.5 为什么 Logs 选择 Loki

相较 ELK / Elasticsearch：

- 部署更轻；
- 与 Grafana 统一；
- 与 Tempo Trace 关联简单；
- 适合结构化应用日志；
- 运维成本相对低。

OpenScope 默认推荐结构化日志，而不是纯文本日志。

OpenScope 锁定 **Loki ≥ 3.0**：日志通过 Loki 原生 OTLP 端点（`/otlp/v1/logs`）直接接收 OTLP 推送。社区 `lokiexporter` 已在 otel-collector-contrib 中废弃并移除，禁止使用旧接入方式；存储使用 TSDB index + 结构化元数据（schema v13）作为默认配置。

---

### 3.6 为什么不默认使用 SkyWalking

SkyWalking 是优秀的一体化 APM，但 OpenScope 需要：

- OTel First；
- 多语言；
- Backend-neutral；
- 应用不绑定特定平台；
- 与 Metrics / Logs / Traces 独立演进。

因此 SkyWalking 作为未来 Backend Adapter，而不是 Core。

---

### 3.7 为什么 V1 不使用 SigNoz / OpenObserve

不是因为能力不足，而是为了控制维护成本。

如果同时正式支持：

- Grafana Stack；
- SigNoz；
- OpenObserve；
- SkyWalking；

需要同时维护：

- Dashboard；
- Alert；
- Query；
- Deployment；
- Upgrade；
- Storage；
- Version Compatibility。

V1 坚持：

> **One Official Backend**

---

## 4. Java 接入架构

OpenScope 提供两种接入模式，**都正式支持**。两者在 OTel SDK 层面互斥（同一 JVM 只能选其一），业务上按项目形态选择：

| | 模式 A：Java Agent | 模式 B：Spring Boot Starter |
|---|---|---|
| 代码侵入 | 零侵入 | 引入依赖 |
| 自动埋点 | HTTP/JDBC/Redis/Kafka 等全量自动 | 基于官方 OTel Spring Boot Starter 自动埋点 |
| 业务 Span API | 弱 | 强（封装 Custom Span / Context API） |
| MDC / 日志关联 | Agent logging instrumentation | Starter 直接集成 |
| 适用场景 | 政务/医疗交付、无法改代码的旧系统 | 自研 Spring Boot 项目（Family-OS、Data-OS 等） |

> **约束**：模式 A 与模式 B 不能混用——同时启用 Java Agent 和 OTel Spring Boot Starter 会造成双重埋点（重复 span / 重复 JVM 指标）。`openscope doctor` 应检测并告警此冲突。

### 4.1 模式 A：Java Agent

推荐：

```bash
java \
  -javaagent:/opt/openscope/agents/opentelemetry-javaagent.jar \
  -Dotel.service.name=data-api \
  -Dotel.exporter.otlp.endpoint=http://otel-collector:4318 \
  -jar app.jar
```

目标：

- 零代码接入；
- 自动 HTTP Trace；
- JDBC；
- Redis；
- Kafka；
- RPC；
- JVM；
- Logging Context。

---

### 4.2 OpenScope Spring Boot Starter

模块：

```text
openscope-spring-boot-starter
```

职责：

- Resource Convention；
- `project.id`；
- `site.id`；
- Environment；
- Service Naming；
- MDC；
- Logging；
- Sensitive Field Policy；
- 自定义业务 Span API 封装；
- 默认配置；
- Health Indicator；
- OpenScope Metadata。

不负责：

- 自研 Trace SDK；
- 自研 Metrics SDK；
- 与 Java Agent 同 JVM 叠加使用。

---

## 5. Java 配置模型

建议：

```yaml
openscope:
  enabled: true

  project:
    id: data-os

  site:
    id: company

  environment:
    name: production

  service:
    namespace: data-platform
    name: data-api
    version: 1.0.0

  otlp:
    endpoint: http://otel-collector:4318

  telemetry:
    traces: true
    metrics: true
    logs: true

  security:
    redaction: strict
```

最终映射到 OTel Resource：

```text
project.id=data-os
site.id=company
deployment.environment.name=production
service.namespace=data-platform
service.name=data-api
service.version=1.0.0
```

---

## 6. Resource Convention

优先采用 OTel Semantic Conventions。

OpenScope 扩展字段必须使用明确命名空间。

推荐：

```text
project.id
site.id
```

核心标准字段：

```text
service.name
service.namespace
service.version
service.instance.id
deployment.environment.name
host.name
container.id
k8s.namespace.name
k8s.pod.name
```

禁止创建重复字段：

```text
appName
applicationName
projectName
serviceId
```

---

## 7. Logging 架构

V0.1 推荐应用日志通路：

```text
Spring Boot Logback event
   ↓ Java Agent logback appender instrumentation
OTLP LogRecord（标准 trace_id / span_id 字段）
   ↓ OTLP/HTTP
OTel Collector
   ↓ Loki native OTLP
Loki
```

V0.1 不使用 stdout/filelog 或 Docker JSON 日志采集；这些路径需要独立的文件发现、轮转、权限和重复采集合同，后续另立需求。概念日志结构：

```json
{
  "timestamp": "2026-08-27T14:00:00+08:00",
  "level": "ERROR",
  "service.name": "data-api",
  "project.id": "data-os",
  "trace_id": "...",
  "span_id": "...",
  "message": "request failed"
}
```

必须支持：

```text
Logs → Trace
Trace → Logs
```

---

## 8. Metrics 架构

支持两种模式。

### 8.1 OTel Native Metrics

```text
Application
   ↓
OTel Metrics SDK
   ↓
OTLP
   ↓
Collector
   ↓
Prometheus
```

### 8.2 Spring Boot / Micrometer Compatible

```text
Spring Boot Actuator
    ↓
/actuator/prometheus
    ↓
Collector Prometheus Receiver
    ↓
Prometheus
```

原则：

- 不强迫旧项目一次性迁移；
- 新项目优先 OTel Native；
- 已有 Micrometer 项目保持兼容。

---

## 9. Trace 架构

```text
Spring Boot
   ↓
OTel Java Agent
   ↓
OTLP
   ↓
Collector
   ↓
Tempo
   ↓
Grafana
```

首期关注：

- HTTP Server；
- HTTP Client；
- JDBC；
- Redis；
- Kafka；
- Scheduled Task；
- Async；
- Exception；
- Custom Business Span。

---

## 10. Collector Pipeline

基础结构：

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  memory_limiter:
  resource:
  attributes:
  transform:
  batch:

exporters:
  otlp/tempo:
  otlphttp/prometheus:
  otlphttp/loki:

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors:
        - memory_limiter
        - resource
        - attributes
        - transform
        - batch
      exporters:
        - otlp/tempo

    metrics:
      receivers: [otlp]
      processors:
        - memory_limiter
        - resource
        - batch
      exporters:
        - otlphttp/prometheus

    logs:
      receivers: [otlp]
      processors:
        - memory_limiter
        - resource
        - attributes
        - transform
        - batch
      exporters:
        - otlphttp/loki
```

版本前提（写入 Distribution BOM，镜像不得低于以下版本）：

- **Prometheus ≥ 3.0**：Metrics 走原生 OTLP Receiver（`--web.enable-otlp-receiver`），Collector 直接 `otlphttp` 推送；不再默认使用 `prometheusremotewrite` exporter。
- **Loki ≥ 3.0**：Logs 走原生 OTLP 端点（`/otlp/v1/logs`）；社区 `lokiexporter` 已废弃移除，禁止采用旧接入方式。
- Tempo、Collector、Grafana 均锁定当前最新稳定版。

实际配置以 OpenScope Distribution 测试版本为准。

V0.1 仅使用已裁决的 `attributes`/`transform` 进行已知敏感 key 删除，并在 BOM 元数据记录每个 Collector component 的逐信号 stability；不得把 alpha redaction/filter 能力包装成生产合规承诺。精确端点、Resource 提升和 processor 顺序见 `docs/architecture/v0.1-standalone-contract.md`。

---

## 11. Sampling

### Development

```text
100%
```

### Test

```text
100%
```

### Production

默认建议逐步支持：

```text
error        → keep
slow request → keep
HTTP 5xx     → keep
normal       → sample
```

V0.1 优先使用简单 head sampling。

Tail Sampling 在后续引入。

原因：

- Tail Sampling 有状态；
- 多 Collector 时需要 Trace-aware routing；
- 增加 Gateway 复杂度。

### 与 Distributed 拓扑的时间线对齐

- V1 Distributed 的验收范围是**数据通路稳定**：Local → Gateway 链路、persistent queue、离线缓冲、回传重试；
- Tail Sampling 引入之前，Local Collector 默认**不做 sampling（100% 上传）**，head sampling 只用于 standalone / central 场景，错误 trace 不受影响；
- Tail Sampling（配合按 traceID 路由的 loadbalancing exporter）作为 V1.x 增强在 Gateway 引入，之后 Local 端才切换为有条件采样；
- 项目架构文档中 "Gateway 做 Sampling" 描述的是目标态，V1 交付清单以本节为准。

---

## 12. Sensitive Data Redaction

默认敏感属性：

```text
authorization
cookie
set-cookie
password
token
access_token
refresh_token
id_card
phone
patient_name
sql.bind.parameters
request.body
response.body
```

处理策略：

```text
Drop
Mask
Hash
Allowlist
```

医疗/政务环境默认：

```text
strict
```

个人普通项目：

```text
standard
```

---

## 13. Persistent Queue

分布式 / 弱网络环境：

```text
Local Collector
    ↓
Persistent Queue
    ↓
Gateway Collector
```

用于：

- VPN 闪断；
- 专线不稳定；
- 上游 Gateway 临时不可用；
- Collector 重启。

Persistent Queue 不替代长期 Storage。

完全隔离环境必须部署本地 Backend。

---

## 14. Deployment Topology

### 14.1 Standalone

```text
docker-compose
├── collector
├── prometheus
├── tempo
├── loki
└── grafana
```

适合：

- 单机；
- 客户内网；
- 政务；
- 医院；
- 开发测试。

V0.1 standalone 的信任边界是单机 loopback：宿主机只暴露 `127.0.0.1:3000/4317/4318`，Prometheus/Tempo/Loki 管理端口只在 Compose 网络可见；Grafana 密码由未提交 `.env` 提供且默认/空密码阻断启动。该边界不得外推到 Central/Distributed；跨网络部署必须另行设计认证、TLS/mTLS 和租户隔离。

---

### 14.2 Central

```text
Applications
    ↓
Central Collector
    ↓
Prometheus / Tempo / Loki
    ↓
Grafana
```

适合：

- Home Server；
- 公司内部；
- 多个自研项目。

---

### 14.3 Distributed

```text
Applications
    ↓
Local Collector
    ↓
Gateway Collector
    ↓
Backends
```

适合：

- 多服务器；
- 多项目；
- 多网络域；
- 弱网络；
- 跨站点。

---

## 15. Grafana Provisioning

OpenScope 必须将 Grafana 配置纳入源码管理。

目录：

```text
grafana/
├── provisioning/
│   ├── datasources/
│   ├── dashboards/
│   └── alerting/
├── dashboards/
│   ├── overview/
│   ├── spring-boot/
│   ├── jvm/
│   ├── http/
│   ├── database/
│   ├── redis/
│   ├── kafka/
│   └── infrastructure/
└── alerts/
```

禁止生产环境人工在 Grafana UI 中长期维护关键配置。

Dashboard / Alert 必须：

- Git 管理；
- Review；
- Versioned；
- 随 Distribution 发布。

---

## 16. Dashboard Variables

统一变量：

```text
site
environment
project
namespace
service
instance
```

所有 Dashboard 必须遵循相同查询上下文。

---

## 17. Alert Model

V1 重点：

### Availability

- 服务不可用；
- 实例 Down。

### HTTP

- 5xx Error Rate；
- P95/P99 Latency；
- Traffic Sudden Change。

### JVM

- Heap Usage；
- GC Pause；
- Thread；
- CPU。

### Database

- Connection Pool Exhaustion；
- Slow Query；
- Error Rate。

### Infrastructure

- CPU；
- Memory；
- Disk；
- Disk Remaining；
- Collector Health。

### SLO（最小实现）

- Prometheus Recording Rule 按 project / service 维度计算可用性与错误率窗口值；
- SLO 目标随 Distribution 配置文件发布并版本化；
- Grafana Managed Alert 基于 budget burn rate 告警（快慢双速率规则）。

V1 不做：多窗口烧毁率完整体系、SLO 管理 API、按租户自定义目标。

---

## 18. Retention

建议默认提供模板。

### Standalone

```yaml
retention:
  metrics: 15d
  logs: 7d
  traces: 3d
```

### Personal Central

```yaml
retention:
  metrics: 30d
  logs: 14d
  traces: 7d
```

### Company Central

```yaml
retention:
  metrics: 90d
  logs: 30d
  traces: 14d
```

最终以磁盘容量与数据量为准。

---

## 19. Storage

V1：

```text
Prometheus → Local / Persistent Volume
Loki       → Local / Object Storage optional
Tempo      → Local / Object Storage optional
Grafana    → Persistent Volume
```

未来建议优先支持：

- S3；
- RustFS；
- Ceph；
- 公有云 Object Storage。

---

## 20. Distribution BOM

OpenScope 统一锁定组件版本。每个 Distribution 发布时锁定**各组件当前最新稳定版**，并设置硬性版本下限：

| 组件 | 版本下限 | 关键前提 |
|---|---|---|
| opentelemetry-collector-contrib | 最新稳定版 | OTLP gRPC/HTTP、otlphttp exporter |
| Prometheus | ≥ 3.0 | 原生 OTLP Receiver（`--web.enable-otlp-receiver`） |
| Loki | ≥ 3.0 | 原生 OTLP 端点 `/otlp/v1/logs`；TSDB schema v13 |
| Tempo | 最新稳定版 | TraceQL |
| Grafana | 最新稳定版 | Provisioning |

V0.1 的 exact candidate tag、Java Agent SHA-256 与 digest 物化规则见 `docs/architecture/v0.1-standalone-contract.md`。`distribution/bom.yaml` 落地后是唯一机器权威，Compose 只能使用 `tag@sha256:digest`；未解析 digest 的候选版本不得启动。

版本策略：

- 一个 OpenScope 版本对应一组组件版本；
- 不允许用户任意升级单组件；
- 所有组合必须经过集成测试；
- Upgrade 以 Distribution 为单位。

---

## 21. CLI

建议提供统一 CLI：

```bash
openscope init
openscope start
openscope stop
openscope restart
openscope status
openscope doctor
openscope logs
openscope backup
openscope restore
openscope upgrade
openscope version
```

V0.1 只承诺 `start / stop / status / doctor / version`；其余命令随对应需求和验收合同进入后续里程碑。

CLI 负责：

- 环境检查；
- 配置生成；
- Docker Compose 管理；
- Storage 检查；
- 端口检查；
- 组件 Health；
- Agent 下载/离线安装；
- Backup；
- Upgrade。

---

## 22. 仓库结构

```text
openscope-observability/
├── pom.xml / mvnw / .mvn/
├── java/
│   ├── openscope-api/
│   ├── openscope-spring-boot-autoconfigure/
│   ├── openscope-spring-boot-starter/
│   ├── openscope-logback/
│   └── openscope-test/
│
├── collector/
│   ├── base/
│   ├── processors/
│   ├── sampling/
│   ├── redaction/
│   └── templates/
│
├── distribution/
│   ├── bom.yaml
│   ├── standalone/
│   ├── central/       # 后续需求批准后创建
│   └── distributed/   # 后续需求批准后创建
│
├── grafana/
│   ├── dashboards/
│   ├── provisioning/
│   └── alerts/
│
├── cli/
├── examples/
├── agents/
├── tools/
├── docs/
└── README.md
```

V0.1 只创建 `distribution/standalone`、`grafana`、`cli`、`examples/springboot-simple`、`agents/java` 和验证工具；Java 自研模块、Central/Distributed、Helm/Kubernetes 在各自需求批准后再创建，禁止为了目录完整预置空模块。

---

## 23. Java 模块建议

```text
openscope-java
├── openscope-api
├── openscope-spring-boot-autoconfigure
├── openscope-spring-boot-starter
├── openscope-logback
└── openscope-test
```

### openscope-api

定义：

- OpenScope Context；
- Project / Site Metadata；
- Business Span Helper；
- Tags / Attributes Helper。

### autoconfigure

负责：

- Spring Boot Auto Configuration；
- Property Binding；
- Resource Mapping；
- Logger Integration。

### starter

聚合用户依赖。

### logback

提供：

- JSON Encoder；
- Trace ID；
- Span ID；
- Project ID；
- Site ID。

---

## 24. 组件健康检查

OpenScope `doctor` 至少检查：

```text
Collector
Prometheus
Tempo
Loki
Grafana
Disk
Ports
OTLP
Datasource
Dashboard Provisioning
Retention
Storage Permission
```

目标：

```bash
openscope doctor
```

输出：

```text
Collector      OK
Prometheus     OK
Tempo          OK
Loki           OK
Grafana        OK
OTLP gRPC      OK
OTLP HTTP      OK
Disk           WARN
```

---

## 25. 测试策略

### Unit Test

- Java Starter；
- Config Parser；
- Resource Convention；
- Redaction Rule。

### Integration Test

构造测试应用：

```text
springboot-simple
springboot-postgresql
springboot-redis
springboot-kafka
```

验证：

- Trace 是否进入 Tempo；
- Metric 是否进入 Prometheus；
- Log 是否进入 Loki；
- Trace ID 是否关联；
- Dashboard 是否存在；
- Alert Rules 是否加载。

### Distribution Test

至少覆盖：

- standalone；
- central；
- offline install；
- upgrade；
- backup；
- restore。

---

## 26. V1 技术边界

V1 正式支持：

```text
Java / Spring Boot
OpenTelemetry
OTLP
OTel Collector
Prometheus
Tempo
Loki
Grafana
Docker Compose
```

V1 暂不正式支持：

```text
SkyWalking Backend
SigNoz Backend
OpenObserve Backend
Datadog Backend
Mimir
Pyroscope
Odigos
eBPF
Node.js
Go
Python
```

这些能力仅保留架构扩展点。

---

## 27. 后续扩展

### V2 多语言

```text
Java
Node.js
Go
Python
```

全部输出：

```text
OTLP
```

后端保持不变。

### V2 Kubernetes

引入：

```text
DaemonSet Collector
Gateway Collector
Helm
K8s Resource Detection
```

### V2 Metrics Scale-out

```text
Prometheus
    ↓
Mimir
```

### V2 Profiling

```text
Pyroscope
```

### V2 Auto Instrumentation

```text
Odigos / eBPF
```

---

## 28. 最终技术架构

```text
┌───────────────────────────────────────────────────┐
│                    Applications                   │
│                                                   │
│       Java / Node.js / Go / Python                │
└────────────────────────┬──────────────────────────┘
                         │
                  OpenTelemetry
                         │
                         ▼
┌───────────────────────────────────────────────────┐
│               OpenScope Convention                │
│                                                   │
│ Resource / Context / Logging / Security / Policy  │
└────────────────────────┬──────────────────────────┘
                         │
                        OTLP
                         │
                         ▼
┌───────────────────────────────────────────────────┐
│            OpenTelemetry Collector                │
│                                                   │
│ Receive → Enrich → Redact → Filter → Sample       │
│         → Batch → Queue → Route                    │
└───────────────┬──────────────┬──────────────┬──────┘
                │              │              │
                ▼              ▼              ▼
          Prometheus         Tempo           Loki
                │              │              │
                └──────────────┼──────────────┘
                               ▼
                            Grafana
```

核心原则保持：

> **OTel Native + Collector Centric + One Official Backend + Multiple Deployment Topologies**

这套技术架构能够覆盖：

- 个人项目；
- 家庭自托管服务；
- 公司内部系统；
- Data-OS；
- 医院项目；
- 政务系统；
- 完全内网环境；
- 未来多语言与大规模部署。
