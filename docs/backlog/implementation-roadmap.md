# Implementation Roadmap

> Last Updated: 2026-08-27
> Status Authority: `docs/backlog/README.md`

本项目不在此维护第二份实施状态表，避免与 backlog 和 created plan 漂移。

当前执行顺序：

1. `docs/plans/2026-08-27-1937-v0.1-standalone-distribution-plan.md` 通过独立 human draft review。
2. Phase 0 解析候选 BOM 的 multi-arch manifest digest，建立真实 Maven/验证入口。
3. 按 Phase 1–4 完成 standalone、三信号、Grafana 关联和 doctor。
4. Phase 5 执行完整验收与独立 closure audit。
5. V0.1 关闭后，才综合 Central/Distributed 和 Starter 的后续需求。

工作项状态、autonomy 与 blocker 只更新 `docs/backlog/README.md`；实施细节、证明命令和 closure gates 只更新对应 plan。
