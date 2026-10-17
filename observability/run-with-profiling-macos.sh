#!/bin/bash
# =============================================================================
# Runs the Blazor app with:
#   - OTLP traces + metrics -> Grafana Cloud (Tempo / Prometheus)
#   - continuous CPU profiling via dotnet-trace: capture every 30s,
#     pprof conversion, real-time push to Grafana Cloud Pyroscope
#
# Prerequisite:
#   dotnet tool install --global dotnet-trace
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../NetAmpowering.Demo.Blazor"
PROFILES_DIR="$SCRIPT_DIR/profiles"
ENV_FILE="$SCRIPT_DIR/.env"
PROFILING_INTERVAL=30

mkdir -p "$PROFILES_DIR"

# -- Loading the .env file ----------------------------------------------------
if [[ -f "$ENV_FILE" ]]; then
  echo "-> Chargement des credentials depuis .env"
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key// /}" ]] && continue
    key="${key// /}"; value="${value// /}"
    export "$key=$value"
  done < "$ENV_FILE"
fi

# -- Reading credentials ------------------------------------------------------
read_credential() {
  local var="$1" prompt="$2" secret="${3:-false}"
  local val="${!var:-}"
  if [[ -n "$val" ]]; then echo "$val"; return; fi
  if [[ "$secret" == "true" ]]; then
    read -rs -p "$prompt: " val; echo "" >&2
  else
    read -r -p "$prompt: " val
  fi
  echo "$val"
}

echo ""
echo "=== Grafana Cloud credentials ==="
echo "    (My Account -> Grafana Cloud -> [Tempo | Prometheus | Pyroscope])"
echo ""

API_TOKEN=$(read_credential "GRAFANA_API_TOKEN" "API token (glc_eyJ...)" true)

echo ""
echo "--- Tempo (traces) ---"
TEMPO_INSTANCE_ID=$(read_credential   "GRAFANA_TEMPO_INSTANCE_ID"   "  Instance ID Tempo")
TEMPO_OTLP_ENDPOINT=$(read_credential "GRAFANA_TEMPO_OTLP_ENDPOINT" "  OTLP endpoint Tempo (https://tempo-prod-X.grafana.net/otlp/v1/traces)")

echo ""
echo "--- Prometheus / Mimir (metriques) ---"
PROMETHEUS_INSTANCE_ID=$(read_credential   "GRAFANA_PROMETHEUS_INSTANCE_ID"   "  Instance ID Prometheus")
PROMETHEUS_OTLP_ENDPOINT=$(read_credential "GRAFANA_PROMETHEUS_OTLP_ENDPOINT" "  OTLP endpoint Prometheus (https://prometheus-prod-X.grafana.net/otlp/v1/metrics)")

echo ""
echo "--- Pyroscope (profils CPU) ---"
PYROSCOPE_INSTANCE_ID=$(read_credential "GRAFANA_PYROSCOPE_INSTANCE_ID" "  Instance ID Pyroscope")
PYROSCOPE_URL=$(read_credential         "GRAFANA_PYROSCOPE_URL"         "  Push URL Pyroscope (https://profiles-prod-XXX.grafana.net)")

echo ""
echo "================================="
echo ""

# -- dotnet-trace check -------------------------------------------------------
if ! command -v dotnet-trace &>/dev/null; then
  echo "WARN: dotnet-trace introuvable -- profiling CPU desactive."
  echo "      dotnet tool install --global dotnet-trace"
  echo ""
  DOTNET_TRACE_AVAILABLE=false
else
  DOTNET_TRACE_AVAILABLE=true
fi

# -- Basic Auth ---------------------------------------------------------------
traces_b64=$(echo -n "${TEMPO_INSTANCE_ID}:${API_TOKEN}" | base64)
metrics_b64=$(echo -n "${PROMETHEUS_INSTANCE_ID}:${API_TOKEN}" | base64)
pyroscope_b64=$(echo -n "${PYROSCOPE_INSTANCE_ID}:${API_TOKEN}" | base64)

# -- OTel and runtime variables ----------------------------------------------------------
# Development: enables static web assets (CSS isolation bundle) and detailed errors.
export ASPNETCORE_ENVIRONMENT=Development
export OpenTelemetry__Enabled=true
export OpenTelemetry__OtlpEndpoint="$TEMPO_OTLP_ENDPOINT"
export OpenTelemetry__OtlpHeaders="Authorization=Basic ${traces_b64}"
export OpenTelemetry__OtlpMetricsEndpoint="$PROMETHEUS_OTLP_ENDPOINT"
export OpenTelemetry__OtlpMetricsHeaders="Authorization=Basic ${metrics_b64}"
export OpenTelemetry__SamplingProbability=1.0

echo "-> Traces    : $TEMPO_OTLP_ENDPOINT (instance $TEMPO_INSTANCE_ID)"
echo "-> Metriques : $PROMETHEUS_OTLP_ENDPOINT (instance $PROMETHEUS_INSTANCE_ID)"
echo "-> Pyroscope : $PYROSCOPE_URL (instance $PYROSCOPE_INSTANCE_ID)"
echo ""

# -- Project build ------------------------------------------------------------
echo "-> Build..."
dotnet build "$PROJECT_DIR/NetAmpowering.Demo.Blazor.csproj" -q

