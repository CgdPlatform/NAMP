using System;
using System.Diagnostics.CodeAnalysis;
using System.Web.UI.WebControls;

namespace NetAmpowering.Demo.WebForms
{
    /// <summary>Main page of the WebForms demo: lists the forecasts and offers a postback reload.</summary>
    [SuppressMessage(
        "Design",
        "CA1051:Do not declare visible instance fields",
        Justification = "ASP.NET WebForms lie les controles serveur a des champs proteges du code-behind.")]
    public partial class DefaultPage : DemoPageBase
    {
        /// <summary>List of the displayed forecasts.</summary>
        protected Repeater ForecastRepeater;

        /// <summary>Reload button (postback).</summary>
        /// <remarks>No .designer file: the controls are declared by hand.</remarks>
        protected Button RefreshButton;

        /// <summary>Status label displayed after a reload.</summary>
        protected Label StatusLabel;

        /// <summary>Loads the forecasts on the first display of the page.</summary>
        /// <param name="e">Event arguments.</param>
        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            if (!IsPostBack)
            {
                Bind();
            }
        }

        /// <summary>Reloads the forecasts after a click on the button.</summary>
        /// <param name="sender">Event source.</param>
        /// <param name="e">Event arguments.</param>
        protected void OnRefreshClick(object sender, EventArgs e)
        {
            Bind();
            StatusLabel.Text = "Rechargé à " + DateTime.Now.ToLongTimeString();
        }

        private void Bind()
        {
            ForecastRepeater.DataSource = Services.Weather.GetForecasts(8);
            ForecastRepeater.DataBind();
        }
    }
}
