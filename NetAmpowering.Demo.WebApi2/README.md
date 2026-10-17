# NetAmpowering.Demo.WebApi2

**ASP.NET Web API 2 (.NET Framework 4.7.2)** demo instrumented by NetAmpowering. .NET Framework counterpart of `NetAmpowering.Demo.WebApi`.

## Run

```powershell
dotnet build NetAmpowering.Demo.WebApi2\NetAmpowering.Demo.WebApi2.csproj
& "$env:ProgramFiles\IIS Express\iisexpress.exe" /path:"$PWD\NetAmpowering.Demo.WebApi2" /port:5303 /clr:v4.0
```

| URL | What you see |
| --- | --- |
| `http://localhost:5303/api/forecasts?days=3` | `Forecasts.GetAll` span (`action.param.days` tag), `WeatherService.GetForecasts`, EF6 SQL spans |
| `http://localhost:5303/api/forecasts/2` · `/api/forecasts/9999` | `Forecasts.GetById`, 200 then 404 |
| `http://localhost:5303/api/forecasts/fail` | failing action |

To see the data: `observability\docker compose up -d` (traces go straight to Tempo on `localhost:4318`, metrics straight to Prometheus on `localhost:9090`; there is no OTel Collector), then Grafana at `http://localhost:3000`.

## What the demo shows

| Feature | Where |
| --- | --- |
| Global filter registered with no code (`GlobalConfiguration`) | `NetAmpowering.AspNet.WebApi` package; `Global.asax.cs` only contains routing |
| Span per service call (AOP) | `WeatherService.cs`: `TracedProxy.Wrap<IWeatherService>` |
| EF6 SQL tracing (LocalDB, database created on first call) | `NetAmpowering.Observability.EntityFramework6` package |
| Production code coverage | `FodyWeavers.xml` + `NetAmpowering.Coverage.AspNet` |
| Binding redirects generated at build time | `NetAmpoweringUpdateBindingRedirects` in the csproj |

Same specifics as the other .NET Framework demos: SDK-style csproj (`bin\`), `httpRuntime targetFramework="4.7.2"`
and `netstandard` assembly in `Web.config`, `<runtime>` section rewritten on every build.
