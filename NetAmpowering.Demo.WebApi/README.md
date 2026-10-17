# NetAmpowering.Demo.WebApi

**ASP.NET Core Web API (.NET 8)** demo, without Blazor: controllers + minimal APIs instrumented by `NetAmpowering.AspNetCore`.

## Run

```powershell
dotnet run --project NetAmpowering.Demo.WebApi\NetAmpowering.Demo.WebApi.csproj   # http://localhost:5304
```

| URL | What you see |
| --- | --- |
| `/api/forecasts?days=3` | `Forecasts.GetAll` span (`action.param.days` tag), `WeatherService.GetAsync` span, EF Core SQL span |
| `/api/forecasts/2` · `/api/forecasts/9999` | `Forecasts.GetById`, 200 then 404 |
| `/api/forecasts/fail` | failing action |
| `/minimal/forecasts/4` · `/minimal/fail` | minimal-API endpoint span (`.WithNetAmpoweringTracing()`, `endpoint.arg.0` tag) |

To see the data: `observability\docker compose up -d` (traces go straight to Tempo on `localhost:4318`, metrics straight to Prometheus on `localhost:9090`; there is no OTel Collector), then Grafana at `http://localhost:3000`.

## What the demo shows

| Feature | Where |
| --- | --- |
| One-line OpenTelemetry pipeline | `builder.AddNetAmpoweringTelemetry()` |
| One span per controller action | `AddControllers().AddApiObservability()` |
| One span per minimal-API endpoint | `.WithNetAmpoweringTracing()` |
| One span per service call (AOP) | `AddTracedScoped<IWeatherService, WeatherService>()` |
| EF Core SQL spans | `builder.AddEntityFrameworkCoreInstrumentation()` |
| Production code coverage | `FodyWeavers.xml` + `builder.AddProductionCoverage()` |
