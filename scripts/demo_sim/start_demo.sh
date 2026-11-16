#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${ROADRUNNER_SIM_PORT:-8765}"

ADB_BIN="$(command -v adb || true)"
if [[ -z "$ADB_BIN" && -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
fi

if [[ -n "$ADB_BIN" ]]; then
  DEVICES="$("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$DEVICES" ]]; then
    while IFS= read -r serial; do
      echo "Forwarding port ${PORT} to ${serial}..."
      "$ADB_BIN" -s "$serial" reverse "tcp:${PORT}" "tcp:${PORT}" || true
    done <<< "$DEVICES"
  else
    echo "Warning: No connected Android device/emulator found for adb reverse."
    echo "Note: Android Emulators can still connect automatically via 10.0.2.2:${PORT}."
  fi
else
  echo "Warning: adb not found. Skipping adb reverse."
fi

URL="http://localhost:${PORT}"
echo "Opening ${URL} in your browser..."
(sleep 1 && open "$URL") &

exec python3 "${SCRIPT_DIR}/server.py"
