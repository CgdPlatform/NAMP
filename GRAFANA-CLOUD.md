# Export to Grafana Cloud

Grafana Cloud is a fully managed observability platform that includes:

- **Grafana** — unified UI
- **Tempo** — distributed traces
- **Prometheus / Mimir** — metrics (Prometheus-compatible)
- **Pyroscope** — continuous profiling (flame graphs) ← included, nothing to host yourself

The app sends **directly** to Grafana Cloud over OTLP — no local OTel Collector
container is needed. Only the native Pyroscope profiler still has to be installed
locally for flame graphs.

---

## Architecture

```text
Blazor app
  │
  ├─ OTLP traces  ───→ OTLP Gateway (otlp-gateway-prod-<zone>.grafana.net)  ──→ Tempo
  ├─ OTLP metrics ───→ Prometheus   (prometheus-prod-<N>-prod-<zone>.grafana.net)
  │
  └─ Pyroscope SDK ──→ Grafana Cloud Pyroscope (profiles-prod-<N>.grafana.net)
```

**Important:** Grafana Cloud exposes two kinds of endpoints for traces:

- **OTLP Gateway** (recommended for HTTP) — a unified endpoint with its own instance ID
- **Direct Tempo** (gRPC only, through Alloy) — a separate Tempo instance ID

For metrics, the direct Prometheus endpoint works over HTTP OTLP.

---

## 1. Create a Grafana Cloud account

