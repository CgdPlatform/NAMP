using Microsoft.EntityFrameworkCore;

namespace NetAmpowering.Demo.Blazor.Data;

/// <summary>EF Core context of the demo (SQLite).</summary>
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    /// <summary>Weather forecasts table.</summary>
    public DbSet<WeatherForecastRecord> WeatherForecasts => Set<WeatherForecastRecord>();
}
