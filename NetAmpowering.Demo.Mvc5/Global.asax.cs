using System.Diagnostics.CodeAnalysis;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;

namespace NetAmpowering.Demo.Mvc5
{
    /// <summary>ASP.NET application of the MVC 5 demo.</summary>
    /// <remarks>OpenTelemetry (NetAmpowering.AspNet), the global action filter (NetAmpowering.AspNet.Mvc) and the coverage Meter (NetAmpowering.Coverage.AspNet) are started before Application_Start.</remarks>
    public class MvcApplication : HttpApplication
    {
        /// <summary>Registers the areas and the default MVC route.</summary>
        [SuppressMessage(
            "Performance",
            "CA1822:Mark members as static",
            Justification = "ASP.NET decouvre Application_Start par son nom : methode d'instance de HttpApplication.")]
        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();
            RouteTable.Routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional });
        }
    }
}
