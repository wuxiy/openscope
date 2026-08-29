#!/usr/bin/env bash
# OpenScope V0.1 acceptance script — drives the sample app and asserts against
# REAL backend data (Tempo/Prometheus/Loki APIs). Fail-closed: any failed check
# exits non-zero; checks never silently downgrade to warnings (AC-D/H/G5).
#
# Usage:
#   ./tools/verify-v0.1.sh [--remote] [--keep-running]
# Requires a started stack (cli/openscope start) and a resolvable sample jar.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE="false"; KEEP="false"
for arg in "$@"; do
  case "$arg" in --remote) REMOTE="true";; --keep-running) KEEP="true";; esac
done

# --- config ----------------------------------------------------------------------
OTLP_ENDPOINT="http://127.0.0.1:4318"
SAMPLE_JAR="examples/springboot-simple/target/springboot-simple-0.1.0-SNAPSHOT.jar"
AGENT_JAR="${AGENT_JAR:-dependencies/opentelemetry-javaagent.jar}"
SAMPLE_PORT="8090"
SAMPLE_LOG="${OPEN_SCOPE_SAMPLE_LOG:-$ROOT_DIR/distribution/standalone/.data/verify-v0.1-sample.log}"
SAMPLE_PID=""
CANARY="V0-1-APP-CANARY-$(date +%s)-$$"
COLLECTOR_CANARY="V0-1-COLLECTOR-CANARY-$(date +%s)-$$"
CONTROL_ID="probe-$(date +%s)-$$"
PASS=0; FAIL=0; CHECKS=0
PROJ="openscope-v01"
ENV_FILE="$ROOT_DIR/distribution/standalone/.env"
GRAFANA_URL=""

# Backends are NOT published to the host (AC-C4). Query through a disposable
# curl container attached to the compose network (backend images are slim and
# lack /bin/sh + wget, so docker exec is unreliable for loki/tempo).
bom_get() { # bom_get <image-key> <field>
  local key="$1" field="$2"
  awk -v k="^  $key:" -v f="^    $field:" '$0 ~ k {on=1; next} on && /^  [a-z]/ {on=0} on && $0 ~ f {sub(/^[[:space:]]*[^:]*:[[:space:]]*/, ""); print; exit}' distribution/bom.yaml
}
QUERY_TAG="$(bom_get query-curl tag)"
QUERY_DIGEST="$(bom_get query-curl digest)"
QUERY_IMAGE="${QUERY_IMAGE:-curlimages/curl:$QUERY_TAG@$QUERY_DIGEST}"
qcurl() { # <url> [extra-args...]
  docker run --rm --network "${PROJ}_openscope-net" --entrypoint /bin/sh \
    "$QUERY_IMAGE" -c 'curl -s "$@"' sh "$@" 2>/dev/null
}
pq() { # prometheus query (stdin-pipe avoids argv quoting splits on embedded quotes)
  local q; q=$(printf '%s' "$1" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))')
  qcurl "http://prometheus:9090/api/v1/query?query=${q}"
}
lq() { # loki query (POST to query_range for streams)
  qcurl -X POST "http://loki:3100/loki/api/v1/query_range" \
    --data-urlencode "query=$1" --data-urlencode "limit=200"
}
tq_search() { # tempo search
  qcurl "http://tempo:3200/api/search?tags=$1&limit=$2"
}
tq_trace() { # tempo trace by id
  qcurl "http://tempo:3200/api/traces/$1"
}
gcurl() { # Grafana API path
  curl -fsS -u "${GF_ADMIN_USER:-admin}:${GF_ADMIN_PASSWORD:-}" \
    -H 'Accept: application/json' "$GRAFANA_URL$1"
}
otlp_post() { # <traces|metrics|logs>, payload on stdin
  curl -fsS -H 'Content-Type: application/json' --data-binary @- \
    "$OTLP_ENDPOINT/v1/$1" >/dev/null
}

pass() { PASS=$((PASS+1)); CHECKS=$((CHECKS+1)); echo "  PASS $*"; }
fail() { FAIL=$((FAIL+1)); CHECKS=$((CHECKS+1)); echo "  FAIL $*"; }
section() { echo; echo "=== $* ==="; }
contains() { printf '%s' "$1" | grep -Fq "$2"; }

