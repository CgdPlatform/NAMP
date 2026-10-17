using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Web.Http;

namespace NetAmpowering.Demo.WebApi2.Controllers
{
    /// <summary>API controller exposing the weather forecasts.</summary>
    [RoutePrefix("api/forecasts")]
    [SuppressMessage(
        "Performance",
        "CA1822:Mark members as static",
        Justification = "Les actions Web API doivent etre des methodes d'instance.")]
    public class ForecastsController : ApiController
    {
        /// <summary>Action that fails on purpose to illustrate error tracing.</summary>
        /// <returns>Never returns: the action throws an exception.</returns>
        /// <remarks>Route: GET api/forecasts/fail.</remarks>
        [HttpGet]
        [Route("fail")]
        public IHttpActionResult Fail()
        {
            throw new InvalidOperationException("Erreur volontaire de la demo Web API 2.");
        }

        /// <summary>Returns the upcoming forecasts.</summary>
        /// <param name="days">Number of forecast days requested.</param>
        /// <returns>The requested forecasts.</returns>
        /// <remarks>Route: GET api/forecasts?days=5. The "Forecasts.GetAll" span carries the action.param.days tag.</remarks>
        [HttpGet]
        [Route("")]
        public IEnumerable<Forecast> GetAll(int days = 8)
        {
            return Services.Weather.GetForecasts(days);
        }

        /// <summary>Returns a forecast from its identifier.</summary>
        /// <param name="id">Forecast identifier.</param>
        /// <returns>The forecast, or a 404 response if it does not exist.</returns>
        /// <remarks>Route: GET api/forecasts/3; 404 if the forecast is missing.</remarks>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult GetById(int id)
        {
            var forecast = Services.Weather.Find(id);
            if (forecast == null)
            {
                return NotFound();
            }

            return Ok(forecast);
        }
    }
}
