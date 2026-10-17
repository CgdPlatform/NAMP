namespace NetAmpowering.Demo.Blazor.Data;

/// <summary>SQLite record of a weather forecast.</summary>
public sealed class WeatherForecastRecord
{
    /// <summary>Date of the forecast.</summary>
    public DateOnly Date { get; set; }

    /// <summary>Row identifier.</summary>
    public int Id { get; set; }

    /// <summary>Summary of the weather.</summary>
    public string? Summary { get; set; }

    /// <summary>Temperature in degrees Celsius.</summary>
    public int TemperatureC { get; set; }
}
