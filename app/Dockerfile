FROM python:3.12-slim

RUN pip install --no-cache-dir prometheus-client==0.21.0 \
 && useradd --create-home --uid 10001 app

WORKDIR /srv
COPY app.py .

USER 10001
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"

CMD ["python", "app.py"]
