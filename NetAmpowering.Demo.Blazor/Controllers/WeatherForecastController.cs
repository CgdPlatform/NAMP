using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetAmpowering.Demo.Blazor.Client.Models;
using NetAmpowering.Demo.Blazor.Data;

namespace NetAmpowering.Demo.Blazor.Controllers;

/// <summary>Weather API of the Blazor demo.</summary>
[ApiController]
[Route("api/[controller]")]
public sealed class WeatherForecastController(AppDbContext db) : ControllerBase
{
    /// <summary>Returns the forecasts stored in the database.</summary>
    /// <param name="cancellationToken">Cancellation token of the request.</param>
    /// <returns>The forecasts.</returns>
    [HttpGet]
    public async Task<IEnumerable<WeatherForecast>> GetAsync(CancellationToken cancellationToken)
    {
        var records = await db.WeatherForecasts
            .OrderBy(w => w.Date)
            .ToListAsync(cancellationToken);

        return records.Select(r => new WeatherForecast
        {
            Date = r.Date,
            TemperatureC = r.TemperatureC,
            Summary = r.Summary,
        });
    }
}
