# Observability stack — Docker Compose

An alternative to installing the binaries by hand. Starts Grafana, Tempo,
Prometheus and Pyroscope with a single command. There is no OTel Collector: applications
send traces straight to Tempo and metrics straight to Prometheus.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

---

## Getting started

```bash
cd observability
docker compose up -d
```

The `-d` option runs the containers in the background.

On first launch Docker downloads the images (~500 MB in total). Later starts are
instant.

### Check that everything is running

```bash
docker compose ps
```

You should see 4 containers with the `running` status:

```
NAME                   STATUS
namp-grafana         running
namp-tempo           running
namp-prometheus      running
namp-pyroscope       running
```

### Open the interfaces

| Service        | URL                           |
|----------------|-------------------------------|
| Grafana        | http://localhost:3000         |
| Prometheus     | http://localhost:9090         |
| Tempo (API)    | http://localhost:3200         |
| Pyroscope      | http://localhost:4040         |
| Tempo (OTLP)   | HTTP :4318 / gRPC :4317       |

Grafana opens without a login — the Tempo, Prometheus and Pyroscope datasources are
provisioned automatically.

The Grafana image is **built locally** from `observability/docker/grafana.Dockerfile`: it compiles the
`grafana-plugin/` panel (Node 22, inside the build — nothing to install on your machine) and bundles it together
with the **NetAmpowering Coverage** dashboard. The first `docker compose up -d` therefore takes a few extra
minutes; after a change in `grafana-plugin/`, rebuild with `docker compose up -d --build grafana`.

---

## Run the Blazor app

No change is needed in `appsettings.json` — the app sends its traces straight to
Tempo (`http://localhost:4318/v1/traces`) and its metrics straight to
Prometheus (`http://localhost:9090/api/v1/otlp/v1/metrics`, through
`OpenTelemetry:OtlpMetricsEndpoint`).

```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

---

## Stopping

```bash
# Stop without removing anything
docker compose stop

# Stop and remove the containers (volume data is kept)
docker compose down

# Remove everything, including the data (stored traces and metrics)
docker compose down -v
```

---

## Viewing the logs

```bash
# All services
docker compose logs -f

# A single service
docker compose logs -f grafana
docker compose logs -f tempo
docker compose logs -f pyroscope
docker compose logs -f prometheus
```

---

## Updating the images

```bash
docker compose pull
docker compose up -d --build
```

---

## Configuration files

The Docker configs live in `observability/docker/` — separate from the configs
used by the manual installation (`start-observability.sh`).

| File | Purpose |
|---|---|
| `docker/tempo.yml` | Tempo config (container-internal paths, metrics-generator → Prometheus) |
| `docker/prometheus.yml` | Prometheus config (no scrape: Prometheus receives OTLP and remote write) |
| `docker/grafana.Dockerfile` | Grafana image: builds the `grafana-plugin/` panel and embeds the coverage dashboard |
| `docker/grafana-provisioning/` | Pre-configured Grafana datasources and dashboard provider |

The only difference from the local configs: every `localhost` is replaced by
the Docker service names (`tempo`, `prometheus`).

---

## Comparison with the manual installation

| | Docker Compose | Manual installation |
|---|---|---|
| Prerequisites | Docker Desktop | 4 binaries to download |
| Start | `docker compose up -d` | `./start-observability.sh` |
| Data | Docker volumes | `observability/data/` |
| Logs | `docker compose logs` | `observability/logs/` |
| Update | `docker compose pull` | Download the binaries again |
| macOS profiling | No (use the local script) | Yes (`run-with-profiling-macos.sh`) |
