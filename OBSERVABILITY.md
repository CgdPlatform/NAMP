# Blazor observability — Integration guide

This guide explains how to instrument a Blazor Server application with
`NetAmpowering.Observability` to automatically get:

- Traces for every HTTP request
- The lifecycle of SignalR circuits
- The lifecycle of components (`OnInitialized`, `OnParametersSet`)
- User events (clicks, inputs...)
- SPA route changes
- Calls to business services (AOP via Castle DynamicProxy)
- .NET runtime metrics (GC, thread pool, memory)

---

## 1. NuGet packages

In the Blazor server project (`.csproj`):

```xml
<!-- Observability library -->
<PackageReference Include="NetAmpowering.Observability" Version="1.0.0" />

<!-- OpenTelemetry — traces and metrics pipeline -->
<PackageReference Include="OpenTelemetry" Version="1.15.3" />
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.15.3" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.15.3" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.15.2" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.15.1" />
<PackageReference Include="OpenTelemetry.Instrumentation.Runtime" Version="1.15.1" />

<!-- Optional — if you use Entity Framework Core -->
<PackageReference Include="OpenTelemetry.Instrumentation.EntityFrameworkCore" Version="1.0.0-beta.9" />
```

---

## 2. Configuration — `appsettings.json`

```json
{
  "OpenTelemetry": {
    "Enabled": true,
    "ApplicationName": "my-app",
    "OtlpEndpoint": "http://localhost:4318/v1/traces",
    "OtlpMetricsEndpoint": "http://localhost:9090/api/v1/otlp/v1/metrics",
    "OtlpHeaders": "",
    "SamplingProbability": 1.0
  }
}
```

| Key | Default | Description |
| --- | --- | --- |
| `Enabled` | `false` | Enables or disables the whole OTel pipeline |
| `ApplicationName` | `"BlazorApp"` | Service name shown in Grafana / Tempo |
| `OtlpEndpoint` | `http://localhost:4318/v1/traces` | OTLP endpoint for **traces** |
| `OtlpHeaders` | _(empty)_ | Auth headers for traces: `Authorization=Basic xxx` (Grafana Cloud) or `X-Token=xxx` (Scaleway) |
| `OtlpMetricsEndpoint` | derived from `OtlpEndpoint` | OTLP endpoint for **metrics** (needed when the two differ, e.g. Prometheus OTLP, Grafana Cloud, Scaleway) |
| `OtlpMetricsHeaders` | derived from `OtlpHeaders` | Auth headers for **metrics** — required on Grafana Cloud, where Prometheus has a different instance ID from Tempo |
| `SamplingProbability` | `0.1` | Sampling rate — `1.0` in dev, `0.1` (10%) in prod |

To disable it in production without changing the code:

```json
{
  "OpenTelemetry": {
    "Enabled": false
  }
}
```

### Examples per backend

#### Local dev (Docker stack, straight to Tempo and Prometheus)

```json
{
  "OpenTelemetry": {
    "Enabled": true,
    "ApplicationName": "my-app",
    "OtlpEndpoint": "http://localhost:4318/v1/traces",
    "OtlpMetricsEndpoint": "http://localhost:9090/api/v1/otlp/v1/metrics",
    "SamplingProbability": 1.0
  }
}
```

#### Grafana Cloud (direct, no container)

Grafana Cloud exposes a separate instance ID per backend (Tempo, Prometheus, Pyroscope).
Traces and metrics therefore need separate headers:

```json
{
  "OpenTelemetry": {
    "Enabled": true,
    "ApplicationName": "my-app",
    "OtlpEndpoint": "https://tempo-prod-10-prod-eu-west-2.grafana.net/otlp/v1/traces",
    "OtlpHeaders": "Authorization=Basic <base64(tempoId:token)>",
    "OtlpMetricsEndpoint": "https://prometheus-prod-24-prod-eu-west-2.grafana.net/otlp/v1/metrics",
    "OtlpMetricsHeaders": "Authorization=Basic <base64(prometheusId:token)>",
    "SamplingProbability": 0.1
  }
}
```

> See [GRAFANA-CLOUD.md](GRAFANA-CLOUD.md) to get the endpoints and instance IDs.

#### Scaleway Cockpit (direct, no container)

```json
{
  "OpenTelemetry": {
    "Enabled": true,
    "ApplicationName": "my-app",
    "OtlpEndpoint": "https://traces.cockpit.fr-par.scw.cloud/otlp/v1/traces",
    "OtlpMetricsEndpoint": "https://metrics.cockpit.fr-par.scw.cloud/otlp/v1/metrics",
    "OtlpHeaders": "X-Token=<your_cockpit_token>",
    "SamplingProbability": 0.1
  }
}
```

---

