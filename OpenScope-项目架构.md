# OpenScope 项目架构文档

> OpenScope —— 基于 OpenTelemetry 的轻量级、跨环境可观测性框架

## 1. 项目背景

OpenScope 用于为不同部署环境下的自研系统、企业内部系统以及政务/医疗交付系统提供统一、轻量、可持续演进的可观测性能力。

当前主要服务对象包括：

- 个人自研项目：Family-OS、Health-OS、Teacher-OS、Everglow、XiangLiZhi 等；
- 公司内部项目：Data-OS 以及其他公司内部服务；
- 政务/医疗交付项目：部署在政务云、医院内网、前置机或完全隔离网络中的 Spring Boot 系统；
- 后续可扩展到 Node.js、Go、Python 等多语言服务。

OpenScope 不试图重新实现一套 APM、日志系统、指标数据库或可视化平台，而是基于成熟开源生态，重点解决以下问题：

1. 如何用统一方式接入不同语言、不同项目和不同部署环境；
2. 如何让应用只依赖 OpenTelemetry，而不绑定具体可观测后端；
3. 如何统一 Trace、Metric、Log 的采集、关联、脱敏、采样和路由；
4. 如何降低 Prometheus、Tempo、Loki、Grafana、OpenTelemetry Collector 的部署与维护成本；
5. 如何让单机、中心化、分布式三种部署拓扑共用同一套技术架构；
6. 如何通过发行版、统一配置、Dashboard、Alert、SLO 等能力，把多个成熟组件包装为一个可维护的软件产品。

---

## 2. 项目定位

OpenScope 的定位不是：

- Another SkyWalking；
- Another SigNoz；
- Another OpenObserve；
- Another Grafana；
- Another Prometheus。

OpenScope 的定位是：

> **OpenTelemetry Native Observability Distribution / Framework**

核心理念：

> **One Core + One Backend + Multiple Deployment Topologies**

即：

- 一套核心标准；
- 一套正式维护的后端技术栈；
- 多种部署拓扑；
- 多语言接入；
- 后端保留可替换能力，但 V1 不同时维护多套 Backend。

---

## 3. 项目目标

### 3.1 核心目标

OpenScope V1 聚焦以下目标：

- Spring Boot 零侵入或低侵入接入；
- 使用 OpenTelemetry 作为统一规范；
- 使用 OTLP 作为统一数据协议；
- 使用 OpenTelemetry Collector 作为统一数据平面；
- Metrics 使用 Prometheus；
- Traces 使用 Grafana Tempo；
- Logs 使用 Grafana Loki；
- Visualization 使用 Grafana；
- 统一 Dashboard、Alert、Retention、Sampling、Redaction；
- 支持单机、中心化、分布式部署；
- 支持离线交付和内网部署；
- 支持不同项目共用同一套中心可观测平台；
- 保持未来对 SkyWalking、SigNoz、OpenObserve、Datadog 等后端的兼容能力。

### 3.2 非目标

V1 不做：

- 自研 Trace Storage；
- 自研 Metrics Storage；
- 自研 Logs Storage；
- 自研 Query Engine；
- 自研 Java Agent；
- 自研 OTLP 协议；
- 自研 Dashboard 引擎；
- 自研完整 APM UI；
- 同时维护 SkyWalking / SigNoz / OpenObserve 多套 Dashboard 与部署方案；
- 从第一天引入 Mimir、Kafka 等大规模组件。

---

## 4. 核心架构原则

### 4.1 OpenTelemetry First

所有应用侧接入均以 OpenTelemetry 为第一标准。

应用只感知：

- OpenTelemetry API / SDK / Agent；
- OTLP Endpoint；
- Resource；
- Semantic Conventions。

应用不得直接依赖：

- Tempo API；
- Loki API；
- Prometheus Remote Write；
- SkyWalking 私有协议；
- SigNoz 私有 SDK；
- Datadog 私有 Agent 能力。

---

### 4.2 Collector Centric

OpenTelemetry Collector 是 OpenScope 的数据平面核心。

Collector 负责：

- 接收；
- 过滤；
- 属性增强；
- 数据脱敏；
- 批处理；
- 采样；
- 重试；
- 持久化队列；
- 数据路由；
- 多后端输出。

应用与后端之间通过 Collector 解耦。

---

