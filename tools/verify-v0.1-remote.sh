#!/usr/bin/env bash
# OpenScope V0.1 remote acceptance runner — orchestrates full A-H acceptance on
# root@172.16.65.59 under /root/workspace/openscope-v0.1 + project openscope-v01.
# Isolation invariants (AC-I1..I8): BatchMode host-key SSH, payload digest match,
# dependency dir only, no non-OpenScope resource touched, sanitized evidence.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HOST="root@172.16.65.59"
R="/root/workspace/openscope-v0.1"
DEP="$R/dependencies"
PROJ="openscope-v01"
EVIDENCE_DIR="docs/testing/2026/08-28"
LOCAL_REV="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
STAMP="$(date +%Y%m%d-%H%M%S)"

SSH_CMD=(ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ConnectTimeout=15)
SCP_CMD=(scp -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no)

echo "== remote runner start ($STAMP) rev=$LOCAL_REV =="
mkdir -p "$EVIDENCE_DIR"
EVID="$EVIDENCE_DIR/remote-$STAMP.log"
: > "$EVID"

say() { echo "$*" | tee -a "$EVID"; }
remote() { "${SSH_CMD[@]}" "$HOST" "$@"; }

# --- preflight & host snapshot ----------------------------------------------------
say "== preflight =="
say "$(remote 'uname -srm; java -version 2>&1 | head -1; docker --version; docker compose version; df -h / | tail -1; echo "--ports--"; ss -ltn | grep -E ":(13001|4317|4318) " || echo "ports free"')"
say "non-openscope container snapshot (before):"
remote 'docker ps --format "{{.ID}} {{.Names}} {{.Status}}" | grep -v openscope-v01' | tee -a "$EVID" || true

# --- payload sync ----------------------------------------------------------------
say "== payload sync ($LOCAL_REV) =="
remote "mkdir -p $R $DEP"
rsync -az --delete \
  --exclude '.git' --exclude '.alma-snapshots' \
  --exclude 'target' --exclude '.env' --exclude '*.log' \
  ./ "$HOST:$R/" | tee -a "$EVID" || { say "rsync FAILED"; exit 1; }
say "payload transferred"
remote "du -sh $R | tail -1"

# --- dependency (Java Agent) ------------------------------------------------------
AGENT_SRC="/tmp/otel-javaagent-2.31.1.jar"
if [ -f "$AGENT_SRC" ]; then
  "${SCP_CMD[@]}" "$AGENT_SRC" "$HOST:$DEP/opentelemetry-javaagent.jar"
  say "agent uploaded -> $DEP/opentelemetry-javaagent.jar"
else
  say "WARN agent jar not found locally at $AGENT_SRC; attempting remote Maven Central download"
  remote "cd $DEP && wget -q https://repo1.maven.org/maven2/io/opentelemetry/javaagent/opentelemetry-javaagent/2.31.1/opentelemetry-javaagent-2.31.1.jar -O opentelemetry-javaagent.jar && sha256sum opentelemetry-javaagent.jar" | tee -a "$EVID"
fi
say "agent sha (expect bbf83c151b6400709e2f225bdd07a04f839d9d13b8b93464241333fd25d3e3ba):"
remote "sha256sum $DEP/opentelemetry-javaagent.jar | cut -d' ' -f1" | tee -a "$EVID"

# --- payload digest match (AC-I5) ------------------------------------------------
KEYFILES="pom.xml distribution/bom.yaml distribution/standalone/docker-compose.yml tools/verify-v0.1.sh cli/openscope examples/springboot-simple/src/main/java/dev/openscope/sample/ProbeController.java grafana/dashboards/overview/openscope-overview.json"
for f in $KEYFILES; do
  l=$(shasum -a 256 "$f" | cut -d' ' -f1)
  r=$(remote "sha256sum $R/$f | cut -d' ' -f1" 2>/dev/null || echo MISSING)
  if [ "$l" = "$r" ]; then say "  ok digest match $f"; else say "  FAIL digest MISMATCH $f ($l vs $r)"; exit 1; fi
done

