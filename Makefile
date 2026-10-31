.PHONY: up down test smoke logs

up:        ## start everything
	docker compose up -d --build

down:      ## stop and remove everything
	docker compose down -v

test:      ## unit-test the alert rules (needs the prom/prometheus image)
	docker run --rm -v "$$PWD/prometheus:/etc/prometheus:ro" --entrypoint promtool \
	  prom/prometheus:v3.13.5 test rules /etc/prometheus/tests/alerts_test.yml

smoke:     ## check the running stack end to end
	./scripts/smoke.sh

logs:
	docker compose logs -f --tail=50