### 4.3 Backend Neutral, But Single Official Backend

OpenScope 架构保持后端中立，但 V1 只正式维护一套后端：

- Prometheus；
- Tempo；
- Loki；
- Grafana。

其他后端仅作为未来扩展能力：

- SkyWalking；
- SigNoz；
- OpenObserve；
- Datadog；
- Grafana Cloud；
- 其他 OTLP-compatible Backend。

原则：

> **支持扩展，不等于当前承担维护责任。**

---

### 4.4 Same Architecture, Different Topologies

不同场景不采用不同技术栈，而采用不同部署拓扑。

OpenScope 正式支持：

- `standalone`
- `central`
- `distributed`

而不以：

- personal
- government
- hospital
- company

作为技术 Profile。

业务场景与技术拓扑解耦。

---

## 5. 总体逻辑架构

```text
┌──────────────────────────────────────────────┐
│              Applications                    │
│                                              │
│ Java / Node.js / Go / Python                 │
└──────────────────────┬───────────────────────┘
                       │
                       │ OpenTelemetry / OTLP
                       ▼
┌──────────────────────────────────────────────┐
│        OpenScope Integration Layer           │
│                                              │
│ Resource / Context / Logging / Convention    │
│ Redaction / Sampling / Configuration         │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│           OpenTelemetry Collector            │
│                                              │
│ Receiver / Processor / Queue / Routing       │
└──────────────────────┬───────────────────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
     Prometheus      Tempo        Loki
          │            │            │
          └────────────┼────────────┘
                       ▼
                    Grafana
```

---

## 6. 项目架构分层

### 6.1 Language Integration Layer

负责不同语言的接入。

V1：

- Java；
- Spring Boot；
- OpenTelemetry Java Agent；
- OpenTelemetry API；
- OpenScope Spring Boot Starter。

未来：

- Node.js；
- Go；
- Python；
- .NET。

---

### 6.2 Observability Convention Layer

这是 OpenScope 最重要的自研资产之一。

负责统一：

- Resource；
- Service Naming；
- Project；
- Site；
- Environment；
- Logging；
- Trace Context；
- Sensitive Data Policy；
- Sampling Policy；
- Metric Naming；
- Dashboard Variables。

统一资源模型：

```text
Site
 └── Environment
      └── Project
           └── Namespace
                └── Service
                     └── Instance
```

示例：

```text
site.id = company
project.id = data-os
deployment.environment.name = production
service.namespace = data-platform
service.name = data-api
service.instance.id = data-api-01
service.version = 1.2.0
```

---

### 6.3 Telemetry Data Plane

由 OpenTelemetry Collector 负责。

主要能力：

- OTLP Receiver；
- Prometheus Receiver；
- Filelog Receiver；
- Hostmetrics Receiver；
- Resource Processor；
- Attributes Processor；
- Transform Processor；
- Filter Processor；
- Memory Limiter；
- Batch；
- Tail Sampling；
- Persistent Queue；
- Retry；
- Exporters。

---

### 6.4 Backend Layer

V1 正式后端：

```text
Metrics  → Prometheus
Traces   → Tempo
Logs     → Loki
UI       → Grafana
Alerts   → Grafana Alerting / Alertmanager
```

后续扩展：

```text
Mimir
SkyWalking
SigNoz
OpenObserve
Datadog
Grafana Cloud
```

---

### 6.5 Distribution Layer

OpenScope 不把各个开源组件直接暴露给最终使用者，而是以统一发行版形式进行管理。

对外暴露：

```bash
openscope start
openscope stop
openscope restart
openscope status
openscope doctor
openscope backup
openscope restore
openscope upgrade
```

内部负责：

- Docker Compose；
- Config Generation；
- Image Version BOM；
- Grafana Provisioning；
- Dashboard Provisioning；
- Alert Provisioning；
- Storage Path；
- Retention；
- Backup；
- Upgrade；
- Health Check。

---

## 7. 三种部署模式

## 7.1 Standalone

适用于：

- 单个政务项目；
- 医院内网项目；
- 前置机；
- 小型公司测试环境；
- 独立开发环境。

```text
Server / VM
│
├── Application
├── OTel Collector
├── Prometheus
├── Tempo
├── Loki
└── Grafana
```

特点：

- 单机部署；
- Docker Compose 优先；
- 支持完全离线；
- 默认较短 Retention；
- 安装升级简单；
- 无需依赖外部中心平台。

