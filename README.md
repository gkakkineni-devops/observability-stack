# observability-stack

A small monitoring setup I built to practice alerting the way I'd want it done on a real team. It runs on Docker Compose with one command, and CI checks every piece of it on each push.

This is a learning project. It is not code from my job, and the demo service only exists to give Prometheus something to watch.

## What's in it

| Piece | What it does |
|---|---|
| `app/` | A tiny Python service. `/work` answers after a random delay and fails some of the time. You can change the failure rate and latency while it runs. |
| Prometheus | Scrapes the app, node-exporter, itself and Alertmanager every 5 seconds. |
| Recording rules | Request rate, error ratio (5m and 1h) and p95 latency, worked out once so dashboards and alerts share the same numbers. |
| Alert rules | Instance down, fast error-budget burn, high error ratio, high p95 latency, and a disk that will fill in 4 hours. |
| Alertmanager | Groups alerts, sends them to a webhook, and mutes warnings when a critical alert is already firing for the same job. |
| Grafana | A "Service overview" dashboard, provisioned from files so nothing is set up by hand. |

## Run it

You need Docker with Compose.

```
make up
```

Then:

- Prometheus: http://127.0.0.1:9090
- Alertmanager: http://127.0.0.1:9093
- Grafana: http://127.0.0.1:3000 (admin / admin, local only)

To see an alert fire, make the app fail more:

```
curl -X POST "http://127.0.0.1:8000/config?error_rate=0.6"
```

After a couple of minutes `HighErrorRatio` fires, and the app logs the webhook it receives (`docker compose logs demo-app`). Set `error_rate=0` to resolve it.

`make down` removes everything.

## How the alerts are built

The error-budget alert is the one I'd explain first. It assumes a 99.9% target, so the budget is 0.001. `ErrorBudgetBurnFast` fires when errors are running at 14.4 times that budget over both the last 5 minutes and the last hour. Checking two windows keeps a short blip from paging anyone, and still catches a real outage quickly.

Every alert has a summary and a runbook note, so whoever gets paged knows where to start.

## How it's tested

The alert rules have unit tests in `prometheus/tests/alerts_test.yml`. They feed in fake time series and check which alerts fire and what they say. Run them with `make test`.

CI (`.github/workflows/ci.yml`) does this on every push:

1. `promtool check config` and `promtool test rules`
2. `amtool check-config`
3. Validates the Grafana dashboard JSON and the compose file
4. Lints the Dockerfile with hadolint and scans the repo with Trivy
5. Starts the whole stack, then `scripts/smoke.sh` checks that every target is up, the rules are loaded, the dashboard exists, and that raising the error rate really moves the error-ratio metric

## Limits

- Single node, no persistent storage, no auth beyond Grafana's default login. Ports are bound to localhost on purpose.
- The webhook receiver just prints alerts. In a real setup it would be Slack, PagerDuty or similar.
- Thresholds are tuned for the demo app, not for any real traffic.

## License

MIT
