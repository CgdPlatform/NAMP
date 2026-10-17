using Microsoft.EntityFrameworkCore;

namespace NetAmpowering.Demo.WebApi;

/// <summary>Weather forecast service, traced automatically via <c>TracedProxy</c> (one span per call).</summary>
public interface IWeatherService
{
    /// <summary>Returns the upcoming forecasts.</summary>
    /// <param name="days">Number of forecast days requested.</param>
    /// <returns>The requested forecasts.</returns>
    Task<List<Forecast>> GetAsync(int days);

    /// <summary>Returns a forecast from its identifier.</summary>
    /// <param name="id">Forecast identifier.</param>
    /// <returns>The forecast, or <c>null</c> if it does not exist.</returns>
    Task<Forecast?> FindAsync(int id);
}

/// <summary>Weather forecast of the demo.</summary>
public class Forecast
{
    /// <summary>Date of the forecast.</summary>
    public DateOnly Date { get; set; }

    /// <summary>Forecast identifier.</summary>
    public int Id { get; set; }

    /// <summary>Summary of the weather.</summary>
    public string? Summary { get; set; }

    /// <summary>Temperature in degrees Celsius.</summary>
    public int TemperatureC { get; set; }
}

/// <summary>EF Core context of the demo (SQLite).</summary>
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    /// <summary>Weather forecasts table.</summary>
    public DbSet<Forecast> Forecasts => Set<Forecast>();
}

/// <summary>Implementation of the weather service.</summary>
public class WeatherService(AppDbContext db) : IWeatherService
{
    /// <inheritdoc/>
    public Task<Forecast?> FindAsync(int id) =>
        db.Forecasts.FirstOrDefaultAsync(f => f.Id == id);

    /// <inheritdoc/>
    public Task<List<Forecast>> GetAsync(int days) =>
        db.Forecasts.OrderBy(f => f.Date).Take(days).ToListAsync();
}
