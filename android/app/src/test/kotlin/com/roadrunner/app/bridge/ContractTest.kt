package com.roadrunner.app.bridge

import org.junit.Assert.assertEquals
import org.junit.Test

class ContractTest {
    @Test
    fun channelsAndMethodsMatchSrs() {
        assertEquals("roadrunner/control", Contract.CONTROL_CHANNEL)
        assertEquals("roadrunner/events", Contract.EVENTS_CHANNEL)
        assertEquals("startRun", Contract.METHOD_START_RUN)
        assertEquals("pauseRun", Contract.METHOD_PAUSE_RUN)
        assertEquals("resumeRun", Contract.METHOD_RESUME_RUN)
        assertEquals("stopRun", Contract.METHOD_STOP_RUN)
        assertEquals("getState", Contract.METHOD_GET_STATE)
        assertEquals("getUnfinishedRun", Contract.METHOD_GET_UNFINISHED_RUN)
        assertEquals("discardRun", Contract.METHOD_DISCARD_RUN)
    }

    @Test
    fun filterAndCalcThresholdsMatchSrs() {
        assertEquals(25.0, Contract.MAX_ACCURACY_M, 0.0001)
        assertEquals(20.0, Contract.FIRST_FIX_MAX_ACCURACY_M, 0.0001)
        assertEquals(12.0, Contract.MAX_IMPLIED_SPEED_MPS, 0.0001)
        assertEquals(0.5, Contract.STATIONARY_SPEED_MPS, 0.0001)
        assertEquals(2.0, Contract.TINY_MOVE_M, 0.0001)
        assertEquals(10, Contract.MAX_GAP_SECONDS)
        assertEquals(6_371_000.0, Contract.EARTH_RADIUS_M, 0.0001)
        assertEquals(50.0, Contract.MIN_DISTANCE_FOR_PACE_M, 0.0001)
        assertEquals(0.5, Contract.MIN_SPEED_FOR_PACE_MPS, 0.0001)
        assertEquals(1200.0, Contract.MAX_PACE_SEC_PER_KM, 0.0001)
        assertEquals(1000.0, Contract.SPLIT_DISTANCE_M, 0.0001)
        assertEquals(5, Contract.SPEED_SMOOTHING_WINDOW_S)
    }
}