DLL_PATH=$(find "$PROJECT_DIR/bin" -name "NetAmpowering.Demo.Blazor.dll" | sort -r | head -1)
if [[ -z "$DLL_PATH" ]]; then
  echo "ERREUR: DLL introuvable apres le build."
  exit 1
fi

# -- App launch ---------------------------------------------------------------
echo "-> Lancement de l'app..."
(cd "$PROJECT_DIR" && dotnet exec "$DLL_PATH") &
APP_PID=$!
echo "   PID : $APP_PID"

# -- Cleanup on exit ----------------------------------------------------------
cleanup() {
  echo ""
  echo "-> Arret..."
  kill "$APP_PID" 2>/dev/null || true
  unset ASPNETCORE_ENVIRONMENT
  unset OpenTelemetry__Enabled OpenTelemetry__OtlpEndpoint OpenTelemetry__OtlpHeaders
  unset OpenTelemetry__OtlpMetricsEndpoint OpenTelemetry__OtlpMetricsHeaders
  unset OpenTelemetry__SamplingProbability
}
trap cleanup EXIT INT TERM

# -- Push function: nettrace -> Speedscope JSON -> collapsed -> Pyroscope ----
send_profile() {
  local trace_file="$1" start_ts="$2" end_ts="$3"
  local base="${trace_file%.nettrace}"
  local speedscope_file="${base}.speedscope.json"

  # 1. Conversion nettrace -> Speedscope JSON
  if ! dotnet-trace convert "$trace_file" --format Speedscope --output "$base" 2>/dev/null; then
    echo "  [$(date '+%H:%M:%S')] Conversion Speedscope echouee"
    rm -f "$trace_file"; return
  fi

  # 2. Speedscope JSON -> collapsed stacks via Python (available natively on macOS)
  local collapsed
  collapsed=$(python3 - "$speedscope_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
frames = data["shared"]["frames"]
lines = []
for profile in data["profiles"]:
    if profile["type"] == "sampled":
        for sample in profile["samples"]:
            stack = ";".join(frames[i]["name"] for i in sample)
            lines.append(f"{stack} 1")
    elif profile["type"] == "evented":
        # Windows ETW format: O=push, C=pop pairs
        ev_stack, peak_stack, peak_reached = [], None, False
        for ev in profile["events"]:
            if ev["type"] == "O":
                ev_stack.append(ev["frame"])
                peak_reached = False
            elif ev["type"] == "C":
                if not peak_reached and ev_stack:
                    peak_stack = ev_stack[:]
                    peak_reached = True
                if ev_stack:
                    ev_stack.pop()
                if not ev_stack and peak_stack:
                    lines.append(";".join(frames[i]["name"] for i in peak_stack) + " 1")
                    peak_stack, peak_reached = None, False
print("\n".join(lines))
PYEOF
)

  local count
  count=$(echo "$collapsed" | wc -l | tr -d ' ')

  # 3. Push to Grafana Cloud Pyroscope (collapsed format)
  local url="${PYROSCOPE_URL}/pyroscope/ingest?name=namp-ampowering.cpu&from=${start_ts}&until=${end_ts}&format=collapsed&sampleRate=100"
  local http_status
  http_status=$(echo "$collapsed" | curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$url" \
    -H "Authorization: Basic ${pyroscope_b64}" \
    -H "Content-Type: text/plain" \
    --data-binary @-)

  local dur=$(( end_ts - start_ts ))
  if [[ "$http_status" == "200" || "$http_status" == "204" || "$http_status" == "422" ]]; then
    echo "  [$(date '+%H:%M:%S')] ${count} samples envoyes (${dur}s, HTTP $http_status)"
  else
    echo "  [$(date '+%H:%M:%S')] Push echoue HTTP $http_status (${dur}s)"
  fi

  rm -f "$trace_file" "$speedscope_file"
}

# -- Continuous profiling loop ------------------------------------------------
if [[ "$DOTNET_TRACE_AVAILABLE" == "true" ]]; then
  # Wait for the app to be ready
  echo "-> Attente du demarrage de l'app..."
  ready=false
  for i in $(seq 1 20); do
    sleep 1
    if dotnet-trace ps 2>/dev/null | grep -q "$APP_PID"; then
      ready=true; break
    fi
    kill -0 "$APP_PID" 2>/dev/null || break
  done

  if [[ "$ready" == "true" ]]; then
    echo "-> Profiling continu (toutes les ${PROFILING_INTERVAL}s). Ctrl+C pour arreter."
    echo ""

    while kill -0 "$APP_PID" 2>/dev/null; do
      start_ts=$(date +%s)
      trace_file="$PROFILES_DIR/blazor_$(date '+%H%M%S').nettrace"

      dotnet-trace collect \
        --process-id "$APP_PID" \
        --duration "00:00:${PROFILING_INTERVAL}" \
        --profile "dotnet-sampled-thread-time" \
        --output "$trace_file" 2>/dev/null || true

      end_ts=$(date +%s)

      [[ -f "$trace_file" ]] && send_profile "$trace_file" "$start_ts" "$end_ts"
    done
  else
    echo "WARN: App non detectee par dotnet-trace -- profiling desactive."
  fi
fi

wait "$APP_PID" 2>/dev/null || true
