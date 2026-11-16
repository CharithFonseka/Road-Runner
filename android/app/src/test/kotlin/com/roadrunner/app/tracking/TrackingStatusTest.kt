package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Test

class TrackingStatusTest {
    @Test
    fun stoppedStatusReturnsRunFilePath() {
        val result = TrackingStatus(
            state = TrackingRunState.STOPPED,
            runId = "run-1",
            filePath = "/data/runs/run-1.jsonl",
        ).toControlMap()
        assertEquals("stopped", result["state"])
        assertEquals("/data/runs/run-1.jsonl", result["filePath"])
    }

    @Test
    fun runningStatusReturnsRunFilePathForRouteRecovery() {
        val result = TrackingStatus(
            state = TrackingRunState.RUNNING,
            runId = "run-1",
            filePath = "/data/runs/run-1.jsonl",
        ).toControlMap()
        assertEquals("/data/runs/run-1.jsonl", result["filePath"])
    }

    @Test
    fun liveSnapshotCarriesAcceptedPosition() {
        val result = LiveSnapshot(
            elapsedMs = 1000,
            movingMs = 1000,
            distanceM = 3.0,
            speedMps = 3.0,
            paceSecPerKm = 333.0,
            lat = -33.8688,
            lon = 151.2093,
            seq = 4,
        ).toMap()
        assertEquals(-33.8688, result["lat"])
        assertEquals(151.2093, result["lon"])
        assertEquals(4, result["seq"])
    }
}
