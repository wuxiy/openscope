# Planning & Audit

> 何时必须写 plan、何时可走 no-plan 路径、audit 与 reviewer 规则。权威流程指南：`docs/plans/00-plan-authoring-and-execution-guide.md`（created plan MUST 遵循）。

## Planning Triggers

任务命中任一条即须先写 plan：

- 改动 API、database/model、auth、integration、deployment 或 public contract 行为
- 跨多个 feature surface 的 user-visible 行为变更
- 跨多模块并改变共享行为
- 预计超过一个 AI session
- 触及 **3 个以上**文件、或预计 ~200 changed lines 以上（即超出下方 no-plan 路径的适用范围）
- 需要分阶段执行或显式 closure gates
- 存在不能藏在 chat 里的 product/technical risk

## No-Plan Path

以下低风险改动可跳过正式 plan：

- copy 变更、小样式修复、test-only 清理
- 有清晰现有测试覆盖的单文件行为修复
- 小规模低风险多文件修改：约 **1–3 个非生成文件**、~200 行以内，且不触碰 contract、data/model、auth、permission、integration、deployment、跨 surface 行为、文档冲突或未决产品风险

即使走 no-plan path，也不允许凭 chat 记忆宣布完成——**cold replay**：对照真实 diff 和真实 verification 命令核验后，补一条 log entry。

## Audit Rules

- created plan 必须：implementation 前 draft review + closure 前 closure audit
- Self-review / self-recorded closure evidence 不能用来关闭自己创建的 plan
- Independent review 必须引用文件和证据，不允许只说 "looks good"

## Reviewer-Availability Fallback

没有第二 reviewer/subagent 时，solo cold-replay 只对 **non-protected 且 non-high-risk** 的 plan 有效，plan 中 MUST 记录使用了 solo review 并注明局限。Protected areas、未决产品风险、source-of-truth 冲突仍要求 human/subagent review，否则保持 open。

本项目当前 reviewer availability = `subagent`（见 `docs/context/ai-autonomy-policy.md`）。
