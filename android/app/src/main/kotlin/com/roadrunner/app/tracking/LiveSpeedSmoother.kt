package com.roadrunner.app.tracking

/**
 * Smooths live speed over roughly five one-second fixes.
 * Uses the location's reported speed when available, together with
 * speed calculated from accepted distance.
 */
class LiveSpeedSmoother {
    private var previousFixUtcMs: Long? = null
    private var previousFixMonotonicMs: Long? = null
    private var smoothedMps = 0.0
    private var hasEstimate = false

    fun accepted(
        addedDistanceM: Double,
        fixUtcMs: Long,
        nowMonotonicMs: Long,
        reportedSpeedMps: Double? = null,
    ) {
        require(addedDistanceM.isFinite() && addedDistanceM >= 0.0)

        val previousMonotonic = previousFixMonotonicMs
        if (
            previousMonotonic != null &&
            nowMonotonicMs - previousMonotonic > STALE_AFTER_MS
        ) {
            reset()
        }

        val previousUtc = previousFixUtcMs
        if (previousUtc != null && fixUtcMs > previousUtc) {
            val seconds = (fixUtcMs - previousUtc) / 1_000.0
            val positionSpeedMps =
                (addedDistanceM / seconds)
                    .coerceIn(0.0, FilterConfig.MAX_IMPLIED_SPEED_MPS)

            val deviceSpeedMps =
                reportedSpeedMps
                    ?.takeIf { it.isFinite() && it >= 0.0 }
                    ?.coerceAtMost(FilterConfig.MAX_IMPLIED_SPEED_MPS)

            val measuredMps = when {
                deviceSpeedMps != null &&
                    deviceSpeedMps < FilterConfig.STATIONARY_SPEED_MPS -> 0.0
                deviceSpeedMps != null ->
                    0.75 * deviceSpeedMps + 0.25 * positionSpeedMps
                else -> positionSpeedMps
            }

            // Start from zero rather than trusting one noisy GPS segment fully.
            smoothedMps = 0.33 * measuredMps + 0.67 * smoothedMps
            hasEstimate = true
        }

        previousFixUtcMs = fixUtcMs
        previousFixMonotonicMs = nowMonotonicMs
    }

    fun rejected() {
        if (!hasEstimate) return
        smoothedMps = (smoothedMps * 0.5).takeIf { it >= 0.1 } ?: 0.0
    }

    fun speedMps(nowMonotonicMs: Long): Double {
        val last = previousFixMonotonicMs ?: return 0.0
        if (!hasEstimate || nowMonotonicMs - last > STALE_AFTER_MS) {
            return 0.0
        }
        return smoothedMps
    }

    fun reset() {
        previousFixUtcMs = null
        previousFixMonotonicMs = null
        smoothedMps = 0.0
        hasEstimate = false
    }

    companion object {
        private const val STALE_AFTER_MS = 5_000L

        fun paceSecPerKm(speedMps: Double): Double? {
            if (speedMps < 0.5) return null
            val pace = 1_000.0 / speedMps
            return pace.takeIf { it <= 20.0 * 60.0 }
        }
    }
}