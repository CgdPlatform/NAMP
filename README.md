# NetAmpowering — zero-code APM for .NET

Turnkey observability for **.NET 8** (Blazor Server, WebAssembly, ASP.NET Core Web API) and **.NET Framework 4.7.2+** (WebForms, MVC 5, Web API 2). It automatically provides traces, metrics, CPU profiles and production code coverage without changing business code, as reusable NuGet packages.

## What is instrumented automatically

| Signal | What is traced |
| --- | --- |
| HTTP traces | Incoming ASP.NET Core / ASP.NET requests, outgoing `HttpClient` calls |
| SignalR circuits | Connection, disconnection and lifetime of Blazor Server circuits |
| Component lifecycle | `OnInitialized`, `OnParametersSet`, `OnAfterRender`, user events (clicks, inputs) |
| WebForms pages | One span per page and per lifecycle stage |
| MVC 5 / Web API 2 / ASP.NET Core actions | One span per controller action |
| SPA navigation | Every route change |
| Business services | Every method call (via Castle DynamicProxy AOP) |
| SQL | One span per command: EF Core, EF6, NHibernate (no parameter values captured) |
| Runtime metrics | GC, thread pool, JIT (.NET runtime metrics) |
| CPU profiles | Pyroscope flame graphs (Linux), dotnet-trace → pprof → Grafana Cloud (macOS / Windows) |
| Production code coverage | Which methods are called, and how often, exported to Prometheus |

## Architecture

```text
NetAmpowering.Observability.Core      (netstandard2.0 — shared core)
NetAmpowering.AspNetCore              (.NET 8 — Web API, minimal APIs)
NetAmpowering.Observability           (.NET 8 — Blazor Server)
NetAmpowering.Observability.WebAssembly
NetAmpowering.AspNet / .Mvc / .WebApi (.NET Framework 4.7.2+)
NetAmpowering.Observability.EntityFrameworkCore / .EntityFramework6 / .NHibernate
NetAmpowering.Coverage / .Core / .Runtime / .AspNet
Demos: NetAmpowering.Demo.Blazor, .WebApi, .WebForms, .Mvc5, .WebApi2
```

## Quick start

### 1. Local observability stack (Docker)

```powershell
cd observability
docker compose up -d
```

| Service | URL |
| --- | --- |
| Grafana | <http://localhost:3000> |
| Prometheus | <http://localhost:9090> |
| Tempo | <http://localhost:3200> |
| Tempo OTLP HTTP (traces) | <http://localhost:4318> |
| Pyroscope | <http://localhost:4040> |

### 2. Run the application

```powershell
dotnet run --project NetAmpowering.Demo.Blazor\NetAmpowering.Demo.Blazor.csproj
```

Open <http://localhost:5221>, browse a few pages, then check the traces in Grafana → Explore → Tempo.
The other demos (Web API, WebForms, MVC 5, Web API 2) are described in the `README.md` of each `NetAmpowering.Demo.*` folder.

### 3. Integrate into your own project

See [OBSERVABILITY.md](OBSERVABILITY.md) for the complete integration guide.

```csharp
// Program.cs
builder.AddBlazorTelemetry();          // OTel pipeline (traces + metrics)
builder.AddBlazorProfiler();           // Pyroscope profiling
builder.Services.AddBlazorObservability(); // circuit handler + navigation
```

```razor
@* _Imports.razor — instruments every component in the folder *@
@using NetAmpowering.Observability.Components
@inherits InstrumentedComponentBase
```

```csharp
// Automatic AOP tracing on your services (requires an interface)
builder.Services.AddTracedScoped<IMyService, MyService>();
```

### Supported backends

- **Local** — Docker Compose (Grafana + Tempo + Prometheus + Pyroscope), see [DOCKER.md](DOCKER.md)
- **Grafana Cloud** — direct OTLP push, see [GRAFANA-CLOUD.md](GRAFANA-CLOUD.md)
- **Scaleway Cockpit** — direct OTLP push, see [SCALEWAY-COCKPIT.md](SCALEWAY-COCKPIT.md)
