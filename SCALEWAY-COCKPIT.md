# Export to Scaleway Cockpit

Scaleway Cockpit is a managed observability platform that includes:

- **Grafana** — unified UI (pre-configured, nothing to install)
- **Tempo** — distributed traces
- **Mimir** — metrics (Prometheus-compatible)
- **Loki** — logs (optional)

Two integration modes are possible:

| Mode | Local containers | When to use it |
| --- | --- | --- |
| **Direct Push** (recommended) | 1 (Pyroscope only) | Simple, no OTel Collector |
| **Via OTel Collector** | 2 (OTel Collector + Pyroscope) | Advanced pipeline, transformations |

> Pyroscope is **not** managed by Scaleway — it always stays local.

---

## Mode A — Direct Push (no OTel Collector)

The app pushes straight to Scaleway Cockpit over OTLP, with the token in a header.

### Architecture

```text
Blazor app
  │
  ├─ OTLP traces  ───→ Scaleway Tempo  (direct HTTPS, X-Token header)
  ├─ OTLP metrics ───→ Scaleway Mimir  (direct HTTPS, X-Token header)
  │
  └─ Pyroscope SDK ──→ Pyroscope (local :4040)
```

### 1. Create a Cockpit token

1. Scaleway console → **Cockpit** → **Tokens** → **Create a token**
2. Tick the permissions:
   - ✅ Push metrics
   - ✅ Push traces
3. Copy the token (shown only once)

### 2. Get the OTLP endpoints

Scaleway console → **Cockpit** → **Settings** → **Data sources**:

| Signal | OTLP endpoint |
| --- | --- |
| Traces | `https://traces.cockpit.fr-par.scw.cloud/otlp/v1/traces` |
| Metrics | `https://metrics.cockpit.fr-par.scw.cloud/otlp/v1/metrics` |

> Regions vary (`fr-par`, `nl-ams`, `pl-waw`).
> Use the URLs shown in your console.

### 3. Configure `appsettings.Production.json`

Create (or update) `NetAmpowering.Demo.Blazor/appsettings.Production.json`:

```json
{
  "OpenTelemetry": {
    "ApplicationName": "demo-blazor",
    "OtlpEndpoint": "https://traces.cockpit.fr-par.scw.cloud/otlp/v1/traces",
    "OtlpMetricsEndpoint": "https://metrics.cockpit.fr-par.scw.cloud/otlp/v1/metrics",
    "OtlpHeaders": "X-Token=<your_cockpit_token>",
    "Enabled": true,
    "SamplingProbability": 0.1
  }
}
```

> Do not commit `appsettings.Production.json` if the token is in clear text.
> Prefer **environment variables** in production:
>
> ```bash
> export OpenTelemetry__OtlpHeaders="X-Token=<your_cockpit_token>"
> ```
>
> ASP.NET Core automatically merges environment variables into the configuration.

### 4. Start Pyroscope (flame graphs only)

If you do not need flame graphs, skip this step.

```bash
docker compose -f observability/docker-compose-scaleway.yml up -d pyroscope
```

### 5. Run the app

#### Without profiling (traces + metrics only)

```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj \
  --launch-profile Production
```

#### With Pyroscope profiling (flame graphs)

##### macOS / Linux

```bash
export PYROSCOPE_SERVER_ADDRESS=http://localhost:4040
export CORECLR_ENABLE_PROFILING=1
export CORECLR_PROFILER={BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}
export CORECLR_PROFILER_PATH=./observability/profiler/Pyroscope.Profiler.Native.so

dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

##### Windows (PowerShell)

```powershell
$env:PYROSCOPE_SERVER_ADDRESS = "http://localhost:4040"
$env:CORECLR_ENABLE_PROFILING  = "1"
$env:CORECLR_PROFILER          = "{BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}"
$env:CORECLR_PROFILER_PATH     = ".\observability\profiler\Pyroscope.Profiler.Native.dll"

dotnet run --project NetAmpowering.Demo.Blazor\NetAmpowering.Demo.Blazor.csproj
```

---

## Mode B — Via OTel Collector

Keeps a local OTel Collector for advanced pipelines (filtering, enrichment,
fan-out to several backends, Prometheus Remote Write conversion).

### Architecture (Mode B)

```text
Blazor app
  │
  ├─ OTLP traces + metrics ──→ OTel Collector (local :4317/4318)
  │                                  │
  │                                  ├─ traces  ──→ Scaleway Tempo
  │                                  └─ metrics ──→ Scaleway Mimir
  │
  └─ Pyroscope SDK ──→ Pyroscope (local :4040)
