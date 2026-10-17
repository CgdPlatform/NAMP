using Microsoft.EntityFrameworkCore;
using NetAmpowering.Demo.Blazor.Components;
using NetAmpowering.Demo.Blazor.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services
    .AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents();

// SQLite database
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite("Data Source=weather.db"));

// Web API + action monitoring (one OTel span per action).
builder.Services
    .AddControllers()
    .AddApiObservability();

// Blazor observability.
builder.Services.AddBlazorObservability();

// OpenTelemetry instrumentation.
builder.AddBlazorTelemetry();

// EF Core query tracing.
builder.AddEntityFrameworkCoreInstrumentation();

// Production code coverage -> metric coverage_method_hit{method_id="N"} in Prometheus.
builder.AddProductionCoverage();

// Blazor profiler.
builder.AddBlazorProfiler();

var app = builder.Build();

// SQLite seed at startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
    if (!db.WeatherForecasts.Any())
    {
        string[] summaries = ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"];
        var rng = new Random(42);
        db.WeatherForecasts.AddRange(Enumerable.Range(1, 15).Select(i => new WeatherForecastRecord
        {
            Date = DateOnly.FromDateTime(DateTime.Now.AddDays(i)),
            TemperatureC = rng.Next(-20, 55),
            Summary = summaries[rng.Next(summaries.Length)],
        }));
        db.SaveChanges();
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);

    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseAntiforgery();

app.MapControllers();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(NetAmpowering.Demo.Blazor.Client._Imports).Assembly);

app.Run();
