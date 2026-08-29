#!/usr/bin/env bash
# OpenScope V0.1 docs consistency check (AC-B1).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail=0

require() { # file
  [ -f "$1" ] && echo "  ok $1" || { echo "  FAIL missing $1"; fail=1; }
}

echo "[verify-docs] structure:"
require README.md
require OpenScope-项目架构.md
require OpenScope-技术架构.md
require distribution/bom.yaml
require distribution/standalone/docker-compose.yml
require distribution/standalone/.env.example
require distribution/standalone/config/collector/collector.yaml
require distribution/standalone/config/prometheus/prometheus.yml
require distribution/standalone/config/tempo/tempo.yaml
require distribution/standalone/config/loki/loki.yaml
require grafana/provisioning/datasources/prometheus.yml
require grafana/provisioning/datasources/tempo.yml
require grafana/provisioning/datasources/loki.yml
require grafana/provisioning/dashboards/dashboards.yml
require grafana/dashboards/overview/openscope-overview.json
require cli/openscope
require agents/java/manifest.yaml
require tools/resolve-bom.sh

echo "[verify-docs] placeholder & forbidden literal scan:"
if grep -rn "^[[:space:]]*image:.*latest" --include="*.yml" --include="*.yaml" distribution/ 2>/dev/null; then
  echo "  FAIL 'latest' used in distribution image references"; fail=1
else
  echo "  ok no 'latest' image references in distribution configs"
fi
if grep -rn "GF_ADMIN_PASSWORD: *.*admin" --include="*.yml" --include="*.yaml" grafana/ distribution/ 2>/dev/null; then
  echo "  FAIL default admin password leaked into config"; fail=1
else
  echo "  ok no default admin password in tracked config"
fi
if git grep -n "change-me-strong-password" -- ':!distribution/standalone/.env.example' ':!cli/openscope' ':!tools/verify-docs.sh' ':!docs/testing/2026/*' >/dev/null 2>&1; then
  echo "  FAIL example password placeholder outside .env.example"; fail=1
else
  echo "  ok example password only in .env.example"
fi

echo "[verify-docs] plan and acceptance state consistency:"
for plan in docs/plans/*-plan.md; do
  [ -f "$plan" ] || continue
  if sed -n '1,10p' "$plan" | grep -q 'Plan Status: completed'; then
    if grep -Eq '^Status: (planned|in progress)|^- \[ \]|pending independent|Status Note: open' "$plan"; then
      echo "  FAIL completed plan contains open phase/gate/evidence: $plan"
      fail=1
    else
      echo "  ok completed plan is textually closed: $plan"
    fi
  fi
done
if sed -n '1,8p' docs/testing/v0.1-acceptance-checklist.md | grep -q 'Checklist Status:.*accepted'; then
  if sed '/^## Final Verdict/,$d' docs/testing/v0.1-acceptance-checklist.md | grep -q '^- \[ \]'; then
    echo "  FAIL accepted checklist still contains unchecked items"
    fail=1
  elif ! grep -q '^- \[x\] `accepted`' docs/testing/v0.1-acceptance-checklist.md; then
    echo "  FAIL accepted checklist does not select the accepted verdict"
    fail=1
  else
    echo "  ok accepted checklist has no unchecked A-I items and selects accepted verdict"
  fi
else
  echo "  ok acceptance checklist is not claiming accepted closure"
fi

if [ "$fail" -eq 0 ]; then echo "[verify-docs] PASSED"; else echo "[verify-docs] FAILED"; fi
exit "$fail"
