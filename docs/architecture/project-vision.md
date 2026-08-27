# Project Vision

> 中文为本文档工作语言（见 docs/context/conventions.md Language Rule）。

## Product Goal

OpenScope 是一个 **OpenTelemetry Native Observability Distribution**：让任意应用——无论部署在个人服务器、公司内网、医院前置机、政务云还是分布式集群——都能以相同的 OTel 标准获得 Metrics + Logs + Traces + APM 能力。不自研存储/查询/UI，核心价值在统一接入约定（Convention）、数据平面治理与可离线交付的发行版。

核心理念：**One Core + One Backend + Multiple Deployment Topologies**
技术路线：**OTel Native + Collector Centric + One Official Backend + Multiple Topologies**

## Primary Users

1. cywu 个人自研项目：Family-OS、Health-OS、Teacher-OS、Everglow、XiangLiZhi（central 拓扑）
2. 公司内部系统：Data-OS 及其他内部服务（central/distributed）
3. 政务/医疗交付项目：政务云、医院内网、前置机、完全隔离网络（standalone，强安全基线）

## Constraints That Must Stay True

- 应用只依赖 OpenTelemetry API/SDK/Agent + OTLP Endpoint，不绑定具体后端
- V1 只正式维护一套后端（Prometheus ≥3.0 / Tempo / Loki ≥3.0 / Grafana）；其余后端只在第二个真实集成出现后建立扩展 seam
- 版本策略：一个 OpenScope 发行版绑定一组组件版本（BOM），发布时取最新稳定版并设硬性下限
- 三种部署拓扑（standalone/central/distributed）共用同一套技术栈，业务场景与技术拓扑解耦
- 数据最小化 + 脱敏三道防线；遥测跨网络域前必须完成前两道防线
- 完全隔离环境不依赖公网运行时下载

## Explicit Non-goals（V1）

自研 Trace/Metrics/Logs 存储、查询引擎、Java Agent、OTLP 协议、Dashboard 引擎、完整 APM UI；同时维护 SkyWalking/SigNoz/OpenObserve 多套后端；第一天引入 Mimir/Kafka。

## Success Criteria for First Runnable Pre-release

《项目架构》§15 V0.1：Spring Boot 最小可用——javaagent 接入 → OTLP 三信号 → Collector → P/T/L/Grafana standalone compose 套件 + 基础关联 Dashboard，可通过 `openscope` CLI（脚本形态）起停、查询状态和 doctor。V0.1 不宣称生产就绪。

## Required Human Decision Points

- 组件版本下限或升级策略变更（Protected Area: ask first）
- 安全/脱敏策略调整
- 离线交付包形态与客户环境特殊约束
- 多套后端支持时点

## Notes

- Keep this document stable and high level.
- 详细选型理由见根目录《OpenScope-技术架构》§3；《项目架构》§2 定位声明。
