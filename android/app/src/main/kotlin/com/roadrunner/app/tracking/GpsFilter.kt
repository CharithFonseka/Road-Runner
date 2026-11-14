package com.roadrunner.app.tracking

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

data class GpsFix(
    val tUtcMs: Long,
    val lat: Double,
    val lon: Double,
    val accM: Double,
    val speedMps: Double?,
    val altM: Double?,
    val isMock: Boolean,
)

enum class RejectionReason {
    INVALID_FIX,
    MOCK_LOCATION,
    POOR_ACCURACY,
    OLD_FIX,
    IMPOSSIBLE_JUMP,
    STATIONARY_JITTER,
}

data class FilterDecision(
    val accepted: Boolean,
    val addedDistanceM: Double = 0.0,
    val reason: RejectionReason? = null,
)

class GpsFilter {
    private var lastAccepted: GpsFix? = null
    private var firstFixAfterResume = false

    /**
     * Call when tracking resumes. The next accepted fix becomes a new
     * starting position, so movement during the pause adds no distance.
     */
    fun markResumed() {
        firstFixAfterResume = true
    }

    fun evaluate(fix: GpsFix): FilterDecision {
        if (!isValid(fix)) {
            return rejected(RejectionReason.INVALID_FIX)
        }
        if (fix.isMock) {
            return rejected(RejectionReason.MOCK_LOCATION)
        }
        if (fix.accM > FilterConfig.MAX_ACCURACY_M) {
            return rejected(RejectionReason.POOR_ACCURACY)
        }

        val previous = lastAccepted

        // A run starts counting position only after a fix better than 20 m.
        if (previous == null) {
            if (fix.accM >= FilterConfig.FIRST_FIX_MAX_ACCURACY_M) {
                return rejected(RejectionReason.POOR_ACCURACY)
            }
            lastAccepted = fix
            firstFixAfterResume = false
            return FilterDecision(accepted = true)
        }

        if (fix.tUtcMs <= previous.tUtcMs) {
            return rejected(RejectionReason.OLD_FIX)
        }

        // Do not connect the pre-pause point to the post-pause point.
        if (firstFixAfterResume) {
            lastAccepted = fix
            firstFixAfterResume = false
            return FilterDecision(accepted = true)
        }

        val distanceM = haversineM(previous, fix)
        val seconds = (fix.tUtcMs - previous.tUtcMs) / 1_000.0
        val impliedSpeedMps = distanceM / seconds

        // This check also applies to gaps longer than 10 seconds.
        if (impliedSpeedMps > FilterConfig.MAX_IMPLIED_SPEED_MPS) {
            return rejected(RejectionReason.IMPOSSIBLE_JUMP)
        }

        val speedMps = fix.speedMps ?: impliedSpeedMps
        if (
            speedMps < FilterConfig.STATIONARY_SPEED_MPS &&
            distanceM < FilterConfig.TINY_MOVE_M
        ) {
            return rejected(RejectionReason.STATIONARY_JITTER)
        }

        lastAccepted = fix
        return FilterDecision(
            accepted = true,
            addedDistanceM = distanceM,
        )
    }

    private fun isValid(fix: GpsFix): Boolean =
        fix.tUtcMs > 0 &&
            fix.lat.isFinite() && fix.lat in -90.0..90.0 &&
            fix.lon.isFinite() && fix.lon in -180.0..180.0 &&
            fix.accM.isFinite() && fix.accM >= 0.0 &&
            (fix.speedMps == null ||
                (fix.speedMps.isFinite() && fix.speedMps >= 0.0)) &&
            (fix.altM == null || fix.altM.isFinite())

    private fun haversineM(a: GpsFix, b: GpsFix): Double {
        val lat1 = Math.toRadians(a.lat)
        val lat2 = Math.toRadians(b.lat)
        val dLat = lat2 - lat1
        val dLon = Math.toRadians(b.lon - a.lon)

        val sinHalfLat = sin(dLat / 2.0)
        val sinHalfLon = sin(dLon / 2.0)
        val h = (
            sinHalfLat * sinHalfLat +
                cos(lat1) * cos(lat2) * sinHalfLon * sinHalfLon
            ).coerceIn(0.0, 1.0)

        return 2.0 * FilterConfig.EARTH_RADIUS_M *
            atan2(sqrt(h), sqrt(1.0 - h))
    }

    private fun rejected(reason: RejectionReason) =
        FilterDecision(accepted = false, reason = reason)
}