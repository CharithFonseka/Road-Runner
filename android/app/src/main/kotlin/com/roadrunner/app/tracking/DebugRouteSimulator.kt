package com.roadrunner.app.tracking

import android.content.Context
import android.content.pm.ApplicationInfo
import android.location.Location
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Debug-only GPS route simulator for repeatable indoor testing and live demos.
 *
 * Advances along a continuous ~1.18 km closed park loop at [targetSpeedMps],
 * optionally syncing live speed/pace controls and telemetry with the local
 * demo web app over `adb reverse tcp:8765 tcp:8765`.
 *
 * Strictly disabled in non-debuggable (release) builds.
 */
class DebugRouteSimulator {
    @Volatile
    private var targetSpeedMps: Double = DEFAULT_SPEED_MPS

    private var distanceAlongLoopM: Double = 0.0
    private val syncExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "RoadRunnerSimSync").apply { isDaemon = true }
    }

    fun nextLocation(timestampUtcMs: Long): Location {
        pollControlAsync()

        val speedMps = targetSpeedMps.coerceAtLeast(0.0)
        distanceAlongLoopM = (distanceAlongLoopM + speedMps) % LOOP.totalLengthM

        val (lat, lon) = LOOP.positionAt(distanceAlongLoopM)
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
            runCatching {
                val conn = (URL("$SERVER_BASE_URL/telemetry").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = HTTP_TIMEOUT_MS
                    readTimeout = HTTP_TIMEOUT_MS
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                }
                conn.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
                conn.responseCode
                conn.disconnect()
            }
        }
    }

    fun close() {
        syncExecutor.shutdownNow()
    }

    private fun pollControlAsync() {
        syncExecutor.execute {
            runCatching {
                val conn = (URL("$SERVER_BASE_URL/control").openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = HTTP_TIMEOUT_MS
                    readTimeout = HTTP_TIMEOUT_MS
                }
                if (conn.responseCode == 200) {
                    val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                    val json = JSONObject(body)
                    if (json.has("targetSpeedMps")) {
                        val next = json.optDouble("targetSpeedMps", targetSpeedMps)
                        if (next.isFinite() && next >= 0.0) {
                            targetSpeedMps = next
                        }
                    }
                }
                conn.disconnect()
            }
        }
    }

    private data class LoopPoint(
        val lat: Double,
        val lon: Double,
        val cumulativeM: Double,
    )

    private class ClosedLoop(val points: List<LoopPoint>, val totalLengthM: Double) {
        fun positionAt(distanceM: Double): Pair<Double, Double> {
            if (points.isEmpty()) return 6.9147 to 79.8612
            val target = ((distanceM % totalLengthM) + totalLengthM) % totalLengthM

            for (i in 1 until points.size) {
                val prev = points[i - 1]
                val next = points[i]
                if (target <= next.cumulativeM) {
                    val segLen = next.cumulativeM - prev.cumulativeM
                    val frac = if (segLen > 0.0) ((target - prev.cumulativeM) / segLen).coerceIn(0.0, 1.0) else 0.0
                    val lat = prev.lat + (next.lat - prev.lat) * frac
                    val lon = prev.lon + (next.lon - prev.lon) * frac
                    return lat to lon
                }
            }
            return points.first().lat to points.first().lon
        }
    }

    companion object {
        private const val PREFS_NAME = "roadrunner_debug_prefs"
        private const val KEY_SIM_ENABLED = "simulate_route"
        private const val DEFAULT_SPEED_MPS = 3.0 // ~10.8 km/h default jog
        private const val SERVER_BASE_URL = "http://127.0.0.1:8765"
        private const val HTTP_TIMEOUT_MS = 250

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

        private val LOOP: ClosedLoop = buildClosedLoop()

        private fun buildClosedLoop(): ClosedLoop {
            val centerLat = 6.9147
            val centerLon = 79.8612
            val metersPerDegLat = 111_132.0
            val metersPerDegLon = 111_132.0 * cos(Math.toRadians(centerLat))

            val steps = 128
            val radiusEastM = 210.0
            val radiusNorthM = 155.0

            val rawCoords = ArrayList<Pair<Double, Double>>(steps + 1)
            for (i in 0..steps) {
                val theta = (2.0 * PI * (i % steps)) / steps
                val eastM = radiusEastM * cos(theta) + 22.0 * sin(2.0 * theta)
                val northM = radiusNorthM * sin(theta) + 14.0 * cos(3.0 * theta)
                val lat = centerLat + (northM / metersPerDegLat)
                val lon = centerLon + (eastM / metersPerDegLon)
                rawCoords.add(lat to lon)
            }

            val points = ArrayList<LoopPoint>(rawCoords.size)
            var cumulative = 0.0
            points.add(LoopPoint(rawCoords[0].first, rawCoords[0].second, 0.0))
            for (i in 1 until rawCoords.size) {
                val prev = rawCoords[i - 1]
                val curr = rawCoords[i]
                cumulative += haversineMeters(prev.first, prev.second, curr.first, curr.second)
                points.add(LoopPoint(curr.first, curr.second, cumulative))
            }
            return ClosedLoop(points = points, totalLengthM = cumulative.coerceAtLeast(1.0))
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
