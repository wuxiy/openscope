# Module Boundaries

> 规划期边界（pre-code）。权威仓库结构：《OpenScope-技术架构》§22。

## Module Families（规划）

### 1. java/ — Java 接入层
- V0.1 只含 `examples/springboot-simple/` 和固定 Java Agent manifest，不创建以下自研模块
- `openscope-api`：Context、Project/Site Metadata、Business Span Helper
- `openscope-spring-boot-autoconfigure`：Auto Configuration、Property Binding、Resource Mapping
- `openscope-spring-boot-starter`：聚合用户依赖（基于官方 otel starter 封装）
- `openscope-logback`：JSON Encoder、trace_id/span_id 注入
- 允许依赖：OpenTelemetry API/Spring Boot Starter；禁止依赖：任何 Backend 客户端库

### 2. collector/ — 数据平面配置资产
- `base/` 标准管线（receiver/processors/exporters）、`sampling/`、`redaction/`
- 只产出 YAML 配置模板与 BOM 引用，不含服务代码

### 3. distribution/ — 发行版装配
- V0.1 只建立 `standalone/` docker-compose + `.env.example`；`central/ | distributed/` 在各自需求批准后创建
- 版本以 BOM 为准；禁止锁定 BOM 之外的版本号

### 4. grafana/ — 可视化资产
- `dashboards/ datasources/ alerts/` 全部 Provisioning 化，Git 管理
- Dashboard 变量固定六元组：site/environment/project/namespace/service/instance

### 5. cli/ — 运维入口
- V0.1 为 shell 脚本包装 docker compose（start/stop/status/doctor/version）；init/backup/restore/upgrade 后续另立需求
- Go CLI 收敛待命令面稳定后；doctor 必须检测 agent+starter 叠加冲突

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
