# Known-Good Baselines

## Baselines

| Date           | Source  | Git State | Scope    | Commands Passed      | Known Failures               | Evidence     | Notes  |
| -------------- | ------- | --------- | -------- | -------------------- | ---------------------------- | ------------ | ------ |
| 2026-08-27     | local   | dirty working tree | full（当前仓库全部已配置验证命令） | `./tools/mission-driver.sh list`; `./tools/mission-driver.sh run demo` | 外部 opencode CLI "Unexpected server error"（demo CHECK 步骤外部引擎问题，非本项目文件问题；reconciliation 正确降级为 completed） | 本次会话运行记录，见 docs/logs/2026/2026-08-27.md | AGE 初始化 + onboarding 完成态；两份根架构文档为 2026-08-27 修订版 |

dirty 工作区变更文件：根目录两份架构文档修订、AGE 脚手架 88 文件新增、本 onboarding 填写的 docs/* 文件。

## When To Update

Update this file when:

- full typecheck/build/lint/test verification passes after a meaningful change
- a previously failing command becomes green and should be remembered
- a team intentionally accepts a known failing command and records it as a known failure, not as a passed command

## Rule

Do not mark a command as passed unless it actually ran in the current repository state.

`Commands Passed` must contain only passing commands. Put accepted failures in `Known Failures` with the reason and evidence.

A dirty working-tree baseline must name the changed files in `Notes` or link to a dated log/testing note that does.

`full` means all real verification commands configured in `docs/context/project-context.md`. Commands explicitly marked `none` are excluded and should be noted.
