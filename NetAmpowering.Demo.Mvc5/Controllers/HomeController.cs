using System;
using System.Diagnostics.CodeAnalysis;
using System.Web.Mvc;

namespace NetAmpowering.Demo.Mvc5.Controllers
{
    /// <summary>MVC controller of the demo: home, forecasts and a failing action.</summary>
    public class HomeController : Controller
    {
        /// <summary>Action that fails on purpose to illustrate error tracing.</summary>
        /// <returns>Never returns: the action throws an exception.</returns>
        [HttpGet]
        [SuppressMessage(
            "Performance",
            "CA1822:Mark members as static",
            Justification = "Une action MVC doit etre une methode d'instance.")]
        public ActionResult Fail()
        {
            throw new InvalidOperationException("Erreur volontaire de la demo MVC 5.");
        }

        /// <summary>Displays the home page.</summary>
        /// <returns>The home view.</returns>
        [HttpGet]
        public ActionResult Index()
        {
            return View();
        }

        /// <summary>Displays the upcoming forecasts; <c>days</c> becomes the <c>action.param.days</c> tag.</summary>
        /// <param name="days">Number of forecast days requested.</param>
        /// <returns>The forecasts view.</returns>
        /// <remarks>A "Home.Weather" span is created by the global filter; "days" becomes the action.param.days tag.</remarks>
        [HttpGet]
        public ActionResult Weather(int days = 8)
        {
            return View(Services.Weather.GetForecasts(days));
        }
    }
}
