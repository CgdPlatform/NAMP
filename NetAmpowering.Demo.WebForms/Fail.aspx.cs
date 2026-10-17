using System;

namespace NetAmpowering.Demo.WebForms
{
    /// <summary>Page that throws an exception on purpose to illustrate error tracing.</summary>
    public partial class FailPage : DemoPageBase
    {
        /// <summary>Throws an exception to illustrate error tracing.</summary>
        /// <param name="e">Event arguments.</param>
        protected override void OnLoad(EventArgs e)
        {
            throw new InvalidOperationException("Erreur volontaire de la demo WebForms.");
        }
    }
}
