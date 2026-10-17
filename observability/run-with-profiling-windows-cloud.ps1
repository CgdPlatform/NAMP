# =============================================================================
# Runs the Blazor app with:
#   - OTLP traces + metrics -> Grafana Cloud (Tempo / Prometheus)
#   - continuous CPU profiling via dotnet-trace: capture every 30s,
#     pprof conversion, real-time push to Grafana Cloud Pyroscope
#
# Prerequisite:
#   dotnet tool install --global dotnet-trace
# =============================================================================

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir   = Join-Path $ScriptDir "..\NetAmpowering.Demo.Blazor"
$SolutionPath = Join-Path $ScriptDir "..\NetAmpowering.sln"
$ProfilesDir  = Join-Path $ScriptDir "profiles"
$EnvFile      = Join-Path $ScriptDir ".env"
$ProfilingIntervalSeconds = 30

New-Item -ItemType Directory -Force -Path $ProfilesDir | Out-Null

# -- OS check -----------------------------------------------------------------
if ($IsWindows -eq $false) {
    Write-Error "Ce script est reserve a Windows."
    exit 1
}

# -- Loading the .env file ----------------------------------------------------
if (Test-Path $EnvFile) {
    Write-Host "-> Chargement des credentials depuis .env"
    Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#][^=]+)=(.*)$' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        $key = $key.Trim(); $value = $value.Trim()
        Set-Item "Env:\$key" $value
    }
}

# -- Reading credentials ------------------------------------------------------
function Read-Credential($EnvVar, $Prompt, $Secret = $false) {
    $val = [Environment]::GetEnvironmentVariable($EnvVar)
    if ($val) { return $val }
    if ($Secret) {
        $val = Read-Host $Prompt -AsSecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($val))
    }
    return Read-Host $Prompt
}

Write-Host ""
Write-Host "=== Grafana Cloud credentials ==="
Write-Host "    (My Account --> Grafana Cloud --> [Tempo | Prometheus | Pyroscope])"
Write-Host ""

$ApiToken = Read-Credential "GRAFANA_API_TOKEN" "API token (glc_eyJ...)" -Secret $true

Write-Host ""
Write-Host "--- Tempo (traces) ---"
$TempoInstanceId   = Read-Credential "GRAFANA_TEMPO_INSTANCE_ID"   "  Instance ID Tempo"
$TempoOtlpEndpoint = Read-Credential "GRAFANA_TEMPO_OTLP_ENDPOINT" "  OTLP endpoint Tempo (https://tempo-prod-X.grafana.net/otlp/v1/traces)"

Write-Host ""
Write-Host "--- Prometheus / Mimir (metriques) ---"
$PrometheusInstanceId   = Read-Credential "GRAFANA_PROMETHEUS_INSTANCE_ID"   "  Instance ID Prometheus"
$PrometheusOtlpEndpoint = Read-Credential "GRAFANA_PROMETHEUS_OTLP_ENDPOINT" "  OTLP endpoint Prometheus (https://prometheus-prod-X.grafana.net/otlp/v1/metrics)"

Write-Host ""
Write-Host "--- Pyroscope (profils CPU) ---"
$PyroscopeInstanceId = Read-Credential "GRAFANA_PYROSCOPE_INSTANCE_ID" "  Instance ID Pyroscope"
$PyroscopeUrl        = Read-Credential "GRAFANA_PYROSCOPE_URL"         "  Push URL Pyroscope (https://profiles-prod-XXX.grafana.net)"

Write-Host ""
Write-Host "================================="
Write-Host ""

# -- dotnet-trace check -------------------------------------------------------
$DotnetTraceAvailable = $null -ne (Get-Command dotnet-trace -ErrorAction SilentlyContinue)
if (-not $DotnetTraceAvailable) {
    Write-Warning "dotnet-trace introuvable -- profiling CPU desactive."
    Write-Warning "  dotnet tool install --global dotnet-trace"
    Write-Host ""
}

