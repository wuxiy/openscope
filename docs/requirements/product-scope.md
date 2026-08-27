# Product Scope

## Current Milestone: V0.1 Standalone

- Product summary: OpenTelemetry-native、Collector-centric 的可观测性发行版；不自研存储、查询和 UI。
- Users: 首阶段面向本机开发/运维者验证个人项目接入；公司、政务和医疗生产使用不是 V0.1 承诺。
- Scope: standalone Compose、Spring Boot Java Agent、OTLP 三信号、P/T/L/Grafana、基础关联 Dashboard、最小 CLI/doctor、固定 BOM。
- Deferred: Central/Distributed、Starter、自研 Java 模块、离线交付、备份升级、HA/多租户/TLS、扩展 Dashboard 与告警。
- Success metrics: AC-01..AC-16 和稳定验收清单全部满足，指定开发机 amd64/x86_64 真实运行，arm64 至少有 manifest 证据。
- Constraints: 应用不绑定后端；敏感数据默认不采集并由 Collector 二次删除；只允许 loopback 暴露；digest 未齐不得启动。

实现级细节以 `docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md` 为准。

## Rule

This file owns current milestone scope.

Do not duplicate stable app surfaces and workflows here. Put current supported behavior in `docs/design/app-overview.md`.

Put implementation sequencing into plans, not here.
