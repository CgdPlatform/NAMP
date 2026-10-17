using System;
using System.Web.UI;

namespace NetAmpowering.Demo.WebForms
{
    /// <summary>
    /// Base page of the demo: binds the ViewState to the user's session (CSRF protection, rule CA5368).
    /// </summary>
    public abstract class DemoPageBase : Page
    {
        /// <summary>Binds the ViewState to the user's session before the page is initialized.</summary>
        /// <param name="e">Event arguments.</param>
        protected override void OnInit(EventArgs e)
        {
            // The session must be initialized so that SessionID stays stable from one request to the next.
            Session["NetAmpowering.Demo"] = true;
            ViewStateUserKey = Session.SessionID;
            base.OnInit(e);
        }
    }
}