# -- Basic Auth ---------------------------------------------------------------
function New-BasicHeader($User, $Pass) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${User}:${Pass}"))
    return "Authorization=Basic $b64"
}
function New-B64($User, $Pass) {
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${User}:${Pass}"))
}

$TracesAuthHeader  = New-BasicHeader $TempoInstanceId      $ApiToken
$MetricsAuthHeader = New-BasicHeader $PrometheusInstanceId $ApiToken
$PyroscopeB64      = New-B64         $PyroscopeInstanceId  $ApiToken
$PyroscopeUrl      = $PyroscopeUrl.TrimEnd('/')

# -- OTel and runtime variables ----------------------------------------------------------
# Development: enables static web assets (CSS isolation bundle) and detailed errors.
# The OTel credentials below override appsettings.json, so the environment does not affect the export.
$env:ASPNETCORE_ENVIRONMENT             = "Development"
$env:OpenTelemetry__Enabled             = "true"
$env:OpenTelemetry__OtlpEndpoint        = $TempoOtlpEndpoint
$env:OpenTelemetry__OtlpHeaders         = $TracesAuthHeader
$env:OpenTelemetry__OtlpMetricsEndpoint = $PrometheusOtlpEndpoint
$env:OpenTelemetry__OtlpMetricsHeaders  = $MetricsAuthHeader
$env:OpenTelemetry__SamplingProbability = "1.0"

Write-Host "-> Traces    : $TempoOtlpEndpoint (instance $TempoInstanceId)"
Write-Host "-> Metriques : $PrometheusOtlpEndpoint (instance $PrometheusInstanceId)"
Write-Host "-> Pyroscope : $PyroscopeUrl (instance $PyroscopeInstanceId)"
Write-Host ""

# -- Project build ------------------------------------------------------------
Write-Host "-> Build..."
dotnet build $SolutionPath --no-incremental -verbosity:minimal
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build echoue."
    exit 1
}

$DllPath = Get-ChildItem -Path "$ProjectDir\bin" -Filter "NetAmpowering.Demo.Blazor.dll" -Recurse |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (-not $DllPath) { Write-Error "DLL introuvable apres le build."; exit 1 }

# -- App launch ---------------------------------------------------------------
Write-Host "-> Lancement de l'app..."
$AppProcess = Start-Process -FilePath "dotnet" -ArgumentList "exec", "`"$DllPath`"" `
              -PassThru -NoNewWindow -WorkingDirectory $ProjectDir
$AppPid = $AppProcess.Id
Write-Host "   PID : $AppPid"

