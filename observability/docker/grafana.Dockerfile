# Grafana with the NetAmpowering coverage panel built in.
# Build context: ../grafana-plugin (see docker-compose.yml).

# ── Stage 1: build the panel plugin ──────────────────────────────────────────
FROM node:22-alpine AS plugin
WORKDIR /plugin
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
# The dashboard export uses a ${DS_PROMETHEUS} import placeholder, which file provisioning
# does not resolve: point it at the provisioned Prometheus datasource (uid "prometheus").
RUN mkdir /provisioned \
 && sed 's/\${DS_PROMETHEUS}/prometheus/g' dashboards/coverage.json > /provisioned/coverage.json

# ── Stage 2: Grafana + plugin + provisioned dashboard ────────────────────────
# (COPY only: the Grafana image runs as a non-root user, so no RUN steps here.)
FROM grafana/grafana:latest
COPY --from=plugin --chown=472:0 /plugin/dist /var/lib/grafana/plugins/netampowering-apm-panel
COPY --from=plugin --chown=472:0 /provisioned /var/lib/grafana/dashboards
