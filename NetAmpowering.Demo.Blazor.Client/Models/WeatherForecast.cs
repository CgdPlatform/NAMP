namespace NetAmpowering.Demo.Blazor.Client.Models;

/// <summary>
/// DTO shared between the WASM client and the WeatherForecast API controller.
/// </summary>
public sealed class WeatherForecast
{
    /// <summary>Date of the forecast.</summary>
    public DateOnly Date { get; set; }

    /// <summary>Summary of the weather (for example "Warm").</summary>
    public string? Summary { get; set; }

    /// <summary>Temperature in degrees Celsius.</summary>
    public int TemperatureC { get; set; }

    /// <summary>Temperature in degrees Fahrenheit, computed from <see cref="TemperatureC"/>.</summary>
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
