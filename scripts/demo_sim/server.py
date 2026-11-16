#!/usr/bin/env python3
"""
Road Runner — Debug Live Map & Random Street Route Demo Server.

Serves the Leaflet web UI on http://localhost:8765, generates random
real-street routes using OSRM foot routing (with local route caching and
offline fallback), and bridges live speed/pace controls and GPS telemetry
with the Android debug build over `adb reverse tcp:8765 tcp:8765`.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
import random
import threading
import time
import urllib.request

PORT = int(os.environ.get("ROADRUNNER_SIM_PORT", "8765"))
STATIC_DIR = os.path.dirname(os.path.abspath(__file__))
ROUTES_CACHE_PATH = os.path.join(STATIC_DIR, "osm_routes_cache.json")
CENTER_LAT = 6.9147
CENTER_LON = 79.8612


def fetch_osrm_random_route() -> list[list[float]] | None:
    """Picks 5 random waypoints around the park/streets and routes via OSRM."""
    m_per_deg_lat = 111_132.0
    m_per_deg_lon = 111_132.0 * math.cos(math.radians(CENTER_LAT))

    # Pick random angles in order around the center so the route forms a natural loop.
    base_angle = random.uniform(0, 2 * math.pi)
    waypoints: list[str] = []
    for k in range(5):
        angle = base_angle + (2 * math.pi * k / 5.0) + random.uniform(-0.35, 0.35)
        radius_m = random.uniform(220.0, 520.0)
        lat = CENTER_LAT + (radius_m * math.sin(angle)) / m_per_deg_lat
        lon = CENTER_LON + (radius_m * math.cos(angle)) / m_per_deg_lon
        waypoints.append(f"{lon:.6f},{lat:.6f}")
    waypoints.append(waypoints[0])  # close the loop

    url = (
        "https://router.project-osrm.org/route/v1/foot/"
        + ";".join(waypoints)
        + "?overview=full&geometries=geojson"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "RoadRunnerDemoSim/1.0"})
    with urllib.request.urlopen(req, timeout=6) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    if data.get("code") != "Ok" or not data.get("routes"):
        return None

    coords = data["routes"][0]["geometry"]["coordinates"]
    if len(coords) < 5:
        return None
    # GeoJSON is [lon, lat]; convert to [lat, lon]
    return [[float(c[1]), float(c[0])] for c in coords]


def load_cached_routes() -> list[list[list[float]]]:
    if os.path.exists(ROUTES_CACHE_PATH):
        try:
            with open(ROUTES_CACHE_PATH, "r", encoding="utf-8") as f:
                routes = json.load(f)
            if isinstance(routes, list) and routes:
                return routes
        except Exception:
            pass
    return []


def save_cached_route(route: list[list[float]]) -> None:
    routes = load_cached_routes()
    routes.append(route)
    if len(routes) > 20:
        routes = routes[-20:]
    try:
        with open(ROUTES_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(routes, f)
    except Exception:
        pass


def build_fallback_street_walk() -> list[list[float]]:
    """Offline fallback street-grid walk around Viharamahadevi Park, Colombo."""
    lat0, lon0 = 6.9125, 79.8585
    d_lat, d_lon = 0.0011, 0.0012
    r, c = 2, 2
    prev = None
    pts = [[lat0 + r * d_lat, lon0 + c * d_lon]]
    for _ in range(22):
        opts = [
            (r + dr, c + dc)
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))
            if 0 <= r + dr <= 4 and 0 <= c + dc <= 4
        ]
        choices = [o for o in opts if o != prev] or opts
        nr, nc = random.choice(choices)
        prev = (r, c)
        r, c = nr, nc
        pts.append([lat0 + r * d_lat, lon0 + c * d_lon])
    return pts


def generate_random_route() -> list[list[float]]:
    try:
        route = fetch_osrm_random_route()
        if route is not None:
            save_cached_route(route)
            return route
    except Exception as exc:
        print(f"OSRM route fetch unavailable ({exc}); checking local cache.")

    cached = load_cached_routes()
    if cached:
        return random.choice(cached)
    return build_fallback_street_walk()


class SimState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.target_speed_mps: float = 3.0  # ~10.8 km/h default jog
        self.route_id: int = int(time.time() * 1000)
        self.route_points: list[list[float]] = generate_random_route()
        self.telemetry: dict | None = None
        self.last_telemetry_at: float = 0.0
        self.trail: list[dict] = []

    def get_control(self) -> dict:
        with self.lock:
            return {
                "targetSpeedMps": self.target_speed_mps,
                "routeId": self.route_id,
            }

    def get_route(self) -> dict:
        with self.lock:
            return {
                "routeId": self.route_id,
                "points": list(self.route_points),
            }

    def set_control(self, payload: dict) -> dict:
        if payload.get("newRoute"):
            new_points = generate_random_route()
            with self.lock:
                if "targetSpeedMps" in payload and payload["targetSpeedMps"] is not None:
                    speed = float(payload["targetSpeedMps"])
                    self.target_speed_mps = max(0.0, min(25.0, speed))
                self.route_id += 1
                self.route_points = new_points
                self.trail.clear()
                self.telemetry = None
                return {
                    "targetSpeedMps": self.target_speed_mps,
                    "routeId": self.route_id,
                }

        with self.lock:
            if "targetSpeedMps" in payload and payload["targetSpeedMps"] is not None:
                speed = float(payload["targetSpeedMps"])
                self.target_speed_mps = max(0.0, min(25.0, speed))
            if payload.get("resetTrail"):
                self.trail.clear()
                self.telemetry = None
            return {
                "targetSpeedMps": self.target_speed_mps,
                "routeId": self.route_id,
            }

    def add_telemetry(self, payload: dict) -> dict:
        with self.lock:
            self.telemetry = payload
            self.last_telemetry_at = time.time()
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
            return {
                "targetSpeedMps": self.target_speed_mps,
                "routeId": self.route_id,
            }

    def get_state(self) -> dict:
        with self.lock:
            connected = (time.time() - self.last_telemetry_at) < 4.0 if self.last_telemetry_at > 0 else False
            return {
                "targetSpeedMps": self.target_speed_mps,
                "routeId": self.route_id,
                "connected": connected,
                "telemetry": self.telemetry,
                "trail": list(self.trail),
            }


STATE: SimState | None = None


class DemoSimHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:  # noqa: A002
        pass

    def _send_json(self, status: int, data: dict) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:
        assert STATE is not None
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
        elif path == "/route":
            self._send_json(200, STATE.get_route())
        elif path == "/state":
            self._send_json(200, STATE.get_state())
        else:
            self._send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        assert STATE is not None
        path = self.path.split("?", 1)[0]
        try:
            payload = self._read_json()
        except Exception:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        if path == "/control":
            updated = STATE.set_control(payload)
            self._send_json(200, updated)
        elif path == "/sync":
            control = STATE.add_telemetry(payload)
            self._send_json(200, control)
        elif path == "/telemetry":
            STATE.add_telemetry(payload)
            self._send_json(200, {"ok": True})
        else:
            self._send_json(404, {"error": "Not found"})


def main() -> None:
    global STATE
    STATE = SimState()
    print(f"Generated random street route with {len(STATE.route_points)} points.")
    server = ThreadingHTTPServer(("0.0.0.0", PORT), DemoSimHandler)
    print(f"Road Runner Demo Simulator running at http://localhost:{PORT}")
    print("Run `adb reverse tcp:8765 tcp:8765` to connect your Android device/emulator.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
