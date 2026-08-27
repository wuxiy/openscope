#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

required_files='docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md
docs/architecture/v0.1-standalone-contract.md
docs/plans/2026-08-27-1937-v0.1-standalone-distribution-plan.md
docs/testing/v0.1-acceptance-checklist.md'

for required_file in $required_files; do
  if [ ! -s "$required_file" ]; then
    echo "missing required V0.1 document: $required_file" >&2
    exit 1
  fi
done

if rg -n '�' OpenScope-项目架构.md OpenScope-技术架构.md docs/context docs/architecture docs/requirements docs/backlog docs/plans docs/testing; then
  echo 'replacement-character corruption found in active documentation' >&2
  exit 1
fi

if rg -n 'Reviewer availability: `<human \| subagent \| none>`' docs/context/ai-autonomy-policy.md; then
  echo 'reviewer availability is still a placeholder' >&2
  exit 1
fi

if rg -n 'docs/requirements/<待从项目架构' docs/backlog/README.md; then
  echo 'P0 backlog still points to a requirement placeholder' >&2
  exit 1
fi

if rg -n 'version:[[:space:]]*\$\{managed\}|> 3\.x' OpenScope-项目架构.md OpenScope-技术架构.md docs/context docs/architecture docs/requirements docs/backlog; then
  echo 'active architecture still contains an unresolved managed version or invalid Prometheus lower-bound syntax' >&2
  exit 1
fi

remote_contract_files='docs/context/project-context.md
docs/requirements/2026-08-27-1937-v0.1-standalone-distribution.md
docs/architecture/v0.1-standalone-contract.md
docs/plans/2026-08-27-1937-v0.1-standalone-distribution-plan.md
docs/testing/v0.1-acceptance-checklist.md'

for remote_contract_file in $remote_contract_files; do
  if ! rg -q '172\.16\.65\.59' "$remote_contract_file"; then
    echo "development validation host missing from: $remote_contract_file" >&2
    exit 1
  fi
  if ! rg -q '/root/workspace/openscope-v0\.1' "$remote_contract_file"; then
    echo "remote workdir missing from: $remote_contract_file" >&2
    exit 1
  fi
done

if rg -n '/opt/openscope-v0\.1|/root/openscope-v0\.1' $remote_contract_files; then
  echo 'active remote contract still references a superseded remote workdir' >&2
  exit 1
fi

echo 'active V0.1 documentation checks passed'
