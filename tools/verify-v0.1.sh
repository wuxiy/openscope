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
SAMPLE_PID=""
CANARY="V0-1-CANARY-$(date +%s)-$$"
PASS=0; FAIL=0; CHECKS=0
PROJ="openscope-v01"

# Backends are NOT published to the host (AC-C4). Query through a disposable
# curl container attached to the compose network (backend images are slim and
# lack /bin/sh + wget, so docker exec is unreliable for loki/tempo).
QUERY_IMAGE="${QUERY_IMAGE:-curlimages/curl:8.10.1}"
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

pass() { PASS=$((PASS+1)); CHECKS=$((CHECKS+1)); echo "  PASS $*"; }
fail() { FAIL=$((FAIL+1)); CHECKS=$((CHECKS+1)); echo "  FAIL $*"; }
section() { echo; echo "=== $* ==="; }

cleanup() {
  [ -n "$SAMPLE_PID" ] && kill "$SAMPLE_PID" 2>/dev/null || true
  wait "$SAMPLE_PID" 2>/dev/null || true
  SAMPLE_PID=""
}

trap cleanup EXIT

# --- preflight -------------------------------------------------------------------
section "preflight"
[ -f "$SAMPLE_JAR" ] || { echo "  FAIL sample jar missing: $SAMPLE_JAR"; exit 1; }
command -v docker >/dev/null || { echo "  FAIL docker missing"; exit 1; }
docker ps --format '{{.Names}}' | grep -qE "^openscope-v01-(collector|prometheus|tempo|loki|grafana)$" || {
  echo "  FAIL stack not running (run: ./cli/openscope start)"; exit 1; }
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
    -Dotel.instrumentation.logback-appender.enabled=true \
    -jar "$SAMPLE_JAR" >/tmp/openscope-sample.log 2>&1 &
  SAMPLE_PID=$!
  for i in $(seq 1 30); do
    curl -sf -o /dev/null "http://127.0.0.1:$SAMPLE_PORT/ok" && break || sleep 1
  done
  curl -sf -o /dev/null "http://127.0.0.1:$SAMPLE_PORT/ok" && echo "  ok app up (pid $SAMPLE_PID)" || { fail "sample app did not become ready"; tail -5 /tmp/openscope-sample.log; exit 1; }
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
  "http://127.0.0.1:$SAMPLE_PORT/sensitive"
echo
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

section "redaction (AC-E1..E3)"
echo "  canary: $CANARY"
RED_GREP() { # api response -> count occurrences of canary (0 = good)
  local resp="$1"
  printf '%s' "$resp" | grep -c "$CANARY" || true
}
L_RED="$(lq '{service_name="openscope-sample"}' || true)"
[ "$(RED_GREP "$L_RED")" -eq 0 ] && pass "Loki: canary absent" || fail "Loki: canary LEAKED"
P_RED="$(pq target_info || true)$(pq '{__name__=~"http_.*"}' || true)"
[ "$(RED_GREP "$P_RED")" -eq 0 ] && pass "Prometheus: canary absent" || fail "Prometheus: canary LEAKED"
T_RED="$(tq_search service.name%3Dopenscope-sample 50 || true)"
[ "$(RED_GREP "$T_RED")" -eq 0 ] && pass "Tempo: canary absent" || fail "Tempo: canary LEAKED"

section "summary"
echo "  checks=$CHECKS passed=$PASS failed=$FAIL"
[ "$KEEP" = "true" ] || cleanup
if [ "$FAIL" -eq 0 ]; then echo "VERIFY-V0.1 PASSED"; exit 0; else echo "VERIFY-V0.1 FAILED ($FAIL failed)"; exit 1; fi