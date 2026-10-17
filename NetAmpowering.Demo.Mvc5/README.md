# NetAmpowering.Demo.Mvc5

ASP.NET MVC 5 demo (.NET Framework 4.7.2) instrumented by NetAmpowering. .NET Framework counterpart of the Blazor demo.

## Run

```powershell
dotnet build NetAmpowering.Demo.Mvc5\NetAmpowering.Demo.Mvc5.csproj
& "$env:ProgramFiles\IIS Express\iisexpress.exe" /path:"$PWD\NetAmpowering.Demo.Mvc5" /port:5302 /clr:v4.0
```

Then `http://localhost:5302/`, `http://localhost:5302/Home/Weather?days=5` and `http://localhost:5302/Home/Fail`.

To see the data: `observability\docker compose up -d` (traces go straight to Tempo on `localhost:4318`, metrics straight to Prometheus on `localhost:9090`; there is no OTel Collector), then Grafana at `http://localhost:3000`.

## What the demo shows

| Feature | Where |
| --- | --- |
| Global filter registered with no code | `NetAmpowering.AspNet.Mvc` package: `Home.Weather` span with the `action.param.days` tag |
| Span per service call (AOP) | `WeatherService.cs`: `TracedProxy.Wrap<IWeatherService>` |
| NHibernate SQL tracing (SQL Server LocalDB, schema created on first call) | `WeatherService.cs`: `cfg.AddNetAmpoweringTracing()` produces `DB query/execute/scalar` spans |
| Production code coverage | `FodyWeavers.xml` + `NetAmpowering.Coverage.AspNet` |
| Binding redirects generated at build time | `NetAmpoweringUpdateBindingRedirects` in the csproj |

## Project specifics

- **SDK-style** csproj (`OutputPath=bin\`): builds with `dotnet build`, no Visual Studio needed.
- `.cshtml` views are compiled on the fly by ASP.NET (C# 5): they are therefore **not** instrumented by the coverage weaver.
- The build rewrites the `<runtime>` section of `Web.config` (binding redirects).
