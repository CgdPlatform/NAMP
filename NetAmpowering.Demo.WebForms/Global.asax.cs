using System;
using System.Web;

namespace NetAmpowering.Demo.WebForms
{
    /// <summary>ASP.NET application of the WebForms demo; OpenTelemetry is started before Application_Start by NetAmpowering.AspNet.</summary>
    /// <remarks>Nothing to do here: NetAmpowering.AspNet starts OpenTelemetry before Application_Start (PreApplicationStartMethod) and NetAmpowering.Coverage.AspNet creates the coverage Meter.</remarks>
    public class WebFormsApplication : HttpApplication
    {
        /// <summary>Application entry point: nothing to configure, telemetry is already started.</summary>
        /// <param name="sender">Event source.</param>
        /// <param name="e">Event arguments.</param>
        protected void Application_Start(object sender, EventArgs e)
        {
        }
    }
}
