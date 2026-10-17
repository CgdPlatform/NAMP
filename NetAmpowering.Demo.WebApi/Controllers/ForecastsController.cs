using Microsoft.AspNetCore.Mvc;

namespace NetAmpowering.Demo.WebApi.Controllers;

/// <summary>API controller exposing the weather forecasts.</summary>
[ApiController]
[Route("api/[controller]")]
public class ForecastsController(IWeatherService weather) : ControllerBase
{
    /// <summary>Action that fails on purpose to illustrate error tracing.</summary>
    /// <returns>Never returns: the action throws an exception.</returns>
    /// <remarks>Route: GET api/forecasts/fail.</remarks>
    [HttpGet("fail")]
    public IActionResult Fail() => throw new InvalidOperationException("Erreur volontaire de la demo Web API.");

    /// <summary>Returns the upcoming forecasts.</summary>
    /// <param name="days">Number of forecast days requested.</param>
    /// <returns>The requested forecasts.</returns>
    /// <remarks>Route: GET api/forecasts?days=5. The "Forecasts.GetAll" span carries the action.param.days tag.</remarks>
    [HttpGet]
    public async Task<IEnumerable<Forecast>> GetAll(int days = 8) => await weather.GetAsync(days);

    /// <summary>Returns a forecast from its identifier.</summary>
    /// <param name="id">Forecast identifier.</param>
    /// <returns>The forecast, or a 404 response if it does not exist.</returns>
    /// <remarks>Route: GET api/forecasts/3; 404 if the forecast is missing.</remarks>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<Forecast>> GetById(int id)
    {
        var forecast = await weather.FindAsync(id);
        return forecast is null ? NotFound() : forecast;
    }
}