cleanup() {
  [ -n "$SAMPLE_PID" ] && kill "$SAMPLE_PID" 2>/dev/null || true
  wait "$SAMPLE_PID" 2>/dev/null || true
  SAMPLE_PID=""
}

trap cleanup EXIT

# --- preflight -------------------------------------------------------------------
section "preflight"
[ -f "$SAMPLE_JAR" ] || { echo "  FAIL sample jar missing: $SAMPLE_JAR"; exit 1; }
[ -f "$ENV_FILE" ] || { echo "  FAIL runtime env missing: $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
GRAFANA_URL="http://127.0.0.1:${GRAFANA_PORT:-3000}"
command -v docker >/dev/null || { echo "  FAIL docker missing"; exit 1; }
command -v python3 >/dev/null || { echo "  FAIL python3 missing"; exit 1; }
printf '%s' "$QUERY_IMAGE" | grep -qE '@sha256:[0-9a-f]{64}$' || { echo "  FAIL query image is not digest-pinned"; exit 1; }
docker ps --format '{{.Names}}' | grep -qE "^openscope-v01-(collector|prometheus|tempo|loki|grafana)$" || {
  echo "  FAIL stack not running (run: ./cli/openscope start)"; exit 1; }
python3 - "$SAMPLE_PORT" <<'PY' || {
import socket,sys
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
    listener.bind(("127.0.0.1", int(sys.argv[1])))
PY
  echo "  FAIL sample port $SAMPLE_PORT is already occupied; refusing to test against a process this run did not start"
  exit 1
}
mkdir -p "$(dirname "$SAMPLE_LOG")"
echo "  ok stack running"

# --- start sample with Java Agent ------------------------------------------------
section "sample app (Java Agent $([ -f "$AGENT_JAR" ] && echo present || echo MISSING))"
[ -f "$AGENT_JAR" ] || fail "java agent jar missing at $AGENT_JAR"
if [ -f "$AGENT_JAR" ]; then
  java \
    -javaagent:"$AGENT_JAR" \
    -Dotel.service.name=openscope-sample \
    -Dotel.service.instance.id=openscope-sample-01 \
    -Dotel.service.version=0.1.0 \
    -Dotel.resource.attributes=site.id=dev-host,project.id=openscope-v01,deployment.environment.name=acceptance,service.namespace=openscope-demo \
    -Dotel.exporter.otlp.endpoint="$OTLP_ENDPOINT" \
    -Dotel.metrics.exporter=otlp \
    -Dotel.traces.exporter=otlp \
    -Dotel.logs.exporter=otlp \
    -Dotel.exporter.otlp.protocol=http/protobuf \
    -Dotel.exporter.otlp.metrics.temporality.preference=cumulative \
    -Dotel.metric.export.interval=5000 \
    -Dotel.instrumentation.logback-appender.enabled=true \
    -jar "$SAMPLE_JAR" >"$SAMPLE_LOG" 2>&1 &
  SAMPLE_PID=$!
  for i in $(seq 1 30); do
    kill -0 "$SAMPLE_PID" 2>/dev/null || {
      fail "sample process exited before readiness (port collision or startup failure)"
      tail -5 "$SAMPLE_LOG"
      exit 1
    }
    curl -sf -o /dev/null "http://127.0.0.1:$SAMPLE_PORT/ok" && break || sleep 1
  done
  if kill -0 "$SAMPLE_PID" 2>/dev/null && curl -sf -o /dev/null "http://127.0.0.1:$SAMPLE_PORT/ok"; then
    echo "  ok app up (pid $SAMPLE_PID)"
  else
    fail "sample app did not become ready as the process started by this run"
    tail -5 "$SAMPLE_LOG"
    exit 1
  fi
  pass "sample started under Java Agent $([ -f "$AGENT_JAR" ] && echo yes || echo no)"
fi

section "traffic generation"
# success, failure, and redaction-canary requests
CANARY_AUTH="Bearer $CANARY"
CANARY_COOKIE="session=$CANARY"
curl -s -o /dev/null -w "ok:%{http_code} " "http://127.0.0.1:$SAMPLE_PORT/ok"
curl -s -o /dev/null -w "fail:%{http_code} " "http://127.0.0.1:$SAMPLE_PORT/fail"
curl -s -o /dev/null -w "sensitive:%{http_code} " \
  -H "Authorization: $CANARY_AUTH" -H "Cookie: $CANARY_COOKIE" \
  -H "X-Token: token-$CANARY" -H "X-Password: password-$CANARY" \
  -H "X-CANARY: $CANARY" \
  "http://127.0.0.1:$SAMPLE_PORT/sensitive"
echo

# Exercise Collector-side deletion independently from Java Agent non-capture.
# Each signal carries a safe control identifier plus the same synthetic secret
# in every sensitive key configured in collector.yaml. The control must arrive;
# the secret must not.
read -r PROBE_TRACE_ID PROBE_SPAN_ID PROBE_START_NS PROBE_END_NS < <(python3 -c '
import secrets,time
now=time.time_ns()
print(secrets.token_hex(16), secrets.token_hex(8), now, now+1_000_000)')

cat <<JSON | otlp_post traces
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"openscope-redaction-probe"}},{"key":"service.namespace","value":{"stringValue":"openscope-demo"}},{"key":"service.instance.id","value":{"stringValue":"redaction-probe-01"}},{"key":"service.version","value":{"stringValue":"0.1.0"}},{"key":"site.id","value":{"stringValue":"dev-host"}},{"key":"project.id","value":{"stringValue":"openscope-v01"}},{"key":"deployment.environment.name","value":{"stringValue":"acceptance"}}]},"scopeSpans":[{"scope":{"name":"openscope-redaction-probe"},"spans":[{"traceId":"$PROBE_TRACE_ID","spanId":"$PROBE_SPAN_ID","name":"collector-redaction-trace","kind":2,"startTimeUnixNano":"$PROBE_START_NS","endTimeUnixNano":"$PROBE_END_NS","attributes":[{"key":"test_id","value":{"stringValue":"$CONTROL_ID"}},{"key":"http.request.header.authorization","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.cookie","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.x-password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.response.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"body","value":{"stringValue":"$COLLECTOR_CANARY"}}],"status":{"code":1}}]}]}]}
JSON

cat <<JSON | otlp_post metrics
{"resourceMetrics":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"openscope-redaction-probe"}},{"key":"service.namespace","value":{"stringValue":"openscope-demo"}},{"key":"service.instance.id","value":{"stringValue":"redaction-probe-01"}},{"key":"service.version","value":{"stringValue":"0.1.0"}},{"key":"site.id","value":{"stringValue":"dev-host"}},{"key":"project.id","value":{"stringValue":"openscope-v01"}},{"key":"deployment.environment.name","value":{"stringValue":"acceptance"}}]},"scopeMetrics":[{"scope":{"name":"openscope-redaction-probe"},"metrics":[{"name":"openscope_redaction_probe","gauge":{"dataPoints":[{"attributes":[{"key":"test_id","value":{"stringValue":"$CONTROL_ID"}},{"key":"http.request.header.authorization","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.cookie","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.x-password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.response.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"body","value":{"stringValue":"$COLLECTOR_CANARY"}}],"timeUnixNano":"$PROBE_END_NS","asDouble":1.0}]}}]}]}]}
JSON

cat <<JSON | otlp_post logs
{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"openscope-redaction-probe"}},{"key":"service.namespace","value":{"stringValue":"openscope-demo"}},{"key":"service.instance.id","value":{"stringValue":"redaction-probe-01"}},{"key":"service.version","value":{"stringValue":"0.1.0"}},{"key":"site.id","value":{"stringValue":"dev-host"}},{"key":"project.id","value":{"stringValue":"openscope-v01"}},{"key":"deployment.environment.name","value":{"stringValue":"acceptance"}}]},"scopeLogs":[{"scope":{"name":"openscope-redaction-probe"},"logRecords":[{"timeUnixNano":"$PROBE_END_NS","severityNumber":9,"severityText":"INFO","body":{"stringValue":"collector redaction control $CONTROL_ID"},"attributes":[{"key":"test_id","value":{"stringValue":"$CONTROL_ID"}},{"key":"http.request.header.authorization","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.cookie","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.header.x-password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.request.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"http.response.body","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"token","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"password","value":{"stringValue":"$COLLECTOR_CANARY"}},{"key":"body","value":{"stringValue":"$COLLECTOR_CANARY"}}]}]}]}]}
JSON
sleep 5   # allow batch flush + one scrape/query interval

section "Tempo (traces)"
# Tempo vParquet search index has a short visibility window after trace ingest;
# poll (up to ~30s) instead of a single shot so a slow flush is not a false FAIL.
T_TOTAL=0
i=0
while [ "${T_TOTAL:-0}" -lt 1 ] && [ "$i" -lt 10 ]; do
  T_TOTAL="$(tq_search service.name%3Dopenscope-sample 20 | python3 -c 'import sys,json;d=json.load(sys.stdin);print(len(d.get("traces",[])))' 2>/dev/null || echo 0)"
  if [ "${T_TOTAL:-0}" -lt 1 ]; then i=$((i+1)); sleep 3; fi
done
if [ "${T_TOTAL:-0}" -ge 1 ]; then
  pass "traces found in Tempo (n=$T_TOTAL)"
  # Iterate over ALL recent traces: the first search hit is often a 200 trace,
  # while AC-D3 requires the 500/failure trace to carry error evidence.
  T_JSON="$(tq_search service.name%3Dopenscope-sample 20)"
  TID="$(printf '%s' "$T_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);ts=sorted(d.get("traces",[]),key=lambda t:int(t.get("startTimeUnixNano",0)));print(ts[-1]["traceID"] if ts else "")' 2>/dev/null || true)"
  if [ -n "${TID:-}" ]; then
    pass "fetched traceID=$TID"
    # resource attributes on the first batch (Tempo returns list of {key,value})
    ATTRS="$(tq_trace "$TID" | python3 -c '
import sys,json
d=json.load(sys.stdin)
attrs={}
def collect_list(al):
    for a in al or []:
        k=a.get("key"); v=a.get("value") or {}
        val=v.get("stringValue") if v.get("stringValue") is not None else (v.get("intValue") if v.get("intValue") is not None else "")
        if k: attrs[k]=str(val)
for b in d.get("batches") or []:
    collect_list(b.get("resource",{}).get("attributes"))
# aggregate span-level failure evidence across ALL traces returned by search
err_code=0; has_500=0
for b in d.get("batches") or []:
    for ss in b.get("scopeSpans") or []:
        for s in ss.get("spans") or []:
            for a in s.get("attributes") or []:
                k=a.get("key"); v=a.get("value") or {}
                if k=="http.response.status_code" and str(v.get("intValue","")).startswith("5"): has_500=1
            if s.get("status",{}).get("code")==2: err_code=1
attrs["span.http.response.status_code"]=str(has_500)
attrs["span.status.error"]=str(err_code)
print(json.dumps(attrs))' 2>/dev/null || echo '{}')"
    for key in site.id project.id deployment.environment.name service.namespace service.name service.instance.id service.version; do
      echo "$ATTRS" | grep -q "\"$key\"" && pass "trace resource attr $key" || fail "trace resource attr $key missing"
    done
    # failure evidence: the first search hit is often a 200/204 trace, so collect
    # error/500 evidence across ALL traces returned by the search: fetch each
    # trace and look for any span with status.code==2 or http.response.status_code==500.
    FAILED=0
    for tid in $(printf '%s' "$T_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(" ".join(t.get("traceID","") for t in d.get("traces",[])))' 2>/dev/null); do
      [ -z "$tid" ] && continue
      HIT="$(tq_trace "$tid" | python3 -c '
import sys,json
d=json.load(sys.stdin)
err=0
for b in d.get("batches") or []:
    for ss in b.get("scopeSpans") or []:
        for s in ss.get("spans") or []:
            if s.get("status",{}).get("code")==2: err=1
            for a in s.get("attributes") or []:
                v=a.get("value") or {}
                if a.get("key")=="http.response.status_code" and str(v.get("intValue","")).startswith("5"): err=1
print(err)' 2>/dev/null || echo 0)"
      if [ "$HIT" = "1" ]; then FAILED=1; break; fi
    done
    [ "$FAILED" -ge 1 ] && pass "failure span evidence present (500/ERROR across traces)" || fail "no ERROR/500 evidence in trace (check span statuses)"
  else
    fail "could not extract traceID from Tempo search"
  fi
else
  fail "no traces in Tempo (AC-D2/D3)"
fi

section "Prometheus (metrics)"
P_INFO_QUERY='target_info{project_id="openscope-v01"}'
P_INFO="{}"
i=0
while [ "$P_INFO" = "{}" ] && [ "$i" -lt 10 ]; do
  P_INFO="$(pq "$P_INFO_QUERY" | python3 -c '
import sys,json
d=json.load(sys.stdin)
rows=d.get("data",{}).get("result",[])
# OpenTelemetry->Prometheus keeps service identity in the job label
found=[m.get("metric",{}) for m in rows if "openscope-sample" in m.get("metric",{}).get("job","")]
print(json.dumps(found[0] if found else {}))' 2>/dev/null || echo '{}')"
  if [ "$P_INFO" = "{}" ]; then i=$((i+1)); sleep 3; fi
done
if [ "$P_INFO" != "{}" ]; then
  pass "target_info present for openscope-sample"
  # OTLP->Prometheus normalization: service.name/namespace -> job label,
  # service.instance.id -> instance. Assert the ACTUAL normalized labels.
  for key in site_id project_id deployment_environment_name service_version job instance; do
    echo "$P_INFO" | grep -q "\"$key\"" && pass "prom label $key" || fail "prom label $key missing"
  done
  echo "$P_INFO" | grep -q "openscope-sample" && pass "job carries service identity openscope-sample" || fail "job identity mismatch"
else
  fail "target_info missing for openscope-sample (AC-D4/D5)"
fi
P_RATE=0
i=0
while [ "${P_RATE:-0}" -lt 1 ] && [ "$i" -lt 10 ]; do
  P_RATE="$(pq 'count(http_server_request_duration_seconds_count{job=~".*openscope-sample.*"})' | python3 -c '
import sys,json
d=json.load(sys.stdin); r=d.get("data",{}).get("result",[]); print(len(r))' 2>/dev/null || echo 0)"
  if [ "${P_RATE:-0}" -lt 1 ]; then i=$((i+1)); sleep 3; fi
done
[ "${P_RATE:-0}" -ge 1 ] && pass "http_server_request_duration_seconds_count series found" || fail "HTTP request metric series missing (AC-D4)"

# Execute the same six-dimensional filters used by the provisioned Dashboard.
# target_info alone is not sufficient proof because resource labels must exist
# on the actual HTTP metric series for these expressions to work.
RED_SELECTOR='site_id="dev-host",deployment_environment_name="acceptance",project_id="openscope-v01",service_namespace="openscope-demo",service_name="openscope-sample",service_instance_id=~".+"'
RED_RATE_Q="sum(rate(http_server_request_duration_seconds_count{$RED_SELECTOR}[5m]))"
RED_ERROR_Q="sum(rate(http_server_request_duration_seconds_count{$RED_SELECTOR,http_response_status_code=~\"5..\"}[5m]))"
RED_P95_Q="histogram_quantile(0.95, sum(rate(http_server_request_duration_seconds_bucket{$RED_SELECTOR}[5m])) by (le))"
for spec in "rate|$RED_RATE_Q" "error|$RED_ERROR_Q" "p95|$RED_P95_Q"; do
  kind="${spec%%|*}"; query="${spec#*|}"; result_count=0
  for _ in $(seq 1 12); do
    result_count="$(pq "$query" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(len(d.get("data",{}).get("result",[])))' 2>/dev/null || echo 0)"
    [ "${result_count:-0}" -ge 1 ] && break
    sleep 5
  done
  [ "${result_count:-0}" -ge 1 ] && pass "Dashboard RED $kind query returns filtered data" || fail "Dashboard RED $kind query returned no filtered data"
done

section "Loki (logs)"
L_LOGS="$(lq '{service_name="openscope-sample"}' | python3 -c '
import sys,json
d=json.load(sys.stdin)
s=d.get("data",{}).get("result",[])
lines=sum(len(x.get("values",[])) for x in s)
md={}
for x in s:
    for v in x.get("values",[]):
        vals=v[1] if isinstance(v,list) else v
        try:
            ob=json.loads(vals)
            if isinstance(ob,dict) and ob.get("trace_id"): md["trace_id"]=ob["trace_id"]
        except Exception: pass
print(json.dumps({"lines":lines,"trace_id":md.get("trace_id","")}))' 2>/dev/null || echo '{"lines":0,"trace_id":""}')"
L_LINES="$(echo "$L_LOGS" | python3 -c 'import sys,json;print(json.load(sys.stdin)["lines"])' 2>/dev/null || echo 0)"
L_TID="$(echo "$L_LOGS" | python3 -c 'import sys,json;print(json.load(sys.stdin)["trace_id"])' 2>/dev/null || echo "")"
if [ "${L_LINES:-0}" -ge 1 ]; then
  pass "log lines found in Loki (n=$L_LINES)"
else
  fail "no logs in Loki (AC-D6)"
fi
# correlation: structured-metadata pipeline filter matching the Tempo trace.
# NOTE: trace_id is structured metadata (non-indexed) on this Loki 3.x stack —
# selector matching ({...trace_id=...}) returns 0; pipeline filter (| trace_id=)
# matches. See local acceptance notes 2026-08-28.
# Search order is not guaranteed to return the traced request first, so iterate
# until we find a trace that actually has matching logs in Loki.
CORR_OK=0
if [ -n "${TID:-}" ]; then
  for cand in $(printf '%s' "$T_JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(" ".join(t.get("traceID","") for t in d.get("traces",[])))' 2>/dev/null); do
    [ -z "$cand" ] && continue
    C_N="$(lq "{service_name=\"openscope-sample\"} | trace_id=\"$cand\"" | python3 -c '
import sys,json
d=json.load(sys.stdin)
s=d.get("data",{}).get("result",[])
print(sum(len(x.get("values",[])) for x in s))' 2>/dev/null || echo 0)"
    if [ "${C_N:-0}" -ge 1 ]; then
      pass "log trace_id matches Tempo traceID (AC-D7/AC-08, trace=$cand streams=$C_N)"
      CORR_OK=1
      break
    fi
  done
  [ "$CORR_OK" -eq 1 ] || fail "trace correlation mismatch: no recent Tempo trace has matching Loki logs (last tried=$TID)"
else
  fail "trace correlation skipped: no TID"
fi

section "Grafana provisioning and datasource health (AC-F1..F4)"
for uid in openscope-prometheus openscope-tempo openscope-loki; do
  DS_HEALTH=""
  for _ in $(seq 1 12); do
    DS_HEALTH="$(gcurl "/api/datasources/uid/$uid/health" 2>/dev/null || true)"
    printf '%s' "$DS_HEALTH" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(OK|ok|success)"' && break
    sleep 5
  done
  printf '%s' "$DS_HEALTH" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(OK|ok|success)"' \
    && pass "datasource $uid health OK" \
    || fail "datasource $uid health failed"
done
GRAFANA_DASHBOARD="$(gcurl '/api/dashboards/uid/openscope-overview' 2>/dev/null || true)"
contains "$GRAFANA_DASHBOARD" 'openscope-overview' \
  && pass "Grafana Dashboard openscope-overview provisioned" \
  || fail "Grafana Dashboard openscope-overview missing"

section "redaction (AC-E1..E3)"
echo "  synthetic canary fingerprint: $(printf '%s' "$CANARY" | python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')"

# E1: application-side non-capture. Fetch full trace bodies, not only Tempo
# search summaries, so captured headers or response bodies cannot hide.
APP_TRACE_FULL=""
for tid in $(printf '%s' "${T_JSON:-{}}" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(" ".join(t.get("traceID","") for t in d.get("traces",[])))' 2>/dev/null); do
  [ -z "$tid" ] || APP_TRACE_FULL+="$(tq_trace "$tid" || true)"
done
APP_LOG_FULL="$(lq '{service_name="openscope-sample"}' || true)"
APP_METRIC_FULL="$(pq 'target_info{job=~".*openscope-sample.*"}' || true)$(pq '{__name__=~"http_.*",job=~".*openscope-sample.*"}' || true)"
E1_LEAK_SIGNALS=""
contains "$APP_TRACE_FULL" "$CANARY" && E1_LEAK_SIGNALS="trace"
contains "$APP_LOG_FULL" "$CANARY" && E1_LEAK_SIGNALS="${E1_LEAK_SIGNALS:+$E1_LEAK_SIGNALS,}log"
contains "$APP_METRIC_FULL" "$CANARY" && E1_LEAK_SIGNALS="${E1_LEAK_SIGNALS:+$E1_LEAK_SIGNALS,}metric"
if printf '%s' "$E1_LEAK_SIGNALS" | grep -q 'log'; then
  printf '%s' "$APP_LOG_FULL" | CANARY="$CANARY" python3 -c '
import json,os,sys
c=os.environ["CANARY"]
d=json.load(sys.stdin)
found=set()
for item in d.get("data",{}).get("result",[]):
    for key,value in item.get("stream",{}).items():
        if c in str(key): found.add("log.stream-key")
        if c in str(value): found.add("log.stream."+str(key))
    for pair in item.get("values",[]):
        if len(pair)>1 and c in str(pair[1]): found.add("log.body")
for location in sorted(found): print("  E1 sanitized locator: "+location)
' 2>/dev/null || echo "  E1 sanitized locator unavailable"
fi
[ -z "$E1_LEAK_SIGNALS" ] \
  && pass "E1 application path did not capture Authorization/Cookie/token/password/body canary" \
  || fail "E1 application path leaked header/body canary in signal(s): $E1_LEAK_SIGNALS"

# E2/E3: Collector-side deletion uses signal-specific positive controls. Each
# control must be stored before absence of the sensitive value can pass.
PROBE_T_SEARCH="{}"
for _ in $(seq 1 12); do
  PROBE_T_SEARCH="$(tq_search service.name%3Dopenscope-redaction-probe 20 || true)"
  contains "$PROBE_T_SEARCH" "$PROBE_TRACE_ID" && break
  sleep 5
done
PROBE_T_FULL="$(tq_trace "$PROBE_TRACE_ID" || true)"
contains "$PROBE_T_FULL" "$CONTROL_ID" && pass "E2 trace control stored" || fail "E2 trace control missing"
contains "$PROBE_T_FULL" "$COLLECTOR_CANARY" && fail "E2 trace sensitive attributes leaked" || pass "E2 trace sensitive attributes deleted"

PROBE_P="{}"
for _ in $(seq 1 12); do
  PROBE_P="$(pq "openscope_redaction_probe{test_id=\"$CONTROL_ID\"}" || true)"
  contains "$PROBE_P" "$CONTROL_ID" && break
  sleep 5
done
contains "$PROBE_P" "$CONTROL_ID" && pass "E2 metric control stored" || fail "E2 metric control missing"
contains "$PROBE_P" "$COLLECTOR_CANARY" && fail "E2 metric sensitive attributes leaked" || pass "E2 metric sensitive attributes deleted"

PROBE_L="{}"
for _ in $(seq 1 12); do
  PROBE_L="$(lq '{service_name="openscope-redaction-probe"}' || true)"
  contains "$PROBE_L" "$CONTROL_ID" && break
  sleep 5
done
contains "$PROBE_L" "$CONTROL_ID" && pass "E2 log control stored" || fail "E2 log control missing"
contains "$PROBE_L" "$COLLECTOR_CANARY" && fail "E2 log sensitive attributes leaked" || pass "E2 log sensitive attributes deleted"

section "summary"
echo "  checks=$CHECKS passed=$PASS failed=$FAIL"
[ "$KEEP" = "true" ] || cleanup
if [ "$FAIL" -eq 0 ]; then echo "VERIFY-V0.1 PASSED"; exit 0; else echo "VERIFY-V0.1 FAILED ($FAIL failed)"; exit 1; fi
