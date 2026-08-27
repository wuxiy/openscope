# MVP Scope

## Purpose

Define the smallest credible product scope.

## V0.1 Boundary

- Must-have: standalone Compose、exact tag + digest BOM、Java Agent OTLP 三信号、真实 P/T/L 查询、Grafana 基础关联 Dashboard、最小 CLI/doctor、敏感 canary 验证。
- Deferred: Central/Distributed、Starter、自研模块、filelog、离线包、备份升级、生产安全和规模化能力。
- Manual operations: 复制 `.env.example`、设置 Grafana 密码、人工点验 Grafana 双向跳转。
- Simulated integrations: 不允许 mock 代替 Prometheus/Tempo/Loki；只允许合成业务请求和敏感 canary 作为测试输入。
- Exit criteria: `docs/testing/v0.1-acceptance-checklist.md` 通过且独立 closure audit 接受。

完整需求与 AC：`docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md`。

## Rule

This file owns the current MVP boundary only.

Do not duplicate long-term product vision from `docs/architecture/project-vision.md` or current app behavior from `docs/design/app-overview.md`.