---

## 7.2 Central

适用于：

- Family-OS；
- Health-OS；
- Teacher-OS；
- Everglow；
- XiangLiZhi；
- Data-OS；
- 公司内部多个项目。

```text
family-os ─────┐
health-os ─────┤
teacher-os ────┤
everglow ──────┼──→ Central Collector
xianglizhi ────┘          │
                          ▼
                Prometheus / Tempo / Loki
                          │
                          ▼
                       Grafana
```

特点：

- 多项目共享；
- 集中 Dashboard；
- 集中告警；
- 集中存储；
- 统一版本；
- 降低维护成本。

---

## 7.3 Distributed

适用于：

- 公司规模扩大；
- 多节点；
- 多机房；
- 政务项目通过专线/VPN回传；
- 数据量增加。

```text
Application
    │
    ▼
Local Collector
    │
    ▼
Gateway Collector
    │
 ┌──┼────┐
 ▼  ▼    ▼
P   T    L
```

特点：

- Local Collector 做 Host/Log 收集与缓冲；
- Gateway Collector 做 Sampling / Routing / Redaction；
- 支持 persistent queue；
- 可逐步扩容；
- 应用侧无需变化。

---

## 8. 典型项目接入

### 8.1 Family-OS / Health-OS / Teacher-OS / Everglow / XiangLiZhi

统一接入个人中心 OpenScope：

```text
service.namespace = personal
project.id = family-os
site.id = home
deployment.environment.name = production
```

多个项目共用一套 OpenScope Center。

---

### 8.2 Data-OS

建议：

```text
project.id = data-os
site.id = company
service.namespace = data-platform
```

后续可监控：

- Spring Boot；
- PostgreSQL；
- Redis；
- Kafka；
- NiFi；
- SeaTunnel；
- JVM；
- Host；
- HTTP；
- Task Pipeline。

---

### 8.3 政务 / 医院交付项目

默认：

```text
deployment.mode = standalone
```

完全内网部署。

如存在专线/VPN：

```text
deployment.mode = distributed
```

本地 Collector 缓冲后向公司中心 Gateway 回传。

---

## 9. Dashboard 产品模型

OpenScope Dashboard 不以 CPU / JVM 作为第一入口，而以 Project / Service 为第一入口。

推荐层级：

```text
OpenScope
├── Overview
├── Projects
│   ├── Project Overview
│   ├── Service Health
│   └── Dependency
├── Services
├── HTTP
├── JVM
├── Database
├── Redis
├── Kafka
├── Infrastructure
└── Alerts
```

统一 Dashboard Variables：

```text
site
environment
project
namespace
service
instance
```

典型排障路径：

```text
Project
 ↓
Service
 ↓
Endpoint
 ↓
Trace
 ↓
Logs
```

---

## 10. Golden Signals

OpenScope 默认统一提供以下观测模型。

### HTTP RED

- Rate；
- Errors；
- Duration。

### JVM

- Heap；
- Non-Heap；
- GC；
- Thread；
- CPU；
- ClassLoader。

### Database

- Connections；
- Query Duration；
- Errors；
- Slow Query。

### Service

- Availability；
- Traffic；
- Error Rate；
- Latency。

### Infrastructure

- CPU；
- Memory；
- Disk；
- Network；
- Process。

---

## 11. 安全与数据治理

OpenScope 默认采用数据最小化原则。

默认不允许采集：

- Authorization；
- Cookie；
- Token；
- Password；
- 请求 Body；
- 响应 Body；
- 身份证；
- 姓名；
- 手机号；
- 医疗数据；
- 体检数据；
- SQL Bind Parameters；
- 其他敏感业务字段。

政务、医疗项目默认采用更严格策略。

### 11.1 纵深防御：脱敏三道防线

Redaction 越早发生越好。对 distributed 场景（专线/VPN 回传），**敏感数据必须在离开客户内网之前完成脱敏**，不允许依赖中心侧补救：

```text
第一道（红线）：Application SDK / Agent
    敏感属性不出进程 —— 按策略直接不采集或采集前掩码
        ↓
第二道：Local Collector 强制 Redaction（strict 场景必开）
    保证回传链路上的数据已清洗
        ↓
第三道（兜底）：Gateway / Central Collector 再校验
    防止策略遗漏与新字段泄漏
        ↓
Resource Enrichment → Filtering → Sampling → Backend
```

