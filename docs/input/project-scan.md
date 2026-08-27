# OpenScope 项目扫描（WI1）

> 扫描日期：2026-08-27。项目当前处于 **pre-code 设计阶段**（无源码），仓库由两份架构文档驱动。

## 仓库现状

| 文件 | 说明 |
|---|---|
| `README.md` | 一句话定位：lightweight, OpenTelemetry-native observability framework |
| `OpenScope-项目架构.md` | 产品/项目视角：背景、定位、三种部署拓扑、Dashboard 模型、离线交付、演进路线 V0.1→V2 |
| `OpenScope-技术架构.md` | 技术视角：选型、Java 双模式接入、Collector 管线、BOM 版本策略、CLI、测试策略 |
| `age/` 脚手架（tools/, missions/, docs/, .env） | AGE 记忆模板，本次初始化 |

## 目标技术栈（来自两份架构文档）

- **标准**：OpenTelemetry（OTel API/SDK/Java Agent）+ OTLP 统一协议
- **数据平面**：opentelemetry-collector-contrib（最新稳定版）
- **后端**：Prometheus > 3.x（原生 OTLP Receiver）、Grafana Tempo（最新稳定版）、Loki ≥ 3.0（原生 `/otlp/v1/logs`）、Grafana（Provisioning）
- **Java 接入**：模式 A `-javaagent` 零侵入 / 模式 B `openscope-spring-boot-starter`（基于官方 otel spring-boot-starter 封装），同 JVM 二选一
- **部署**：Docker Compose 优先；standalone / central / distributed 三拓扑；完全离线发行版
- **自研件**：Starter（Spring Boot autoconfigure + logback JSON）、Distribution BOM、CLI（V0.x 为 shell 脚本包装）

## 主入口与验证

- 无可运行代码，build/test/lint 均 `none`
- 当前有效验证命令：
  - `./tools/mission-driver.sh list`
  - `./tools/mission-driver.sh run demo`（引擎冒烟，已验证 reconciled → completed）
  - 占位符检查：`grep -rn "<fill\|<path>" docs/`

## 关键决策记录（2026-08-27 评审确定）

1. Agent + Starter 双模式并存（互斥，doctor 检测叠加冲突）
2. 版本下限锁定：Prometheus >3.x、Loki ≥3.0，组件取发布时最新稳定版
3. Metrics 管线走 `otlphttp/prometheus`（弃 prometheusremotewrite）
4. 脱敏三道防线：SDK 红线 → Local Collector 强制 → Gateway 兜底；数据出内网前必须过前两道
5. V1 Distributed 验收=数据通路稳定；Tail Sampling 为 V1.x 增强（引入前 Local 默认 100% 上传）
6. SLO 最小实现进 V1.0（Recording Rule + burn rate 告警）；仓库结构以《技术架构》§22 为单一权威

## 下一切片建议

按《项目架构》§15 V0.1：最小 standalone Docker Compose 发行版（collector+P/T/L/Grafana）+ springboot-simple 示例接入。
