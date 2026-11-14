package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Test

class RunClockTest {
    @Test
    fun movingTimeFreezesDuringPauseAndAfterStop() {
        val clock = RunClock(startedMonotonicMs = 10_000)

        assertEquals(RunTime(4_000, 4_000), clock.snapshot(14_000))

        clock.pause(14_000)
        assertEquals(RunTime(10_000, 4_000), clock.snapshot(20_000))

        clock.resume(22_000)
        assertEquals(RunTime(13_000, 5_000), clock.snapshot(23_000))

        clock.stop(25_000)
        assertEquals(RunTime(15_000, 7_000), clock.snapshot(40_000))
    }
}