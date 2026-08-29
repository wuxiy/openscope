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
EVIDENCE_DIR="docs/testing/2026/08-29"
LOCAL_REV="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
STAMP="$(date +%Y%m%d-%H%M%S)"
AGENT_SHA="$(awk '/^  sha256:/{print $2; exit}' agents/java/manifest.yaml)"
JDK_VERSION="$(awk '/^  java-jdk:/{on=1} on && /^    version:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_DIR="$(awk '/^  java-jdk:/{on=1} on && /^    directory:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_ARCHIVE="$(awk '/^  java-jdk:/{on=1} on && /^    archive:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_SHA="$(awk '/^  java-jdk:/{on=1} on && /^    sha256:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_URL="$(awk '/^  java-jdk:/{on=1} on && /^    source:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_MIRROR_URL="$(awk '/^  java-jdk:/{on=1} on && /^    mirror:/{sub(/^[^:]*: */, ""); print; exit}' distribution/bom.yaml)"
JDK_HOME="$DEP/$JDK_DIR"

printf '%s' "$JDK_SHA" | grep -qE '^[0-9a-f]{64}$' || { echo "invalid isolated JDK SHA pin" >&2; exit 1; }
[ -n "$JDK_VERSION" ] && [ -n "$JDK_DIR" ] && [ -n "$JDK_ARCHIVE" ] && [ -n "$JDK_URL" ] && [ -n "$JDK_MIRROR_URL" ] \
  || { echo "incomplete isolated JDK BOM pin" >&2; exit 1; }

SSH_CMD=(ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ConnectTimeout=15)
SCP_CMD=(scp -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no)

echo "== remote runner start ($STAMP) rev=$LOCAL_REV =="
mkdir -p "$EVIDENCE_DIR"
EVID="$EVIDENCE_DIR/remote-$STAMP.txt"
: > "$EVID"

say() { echo "$*" | tee -a "$EVID"; }
remote() { "${SSH_CMD[@]}" "$HOST" "$@"; }
remote_non_openscope_snapshot() { # <remote-output-path>
  remote "docker ps -q | while read -r id; do name=\$(docker inspect --format '{{.Name}}' \"\$id\"); case \"\$name\" in /$PROJ-*) continue ;; esac; docker inspect --format '{{.Id}} {{.Name}} {{.State.Status}} {{.State.Running}} {{.RestartCount}} {{.Config.Image}}' \"\$id\"; done | sort > '$1'"
}

# --- preflight & host snapshot ----------------------------------------------------
say "== preflight =="
set +e
PREFLIGHT="$(remote "set -eu; test -d '$R' || { echo 'BLOCKED remote workdir missing: $R'; exit 1; }; for tool in wget tar sha256sum; do command -v \"\$tool\" >/dev/null 2>&1 || { echo \"BLOCKED required bootstrap tool missing: \$tool\"; exit 1; }; done; uname -srm; java -version 2>&1 | head -1 || true; docker --version; docker compose version; docker buildx version; echo '--workdir-filesystem--'; df -hP '$R' | tail -1; echo '--ports--'; ss -ltn | grep -E ':(13001|4317|4318) ' || echo 'ports free'; set -- \$(df -kP '$R' | tail -1); avail_gi=\$((\$4/1024/1024)); use=\${5%%%}; [ \"\$avail_gi\" -ge 10 ] && [ \"\$use\" -lt 90 ] || { echo \"BLOCKED disk guard workdir=$R available=\${avail_gi}GiB usage=\${use}%\"; exit 1; }")"
PREFLIGHT_RC=$?
set -e
say "$PREFLIGHT"
if [ "$PREFLIGHT_RC" -ne 0 ]; then
  say "REMOTE ACCEPTANCE BLOCKED before payload sync or container operations"
  exit "$PREFLIGHT_RC"
fi
INITIAL_RUNNING="$(remote "docker ps --filter label=com.docker.compose.project=$PROJ --format '{{.Names}}' | wc -l")"
say "initial OpenScope running containers=$INITIAL_RUNNING"

# --- payload sync ----------------------------------------------------------------
say "== payload sync ($LOCAL_REV) =="
remote "mkdir -p $R $DEP"
rsync -az --delete \
  --exclude '.git' --exclude '.alma-snapshots' \
  --exclude 'target' --exclude 'dependencies' --exclude '.env' --exclude '*.log' \
  ./ "$HOST:$R/" | tee -a "$EVID" || { say "rsync FAILED"; exit 1; }
say "payload transferred"
remote "du -sh $R | tail -1"

PAYLOAD_MANIFEST="$(mktemp)"
trap 'rm -f "$PAYLOAD_MANIFEST"' EXIT
git ls-files | grep -Ev '(^|/)target/|\.log$' | while IFS= read -r f; do
  [ -f "$f" ] && shasum -a 256 "$f"
done > "$PAYLOAD_MANIFEST"
PAYLOAD_ID="$(shasum -a 256 "$PAYLOAD_MANIFEST" | cut -d' ' -f1)"
say "payload manifest sha256=$PAYLOAD_ID"
if [ -n "$(git status --porcelain)" ]; then
  say "payload git state=dirty (manifest identifies working-tree contents)"
else
  say "payload git state=clean"
fi
"${SCP_CMD[@]}" "$PAYLOAD_MANIFEST" "$HOST:$DEP/payload.sha256"
remote "cd $R && sha256sum -c $DEP/payload.sha256 >/dev/null && echo payload-manifest-ok" | tee -a "$EVID"

# --- isolated build/runtime JDK --------------------------------------------------
say "== isolated JDK $JDK_VERSION =="
remote "
set -eu
mkdir -p '$DEP'
archive='$DEP/$JDK_ARCHIVE'
if [ -f \"\$archive\" ]; then
  actual=\$(sha256sum \"\$archive\" | cut -d' ' -f1)
  if [ \"\$actual\" != '$JDK_SHA' ]; then
    mv \"\$archive\" \"\$archive.invalid-$STAMP\"
  fi
fi
if [ ! -f \"\$archive\" ]; then
  download=\"\$archive.download-$STAMP\"
  if ! wget -q --timeout=30 --tries=2 '$JDK_MIRROR_URL' -O \"\$download\"; then
    mv \"\$download\" \"\$download.mirror-failed\"
    download=\"\$archive.download-$STAMP-official\"
    wget -q --timeout=30 --tries=2 '$JDK_URL' -O \"\$download\"
  fi
  actual=\$(sha256sum \"\$download\" | cut -d' ' -f1)
  [ \"\$actual\" = '$JDK_SHA' ] || { mv \"\$download\" \"\$download.invalid\"; echo isolated-jdk-sha-mismatch; exit 1; }
  mv \"\$download\" \"\$archive\"
fi
[ \"\$(sha256sum \"\$archive\" | cut -d' ' -f1)\" = '$JDK_SHA' ] || { echo isolated-jdk-sha-mismatch; exit 1; }
if [ ! -x '$JDK_HOME/bin/javac' ]; then
  stage=\$(mktemp -d '$DEP/jdk-stage.XXXXXX')
  tar -xzf \"\$archive\" -C \"\$stage\"
  [ -x \"\$stage/$JDK_DIR/bin/javac\" ] || { echo isolated-jdk-layout-mismatch; exit 1; }
  [ ! -e '$JDK_HOME' ] || mv '$JDK_HOME' '$JDK_HOME.invalid-$STAMP'
  mv \"\$stage/$JDK_DIR\" '$JDK_HOME'
  rmdir \"\$stage\"
fi
export JAVA_HOME='$JDK_HOME'
export PATH=\"\$JAVA_HOME/bin:\$PATH\"
java -version
javac --release 21 -version
echo isolated-jdk-sha-ok
" 2>&1 | tee -a "$EVID"

# --- dependency (Java Agent) ------------------------------------------------------
AGENT_SRC="$ROOT_DIR/dependencies/opentelemetry-javaagent.jar"
if [ -f "$AGENT_SRC" ]; then
  remote "mkdir -p $DEP"
  "${SCP_CMD[@]}" "$AGENT_SRC" "$HOST:$DEP/opentelemetry-javaagent.jar"
  say "agent uploaded -> $DEP/opentelemetry-javaagent.jar"
else
  say "WARN agent jar not found locally at $AGENT_SRC; attempting remote Maven Central download"
  remote "cd $DEP && wget -q https://repo1.maven.org/maven2/io/opentelemetry/javaagent/opentelemetry-javaagent/2.31.1/opentelemetry-javaagent-2.31.1.jar -O opentelemetry-javaagent.jar && sha256sum opentelemetry-javaagent.jar" | tee -a "$EVID"
fi
say "agent sha verification:"
remote "actual=\$(sha256sum $DEP/opentelemetry-javaagent.jar | cut -d' ' -f1); [ \"\$actual\" = '$AGENT_SHA' ] || { echo agent-sha-mismatch; exit 1; }; echo agent-sha-ok" | tee -a "$EVID"

# --- payload digest match (AC-I5) ------------------------------------------------
KEYFILES="pom.xml distribution/bom.yaml distribution/standalone/docker-compose.yml tools/verify-v0.1.sh cli/openscope examples/springboot-simple/src/main/java/dev/openscope/sample/ProbeController.java grafana/dashboards/overview/openscope-overview.json"
for f in $KEYFILES; do
  l=$(shasum -a 256 "$f" | cut -d' ' -f1)
  r=$(remote "sha256sum $R/$f | cut -d' ' -f1" 2>/dev/null || echo MISSING)
  if [ "$l" = "$r" ]; then say "  ok digest match $f"; else say "  FAIL digest MISMATCH $f ($l vs $r)"; exit 1; fi
done

# --- env (grafana on 13001, non-default password, BOM digests from local bom.yaml) ---
say "== env =="
GF_PW="OpenScope$(date +%s)Qa1x"   # non-default, ASCII-safe (no $, backtick, quotes), kept only on remote
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
echo .env-written"

# --- static/build gates: no container mutation before these pass -----------------
say "== remote static and build gates =="
set +e
remote "export JAVA_HOME='$JDK_HOME'; export PATH=\"\$JAVA_HOME/bin:\$PATH\"; cd $R && chmod +x tools/*.sh cli/openscope \
  && echo '-- executable prune guard --' && ! grep -REn '^[[:space:]]*docker[[:space:]]+system[[:space:]]+prune' tools cli \
  && echo '-- bom check --' && ./tools/resolve-bom.sh --check \
  && echo '-- compose config --' && docker compose --project-name $PROJ -f distribution/standalone/docker-compose.yml --env-file distribution/standalone/.env config --quiet && echo compose-config-ok \
  && echo '-- verify-docs --' && ./tools/verify-docs.sh \
  && echo '-- mvnw runtime --' && ./mvnw -version \
  && echo '-- mvnw clean verify --' && ./mvnw -q -pl examples/springboot-simple -am clean verify" 2>&1 | tee -a "$EVID"
STATIC_RC=${PIPESTATUS[0]}
set -e
say "remote static/build exit=$STATIC_RC"
if [ "$STATIC_RC" -ne 0 ]; then
  say "REMOTE ACCEPTANCE FAILED before container operations"
  exit "$STATIC_RC"
fi

# --- runtime acceptance -----------------------------------------------------------
remote_non_openscope_snapshot "$DEP/non-openscope-before.txt"
say "non-openscope container snapshot (before):"
remote "cat $DEP/non-openscope-before.txt" | tee -a "$EVID"
say "== remote runtime execution =="
set +e
remote "export JAVA_HOME='$JDK_HOME'; export PATH=\"\$JAVA_HOME/bin:\$PATH\"; cd $R \
  && echo '-- cli start --' && ./cli/openscope start \
  && echo '-- force recreate from current config, preserving volumes --' && docker compose -p $PROJ -f distribution/standalone/docker-compose.yml --env-file distribution/standalone/.env up -d --force-recreate \
  && sleep 8 \
  && echo '-- synchronize persisted Grafana admin password --' \
  && docker exec -e OPEN_SCOPE_ADMIN_PASSWORD='$GF_PW' $PROJ-grafana /bin/sh -c 'grafana cli --homepath /usr/share/grafana --config /etc/grafana/grafana.ini admin reset-admin-password \"\$OPEN_SCOPE_ADMIN_PASSWORD\"' \
  && echo '-- cli status --' && ./cli/openscope status \
  && echo '-- cli doctor --' && ./cli/openscope doctor \
  && echo '-- verify-v0.1 run 1 --' && AGENT_JAR=$DEP/opentelemetry-javaagent.jar ./tools/verify-v0.1.sh --remote \
  && echo '-- verify-v0.1 run 2 --' && AGENT_JAR=$DEP/opentelemetry-javaagent.jar ./tools/verify-v0.1.sh --remote --keep-running \
  && echo '-- doctor failure injection --' \
  && for svc in collector prometheus tempo loki grafana; do \
       failure_file=$DEP/doctor-failure-\$svc.txt; \
       recovery_file=$DEP/doctor-recovery-\$svc.txt; \
       docker compose -p $PROJ -f distribution/standalone/docker-compose.yml --env-file distribution/standalone/.env stop "\$svc" >/dev/null || exit 1; \
       if ./cli/openscope doctor >"\$failure_file" 2>&1; then \
         echo "FAIL doctor returned zero with \$svc stopped"; exit 1; \
       fi; \
       grep -Fq 'container not running' "\$failure_file" \
         || { echo "FAIL doctor did not identify stopped component \$svc"; exit 1; }; \
       docker compose -p $PROJ -f distribution/standalone/docker-compose.yml --env-file distribution/standalone/.env start "\$svc" >/dev/null || exit 1; \
       ./cli/openscope doctor >"\$recovery_file" 2>&1 \
         || { echo "FAIL doctor did not recover after starting \$svc"; tail -20 "\$recovery_file"; exit 1; }; \
       echo "PASS doctor failed closed and recovered for \$svc"; \
     done" 2>&1 | tee -a "$EVID"
RC=${PIPESTATUS[0]}
set -e
say "remote execution exit=$RC"

# --- evidence recovery + cleanup ---------------------------------------------------
say "== evidence & cleanup =="
if [ "$INITIAL_RUNNING" -eq 0 ]; then
  remote "cd $R && ./cli/openscope stop || true" | tee -a "$EVID" || true
  say "OpenScope restored to initial stopped state"
else
  say "OpenScope left running to match initial state"
fi
remote_non_openscope_snapshot "$DEP/non-openscope-after.txt"
say "non-openscope container snapshot (after):"
remote "cat $DEP/non-openscope-after.txt" | tee -a "$EVID"
if remote "diff -u $DEP/non-openscope-before.txt $DEP/non-openscope-after.txt >/dev/null"; then
  say "non-openscope snapshot unchanged"
else
  say "FAIL non-openscope snapshot changed"
  RC=1
fi
"${SCP_CMD[@]}" "$HOST:$R/distribution/standalone/.data/verify-v0.1-sample.log" "$EVIDENCE_DIR/sample-$STAMP.txt" 2>/dev/null || true

say "remote runner finished rc=$RC"
[ "$RC" -eq 0 ] && echo "REMOTE ACCEPTANCE PASSED (see $EVID)" || { echo "REMOTE ACCEPTANCE FAILED rc=$RC (see $EVID)"; exit 1; }
