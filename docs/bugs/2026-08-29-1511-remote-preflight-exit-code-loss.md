# Remote Preflight Exit Code Loss

## Problem

- The remote acceptance preflight printed `BLOCKED disk guard available=9GiB`, but the runner continued into payload sync and OpenScope container operations.
- The affected script was `tools/verify-v0.1-remote.sh`; impact was limited to the OpenScope project, but its Grafana volume was deleted and the stack was stopped despite the failed guard.
- Non-OpenScope containers and resources were unchanged.

## Reproduction

- Validation host has less than 10 GiB available.
- Run `./tools/verify-v0.1-remote.sh` from the repository.
- In the faulty version, the preflight SSH call was embedded in `say "$(remote ... )"`; the remote command returned non-zero, while `say` returned the successful status of `tee`.

## Diagnostic Method

- The contradiction was visible in one output stream: `BLOCKED disk guard` was immediately followed by `payload sync`.
- The initial hypothesis that `set -e` was ineffective for SSH was rejected after inspecting the call boundary: `set -e` saw the logging function's status, not the command substitution's status.
- `docs/testing/2026/08-29/remote-20260829-151105.txt` is the direct evidence. A second run after the fix exited immediately after preflight.

## Root Cause

- `tools/verify-v0.1-remote.sh` collapsed a state-bearing remote command into an argument to a logging function.
- The logging wrapper did not preserve the nested command's exit code, converting a fail-closed gate into log-only output.
- Destructive OpenScope-only reset operations were ordered before static/build gates, increasing the impact of later failures.

## Fix

- Capture preflight output and exit status separately, log the captured output, then explicitly exit before payload sync when the status is non-zero.
- Run payload, checksum, Compose, docs and clean Maven build gates before any container mutation.
- Remove Grafana volume deletion; force-recreate current containers while preserving volumes.
- Capture initial OpenScope running state and restore it after the runtime attempt.

## Tests

- `docs/testing/2026/08-29/remote-20260829-151313.txt` — remote integration preflight: with 9 GiB available, exits 1 before payload sync or container operations.
- `bash -n tools/verify-v0.1-remote.sh` — syntax regression check.
- The exit-code regression is fixed. A later review found the preflight was checking `/` instead of the default workdir filesystem; the guard now checks `/root/workspace/openscope-v0.1`, which is on `/dev/vdb` with about 194 GiB available. Full runtime regression remains pending explicit execution authorization.

## Affected Artifacts

- `tools/verify-v0.1-remote.sh` — fail-closed preflight, gate ordering, volume preservation and initial-state restoration.
- `docs/testing/2026/08-29.md` — observed impact and verification boundary.
- `docs/plans/2026-08-29-1502-v0.1-acceptance-remediation-plan.md` — closure ownership.

## Notes For Future Refactors

- Never pass a command whose exit status controls safety into `say`, `echo`, `tee` or another wrapper without capturing and testing its status first.
- Keep all non-mutating gates before `compose up/down`, volume operations or remote cleanup.
- Evaluate capacity on the filesystem containing the owned workdir, not an assumed root filesystem.
- A cleanup path should restore the initial scoped-project state; it must not assume the stack should always be stopped.

## Prevention Gap

- The old runner had no negative test proving that each preflight failure stopped before the first remote write or container operation.
