# Module Boundaries

> 当前基线：V0.1 standalone 已实施并于 2026-08-29 验收 accepted。权威仓库结构：《OpenScope-技术架构》§22。

## Module Families（已落地/规划）

### 1. java/ — Java 接入层
- **已落地**：`examples/springboot-simple/`（Java 21 + OTel Java Agent 2.31.1，ProbeController 三端点）+ `agents/java/manifest.yaml`（Agent 版本/SHA 归档）
- 规划中（V0.2+，依赖真实 Agent 缺口）：`openscope-api`（Context、Project/Site Metadata、Business Span Helper）、`openscope-spring-boot-autoconfigure`、`openscope-spring-boot-starter`、`openscope-logback`（JSON Encoder、trace_id/span_id 注入）
- 允许依赖：OpenTelemetry API/Spring Boot Starter；禁止依赖：任何 Backend 客户端库

### 2. collector/ — 数据平面配置资产
- **已落地**：`distribution/standalone/config/collector/collector.yaml`（otlp receiver + memory_limiter/resource/attributes-redact/batch/otlphttp exporters，traces/metrics/logs 三管线，无 filelog 通路）
- `sampling/`、`redaction/` 独立模板延后（Tail Sampling 为 V1.x）

### 3. distribution/ — 发行版装配
- **已落地**：`standalone/`（docker-compose.yml + config/* + .env.example）+ `bom.yaml`（五组件 tag@digest，BOM 唯一版本源）
- `central/ | distributed/` 在各自需求批准后创建
- 版本以 BOM 为准；禁止锁定 BOM 之外的版本号

### 4. grafana/ — 可视化资产
- **已落地**：`grafana/provisioning/datasources/{prometheus,tempo,loki}.yml`（UID 固定 `openscope-*`，含 trace_id/span_id 关联 derivedFields）+ `grafana/dashboards/overview/openscope-overview.json`（六元组变量）
- 全部 Provisioning 化，Git 管理；Dashboard 变量固定六元组：site/environment/project/namespace/service/instance

### 5. cli/ — 运维入口
- **已落地**：`cli/openscope`（start/stop/status/doctor/version，shell 包装 docker compose；BOM digest 注入、C5 密码 gate、磁盘/端口/卷 fail-closed）
- init/backup/restore/upgrade 后续另立需求；Go CLI 收敛待命令面稳定后；doctor 已内置 grafana datasource/dashboard/agent 检查（agent+starter 叠加检测 V0.2）

## Dependency Direction（必须保持）

```text
java/* ──▶ OTLP ──▶ collector/* ──▶ distribution/* 声明的后端
                 （grafana/* 只被 distribution 引用）
cli/* ──▶ distribution/*（CLI 不直接改组件版本）
```

## Forbidden Shortcuts

- 应用代码 import Tempo/Loki/Prometheus SDK —— 一律走 OTel/OTLP
- 双文档各自定义仓库结构 —— 结构性结论只写在技术架构 §22
- BOM 外浮动版本号

## Test Ownership

examples/* → Maven 单测 + 真实后端集成验证；distribution/* → Compose/上游配置校验 + `tools/verify-v0.1.sh`；grafana/* → Provisioning API 检查 + 人工关联点验。mission-driver demo 不属于产品验收。
