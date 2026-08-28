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
if git grep -n "change-me-strong-password" -- ':!distribution/standalone/.env.example' ':!cli/openscope' ':!tools/verify-docs.sh' >/dev/null 2>&1; then
  echo "  FAIL example password placeholder outside .env.example"; fail=1
else
  echo "  ok example password only in .env.example"
fi

if [ "$fail" -eq 0 ]; then echo "[verify-docs] PASSED"; else echo "[verify-docs] FAILED"; fi
exit "$fail"