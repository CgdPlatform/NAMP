using Microsoft.EntityFrameworkCore;
using NetAmpowering.Demo.WebApi;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlite("Data Source=weather.db"));

// One span per controller action.
builder.Services.AddControllers().AddApiObservability();

// One span per service method call (AOP, Castle DynamicProxy).
builder.Services.AddTracedScoped<IWeatherService, WeatherService>();

// OpenTelemetry: traces + metrics + OTLP export.
builder.AddNetAmpoweringTelemetry();

// EF Core: one span per SQL query.
builder.AddEntityFrameworkCoreInstrumentation();

// Code coverage in production.
builder.AddProductionCoverage();

// Pyroscope profiler (inactive without the native profiler).
builder.AddNetAmpoweringProfiler();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
    if (!db.Forecasts.Any())
    {
        string[] summaries = ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"];
        var rng = new Random(42);
        db.Forecasts.AddRange(Enumerable.Range(1, 15).Select(i => new Forecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today.AddDays(i)),
            TemperatureC = rng.Next(-20, 55),
            Summary = summaries[rng.Next(summaries.Length)],
        }));
        db.SaveChanges();
    }
}

app.MapControllers();

// Minimal API: one span per endpoint thanks to WithNetAmpoweringTracing().
app.MapGet("/minimal/forecasts/{days:int}", async (int days, IWeatherService weather) => await weather.GetAsync(days))
   .WithNetAmpoweringTracing();

app.MapGet("/minimal/fail", () => { throw new InvalidOperationException("Erreur volontaire de la minimal API."); })
   .WithNetAmpoweringTracing();

app.Run();
