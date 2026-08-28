# OpenScope

> **OpenTelemetry-native observability distribution** —— 轻量、跨环境（standalone / central / distributed）的可观测性框架。
> OTel Native + Collector Centric + One Official Backend + Multiple Deployment Topologies。

[![V0.1 acceptance](https://img.shields.io/badge/V0.1-accepted-2ea44f)](docs/testing/v0.1-acceptance-checklist.md)

## 这是什么

OpenScope 不做新的存储/查询/UI，而是把成熟开源组件（OpenTelemetry + Collector + Prometheus + Tempo + Loki + Grafana）包装成一个**可离线交付、按发行版升版、应用零侵入接入**的软件产品：

- 应用只依赖 **OpenTelemetry API/Agent + OTLP**，不绑定任何私有后端
- V1 只正式维护一套后端：**Prometheus(>3.x 原生 OTLP) + Tempo + Loki(≥3.0 原生 OTLP) + Grafana Provisioning**（BOM digest 锁定，无浮动 tag）
- 三种拓扑共用同一技术栈：`standalone`（单机/内网/政务医院交付）→ `central`（多项目共享）→ `distributed`（跨网络域，随 V1.x 演进）
- 脱敏三道防线 + 固定六元组 Resource 模型（site/environment/project/namespace/service/instance）

## 快速开始（V0.1 standalone）

```bash
# 1. 准备
cp distribution/standalone/.env.example distribution/standalone/.env
#    编辑 .env：GF_ADMIN_PASSWORD 必须改为非默认值；GRAFANA_PORT 按需

# 2. 启动
./cli/openscope start      # 启动 5 组件栈（collector/prometheus/tempo/loki/grafana）
./cli/openscope status     # 查看状态
./cli/openscope doctor     # 健康检查（含 datasource/dashboard）

# 3. 接入应用（零侵入，Java Agent）
java -javaagent:/opt/openscope/agents/opentelemetry-javaagent.jar \
  -Dotel.service.name=my-service \
  -Dotel.exporter.otlp.endpoint=http://127.0.0.1:4318 \
  -jar app.jar

# 4. 可视化
open http://127.0.0.1:3000   # OpenScope Overview（按 project/service 入口）
```

停止（保留数据）：`./cli/openscope stop`。完整离线交付包结构见《OpenScope-项目架构》§12。

## 验收状态

- ✅ **V0.1 standalone accepted**（2026-08-28）：25/25 检查全过 ×2、restart 持久化、canary 三路脱敏、doctor 失败注入、amd64 远端真实运行
- 证据：`docs/testing/2026/08-28.md` + `docs/testing/2026/08-28/`
- 遗留：arm64 真实运行（仅 manifest 证据）；central/distributed 与 Tail Sampling 为 V1.x

## 仓库结构（v0.1）

```text
distribution/standalone/   docker-compose + 五组件配置 + .env 模板
distribution/bom.yaml      组件版本唯一权威（tag@digest）
cli/openscope              start/stop/status/doctor/version
examples/springboot-simple Java Agent 零侵入示例（ok/fail/sensitive）
grafana/provisioning/      三 datasource + Overview dashboard（Git 管理）
tools/                     resolve-bom / verify-docs / verify-v0.1(.remote)
agents/java/manifest.yaml  Java Agent 版本归档
docs/                      AGE 记忆层（context/architecture/requirements/plans/…）
```

## 文档

- 《OpenScope-项目架构》：定位、拓扑、Dashboard 模型、演进路线 V0.1→V2
- 《OpenScope-技术架构》：选型理由、Collector 管线、BOM 策略、Java 双模式接入
- `docs/`（AGE）：agent 协作规则与项目记忆；`AGENTS.md` 为执行入口

## License

[Apache-2.0](LICENSE)