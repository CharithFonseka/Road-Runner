package com.roadrunner.app.tracking

/**
 * Smooths segment speed with an EMA of roughly five one-second fixes.
 * It uses distance accepted by GpsFilter, not rejected GPS movement.
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
    ) {
        require(addedDistanceM.isFinite() && addedDistanceM >= 0.0)

        val previousMonotonic = previousFixMonotonicMs
        if (
            previousMonotonic != null &&
            nowMonotonicMs - previousMonotonic > STALE_AFTER_MS
        ) {
            previousFixUtcMs = null
            smoothedMps = 0.0
            hasEstimate = false
        }

        val previousUtc = previousFixUtcMs
        if (previousUtc != null && fixUtcMs > previousUtc) {
            val seconds = (fixUtcMs - previousUtc) / 1_000.0
            val measuredMps =
                (addedDistanceM / seconds)
                    .coerceIn(0.0, FilterConfig.MAX_IMPLIED_SPEED_MPS)

            smoothedMps =
                if (hasEstimate) {
                    0.33 * measuredMps + 0.67 * smoothedMps
                } else {
                    measuredMps
                }
            hasEstimate = true
        }

        previousFixUtcMs = fixUtcMs
        previousFixMonotonicMs = nowMonotonicMs
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