## 3. Configuration — `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// ── OpenTelemetry (traces + metrics) ─────────────────────────────────────────
// Reads Enabled, ApplicationName, OtlpEndpoint, OtlpMetricsEndpoint, OtlpHeaders,
// SamplingProbability from the configuration.
builder.AddBlazorTelemetry();

// ── Pyroscope profiler (flame graphs) ────────────────────────────────────────
// Reads Pyroscope:Enable from the configuration. No-op if the native profiler
// is not loaded (CORECLR_* not set).
builder.AddBlazorProfiler();

// ── Blazor DI services (circuit handler + navigation) ────────────────────────
builder.Services.AddBlazorObservability();

var app = builder.Build();
// ...
app.Run();
```

> **`AddBlazorTelemetry()`** configures the complete OTel pipeline:
> traces (AspNetCore, HttpClient, EF Core, Blazor) + runtime metrics,
> OTLP batch export with the endpoint and headers from the configuration.
>
> **`AddBlazorInstrumentation()`** (called internally) registers the 5 ActivitySources
> (`BlazorApp.Circuits`, `.Components`, `.Business`, `.Services`, `.Navigation`).
>
> **`AddBlazorObservability()`** registers the required DI services
> (circuit handler, navigation instrumentation).

---

## 4. Automatic component instrumentation

### 4a. Inheritance through `_Imports.razor`

To instrument **every component in a folder** without touching each file,
add to `Components/_Imports.razor`:

```razor
@using NetAmpowering.Observability.Components
@inherits InstrumentedComponentBase
```

All the components in the folder automatically inherit from `InstrumentedComponentBase`.

### 4b. Important rule — which methods to override

`InstrumentedComponentBase` uses the **template method** pattern: the methods
`OnInitializedAsync` and `OnParametersSetAsync` are `sealed` so that the
span wraps all of the component's work. You have to override the **Core** methods:

| ❌ Do not override | ✅ Override instead |
| --- | --- |
| `OnInitializedAsync()` | `OnInitializedCoreAsync()` |
| `OnParametersSetAsync()` | `OnParametersSetCoreAsync()` |
| `OnAfterRenderAsync(bool firstRender)` | `OnAfterRenderCoreAsync(bool firstRender)` |

```razor
@code {
    // ✅ Correct — the span includes all this work
    protected override async Task OnInitializedCoreAsync()
    {
        await Task.Delay(500);
        data = await MyService.GetDataAsync();
    }

    // ❌ Avoid — the span only measures ComponentBase (no-op)
    // protected override async Task OnInitializedAsync()
    // {
    //     await Task.Delay(500);
    // }
}
```

### 4c. What is traced automatically

Without writing a single line of tracing code in your components:

| Event | Generated span |
| --- | --- |
| Initialization | `MyComponent.OnInitialized` |
| Parameter change | `MyComponent.OnParametersSet` |
| After render (DOM available) | `MyComponent.OnAfterRender` |
| Button click, input... | `MyComponent.HandleEvent` |

### 4d. Tracing a specific operation inside a component

For a custom span inside a component, use `TraceOperationAsync`:

```razor
@code {
    private async Task LoadData()
    {
        // With a return value
        var result = await TraceOperationAsync(
            "LoadData.ApiCall",
            () => MyService.GetDataAsync(),
            tags: new() { ["api.endpoint"] = "/data" });

        // Without a return value
        await TraceOperationAsync(
            "LoadData.Processing",
            async () => { await ProcessAsync(result); });
    }
}
```

---

## 5. Enabling navigation tracing

Inject `NavigationInstrumentation` in `MainLayout.razor` to enable the
tracing of SPA route changes:

```razor
@* MainLayout.razor *@
@using NetAmpowering.Observability.Services
@inject NavigationInstrumentation NavInstrumentation

@* The rest of the layout... *@
```

> Injection alone enables the service — no method call is needed.
> A `Navigation.LocationChanged` span is created on every route change.

---

## 6. Automatic tracing of business services

To automatically trace every call to a service (without modifying the service),
use `AddTracedScoped/Singleton/Transient` in place of the standard `Add`:

```csharp
// ❌ Standard — no tracing
builder.Services.AddScoped<IMyService, MyService>();

// ✅ With automatic tracing of every method
builder.Services.AddTracedScoped<IMyService, MyService>();
builder.Services.AddTracedSingleton<IMyService, MyService>();
builder.Services.AddTracedTransient<IMyService, MyService>();
```

Every method call automatically generates a span:

- Name: `MyService.MyMethod`
- Tags: `service.type`, `service.method`, `service.namespace`
- Primitive parameters (string, int, Guid, DateTime...) are added as tags

> **Prerequisite**: the service must be registered through an **interface**.
> Castle DynamicProxy cannot intercept concrete classes.

---

## 7. Manual business enrichment

To add business context to any span, use `BusinessContextEnricher`:

```csharp
using NetAmpowering.Observability.Services;
using System.Diagnostics;