合规基线：任何遥测数据跨网络域传输前，至少经过第一道 + 第二道防线。

---

## 12. 离线交付

政务/医院部署包建议：

```text
openscope-distribution-v1.0.0/
├── docker-compose.yml
├── .env
├── images/
│   ├── otel-collector.tar
│   ├── prometheus.tar
│   ├── tempo.tar
│   ├── loki.tar
│   └── grafana.tar
├── agents/
│   └── java/
├── config/
├── dashboards/
├── alerts/
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── backup.sh
│   ├── upgrade.sh
│   └── doctor.sh
└── README.md
```

要求：

- 不依赖公网；
- 不运行时在线下载镜像；
- 不依赖在线插件市场；
- Agent 随发行版提供；
- 配置版本统一。

---

## 13. 版本与维护策略

OpenScope 维护 Distribution BOM，而不是分别让客户管理组件版本。

每个组件在发行时锁定 exact tag + image manifest digest，并设硬性版本下限：Prometheus ≥ 3.0（原生 OTLP Receiver）、Loki ≥ 3.0（原生 OTLP 日志端点）。V0.1 候选组合与 digest 物化规则由 `docs/architecture/v0.1-standalone-contract.md` 定义；实施后唯一机器权威为 `distribution/bom.yaml`。

原则：

- 每个 OpenScope 版本绑定唯一经过测试的组件组合；
- 不支持随意混搭版本；
- 升级以 OpenScope Distribution 为单位；
- Dashboard / Alert / Collector Config 与发行版一起测试；
- 客户环境不自行升级单组件。

---

## 14. 项目目录建议

仓库结构的唯一权威版本维护在《OpenScope-技术架构》§22「仓库结构」，本文档不再重复列出，避免双文档漂移。

---

## 15. 演进路线

### V0.1

目标：首个可运行的 Spring Boot standalone pre-release，不等于生产就绪。

- Java Agent；
- OTLP；
- Collector；
- Prometheus；
- Tempo；
- Loki；
- Grafana；
- Standalone；
- 基础 Dashboard；
- Logs ↔ Trace 基础关联；
- Docker Compose；
- 最小 CLI：start / stop / status / doctor / version。

V0.1 日志只走 Java Agent Logback instrumentation → OTLP LogRecord → Collector → Loki；Central、Starter、stdout/filelog、离线交付、备份升级均不进入该里程碑。实施级范围与验收标准见 `docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md`。

### V0.2

- Spring Boot Starter；
- Resource Convention 的 Starter 封装与高级治理；
- MDC；
- Project / Site 管理模型；
- JVM Dashboard；
- HTTP RED；
- Database Dashboard；
- 扩展 Logs ↔ Trace；
- Metrics ↔ Trace。

### V0.3

- Alert；
- Sampling；
- 可配置高级 Redaction；
- Retention；
- Persistent Queue；
- Offline Distribution；
- 完整运维 CLI：Upgrade / Backup / Restore / 深度 Doctor。

### V1.0

- Java 稳定版；
- Standalone / Central / Distributed 稳定（Distributed 以数据通路 + 离线缓冲稳定为验收标准，Tail Sampling 属后续增强）；
- 最小 SLO（Recording Rule + burn rate 告警）；
- 完整发行版；
- 标准 Dashboard；
- 安全基线；
- 文档体系。

### V2

- Node.js；
- Go；
- Python；
- Kubernetes；
- Helm；
- Mimir Scale-out；
- SLO；
- Profiling；
- eBPF；
- Odigos / Pyroscope 等生态集成。

---

## 16. 最终定位

OpenScope 的最终价值不是提供新的 Telemetry Storage，而是：

> **让任意一个应用，无论部署在个人服务器、公司内网、医院前置机、政务云还是分布式集群，都能以相同的 OpenTelemetry 标准获得 Metrics + Logs + Traces + APM 能力。**

最终稳定架构：

```text
OpenTelemetry
      ↓
OpenScope Convention
      ↓
OpenTelemetry Collector
      ↓
Prometheus + Tempo + Loki
      ↓
Grafana
```

技术路线：

> **OTel Native + Collector Centric + One Official Backend + Multiple Deployment Topologies**
