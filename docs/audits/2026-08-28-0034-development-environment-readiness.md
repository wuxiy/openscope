# V0.1 Development Environment Readiness Audit

> Audit Date: 2026-08-28 00:34 CST
> Target: `root@172.16.65.59`
> Scope: read-only SSH connectivity, toolchain, capacity, port, shared-host isolation and upstream connectivity
> Mutation Boundary: no remote files, containers, images, volumes, networks, packages or services were changed

## Verdict

- **SSH and base toolchain: pass.** Passwordless BatchMode SSH with known host key works; x86_64, Java 21, Docker, Compose and Buildx meet the V0.1 validation baseline.
- **Shared-host readiness: needs guarded profile.** The host runs unrelated workloads, Grafana default port 3000 is occupied, and disk headroom is limited; isolation and fail-closed preflight are mandatory.
- **BOM/runtime readiness: blocked.** Maven Central is reachable, but Docker Registry and Buildx manifest inspection time out. No image pull or product runtime validation was attempted.

## Observed Facts

| Dimension | Evidence |
| --- | --- |
| Host | CentOS Stream 9, kernel 5.14, `x86_64` |
| Capacity | 16 vCPU, 62 GiB RAM, no swap |
| Root filesystem | 79 GiB total, 66 GiB used, 14 GiB available, 83% |
| Java | Red Hat OpenJDK 21.0.11 |
| Docker | client/server 29.5.3; service active |
| Compose / Buildx | Compose 5.1.4; Buildx 0.34.1 |
| Shared workload | 33 running containers; Docker images 53.94 GiB; build cache 16.03 GiB |
| Port conflicts | `127.0.0.1:3000` owned by `multica-frontend-1`; `0.0.0.0:13000` also occupied |
| Available candidate ports | `13001`, `4317`, `4318` had no listener at probe time |
| Workdir | `/opt/openscope-v0.1` absent at probe time |
| Maven Central | HTTP 200 |
| Docker Registry | direct `/v2/` request timed out; `buildx imagetools inspect prom/prometheus:v3.14.0` timed out with exit 124 |
| Registry mirrors | Docker daemon reports four configured mirrors, but Buildx manifest inspection still used `registry-1.docker.io` and timed out |

## Required Plan Revisions

1. Full runtime acceptance runs on this x86_64 host; arm64 is manifest-only unless separately executed.
2. Use `/opt/openscope-v0.1`, Compose project `openscope-v01`, Grafana loopback port `13001`, and standard loopback OTLP `4317/4318`.
3. Snapshot non-OpenScope container ID/status before and after; any unrelated lifecycle change fails acceptance.
4. Block start below 10 GiB free or at 90% filesystem use; never auto-prune shared Docker state.
5. Add a remote runner that verifies payload identity, SSH host key, command scope and evidence collection.
6. Resolve the Registry/manifest path during Phase 0 before any Compose start; configured mirrors are not currently sufficient evidence.

## Commands Executed

- SSH known-host lookup and effective configuration inspection.
- Read-only remote OS/toolchain/capacity/port/container inventory.
- HTTP reachability checks for Docker Registry and Maven Central.
- Read-only Buildx manifest inspection with a 25-second timeout.

All product build/runtime/E2E checks remain unexecuted.

## Human Path Override

cywu 随后明确要求依赖文件放在开发机 `/root` 下。上文基于探测提出的 `/opt/openscope-v0.1` 建议已被替代；active contract 使用 `/root/openscope-v0.1`，依赖统一进入 `/root/openscope-v0.1/dependencies`，不直接散落在 `/root` 根层。只读复核确认 `/root/openscope-v0.1` 当前不存在，后续创建不会覆盖同名既有目录。

第二次人工覆盖将最终 active workdir 指定为 `/root/workspace/openscope-v0.1`，依赖目录相应为 `/root/workspace/openscope-v0.1/dependencies`。只读复核确认新目标路径当前不存在；前述 `/opt/...` 与 `/root/openscope-v0.1` 均只保留为历史决策记录，不再用于实施。
