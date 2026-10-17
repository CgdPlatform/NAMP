# NetAmpowering.Demo.WebForms

ASP.NET WebForms demo (.NET Framework 4.7.2) instrumented by NetAmpowering. .NET Framework counterpart of the Blazor demo.

## Run

```powershell
dotnet build NetAmpowering.Demo.WebForms\NetAmpowering.Demo.WebForms.csproj
& "$env:ProgramFiles\IIS Express\iisexpress.exe" /path:"$PWD\NetAmpowering.Demo.WebForms" /port:5301 /clr:v4.0
```

Then `http://localhost:5301/Default.aspx` (postback: "Reload" button) and `http://localhost:5301/Fail.aspx` (deliberate exception).

To see the data: `observability\docker compose up -d` (traces go straight to Tempo on `localhost:4318`, metrics straight to Prometheus on `localhost:9090`; there is no OTel Collector), then Grafana at `http://localhost:3000`.

## What the demo shows

| Feature | Where |
| --- | --- |
| Zero-code startup (HTTP modules registered before `Application_Start`) | `NetAmpowering.AspNet` packages, `Global.asax.cs` is empty |
| `Page.{Type}` span + one span per lifecycle stage | `Default.aspx`, `Fail.aspx` |
| Span per service call (AOP) | `WeatherService.cs`: `TracedProxy.Wrap<IWeatherService>` |
| Entity Framework 6 SQL tracing (SQL Server LocalDB, database created on first call) | `WeatherService.cs`, `NetAmpowering.Observability.EntityFramework6` package: `DB query/execute/scalar` spans |
| Production code coverage | `FodyWeavers.xml` + `NetAmpowering.Coverage.AspNet` |
| Binding redirects generated at build time | `NetAmpoweringUpdateBindingRedirects` in the csproj |

## Project specifics

- **SDK-style** csproj (`OutputPath=bin\`): builds with `dotnet build`, no Visual Studio needed. IIS Express serves the folder directly.
- `Web.config`: `httpRuntime targetFramework="4.7.2"` and the `netstandard` assembly in `<compilation>` are **mandatory**
  (without the latter, `.aspx` pages compiled on the fly fail with CS0012).
- The build rewrites the `<runtime>` section of `Web.config` (binding redirects).
- No `.designer.cs` file: controls are declared by hand in the code-behind.
