#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Local observability stack — Grafana + Tempo + Pyroscope + Prometheus
#
#   Prometheus   → http://localhost:9090
#   Tempo        → http://localhost:3200  (traces backend)
#   Pyroscope    → http://localhost:4040  (profiling / flame graphs)
#   Grafana      → http://localhost:3000  (unified UI — traces, metrics, profiles)
#   Tempo (OTLP) → apps send traces to :4318 (HTTP) / :4317 (gRPC)
#   Prometheus   → apps send metrics to :9090/api/v1/otlp/v1/metrics
#
# ── Prerequisites (manual download, no Homebrew) ─────────────────────────────
#   Prometheus  : https://prometheus.io/download/
#   Tempo       : https://github.com/grafana/tempo/releases  ("tempo" binary)
#   Pyroscope   : https://github.com/grafana/pyroscope/releases  ("pyroscope" binary)
#   Grafana     : https://grafana.com/grafana/download  (tar.gz → extract, add bin/ to PATH)
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DATA_DIR="$SCRIPT_DIR/data"
mkdir -p "$LOG_DIR" "$DATA_DIR/prometheus" "$DATA_DIR/grafana" "$DATA_DIR/tempo/generator/wal"

# ── Checks ───────────────────────────────────────────────────────────────────
check_binary() {
  if ! command -v "$1" &>/dev/null; then
    echo "⚠️   '$1' introuvable — voir commentaires en haut de ce script."
    return 1
  fi
  return 0
}

MISSING=0
check_binary prometheus    || MISSING=1
check_binary tempo         || MISSING=1
check_binary grafana       || MISSING=1
PYROSCOPE_OK=0
check_binary pyroscope     && PYROSCOPE_OK=1

if [ "$MISSING" -eq 1 ]; then
  echo "❌  Des binaires sont manquants. Installez-les et relancez."
  exit 1
fi

# ── Stop existing processes ──────────────────────────────────────────────────
echo "→ Arrêt des processus existants..."
pkill -f "prometheus"       2>/dev/null
pkill -f "tempo"            2>/dev/null
pkill -f "pyroscope"        2>/dev/null
pkill -f "grafana"          2>/dev/null
sleep 1

# ── Prometheus ───────────────────────────────────────────────────────────────
echo "→ Démarrage Prometheus..."
prometheus \
  --config.file="$SCRIPT_DIR/prometheus.yml" \
  --storage.tsdb.path="$DATA_DIR/prometheus" \
  --web.listen-address="0.0.0.0:9090" \
  --web.enable-lifecycle \
  --enable-feature=exemplar-storage \
  --web.enable-otlp-receiver \
  --web.enable-remote-write-receiver \
  > "$LOG_DIR/prometheus.log" 2>&1 &
echo "  PID Prometheus : $!"
sleep 1

# ── Tempo ─────────────────────────────────────────────────────────────────────
echo "→ Démarrage Tempo..."
tempo -config.file="$SCRIPT_DIR/tempo.yml" \
  > "$LOG_DIR/tempo.log" 2>&1 &
echo "  PID Tempo : $!"
sleep 2

# ── Pyroscope (optional) ──────────────────────────────────────────────────────
if [ "$PYROSCOPE_OK" -eq 1 ]; then
  echo "→ Démarrage Pyroscope..."
  pyroscope \
    -pyroscopedb.data-path="$DATA_DIR/pyroscope" \
    -server.http-listen-port=4040 \
    -server.grpc-listen-port=9096 \
    > "$LOG_DIR/pyroscope.log" 2>&1 &
  echo "  PID Pyroscope : $!"
  sleep 1
else
  echo "⚠️   Pyroscope absent — flame graphs désactivés (le reste fonctionne)."
fi

# ── Grafana ───────────────────────────────────────────────────────────────────
echo "→ Démarrage Grafana..."

# Detect the homepath (Grafana installation directory)
GRAFANA_HOMEPATH=""
for candidate in \
    "$(command -v grafana 2>/dev/null | xargs -I{} dirname {} | xargs -I{} dirname {})" \
    "/opt/grafana-v11.6.0" \
    "/opt/grafana" \
    "/usr/share/grafana"; do
  if [ -d "$candidate/public" ]; then
    GRAFANA_HOMEPATH="$candidate"
    break
  fi
done

if [ -z "$GRAFANA_HOMEPATH" ]; then
  echo "❌  Impossible de localiser le homepath Grafana."
  echo "    Définissez GRAFANA_HOMEPATH dans votre shell et relancez :"
  echo "    GRAFANA_HOMEPATH=/chemin/vers/grafana ./start-observability.sh"
  exit 1
fi

echo "  homepath : $GRAFANA_HOMEPATH"

GF_PATHS_PROVISIONING="$SCRIPT_DIR/grafana/provisioning" \
GF_PATHS_DATA="$DATA_DIR/grafana" \
GF_SERVER_HTTP_PORT=3000 \
GF_AUTH_ANONYMOUS_ENABLED=true \
GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
GF_AUTH_DISABLE_LOGIN_FORM=true \
grafana server --homepath="$GRAFANA_HOMEPATH" \
  > "$LOG_DIR/grafana.log" 2>&1 &
echo "  PID Grafana : $!"
sleep 3

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "✅  Stack démarrée :"
echo ""
echo "    Grafana        → http://localhost:3000   (traces + métriques + profils)"
echo "    Prometheus     → http://localhost:9090"
echo "    Tempo          → http://localhost:3200"
if [ "$PYROSCOPE_OK" -eq 1 ]; then
echo "    Pyroscope      → http://localhost:4040   (flame graphs)"
fi
echo "    OTLP traces    → Tempo :4318 (HTTP) | :4317 (gRPC)"
echo "    OTLP métriques → Prometheus :9090/api/v1/otlp/v1/metrics"
echo ""
echo "    Logs : $LOG_DIR/"
echo ""
echo "    Pour les flame graphs .NET, lancer l'app avec :"
echo "    ./observability/run-with-profiling.sh"
echo ""
echo "    Sinon (traces + métriques uniquement) :"
echo "    dotnet run --project NetAmpowering.Demo.Blazor/NetAmpowering.Demo.Blazor.csproj"