public class OrderService
{
    public async Task PlaceOrderAsync(string userId, Guid orderId)
    {
        // Start a business span
        using var activity = BusinessContextEnricher.StartBusinessOperation("Order.Place");

        // Enrich with the user context
        BusinessContextEnricher.EnrichWithUserContext(activity, userId, role: "client");

        // Enrich with the functional context
        BusinessContextEnricher.EnrichWithFeatureContext(activity, "Cart", "Validation");

        // Add custom tags
        activity?.SetTag("order.id", orderId);

        await _repository.SaveAsync(/* ... */);
    }
}
```

---

## 8. Available trace sources

The library exposes 5 `ActivitySource`s. You can reference them in your own
classes to create spans in the right context:

```csharp
using NetAmpowering.Observability;
using System.Diagnostics;

// Span in the "business services" context
private static readonly ActivitySource Source = new(ActivitySources.Services);

// Span in the "business" context
private static readonly ActivitySource Source = new(ActivitySources.Business);
```

| Constant | Value | Usage |
| --- | --- | --- |
| `ActivitySources.Circuits` | `BlazorApp.Circuits` | SignalR lifecycle |
| `ActivitySources.Components` | `BlazorApp.Components` | Blazor components |
| `ActivitySources.Business` | `BlazorApp.Business` | Business logic |
| `ActivitySources.Services` | `BlazorApp.Services` | Application services |
| `ActivitySources.Navigation` | `BlazorApp.Navigation` | SPA routes |

---

## 9. Continuous profiling (flame graphs)

To find the methods that consume the most CPU, enable the profiler
before starting the app with the following environment variables.

### Linux — Pyroscope (flame graphs in Grafana)

Requires `Pyroscope.Profiler.Native.so` in `observability/profiler/`
(see [observability/run-with-profiling.sh](observability/run-with-profiling.sh)).

```bash
export CORECLR_ENABLE_PROFILING=1
export CORECLR_PROFILER="{BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}"
export CORECLR_PROFILER_PATH="/path/to/observability/profiler/Pyroscope.Profiler.Native.so"
export PYROSCOPE_APPLICATION_NAME="my-app"
export PYROSCOPE_SERVER_ADDRESS="http://localhost:4040"
export PYROSCOPE_PROFILING_ENABLED="true"

dotnet run --project MyApp/MyApp.csproj
```

The flame graphs appear in Grafana → **Explore** → **Pyroscope** datasource.
From a slow trace in Tempo, the **View Profile** button opens the flame graph
for that exact moment.

### macOS and Windows — dotnet-trace

The native Pyroscope profiler only supports Linux. On macOS and Windows,
use **dotnet-trace** (EventPipe) for CPU capture:

```bash
# macOS — capture + push pprof to Grafana Cloud in a single command
./observability/run-with-profiling-macos.sh
```

```bash
# Manual — attach to an existing process
dotnet-trace collect --process-id <PID> --profile dotnet-sampled-thread-time --output profile.nettrace

# Convert to pprof for Grafana Cloud Pyroscope
dotnet-trace convert profile.nettrace --format Pprof

# View locally
dotnet-trace convert profile.nettrace --format Speedscope
# then drop the file on https://www.speedscope.app
```

### macOS — dotnet-trace (Pyroscope not supported on macOS)

```bash
# Install dotnet-trace (once)
dotnet tool install --global dotnet-trace

# Start the app, note its PID, then in another terminal:
# "dotnet-sampled-thread-time" is the CPU profile for macOS
# ("cpu-sampling" is Linux only)
dotnet-trace collect --process-id <PID> --profile dotnet-sampled-thread-time --output profile.nettrace

# View on https://www.speedscope.app
```

> The `run-with-profiling-*.sh/.ps1` scripts in `observability/` automate
> these steps for each platform.

---

## 10. Summary — what is instrumented without writing code

| Feature | Activation |
| --- | --- |
| ASP.NET Core HTTP requests | `AddAspNetCoreInstrumentation()` in `Program.cs` |
| Outgoing `HttpClient` calls | `AddHttpClientInstrumentation()` in `Program.cs` |
| Entity Framework queries | `AddEntityFrameworkCoreInstrumentation()` in `Program.cs` |
| SignalR circuits (connect/disconnect) | `AddBlazorObservability()` in `Program.cs` |
| Component lifecycle | `@inherits InstrumentedComponentBase` in `_Imports.razor` |
| User events (clicks...) | Included in `InstrumentedComponentBase` |
| SPA route changes | `@inject NavigationInstrumentation` in `MainLayout.razor` |
| Business service calls | `AddTracedScoped/Singleton/Transient()` in `Program.cs` |
| GC, thread pool, JIT metrics | `AddRuntimeInstrumentation()` in `Program.cs` |