# -- Push function: nettrace -> Speedscope JSON -> collapsed -> Pyroscope ----
function Send-Profile($TraceFile, $StartTs, $EndTs) {
    # dotnet-trace appends ".speedscope.json" to the base name -- pass it without extension
    $speedscopeBase = Join-Path ([IO.Path]::GetDirectoryName($TraceFile)) `
                                ([IO.Path]::GetFileNameWithoutExtension($TraceFile))
    $speedscopeFile = $speedscopeBase + ".speedscope.json"
    try {
        # 1. Conversion nettrace -> Speedscope JSON
        dotnet-trace convert $TraceFile --format Speedscope --output $speedscopeBase 2>$null
        if (-not (Test-Path $speedscopeFile)) { return }

        # 2. Speedscope JSON -> collapsed stacks (text format "stack;frame count")
        $data   = Get-Content $speedscopeFile -Raw | ConvertFrom-Json
        $frames = $data.shared.frames
        $lines  = [System.Collections.Generic.List[string]]::new()

        foreach ($prof in @($data.profiles)) {
            if ($prof.type -eq "sampled") {
                # macOS / earlier format
                for ($i = 0; $i -lt $prof.samples.Count; $i++) {
                    $stackStr = ($prof.samples[$i] | ForEach-Object { $frames[$_].name }) -join ";"
                    $lines.Add("$stackStr 1")
                }
            } elseif ($prof.type -eq "evented") {
                # Windows ETW -- O/C pairs: O=push, C=pop
                # Capture the stack at its peak (1st C after a run of O), emit when the stack is empty
                $evStack    = [System.Collections.Generic.List[int]]::new()
                $peakStack  = $null
                $peakReached = $false

                foreach ($ev in @($prof.events)) {
                    if ($ev.type -eq "O") {
                        $evStack.Add([int]$ev.frame)
                        $peakReached = $false
                    } elseif ($ev.type -eq "C") {
                        if (-not $peakReached -and $evStack.Count -gt 0) {
                            $peakStack   = $evStack.ToArray()
                            $peakReached = $true
                        }
                        if ($evStack.Count -gt 0) { $evStack.RemoveAt($evStack.Count - 1) }
                        if ($evStack.Count -eq 0 -and $null -ne $peakStack) {
                            $stackStr = ($peakStack | ForEach-Object { $frames[$_].name }) -join ";"
                            $lines.Add("$stackStr 1")
                            $peakStack   = $null
                            $peakReached = $false
                        }
                    }
                }
            }
        }
        if ($lines.Count -eq 0) { Write-Warning "  Aucun sample CPU dans la trace -- skip."; return }

        # 3. Push to Grafana Cloud Pyroscope (collapsed format)
        $body = [Text.Encoding]::UTF8.GetBytes($lines -join "`n")
        $url  = "${PyroscopeUrl}/pyroscope/ingest" +
                "?name=namp-ampowering.cpu" +
                "&from=${StartTs}&until=${EndTs}" +
                "&format=collapsed&sampleRate=100"
        Invoke-WebRequest -Uri $url -Method POST `
            -Headers @{ "Authorization" = "Basic $PyroscopeB64" } `
            -ContentType "text/plain" `
            -Body $body -UseBasicParsing | Out-Null

        $dur = $EndTs - $StartTs
        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] $($lines.Count) samples envoyes (${dur}s)"
    } catch {
        Write-Warning "  Push echoue : $($_.Exception.Message)"
    } finally {
        Remove-Item $TraceFile      -ErrorAction SilentlyContinue
        Remove-Item $speedscopeFile -ErrorAction SilentlyContinue
    }
}

# -- Continuous profiling loop ------------------------------------------------
try {
    if ($DotnetTraceAvailable) {
        # Wait for the app to be ready
        Write-Host "-> Attente du demarrage de l'app..."
        $ready = $false
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 1
            $psOut = & dotnet-trace ps 2>$null
            if ($psOut -match [regex]::Escape($AppPid.ToString())) { $ready = $true; break }
            if ($AppProcess.HasExited) { break }
        }

        if (-not $ready) {
            Write-Warning "App non detectee par dotnet-trace -- profiling desactive."
        } else {
            Write-Host "-> Profiling continu (toutes les ${ProfilingIntervalSeconds}s). Ctrl+C pour arreter."
            Write-Host ""

            while (-not $AppProcess.HasExited) {
                $startTs   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $traceFile = Join-Path $ProfilesDir "blazor_$(Get-Date -Format 'HHmmss').nettrace"
                $duration  = "00:00:$ProfilingIntervalSeconds"

                dotnet-trace collect `
                    --process-id $AppPid `
                    --duration $duration `
                    --profile "dotnet-sampled-thread-time" `
                    --output $traceFile 2>$null

                $endTs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

                if (Test-Path $traceFile) {
                    Send-Profile $traceFile $startTs $endTs
                }
            }
        }
    }

    # If there is no dotnet-trace or the app has already stopped, wait for the app
    if (-not $AppProcess.HasExited) {
        Write-Host "-> Ctrl+C pour arreter."
        $AppProcess.WaitForExit()
    }

} finally {
    if (-not $AppProcess.HasExited) { Stop-Process -Id $AppPid -ErrorAction SilentlyContinue }

    Remove-Item Env:\ASPNETCORE_ENVIRONMENT              -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__Enabled             -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpEndpoint        -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpHeaders         -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpMetricsEndpoint -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__OtlpMetricsHeaders  -ErrorAction SilentlyContinue
    Remove-Item Env:\OpenTelemetry__SamplingProbability -ErrorAction SilentlyContinue
}
