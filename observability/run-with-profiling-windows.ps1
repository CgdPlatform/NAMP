# =============================================================================
# Runs the Blazor app with traces + metrics sent to the local stack.
#
# Prerequisite: start-observability.ps1 must be run first.
#
#   Tempo (traces)       → http://localhost:4318
#   Prometheus (metrics) → http://localhost:9090
#   Grafana        → http://localhost:3000
# =============================================================================

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir  = Join-Path $ScriptDir "..\NetAmpowering.Demo.Blazor"
$SolutionPath = Join-Path $ScriptDir "..\NetAmpowering.sln"

# -- OTel variables → local stack ---------------------------------------------
$env:ASPNETCORE_ENVIRONMENT             = "Development"
$env:OpenTelemetry__Enabled             = "true"
$env:OpenTelemetry__OtlpEndpoint        = "http://localhost:4318/v1/traces"
$env:OpenTelemetry__OtlpMetricsEndpoint = "http://localhost:9090/api/v1/otlp/v1/metrics"
$env:OpenTelemetry__OtlpHeaders         = ""
$env:OpenTelemetry__OtlpMetricsHeaders  = ""
$env:OpenTelemetry__SamplingProbability = "1.0"

Write-Host "-> Traces    : http://localhost:4318/v1/traces"
Write-Host "-> Metriques : http://localhost:9090/api/v1/otlp/v1/metrics"
Write-Host "-> Grafana   : http://localhost:3000"
Write-Host ""

# -- Build --------------------------------------------------------------------
Write-Host "-> Build..."
dotnet build $SolutionPath --no-incremental -verbosity:minimal
if ($LASTEXITCODE -ne 0) { Write-Error "Build echoue."; exit 1 }

$DllPath = Get-ChildItem -Path "$ProjectDir\bin" -Filter "NetAmpowering.Demo.Blazor.dll" -Recurse |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (-not $DllPath) { Write-Error "DLL introuvable apres le build."; exit 1 }

# -- Launch -------------------------------------------------------------------
Write-Host "-> Lancement de l'app... (Ctrl+C pour arreter)"
Write-Host ""

try {
    $AppProcess = Start-Process -FilePath "dotnet" -ArgumentList "exec", "`"$DllPath`"" `
                  -PassThru -NoNewWindow -WorkingDirectory $ProjectDir
    $AppProcess.WaitForExit()
} finally {
    if (-not $AppProcess.HasExited) { Stop-Process -Id $AppProcess.Id -ErrorAction SilentlyContinue }

    Remove-Item Env:\ASPNETCORE_ENVIRONMENT              -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__Enabled              -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpEndpoint         -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpMetricsEndpoint  -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpHeaders          -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpMetricsHeaders   -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__SamplingProbability  -ErrorAction SilentlyContinue
}
