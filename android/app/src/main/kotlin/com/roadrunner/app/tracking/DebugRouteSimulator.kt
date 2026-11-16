package com.roadrunner.app.tracking

import android.content.Context
import android.content.pm.ApplicationInfo
import android.location.Location
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Debug-only GPS route simulator for repeatable indoor testing and live demos.
 *
 * Fetches a randomized real-street route from the local demo server (`GET /route`)
 * before emitting the first fix so there is zero mid-run jump/teleport, and
 * syncs speed controls + telemetry in a single `POST /sync` round-trip.
 * Automatically tries `127.0.0.1:8765` (USB `adb reverse`) and `10.0.2.2:8765`
 * (Android Emulator host bridge).
 *
 * Strictly disabled in non-debuggable (release) builds.
 */
class DebugRouteSimulator {
    @Volatile
    private var targetSpeedMps: Double = DEFAULT_SPEED_MPS

    @Volatile
    private var activeBaseUrl: String? = null

    @Volatile
    private var activePath: StreetPath = buildFallbackStreetWalk()

    private var distanceAlongPathM: Double = 0.0
    private var prepared = false
    private val syncInFlight = AtomicBoolean(false)
    private val syncExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "RoadRunnerSimSync").apply { isDaemon = true }
    }

    /**
     * Loads the active street route and initial target speed from the demo
     * server before the first fix is generated, preventing any mid-run jump.
     * Safe to call on the recorder's background worker thread.
     */
    fun prepare() {
        if (prepared) return
        prepared = true

        val baseUrl = resolveServerUrl() ?: return
        activeBaseUrl = baseUrl

        runCatching {
            val ctrlConn = openGet("$baseUrl/control", INITIAL_TIMEOUT_MS)
            if (ctrlConn.responseCode == 200) {
                val ctrlJson = JSONObject(ctrlConn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
                if (ctrlJson.has("targetSpeedMps")) {
                    val next = ctrlJson.optDouble("targetSpeedMps", targetSpeedMps)
                    if (next.isFinite() && next >= 0.0) {
                        targetSpeedMps = next
                    }
                }
            }
            ctrlConn.disconnect()
        }

        runCatching {
            val routeConn = openGet("$baseUrl/route", INITIAL_TIMEOUT_MS)
            if (routeConn.responseCode == 200) {
                val body = routeConn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val json = JSONObject(body)
                val pointsArray = json.optJSONArray("points")
                if (pointsArray != null && pointsArray.length() >= 2) {
                    val coords = ArrayList<Pair<Double, Double>>(pointsArray.length())
                    for (i in 0 until pointsArray.length()) {
                        val pt = pointsArray.optJSONArray(i) ?: continue
                        if (pt.length() >= 2) {
                            coords.add(pt.getDouble(0) to pt.getDouble(1))
                        }
                    }
                    if (coords.size >= 2) {
                        activePath = buildStreetPath(coords)
                        distanceAlongPathM = 0.0
                    }
                }
            }
            routeConn.disconnect()
        }
    }

    fun nextLocation(timestampUtcMs: Long): Location {
        if (!prepared) prepare()

        val speedMps = targetSpeedMps.coerceAtLeast(0.0)
        distanceAlongPathM += speedMps

        val (lat, lon) = activePath.positionAt(distanceAlongPathM)
        return Location("gps").apply {
            latitude = lat
            longitude = lon
            accuracy = 5.2f
            speed = speedMps.toFloat()
            altitude = 12.0
            time = timestampUtcMs
        }
    }

    fun reportTelemetry(
        lat: Double,
        lon: Double,
        distanceM: Double,
        movingMs: Long,
        smoothedSpeedMps: Double,
        paceSecPerKm: Double?,
        accepted: Boolean,
        reason: String?,
    ) {
        if (!syncInFlight.compareAndSet(false, true)) return

        val payload = JSONObject().apply {
            put("lat", lat)
            put("lon", lon)
            put("distanceM", distanceM)
            put("movingMs", movingMs)
            put("smoothedSpeedMps", smoothedSpeedMps)
            if (paceSecPerKm != null && paceSecPerKm.isFinite()) {
                put("paceSecPerKm", paceSecPerKm)
            } else {
                put("paceSecPerKm", JSONObject.NULL)
            }
            put("accepted", accepted)
            if (reason != null) {
                put("reason", reason)
            }
        }.toString()

        syncExecutor.execute {
            try {
                val baseUrl = activeBaseUrl ?: resolveServerUrl()?.also { activeBaseUrl = it } ?: return@execute
                val conn = (URL("$baseUrl/sync").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = SYNC_TIMEOUT_MS
                    readTimeout = SYNC_TIMEOUT_MS
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    setRequestProperty("Connection", "close")
                }
                conn.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
                if (conn.responseCode == 200) {
                    val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                    val json = JSONObject(body)
                    if (json.has("targetSpeedMps")) {
                        val next = json.optDouble("targetSpeedMps", targetSpeedMps)
                        if (next.isFinite() && next >= 0.0) {
                            targetSpeedMps = next
                        }
                    }
                } else {
                    activeBaseUrl = null
                }
                conn.disconnect()
            } catch (_: Exception) {
                // Re-resolve host on next tick in case adb reverse was re-established.
                activeBaseUrl = null
            } finally {
                syncInFlight.set(false)
            }
        }
    }

    fun close() {
        syncExecutor.shutdownNow()
    }

    private fun resolveServerUrl(): String? {
        for (candidate in SERVER_CANDIDATES) {
            val ok = runCatching {
                val conn = openGet("$candidate/control", PROBE_TIMEOUT_MS)
                val code = conn.responseCode
                conn.disconnect()
                code == 200
            }.getOrDefault(false)
            if (ok) return candidate
        }
        return null
    }

    private fun openGet(url: String, timeoutMs: Int): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = timeoutMs
            readTimeout = timeoutMs
            setRequestProperty("Connection", "close")
        }

    private data class PathNode(
        val lat: Double,
        val lon: Double,
        val cumulativeM: Double,
    )

    private class StreetPath(val nodes: List<PathNode>, val totalLengthM: Double) {
        private val isClosedLoop: Boolean =
            nodes.size >= 2 &&
                haversineMeters(
                    nodes.first().lat,
                    nodes.first().lon,
                    nodes.last().lat,
                    nodes.last().lon,
                ) <= 25.0

        fun positionAt(distanceM: Double): Pair<Double, Double> {
            if (nodes.isEmpty()) return 6.9147 to 79.8612
            if (nodes.size == 1 || totalLengthM <= 0.0) return nodes[0].lat to nodes[0].lon

            val target = if (isClosedLoop) {
                ((distanceM % totalLengthM) + totalLengthM) % totalLengthM
            } else {
                val cycle = totalLengthM * 2.0
                val mod = ((distanceM % cycle) + cycle) % cycle
                if (mod <= totalLengthM) mod else cycle - mod
            }

            for (i in 1 until nodes.size) {
                val prev = nodes[i - 1]
                val next = nodes[i]
                if (target <= next.cumulativeM) {
                    val segLen = next.cumulativeM - prev.cumulativeM
                    val frac = if (segLen > 0.0) ((target - prev.cumulativeM) / segLen).coerceIn(0.0, 1.0) else 0.0
                    val lat = prev.lat + (next.lat - prev.lat) * frac
                    val lon = prev.lon + (next.lon - prev.lon) * frac
                    return lat to lon
                }
            }
            return nodes.last().lat to nodes.last().lon
        }
    }

    companion object {
        private const val PREFS_NAME = "roadrunner_debug_prefs"
        private const val KEY_SIM_ENABLED = "simulate_route"
        private const val DEFAULT_SPEED_MPS = 3.0 // ~10.8 km/h default jog
        private val SERVER_CANDIDATES = listOf(
            "http://127.0.0.1:8765", // USB adb reverse (physical phone or emulator)
            "http://10.0.2.2:8765",  // Android Emulator direct host bridge
        )
        private const val PROBE_TIMEOUT_MS = 450
        private const val INITIAL_TIMEOUT_MS = 1_500
        private const val SYNC_TIMEOUT_MS = 1_200

        fun isDebuggable(context: Context): Boolean =
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

        fun isEnabled(context: Context): Boolean {
            if (!isDebuggable(context)) return false
            return context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_SIM_ENABLED, false)
        }

        fun setEnabled(context: Context, enabled: Boolean) {
            if (!isDebuggable(context)) return
            context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_SIM_ENABLED, enabled)
                .apply()
        }

        private fun buildStreetPath(coords: List<Pair<Double, Double>>): StreetPath {
            val nodes = ArrayList<PathNode>(coords.size)
            var cumulative = 0.0
            nodes.add(PathNode(coords[0].first, coords[0].second, 0.0))
            for (i in 1 until coords.size) {
                val prev = coords[i - 1]
                val curr = coords[i]
                cumulative += haversineMeters(prev.first, prev.second, curr.first, curr.second)
                nodes.add(PathNode(curr.first, curr.second, cumulative))
            }
            return StreetPath(nodes = nodes, totalLengthM = cumulative.coerceAtLeast(1.0))
        }

        private fun buildFallbackStreetWalk(): StreetPath {
            val lat0 = 6.9125
            val lon0 = 79.8585
            val dLat = 0.0011
            val dLon = 0.0012
            var r = 2
            var c = 2
            var prevR = -1
            var prevC = -1
            val rng = Random.Default
            val coords = ArrayList<Pair<Double, Double>>(24)
            coords.add((lat0 + r * dLat) to (lon0 + c * dLon))

            repeat(22) {
                val options = listOf(1 to 0, -1 to 0, 0 to 1, 0 to -1)
                    .map { (dr, dc) -> (r + dr) to (c + dc) }
                    .filter { (nr, nc) -> nr in 0..4 && nc in 0..4 }
                val nonBacktrack = options.filter { (nr, nc) -> nr != prevR || nc != prevC }
                val (nr, nc) = (if (nonBacktrack.isNotEmpty()) nonBacktrack else options).random(rng)
                prevR = r
                prevC = c
                r = nr
                c = nc
                coords.add((lat0 + r * dLat) to (lon0 + c * dLon))
            }
            return buildStreetPath(coords)
        }

        private fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val rLat1 = Math.toRadians(lat1)
            val rLat2 = Math.toRadians(lat2)
            val dLat = rLat2 - rLat1
            val dLon = Math.toRadians(lon2 - lon1)
            val sinLat = sin(dLat / 2.0)
            val sinLon = sin(dLon / 2.0)
            val h = (sinLat * sinLat + cos(rLat1) * cos(rLat2) * sinLon * sinLon).coerceIn(0.0, 1.0)
            return 2.0 * FilterConfig.EARTH_RADIUS_M * atan2(sqrt(h), sqrt(1.0 - h))
        }
    }
}
