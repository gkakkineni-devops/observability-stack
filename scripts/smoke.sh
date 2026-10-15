#!/usr/bin/env bash
# Starts nothing itself. Run it after `docker compose up -d --build`.
# It checks that every piece is up and that an error spike shows up in the metrics.
set -euo pipefail

PROM=${PROM:-http://127.0.0.1:9090}
GRAFANA=${GRAFANA:-http://127.0.0.1:3000}
APP=${APP:-http://127.0.0.1:8000}
AM=${AM:-http://127.0.0.1:9093}

say() { printf '\n== %s\n' "$*"; }
wait_for() { # name, command...
  local name=$1; shift
  for _ in $(seq 1 60); do
    if "$@" >/dev/null 2>&1; then echo "ok: $name"; return 0; fi
    sleep 2
  done
  echo "FAILED: $name did not become ready" >&2
  return 1
}

say "Waiting for the services"
wait_for "prometheus"   curl -fsS "$PROM/-/ready"
wait_for "alertmanager" curl -fsS "$AM/-/ready"
wait_for "grafana"      curl -fsS "$GRAFANA/api/health"
wait_for "demo-app"     curl -fsS "$APP/healthz"

say "Every scrape target is up"
wait_for "all targets healthy" \
  bash -c "curl -fsS $PROM/api/v1/targets | jq -e '[.data.activeTargets[].health] | length > 0 and all(. == \"up\")'"

say "Rules are loaded and healthy"
curl -fsS "$PROM/api/v1/rules" | jq -e '
  [.data.groups[].rules[]] | length >= 9 and all(.health == "ok")'

say "Grafana has the provisioned dashboard"
curl -fsS -u admin:admin "$GRAFANA/api/search?query=Service" | jq -e 'map(.title) | index("Service overview") != null'

say "Healthy traffic gives a low error ratio"
for _ in $(seq 1 100); do curl -s -o /dev/null "$APP/work"; done

say "Break the service on purpose: 60% errors"
curl -fsS -X POST "$APP/config?error_rate=0.6" | jq .
for _ in $(seq 1 300); do curl -s -o /dev/null "$APP/work"; done

say "The error ratio shows up in Prometheus"
wait_for "error ratio above 10%" \
  bash -c "curl -fsS --data-urlencode 'query=job:http_errors:ratio_rate5m{job=\"demo-app\"}' $PROM/api/v1/query | jq -e '.data.result[0].value[1] | tonumber > 0.1'"

say "The alert fires in Prometheus and reaches Alertmanager"
# Keep sending traffic, or the 5 minute rate goes flat and the alert clears.
( while true; do curl -s -o /dev/null "$APP/work"; sleep 0.1; done ) &
TRAFFIC=$!
trap 'kill $TRAFFIC 2>/dev/null || true' EXIT
fired=""
for _ in $(seq 1 150); do
  if curl -fsS "$PROM/api/v1/alerts" | jq -e '[.data.alerts[] | select(.labels.alertname=="HighErrorRatio" and .state=="firing")] | length > 0' >/dev/null; then
    fired=yes; break
  fi
  sleep 2
done
[ -n "$fired" ] || { echo "FAILED: HighErrorRatio never fired in Prometheus" >&2; exit 1; }
echo "ok: HighErrorRatio is firing in Prometheus"
wait_for "alert delivered to Alertmanager" \
  bash -c "curl -fsS $AM/api/v2/alerts | jq -e '[.[] | select(.labels.alertname==\"HighErrorRatio\")] | length > 0'"

say "Put it back"
kill $TRAFFIC 2>/dev/null || true
curl -fsS -X POST "$APP/config?error_rate=0" >/dev/null
echo
echo "Smoke test passed"