1. Go to [grafana.com](https://grafana.com) → **Create free account**
2. Create a stack (e.g. `my-app`) — a `my-app.grafana.net` URL is provisioned
3. In **My Account**, click the stack to see the details of each backend

---

## 2. Get the endpoints and instance IDs

Grafana Cloud console → **My Account** → your stack → click each service:

| Signal | Where to find it in the console | Instance ID | OTLP HTTP endpoint |
| --- | --- | --- | --- |
| **Traces** (Tempo) | Stack → Tempo → **"OTLP Endpoint"** section | The `Instance ID` shown in that section | `https://otlp-gateway-prod-<zone>.grafana.net/otlp/v1/traces` |
| **Metrics** (Prometheus) | Stack → Prometheus | `prometheusId` | `https://prometheus-prod-<N>-prod-<zone>.grafana.net/otlp/v1/metrics` |
| **Profiles** (Pyroscope) | Stack → Pyroscope | `pyroscopeId` | `https://profiles-prod-<N>.grafana.net` (push URL) |

> **⚠️ Traces — use the OTLP Gateway, not the direct Tempo URL.**
>
> Grafana Cloud shows two URLs for Tempo:
>
> - `tempo-prod-<N>-prod-<zone>.grafana.net` — gRPC connection through Alloy only, **does not work** with HTTP OTLP
> - `otlp-gateway-prod-<zone>.grafana.net/otlp` — HTTP OTLP gateway, **the one to use** with the .NET SDK
>
> The instance ID to use is the one shown in the **"OTLP Endpoint"** section (not the Tempo gRPC ID).
> In `.env`, append `/v1/traces` to the URL because the .NET SDK does not add the path automatically.
>
> Example: instance ID `1639312`, endpoint `https://otlp-gateway-prod-eu-west-2.grafana.net/otlp/v1/traces`.

---

## 3. Create an API token

1. **My Account** → **Access Policies** → **Create access policy**
2. Name: `namp-push`
3. Scopes to tick:
   - ✅ `metrics:write`
   - ✅ `traces:write`
   - ✅ `profiles:write`
4. **Create**, then **Add token** → copy the token (shown only once)

> One token is enough for every backend. Each backend uses its own
> instance ID as the `username` in the Basic Auth header.

---

## 4. Configure `appsettings.Production.json`

The app reads the endpoints and headers from the ASP.NET Core configuration.

Create (or update) `NetAmpowering.Demo.Blazor/appsettings.Production.json`:

```json
{
  "OpenTelemetry": {
    "ApplicationName": "demo-blazor",
    "OtlpEndpoint": "https://otlp-gateway-prod-eu-west-2.grafana.net/otlp/v1/traces",
    "OtlpHeaders": "Authorization=Basic <base64(gatewayInstanceId:token)>",
    "OtlpMetricsEndpoint": "https://prometheus-prod-<N>-prod-eu-west-2.grafana.net/otlp/v1/metrics",
    "OtlpMetricsHeaders": "Authorization=Basic <base64(prometheusId:token)>",
    "Enabled": true,
    "SamplingProbability": 0.1
  }
}
```

To generate the Base64 values of the headers:

```powershell
# Traces — OTLP Gateway (instance ID shown in Tempo > "OTLP Endpoint")
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("1639312:glc_eyJ..."))

# Prometheus (metrics)
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("3202848:glc_eyJ..."))
```

```bash
# macOS / Linux — Traces (OTLP Gateway)
echo -n "1639312:glc_eyJ..." | base64

# Prometheus
echo -n "3202848:glc_eyJ..." | base64
```

> Do not commit `appsettings.Production.json` if the tokens are in clear text.
> Prefer **environment variables** in production:
>
> ```bash
> export OpenTelemetry__OtlpHeaders="Authorization=Basic <base64_tempo>"
> export OpenTelemetry__OtlpMetricsHeaders="Authorization=Basic <base64_prometheus>"
> ```
>
> ASP.NET Core automatically merges environment variables into the configuration.

---

## 5. Run the app

### Recommended — automated scripts

The scripts handle the credentials and start the app in a single command:

```powershell
# Windows — traces + metrics + CPU profiling (dotnet-trace → pprof → Pyroscope)
.\observability\run-with-profiling-windows.ps1
```

```bash
# macOS — traces + metrics + CPU profiling (dotnet-trace → pprof → Pyroscope)
./observability/run-with-profiling-macos.sh
```

Both scripts do the same thing: on Ctrl+C the `.nettrace` is converted to pprof
and pushed to Grafana Cloud Pyroscope. If `dotnet-trace` is not installed, the app
runs normally with traces + metrics only.

It reads the credentials from `observability/.env` (already in `.gitignore`):

```ini
GRAFANA_API_TOKEN=glc_eyJ...

# Traces — OTLP Gateway (Stack > Tempo > "OTLP Endpoint" section)
# DO NOT use tempo-prod-<N>-... (gRPC only, not HTTP OTLP)
GRAFANA_TEMPO_INSTANCE_ID=1639312
GRAFANA_TEMPO_OTLP_ENDPOINT=https://otlp-gateway-prod-eu-west-2.grafana.net/otlp/v1/traces

# Metrics (Stack > Prometheus)
GRAFANA_PROMETHEUS_INSTANCE_ID=3202848
GRAFANA_PROMETHEUS_OTLP_ENDPOINT=https://prometheus-prod-65-prod-eu-west-2.grafana.net/otlp/v1/metrics

# CPU profiles (Stack > Pyroscope)
GRAFANA_PYROSCOPE_INSTANCE_ID=1639312
GRAFANA_PYROSCOPE_URL=https://profiles-prod-002.grafana.net
```

### Without profiling (traces + metrics only)

```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj \
  --launch-profile Production
```

### With Pyroscope profiling (flame graphs) — Linux only

> The native Pyroscope profiler only supports Linux. On **macOS and Windows**,
> `dotnet-trace` (EventPipe) captures the CPU profiles and pushes them as pprof
> to Grafana Cloud Pyroscope — the result in Grafana is identical.

#### Linux

```bash
export PYROSCOPE_SERVER_ADDRESS=https://profiles-prod-006.grafana.net
export PYROSCOPE_BASIC_AUTH_USER=3456789          # Pyroscope instance ID
export PYROSCOPE_BASIC_AUTH_PASSWORD=glc_eyJ...   # API token
export CORECLR_ENABLE_PROFILING=1
export CORECLR_PROFILER={BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}
export CORECLR_PROFILER_PATH=./observability/profiler/Pyroscope.Profiler.Native.so
export Pyroscope__Enable=true

dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

---

## 6. Open Grafana Cloud

Open `https://my-app.grafana.net`.

The **Tempo**, **Prometheus** and **Pyroscope** datasources are
provisioned automatically.

### Traces

**Explore** → **Tempo** datasource → Search → `service.name = demo-blazor`

### Metrics

**Explore** → **Prometheus** datasource → `rate(traces_spanmetrics_calls_total[1m])`

### Flame graphs

**Explore** → **Grafana Pyroscope** datasource → Service: `demo-blazor`

---

## Comparison of the modes

| Aspect | Local (Docker) | Scaleway Cockpit | Grafana Cloud |
| --- | --- | --- | --- |
| Compose file | `docker-compose.yml` | `docker-compose-scaleway.yml` | — (none) |
| Grafana | Local `:3000` | Scaleway (managed) | Grafana Cloud (managed) |
| Tempo | Local `:3200` | Scaleway (managed) | Grafana Cloud (managed) |
| Metrics | Prometheus `:9090` | Scaleway Mimir (managed) | Grafana Cloud Prometheus (managed) |
| Pyroscope | Local `:4040` | Local `:4040` | **Grafana Cloud (managed)** |
| OTel Collector | **None** | **None** (Direct Push) / local (collector mode) | **None** |
| Local containers | 4 | 1 | **0** |
| Usage | Dev | Staging / Prod | Staging / Prod |

---

## Troubleshooting

| Error | Likely cause | Fix |
| --- | --- | --- |
| `401 Unauthorized` traces | Invalid Tempo instance ID or token | Check `OtlpHeaders` — Base64 of `tempoId:token` |
| `401 Unauthorized` metrics | Invalid Prometheus instance ID or token | Check `OtlpMetricsHeaders` — Base64 of `prometheusId:token` |
| `401 Unauthorized` profiles | Invalid Pyroscope instance ID | Check that `PYROSCOPE_BASIC_AUTH_USER` = Pyroscope instance ID |
| `403 Forbidden` | Insufficient scopes | Check `traces:write`, `metrics:write`, `profiles:write` |
| Traces not visible | Wrong `OtlpEndpoint` | Copy the exact URL from **My Account → Stack → Tempo** |
| Metrics not visible | `OtlpMetricsEndpoint` or `OtlpMetricsHeaders` missing | Add both keys with the Prometheus ID |
| No flame graphs | `CORECLR_*` variables missing | Use the script or set the variables manually |
