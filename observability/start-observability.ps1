# ─────────────────────────────────────────────────────────────────────────────
# Local observability stack — Grafana + Tempo + Prometheus
#
#   Prometheus     → http://localhost:9090
#   Tempo          → http://localhost:3200  (traces backend)
#   Grafana        → http://localhost:3000  (unified UI — traces + metrics)
#   Tempo (OTLP)   → apps send traces to :4318 (HTTP) / :4317 (gRPC)
#   Prometheus     → apps send metrics to :9090/api/v1/otlp/v1/metrics
#
# ── Prerequisites (binaries on the Windows PATH) ─────────────────────────────
#   Prometheus  : https://prometheus.io/download/
#   Tempo       : https://github.com/grafana/tempo/releases
#   Grafana     : winget install GrafanaLabs.Grafana
# ─────────────────────────────────────────────────────────────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir    = Join-Path $ScriptDir "logs"
$DataDir   = Join-Path $ScriptDir "data"

New-Item -ItemType Directory -Force -Path $LogDir                      | Out-Null
New-Item -ItemType Directory -Force -Path "$DataDir\prometheus"        | Out-Null
New-Item -ItemType Directory -Force -Path "$DataDir\grafana"           | Out-Null
New-Item -ItemType Directory -Force -Path "$DataDir\tempo\blocks"      | Out-Null
New-Item -ItemType Directory -Force -Path "$DataDir\tempo\wal"         | Out-Null
New-Item -ItemType Directory -Force -Path "$DataDir\tempo\generator\wal" | Out-Null

# ── Binary checks ─────────────────────────────────────────────────────────────
function Test-Binary($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Warning "'$name' introuvable dans le PATH."
        return $false
    }
    return $true
}

$missing = $false
foreach ($bin in @("prometheus", "tempo", "grafana")) {
    if (-not (Test-Binary $bin)) { $missing = $true }
}
if ($missing) {
    Write-Error "Des binaires sont manquants. Ajoutez-les au PATH et relancez."
    exit 1
}

# ── Stop existing processes ───────────────────────────────────────────────────
Write-Host "-> Arret des processus existants..."

# By name
foreach ($name in @("prometheus", "tempo", "grafana")) {
    Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
}

# By port (safety net if the name does not match)
foreach ($port in @(4318, 4317, 9090, 3200)) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
    }
}

Start-Sleep -Seconds 2

# ── Prometheus ────────────────────────────────────────────────────────────────
Write-Host "-> Demarrage Prometheus..."
$prom = Start-Process -FilePath "prometheus" `
    -ArgumentList (
        "--config.file=`"$ScriptDir\prometheus.yml`"",
        "--storage.tsdb.path=`"$DataDir\prometheus`"",
        "--web.listen-address=0.0.0.0:9090",
        "--web.enable-lifecycle",
        "--enable-feature=exemplar-storage",
        "--web.enable-otlp-receiver",
        "--web.enable-remote-write-receiver"
    ) `
    -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$LogDir\prometheus.log" `
    -RedirectStandardError  "$LogDir\prometheus-err.log"
Write-Host "  PID Prometheus : $($prom.Id)"
Start-Sleep -Seconds 1

# ── Tempo ─────────────────────────────────────────────────────────────────────
Write-Host "-> Demarrage Tempo..."
$tempo = Start-Process -FilePath "tempo" `
    -ArgumentList "-config.file=`"$ScriptDir\tempo.yml`"" `
    -WorkingDirectory $ScriptDir `
    -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$LogDir\tempo.log" `
    -RedirectStandardError  "$LogDir\tempo-err.log"
Write-Host "  PID Tempo : $($tempo.Id)"
Start-Sleep -Seconds 2

# ── Grafana ───────────────────────────────────────────────────────────────────
Write-Host "-> Demarrage Grafana..."

# Detect the Grafana homepath
$grafanaHome = $env:GRAFANA_HOMEPATH
if (-not $grafanaHome) {
    $candidates = @(
        "C:\Program Files\GrafanaLabs\grafana",
        "C:\grafana"
    )
    foreach ($c in $candidates) {
        if (Test-Path "$c\public") { $grafanaHome = $c; break }
    }
}
if (-not $grafanaHome) {
    # Derive it from the exe on the PATH: ..\bin\grafana.exe → ..
    $grafanaExe = (Get-Command "grafana" -ErrorAction SilentlyContinue).Source
    if ($grafanaExe) {
        $candidate = Split-Path -Parent (Split-Path -Parent $grafanaExe)
        if (Test-Path "$candidate\public") { $grafanaHome = $candidate }
    }
}
if (-not $grafanaHome -or -not (Test-Path "$grafanaHome\public")) {
    Write-Error "Impossible de localiser le homepath Grafana."
    Write-Error "Definissez `$env:GRAFANA_HOMEPATH=C:\chemin\vers\grafana et relancez."
    exit 1
}
Write-Host "  homepath : $grafanaHome"

$env:GF_PATHS_PROVISIONING    = "$ScriptDir\grafana\provisioning"
$env:GF_PATHS_DATA            = "$DataDir\grafana"
$env:GF_SERVER_HTTP_PORT      = "3000"
$env:GF_AUTH_ANONYMOUS_ENABLED    = "true"
$env:GF_AUTH_ANONYMOUS_ORG_ROLE   = "Admin"
$env:GF_AUTH_DISABLE_LOGIN_FORM   = "true"
$env:GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS = "netampowering-apm-panel"

$grafana = Start-Process -FilePath "grafana" `
    -ArgumentList "server --homepath=`"$grafanaHome`"" `
    -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$LogDir\grafana.log" `
    -RedirectStandardError  "$LogDir\grafana-err.log"
Write-Host "  PID Grafana : $($grafana.Id)"
Start-Sleep -Seconds 3

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Stack demarree :"
Write-Host ""
Write-Host "  Grafana        -> http://localhost:3000   (traces + metriques)"
Write-Host "  Prometheus     -> http://localhost:9090"
Write-Host "  Tempo          -> http://localhost:3200   (OTLP HTTP :4318)"
Write-Host "  Prometheus     -> OTLP metriques /api/v1/otlp/v1/metrics"
Write-Host ""
Write-Host "  Logs : $LogDir\"
Write-Host ""
Write-Host "  Pour demarrer l'app :"
Write-Host "  dotnet run --project NetAmpowering.Demo.Blazor\NetAmpowering.Demo.Blazor.csproj"
