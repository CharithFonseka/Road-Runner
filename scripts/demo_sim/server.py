#!/usr/bin/env python3
"""
Road Runner — Debug Live Map & Pace Demo Server.

Serves the Leaflet web UI on http://localhost:8765 and bridges live
speed/pace controls and GPS telemetry with the Android debug build
over `adb reverse tcp:8765 tcp:8765`.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import threading

PORT = int(os.environ.get("ROADRUNNER_SIM_PORT", "8765"))
STATIC_DIR = os.path.dirname(os.path.abspath(__file__))


class SimState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.target_speed_mps: float = 3.0  # ~10.8 km/h default jog
        self.telemetry: dict | None = None
        self.trail: list[dict] = []

    def get_control(self) -> dict:
        with self.lock:
            return {"targetSpeedMps": self.target_speed_mps}

    def set_control(self, payload: dict) -> dict:
        with self.lock:
            if "targetSpeedMps" in payload and payload["targetSpeedMps"] is not None:
                speed = float(payload["targetSpeedMps"])
                self.target_speed_mps = max(0.0, min(25.0, speed))
            if payload.get("resetTrail"):
                self.trail.clear()
                self.telemetry = None
            return {"targetSpeedMps": self.target_speed_mps}

    def add_telemetry(self, payload: dict) -> None:
        with self.lock:
            self.telemetry = payload
            lat = payload.get("lat")
            lon = payload.get("lon")
            if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
                self.trail.append(
                    {
                        "lat": lat,
                        "lon": lon,
                        "speedMps": payload.get("smoothedSpeedMps", 0.0),
                        "accepted": payload.get("accepted", True),
                    }
                )
                if len(self.trail) > 5000:
                    self.trail = self.trail[-5000:]

    def get_state(self) -> dict:
        with self.lock:
            return {
                "targetSpeedMps": self.target_speed_mps,
                "telemetry": self.telemetry,
                "trail": list(self.trail),
            }


STATE = SimState()


class DemoSimHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:  # noqa: A002
        # Keep console clean during live demo.
        pass

    def _send_json(self, status: int, data: dict) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            index_path = os.path.join(STATIC_DIR, "index.html")
            with open(index_path, "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path == "/control":
            self._send_json(200, STATE.get_control())
        elif path == "/state":
            self._send_json(200, STATE.get_state())
        else:
            self._send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        path = self.path.split("?", 1)[0]
        try:
            payload = self._read_json()
        except Exception:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        if path == "/control":
            updated = STATE.set_control(payload)
            self._send_json(200, updated)
        elif path == "/telemetry":
            STATE.add_telemetry(payload)
            self._send_json(200, {"ok": True})
        else:
            self._send_json(404, {"error": "Not found"})


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", PORT), DemoSimHandler)
    print(f"Road Runner Demo Simulator running at http://localhost:{PORT}")
    print("Run `adb reverse tcp:8765 tcp:8765` to connect your Android device/emulator.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
