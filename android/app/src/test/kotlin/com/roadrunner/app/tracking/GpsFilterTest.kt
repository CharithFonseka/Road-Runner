package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GpsFilterTest {
    private fun fix(
        timeMs: Long,
        lon: Double = 79.8612,
        accuracyM: Double = 5.0,
        speedMps: Double? = 2.0,
        mock: Boolean = false,
    ) = GpsFix(
        tUtcMs = timeMs,
        lat = 6.9271,
        lon = lon,
        accM = accuracyM,
        speedMps = speedMps,
        altM = null,
        isMock = mock,
    )

    @Test
    fun firstFixNeedsAccuracyBetterThanTwentyMeters() {
        val filter = GpsFilter()

        assertFalse(filter.evaluate(fix(1_000, accuracyM = 20.0)).accepted)

        val firstGoodFix = filter.evaluate(fix(2_000, accuracyM = 19.0))
        assertTrue(firstGoodFix.accepted)
        assertEquals(0.0, firstGoodFix.addedDistanceM, 0.001)
    }

    @Test
    fun laterFixAddsDistanceButPoorAccuracyDoesNot() {
        val filter = GpsFilter()
        filter.evaluate(fix(1_000))

        val good = filter.evaluate(fix(6_000, lon = 79.8613))
        assertTrue(good.accepted)
        assertTrue(good.addedDistanceM > 10.0)

        val poor = filter.evaluate(
            fix(7_000, lon = 79.8614, accuracyM = 25.1)
        )
        assertEquals(RejectionReason.POOR_ACCURACY, poor.reason)
    }

    @Test
    fun rejectsMockFixAndImpossibleJump() {
        val filter = GpsFilter()
        filter.evaluate(fix(1_000))

        assertEquals(
            RejectionReason.MOCK_LOCATION,
            filter.evaluate(fix(2_000, mock = true)).reason,
        )
        assertEquals(
            RejectionReason.IMPOSSIBLE_JUMP,
            filter.evaluate(fix(2_000, lon = 79.8712)).reason,
        )
    }

    @Test
    fun ignoresSmallStationaryJitter() {
        val filter = GpsFilter()
        filter.evaluate(fix(1_000))

        val jitter = filter.evaluate(
            fix(3_000, lon = 79.861205, speedMps = 0.2)
        )
        assertEquals(RejectionReason.STATIONARY_JITTER, jitter.reason)
    }

    @Test
    fun firstFixAfterResumeAddsNoDistance() {
        val filter = GpsFilter()
        filter.evaluate(fix(1_000))
        filter.markResumed()

        val resumed = filter.evaluate(fix(61_000, lon = 79.8712))
        assertTrue(resumed.accepted)
        assertEquals(0.0, resumed.addedDistanceM, 0.001)

        val next = filter.evaluate(fix(66_000, lon = 79.8713))
        assertTrue(next.addedDistanceM > 10.0)
    }

    @Test
    fun reasonableMovementAcrossLongGapCounts() {
        val filter = GpsFilter()
        filter.evaluate(fix(1_000))

        val afterGap = filter.evaluate(fix(16_000, lon = 79.8615))
        assertTrue(afterGap.accepted)
        assertTrue(afterGap.addedDistanceM > 30.0)
    }
}