```

### 1. Create the `.env` file

Create `observability/.env` (already in `.gitignore`):

```bash
SCALEWAY_COCKPIT_TOKEN=your_token_here
SCALEWAY_TRACES_ENDPOINT=https://traces.cockpit.fr-par.scw.cloud
SCALEWAY_METRICS_ENDPOINT=https://metrics.cockpit.fr-par.scw.cloud/api/v1/push
```

### 2. Start the stack

```bash
cd observability
docker compose -f docker-compose-scaleway.yml up -d
```

| Container | Purpose | Port |
| --- | --- | --- |
| `namp-otelcollector` | Collects and pushes to Scaleway | 4317 / 4318 |
| `namp-pyroscope` | Continuous profiling (flame graphs) | 4040 |

### 3. Check the logs

```bash
docker compose -f docker-compose-scaleway.yml logs -f otelcollector
```

These lines confirm that the data reaches Scaleway:

```text
Exporting items  {"kind": "exporter", "data_type": "traces", "name": "otlp/scaleway"}
Exporting items  {"kind": "exporter", "data_type": "metrics", "name": "prometheusremotewrite/scaleway"}
```

### 4. Run the Blazor app

No change is needed in `appsettings.json` — the app sends to `http://localhost:4318`
(the port exposed by the OTel Collector container).

```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

### 5. Stopping

```bash
# Stop without removing the data
docker compose -f docker-compose-scaleway.yml stop

# Stop and remove the containers
docker compose -f docker-compose-scaleway.yml down

# Remove everything, including the Pyroscope data
docker compose -f docker-compose-scaleway.yml down -v
```

---

## Open the Scaleway Grafana

Scaleway console → **Cockpit** → **Open Grafana**.

The **Tempo** and **Mimir** datasources are provisioned automatically.

### Traces

**Explore** → **Tempo** datasource → Search → `service.name = demo-blazor`

### Metrics

**Explore** → **Prometheus** datasource → for example `rate(span_metrics_calls_total[1m])`
(available in Mode B, where the collector's `spanmetrics` connector generates the RED metrics).

### Add Pyroscope as a datasource

The Scaleway Grafana runs in the cloud — it cannot reach `localhost`.

1. Scaleway console → **Cockpit** → **Open Grafana**
2. Left menu → **Connections** → **Data sources** → **Add new data source**
3. Search for **Grafana Pyroscope** and click it
4. Enter the URL for your environment:

| Environment | Pyroscope URL |
| --- | --- |
| **Local dev** | ngrok tunnel `https://abc123.ngrok-free.app` |
| **Production** | `http://your-public-ip:4040` or a subdomain |

#### Local dev — expose Pyroscope through ngrok

```bash
# Start Pyroscope
docker compose -f observability/docker-compose-scaleway.yml up -d pyroscope

# Open the tunnel
ngrok http 4040
```

ngrok prints a public URL (`https://abc123.ngrok-free.app`) to paste into the
Grafana datasource.

> The ngrok URL changes on every restart (free account). Update the
> datasource in Grafana for each new session.

---

## Comparison of the modes

| Aspect | Local (Docker) | Scaleway Direct Push | Scaleway + OTel Collector |
| --- | --- | --- | --- |
| Compose file | `docker-compose.yml` | — (none) | `docker-compose-scaleway.yml` |
| Grafana | Local `:3000` | Scaleway (managed) | Scaleway (managed) |
| Tempo | Local `:3200` | Scaleway (managed) | Scaleway (managed) |
| Metrics | Prometheus `:9090` | Scaleway Mimir | Scaleway Mimir |
| OTel Collector | **None** | **None** | Local |
| Pyroscope | Local `:4040` | Local `:4040` | Local `:4040` |
| Local containers | 4 | **1** | 2 |
| Usage | Dev | Staging / Prod | Staging / Prod (advanced) |

---

## Troubleshooting

| Error | Likely cause | Fix |
| --- | --- | --- |
| `401 Unauthorized` | Invalid token | Check the token in the config / `.env` |
| `403 Forbidden` | Insufficient scopes | Check `Push traces` and `Push metrics` on the token |
| Traces not visible | Wrong `OtlpEndpoint` | Copy the exact URL from the Scaleway console |
| Metrics missing | `OtlpMetricsEndpoint` absent | Add the key to `appsettings.Production.json` |
| No flame graphs | `localhost` unreachable from Grafana | Use ngrok or a public IP for the datasource |
