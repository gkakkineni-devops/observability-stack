"""A tiny service that makes the monitoring stack interesting.

It serves /work with a random delay, and you can change how often it fails and
how slow it is with POST /config. Prometheus scrapes /metrics. Alertmanager
sends alerts to POST /alerts, which just prints them, so you can watch an
alert travel the whole path without any outside service.
"""
import json
import random
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

REQUESTS = Counter("http_requests_total", "Requests handled", ["method", "path", "status"])
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request duration in seconds",
    ["path"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)

state = {"error_rate": 0.0, "latency": 0.05}
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep the container logs for alerts only
        return

    def _send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/metrics":
            return self._send(200, generate_latest(), CONTENT_TYPE_LATEST)
        if path == "/healthz":
            return self._send(200, '{"status":"ok"}')
        if path == "/work":
            start = time.perf_counter()
            with lock:
                error_rate, latency = state["error_rate"], state["latency"]
            time.sleep(random.uniform(0, latency * 2))
            status = 500 if random.random() < error_rate else 200
            LATENCY.labels(path="/work").observe(time.perf_counter() - start)
            REQUESTS.labels(method="GET", path="/work", status=str(status)).inc()
            return self._send(status, json.dumps({"ok": status == 200}))
        REQUESTS.labels(method="GET", path="other", status="404").inc()
        return self._send(404, '{"error":"not found"}')

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        if parsed.path == "/config":
            query = parse_qs(parsed.query)
            with lock:
                if "error_rate" in query:
                    state["error_rate"] = min(max(float(query["error_rate"][0]), 0.0), 1.0)
                if "latency" in query:
                    state["latency"] = max(float(query["latency"][0]), 0.0)
                current = dict(state)
            return self._send(200, json.dumps(current))
        if parsed.path == "/alerts":
            payload = json.loads(body or b"{}")
            for alert in payload.get("alerts", []):
                labels = alert.get("labels", {})
                print(
                    f"ALERT {alert.get('status', '?').upper()}: {labels.get('alertname')} "
                    f"({labels.get('severity')}) - {alert.get('annotations', {}).get('summary', '')}",
                    flush=True,
                )
            return self._send(200, "{}")
        return self._send(404, '{"error":"not found"}')


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8000), Handler)
    print("demo-app listening on :8000", flush=True)
    server.serve_forever()
