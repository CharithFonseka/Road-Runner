#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${ROADRUNNER_SIM_PORT:-8765}"

ADB_BIN="$(command -v adb || true)"
if [[ -z "$ADB_BIN" && -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
fi

if [[ -n "$ADB_BIN" ]]; then
  echo "Setting up USB port forwarding (adb reverse tcp:${PORT} tcp:${PORT})..."
  if "$ADB_BIN" reverse "tcp:${PORT}" "tcp:${PORT}"; then
    echo "Connected device/emulator forwarded."
  else
    echo "Warning: No connected Android device/emulator found for adb reverse."
    echo "Plug in your phone (USB debugging on) or start an emulator, then re-run this script."
  fi
else
  echo "Warning: adb not found. Skipping adb reverse."
fi

URL="http://localhost:${PORT}"
echo "Opening ${URL} in your browser..."
(sleep 1 && open "$URL") &

exec python3 "${SCRIPT_DIR}/server.py"
