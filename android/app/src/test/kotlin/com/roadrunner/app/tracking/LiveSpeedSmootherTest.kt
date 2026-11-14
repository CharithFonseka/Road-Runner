package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LiveSpeedSmootherTest {
    @Test
    fun startsAtZeroThenUsesAcceptedDistance() {
        val smoother = LiveSpeedSmoother()

        smoother.accepted(0.0, 1_000, 1_000)
        assertEquals(0.0, smoother.speedMps(1_000), 0.001)

        smoother.accepted(10.0, 2_000, 2_000)
        assertEquals(10.0, smoother.speedMps(2_000), 0.001)
        assertEquals(0.0, smoother.speedMps(7_001), 0.001)
    }

    @Test
    fun resetRemovesPrePauseSpeed() {
        val smoother = LiveSpeedSmoother()
        smoother.accepted(0.0, 1_000, 1_000)
        smoother.accepted(5.0, 2_000, 2_000)

        smoother.reset()
        smoother.accepted(0.0, 20_000, 20_000)

        assertEquals(0.0, smoother.speedMps(20_000), 0.001)
    }

    @Test
    fun paceFollowsDisplayLimits() {
        assertEquals(
            500.0,
            LiveSpeedSmoother.paceSecPerKm(2.0)!!,
            0.001,
        )
        assertNull(LiveSpeedSmoother.paceSecPerKm(0.5))
    }
}   