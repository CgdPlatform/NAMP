<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="NetAmpowering.Demo.WebForms.DefaultPage" %>
<!DOCTYPE html>
<html>
<head runat="server">
  <title>NetAmpowering - Demo WebForms</title>
  <style>
    body { font-family: Segoe UI, sans-serif; margin: 2rem; }
    table { border-collapse: collapse; } td, th { border: 1px solid #ccc; padding: .3rem .8rem; }
  </style>
</head>
<body>
  <form id="form1" runat="server">
    <h1>Demo WebForms</h1>
    <p>Chaque etape du cycle de vie de cette page est un span OpenTelemetry (Page.PreInit, Page.Load, ...).</p>
    <asp:Button ID="RefreshButton" runat="server" Text="Recharger (postback)" OnClick="OnRefreshClick" />
    <a href="Fail.aspx">Page en erreur</a>
    <p><asp:Label ID="StatusLabel" runat="server" /></p>
    <table>
      <tr><th>Date</th><th>Temp. (C)</th><th>Resume</th></tr>
      <asp:Repeater ID="ForecastRepeater" runat="server">
        <ItemTemplate>
          <tr>
            <td><%# Eval("Date", "{0:d}") %></td>
            <td><%# Eval("TemperatureC") %></td>
            <td><%# Eval("Summary") %></td>
          </tr>
        </ItemTemplate>
      </asp:Repeater>
    </table>
  </form>
</body>
</html>
