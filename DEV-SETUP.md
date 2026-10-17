# Local development environment

This guide explains how to start the observability stack and run the app
in debug mode on macOS, Linux and Windows.

---

## Step 1 — Start the observability stack

Two options depending on your platform.

### Option A — Docker Compose (recommended on every platform)

Works the same way on macOS, Linux and Windows.
Prerequisite: [Docker Desktop](https://www.docker.com/products/docker-desktop/) running.

```bash
cd observability
docker compose up -d
```

See [DOCKER.md](DOCKER.md) for details.

---

### Option B — Local scripts

Requires the binaries to be installed manually
(see the comments at the top of `start-observability.sh` / `start-observability.ps1`).

**macOS / Linux**
```bash
./observability/start-observability.sh
```

**Windows**
```powershell
.\observability\start-observability.ps1
```

---

## Step 2 — Run the app in debug mode

### macOS

**Terminal**
```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

**VS Code**
1. Open the `NetAmpowering.Demo.Blazor/` folder in VS Code
2. Install the **C# Dev Kit** extension if you have not already
3. `F5` → select the `Launch (Blazor Server)` profile

**JetBrains Rider**
1. Open `NetAmpowering.sln`
2. Select the `NetAmpowering.Demo.Blazor` project in the toolbar
3. `^D` (Ctrl+D) to start debugging

---

### Linux

**Terminal**
```bash
dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj
```

**VS Code**
```bash
code NetAmpowering.Demo.Blazor/
# Then F5 → Launch (Blazor Server) profile
```

**With Pyroscope profiling enabled** (flame graphs in Grafana)
```bash
./observability/run-with-profiling.sh
```
> Requires `Pyroscope.Profiler.Native.so` to be placed in `observability/profiler/`.
> See the instructions in the script.

---

### Windows

**PowerShell**
```powershell
dotnet run --project NetAmpowering.Demo.Blazor\NetAmpowering.Demo.Blazor.csproj
```

**Visual Studio 2022**
1. Open `NetAmpowering.sln`
2. Set `NetAmpowering.Demo.Blazor` as the startup project
3. `F5` to start debugging

**VS Code**
1. Open the `NetAmpowering.Demo.Blazor\` folder in VS Code
2. `F5` → `Launch (Blazor Server)` profile

**With Pyroscope profiling enabled**
```powershell
.\observability\run-with-profiling-windows.ps1
```
> If the execution policy blocks the script:
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

---

## Step 3 — Check that everything works

Once the app is running, open http://localhost:5000 and browse a few pages.

**Check the traces in Grafana**
1. Open http://localhost:3000
2. **Explore** → **Tempo** datasource
3. Query type → **Search** → Service Name: `demo-blazor`
4. The traces of the visited pages should appear

**Check the metrics**
1. **Explore** → **Prometheus** datasource
2. Type: `rate(traces_spanmetrics_calls_total[1m])`
3. The RED metrics (rate, errors, duration) should be present

**If something is wrong**

Check the logs of Tempo (traces) and Prometheus (OTLP metrics):

```bash
# Docker Compose
docker compose logs -f tempo prometheus

# Manual installation (macOS/Linux)
tail -f observability/logs/tempo.log observability/logs/prometheus.log
```

---

## CPU profiling (hot spots)

| Platform | Tool | Command |
|---|---|---|
| macOS | dotnet-trace → Speedscope | `./observability/run-with-profiling-macos.sh` |
| Linux | Pyroscope → Grafana | `./observability/run-with-profiling.sh` |
| Windows | Pyroscope → Grafana | `.\observability\run-with-profiling-windows.ps1` |

---

## URL summary

| Service | URL |
|---|---|
| Blazor app | http://localhost:5000 |
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Tempo | http://localhost:3200 |
| Tempo (OTLP HTTP, traces) | http://localhost:4318 |
| Prometheus (OTLP, metrics) | http://localhost:9090/api/v1/otlp/v1/metrics |
