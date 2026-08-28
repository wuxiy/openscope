#!/usr/bin/env bash
# OpenScope V0.1 BOM resolver.
# Resolves exact-tag multi-arch manifest digests and writes them back into
# distribution/bom.yaml. Idempotent; --check only validates existing entries.
#
# Resolution order:
#   1. registry API via curl (GHCR public: anonymous token flow)
#   2. local Docker daemon image RepoDigest (works through configured mirrors)
#   3. remote daemon via SSH when REMOTE_HOST is set
# Fails with non-zero exit if any digest cannot be resolved (AC-A1/A2 gate).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOM_FILE="$ROOT_DIR/distribution/bom.yaml"
REMOTE_HOST="${REMOTE_HOST:-root@172.16.65.59}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10)

# resolve <registry> <repo> <tag> -> prints sha256:... or exits 1
resolve_ghcr() { # repo tag
  local repo="$1" tag="$2" tok url
  tok=$(curl -fsS --max-time 25 "https://ghcr.io/token?scope=repository:$repo:pull&service=ghcr.io" | sed -E 's/.*"token":"([^"]+)".*/\1/') || return 1
  url="https://ghcr.io/v2/$repo/manifests/$tag"
  curl -fsSI --max-time 25 -H "Authorization: Bearer $tok" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
    "$url" | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:" {print $2}' || return 1
}

resolve_dockerhub() { # repo tag
  local repo="$1" tag="$2" tok url
  tok=$(curl -fsS --max-time 20 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo:pull" | sed -E 's/.*"token":"([^"]+)".*/\1/') || return 1
  url="https://registry-1.docker.io/v2/$repo/manifests/$tag"
  curl -fsSI --max-time 25 -H "Authorization: Bearer $tok" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
    "$url" | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:" {print $2}' || return 1
}

resolve_daemon() { # repo tag
  docker image inspect --format '{{index .RepoDigests 0}}' "$1:$2" 2>/dev/null | sed -E 's/^[^@]+@//' || return 1
}

resolve_remote_daemon() { # repo tag
  ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" \
    "docker image inspect --format '{{index .RepoDigests 0}}' '$1:$2' 2>/dev/null | sed -E 's/^[^@]+@//'" 2>/dev/null || return 1
}

# image key -> "registry|repo|tag"
plan() { # key
  case "$1" in
    otelcol-contrib) echo "ghcr|open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib|0.159.0" ;;
    prometheus)      echo "ghcr|prometheus/prometheus|v3.14.0" ;;
    tempo)           echo "dockerhub|grafana/tempo|3.0.3" ;;
    loki)            echo "dockerhub|grafana/loki|3.7.6" ;;
    grafana)         echo "dockerhub|grafana/grafana|13.2.0" ;;
    *) echo "unknown-key" ;;
  esac
}

set_digest() { # key digest
  awk -v k="^  $1:" -v d="$2" '
    $0 ~ k {on=1}
    on && /^    digest:/ {print "    digest: " d; on=0; next}
    {print}
  ' "$BOM_FILE" > "$BOM_FILE.tmp" && mv "$BOM_FILE.tmp" "$BOM_FILE"
}

echo "OpenScope BOM resolver — $BOM_FILE"
[ -f "$BOM_FILE" ] || { echo "BOM file missing: $BOM_FILE" >&2; exit 1; }

if [ "${1:-}" = "--check" ]; then
  bad=0
  for key in otelcol-contrib prometheus tempo loki grafana; do
    d=$(awk -v k="^  $key:" '$0 ~ k {on=1} on && /^    digest:/ {sub(/^[^:]*: */, ""); print; exit}' "$BOM_FILE")
    if printf '%s' "$d" | grep -qE '^sha256:[0-9a-f]{64}$'; then
      echo "  ok $key $d"
    else
      echo "  FAIL $key digest='${d:-<empty>}'"; bad=1
    fi
  done
  [ "$bad" -eq 0 ] && echo "BOM digest check PASSED" || { echo "BOM digest check FAILED" >&2; exit 1; }
  exit 0
fi

for key in otelcol-contrib prometheus tempo loki grafana; do
  IFS='|' read -r registry repo tag <<< "$(plan "$key")"
  d=""
  case "$registry" in
    ghcr) d=$(resolve_ghcr "$repo" "$tag" || true) ;;
    dockerhub)
      d=$(resolve_dockerhub "$repo" "$tag" || true)
      [ -n "$d" ] || d=$(resolve_daemon "$repo" "$tag" || true)
      [ -n "$d" ] || d=$(resolve_remote_daemon "$repo" "$tag" || true)
      ;;
  esac
  if [ -n "$d" ]; then
    echo "  resolved $key $repo@$d"
    set_digest "$key" "$d"
  else
    echo "  UNRESOLVED $key ($registry/$repo:$tag)" >&2
    exit 1
  fi
done
echo "BOM updated. Run '$0 --check' to verify."