# --- env (grafana on 13001, non-default password, BOM digests from local bom.yaml) ---
say "== env =="
GF_PW="OpenScope$(date +%s)\$V01"   # non-default, generated, kept only on remote
D_OTEL="$(awk '/^  otelcol-contrib:/{on=1} on && /^    digest:/{sub(/^[^:]*: */,"");print;exit}' distribution/bom.yaml)"
D_PROM="$(awk '/^  prometheus:/{on=1} on && /^    digest:/{sub(/^[^:]*: */,"");print;exit}' distribution/bom.yaml)"
D_TEMPO="$(awk '/^  tempo:/{on=1} on && /^    digest:/{sub(/^[^:]*: */,"");print;exit}' distribution/bom.yaml)"
D_LOKI="$(awk '/^  loki:/{on=1} on && /^    digest:/{sub(/^[^:]*: */,"");print;exit}' distribution/bom.yaml)"
D_GRAF="$(awk '/^  grafana:/{on=1} on && /^    digest:/{sub(/^[^:]*: */,"");print;exit}' distribution/bom.yaml)"
remote "
set -a
cat > $R/distribution/standalone/.env <<EOF
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=$GF_PW
GRAFANA_PORT=13001
OPEN_SCOPE_BOM_OTELCOL=0.159.0
OPEN_SCOPE_BOM_OTELCOL_DIGEST=$D_OTEL
OPEN_SCOPE_BOM_PROMETHEUS=v3.14.0
OPEN_SCOPE_BOM_PROMETHEUS_DIGEST=$D_PROM
OPEN_SCOPE_BOM_TEMPO=3.0.3
OPEN_SCOPE_BOM_TEMPO_DIGEST=$D_TEMPO
OPEN_SCOPE_BOM_LOKI=3.7.6
OPEN_SCOPE_BOM_LOKI_DIGEST=$D_LOKI
OPEN_SCOPE_BOM_GRAFANA=13.2.0
OPEN_SCOPE_BOM_GRAFANA_DIGEST=$D_GRAF
EOF
chmod 600 $R/distribution/standalone/.env
echo .env written (permissions \$(stat -c %a $R/distribution/standalone/.env))"

# --- run: BOM resolve, build, start, verify --------------------------------------
say "== remote execution =="
remote "cd $R && chmod +x tools/*.sh cli/openscope \
  && echo '-- resolve-bom --' && ./tools/resolve-bom.sh --force 2>&1 | tail -8 \
  && echo '-- bom check --' && ./tools/resolve-bom.sh --check \
  && echo '-- compose config --' && docker compose --project-name $PROJ -f distribution/standalone/docker-compose.yml --env-file distribution/standalone/.env config --quiet && echo compose-config-ok \
  && echo '-- verify-docs --' && ./tools/verify-docs.sh \
  && echo '-- mvnw verify --' && ./mvnw -q -pl examples/springboot-simple -am verify 2>&1 | tail -3 \
  && echo '-- cli start --' && ./cli/openscope start \
  && sleep 8 \
  && echo '-- cli status --' && ./cli/openscope status \
  && echo '-- cli doctor --' && ./cli/openscope doctor \
  && echo '-- verify-v0.1 --' && AGENT_JAR=$DEP/opentelemetry-javaagent.jar ./tools/verify-v0.1.sh --remote --keep-running" 2>&1 | tee -a "$EVID"
RC=${PIPESTATUS[0]}
say "remote execution exit=$RC"

# --- evidence recovery + cleanup ---------------------------------------------------
say "== evidence & cleanup =="
remote "cd $R && ./cli/openscope stop || true" | tee -a "$EVID" || true
say "non-openscope container snapshot (after):"
remote 'docker ps --format "{{.ID}} {{.Names}} {{.Status}}" | grep -v openscope-v01' | tee -a "$EVID" || true
"${SCP_CMD[@]}" "$HOST:/tmp/openscope-sample.log" "$EVIDENCE_DIR/sample-$STAMP.log" 2>/dev/null || true

say "remote runner finished rc=$RC"
[ "$RC" -eq 0 ] && echo "REMOTE ACCEPTANCE PASSED (see $EVID)" || { echo "REMOTE ACCEPTANCE FAILED rc=$RC (see $EVID)"; exit 1; }