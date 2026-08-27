# Product Baseline Requirements

## Purpose

Define the product baseline that guides implementation slices. This project may start from small complete loops, but each loop is implemented as formal product behavior rather than temporary or demo-only behavior.

## Product Capabilities

- 以 OpenTelemetry/OTLP 统一接入应用的 Metrics、Traces、Logs
- 以 Collector 为数据平面，将信号路由到唯一官方后端组合 Prometheus/Tempo/Loki/Grafana
- 通过 Distribution BOM、版本化配置和 Grafana Provisioning 提供可重复发行
- 支持 standalone、central、distributed 多拓扑逐步演进；当前只实施 standalone

## First Complete Loop

首个完整闭环由 `docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md` 定义：

- Spring Boot + 固定 OTel Java Agent 产生 OTLP 三信号
- Collector 处理后写入 Prometheus、Tempo、Loki
- Grafana 通过 Provisioning 查询并完成 Logs ↔ Trace 关联
- CLI/doctor 与真实后端验证脚本证明启动、失败和重复执行语义

This first loop is not a disposable prototype. Unsupported capabilities remain product areas whose implementation order is tracked outside stable design docs.

## Manual Operations Allowed During Early Slices

- 运维者复制 `.env.example` 并设置非默认 Grafana 管理员密码
- 指定开发机 `root@172.16.65.59` 完成 amd64/x86_64 真实运行；arm64 在 V0.1 可先以 manifest 存在性证据标记为 manifest-only
- 远端共享主机必须使用隔离 workdir/Compose project，并证明未影响非 OpenScope 资源
- Grafana Logs ↔ Trace 最终行为允许人工点验，但配置存在性与数据源健康必须机器验证

## Development Or Local Integration Substitutes

- 不允许用 mock backend、容器 healthy 或 mission-driver demo 代替三后端真实查询。
- 合成请求和敏感 canary 只作为测试输入，不进入正式数据或示例凭据。

## Completion Criteria For The First Loop

- AC-01..AC-16 均有真实证据，执行、失败、跳过和人工状态分开记录
- `docs/testing/v0.1-acceptance-checklist.md` 无 in-scope 未决项
- 独立 closure audit 接受实现、文档和验证证据

## Rule

This file owns the implementation-ready product baseline and first complete loop.

Do not duplicate long-term vision from `docs/architecture/project-vision.md` or stable app behavior from `docs/design/app-overview.md`. Put implementation sequencing into `docs/backlog/` or a roadmap, not into every design doc.
