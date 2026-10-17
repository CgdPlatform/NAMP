#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Runs the Blazor app with Pyroscope continuous profiling enabled (Linux only)
#
# The native Pyroscope .NET profiler only supports Linux (glibc/musl).
# On macOS, use run-with-profiling-macos.sh (dotnet-trace).
#
# In-process architecture (since the Pyroscope NuGet migration):
#   • CORECLR_* loads the native profiler into the .NET process at startup.
#   • The managed SDK (Pyroscope NuGet) then controls internally:
#       - which profiling types are active (CPU, allocation…)
#       - the labels/tags sent to Pyroscope (environment, host, version)
#   • These behaviours are driven by appsettings.Development.json through
#     the "Features:Pyroscope" feature flag and the "Pyroscope" section.
#   • PYROSCOPE_APPLICATION_NAME and PYROSCOPE_SERVER_ADDRESS remain
#     environment variables because the native CLR profiler needs them to
#     know where to send the data — they cannot come from managed code.
#
# Prerequisite — download the native profiler from:
#   https://github.com/grafana/pyroscope-dotnet/releases
#
# Pick according to your Linux distribution:
#   glibc (Ubuntu, Debian, Fedora, RHEL) → pyroscope.0.15.0-glibc-x86_64.tar.gz
#   musl  (Alpine)                        → pyroscope.0.15.0-musl-x86_64.tar.gz
#   ARM64 glibc                           → pyroscope.0.15.0-glibc-aarch64.tar.gz
#
# Extract into observability/profiler/:
#   mkdir -p observability/profiler
#   tar -xzf pyroscope.0.15.0-glibc-x86_64.tar.gz -C observability/profiler/
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../NetAmpowering.Demo.Blazor"
PROFILER_DIR="$SCRIPT_DIR/profiler"

# ── OS check ──────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "❌  Ce script est réservé à Linux."
  echo "    Sur macOS, utilisez : ./run-with-profiling-macos.sh"
  exit 1
fi

# ── Native profiler detection ─────────────────────────────────────────────────
PROFILER_LIB=$(find "$PROFILER_DIR" -name "Pyroscope.Profiler.Native.so" 2>/dev/null | head -1)

if [ -z "$PROFILER_LIB" ]; then
  echo "❌  Pyroscope.Profiler.Native.so introuvable dans : $PROFILER_DIR"
  echo ""
  echo "    Téléchargez le profiler natif depuis :"
  echo "    https://github.com/grafana/pyroscope-dotnet/releases"
  echo ""
  ARCH=$(uname -m)
  if [ "$ARCH" = "aarch64" ]; then
    echo "    Architecture détectée : ARM64"
    echo "    → pyroscope.0.15.0-glibc-aarch64.tar.gz  (glibc : Ubuntu, Debian…)"
    echo "    → pyroscope.0.15.0-musl-aarch64.tar.gz   (musl : Alpine)"
  else
    echo "    Architecture détectée : x86_64"
    echo "    → pyroscope.0.15.0-glibc-x86_64.tar.gz   (glibc : Ubuntu, Debian…)"
    echo "    → pyroscope.0.15.0-musl-x86_64.tar.gz    (musl : Alpine)"
  fi
  echo ""
  echo "    Puis :"
  echo "    mkdir -p observability/profiler"
  echo "    tar -xzf pyroscope.0.15.0-glibc-x86_64.tar.gz -C observability/profiler/"
  exit 1
fi

echo "→ Profiler natif : $PROFILER_LIB"
echo "→ Lancement avec profiling CPU activé..."
echo "   Pyroscope UI → http://localhost:4040"
echo ""

CORECLR_ENABLE_PROFILING=1 \
CORECLR_PROFILER="{BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}" \
CORECLR_PROFILER_PATH="$PROFILER_LIB" \
PYROSCOPE_APPLICATION_NAME="namp-ampowering" \
PYROSCOPE_SERVER_ADDRESS="http://localhost:4040" \
dotnet run --project "$PROJECT_DIR/NetAmpowering.Demo.Blazor.csproj"
