# Changelog

Newest first. Dates are when the change landed on main.

## 2026-11

- Nov 20: Renamed a smoke test step that claimed to check a low error ratio but only sends healthy traffic.
- Nov 19: The smoke test now expects at least 10 loaded rules (6 alerts and 4 recording rules), so a rule that stops loading gets caught.

- Nov 16: README got an "If something doesn't work" section.
- Nov 16: The smoke test now always resets the demo app's error rate and stops its traffic loop, even when a check fails.
- Nov 13: README got a "What I'd do next" section.
- Nov 11: README got a "How it fits together" diagram.
- Nov 10: README got a CI status badge.
- Nov 8: Added the `HighMemoryUsage` alert (memory above 90% for 10 minutes) and a fifth rule test for it.
- Nov 7: Grafana dashboard got an "Alerts firing" stat panel next to "Targets up".
- Nov 6: node-exporter moved from v1.8.2 to v1.12.1.
- Nov 5: CI now uses actions/checkout v7.
- Nov 3: Alertmanager moved from v0.27.0 to v0.34.2.

## 2026-10

- Oct 31: Prometheus moved from v2.55.1 to v3.13.5 (the 3.13 LTS line).
- Oct 26: Dependabot now watches the base image and the workflow actions.
- Oct 15: The smoke test now waits for the alert to fire and reach Alertmanager.
- Oct 15: First version: Prometheus, Alertmanager, Grafana, a small demo app, alert rules with promtool tests, and CI.
