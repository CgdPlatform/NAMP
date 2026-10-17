using System.Diagnostics.CodeAnalysis;
using System.Web;
using System.Web.Http;

namespace NetAmpowering.Demo.WebApi2
{
    /// <summary>ASP.NET application of the Web API 2 demo.</summary>
    /// <remarks>OpenTelemetry (NetAmpowering.AspNet), the global action filter (NetAmpowering.AspNet.WebApi), EF6 tracing and the coverage Meter are started before Application_Start.</remarks>
    public class WebApiApplication : HttpApplication
    {
        /// <summary>Configures Web API routing (attribute routes and default route).</summary>
        [SuppressMessage(
            "Performance",
            "CA1822:Mark members as static",
            Justification = "ASP.NET decouvre Application_Start par son nom : methode d'instance de HttpApplication.")]
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(config =>
            {
                config.MapHttpAttributeRoutes();
                config.Routes.MapHttpRoute(
                    name: "DefaultApi",
                    routeTemplate: "api/{controller}/{id}",
                    defaults: new { id = RouteParameter.Optional });
            });
        }
    }
}
