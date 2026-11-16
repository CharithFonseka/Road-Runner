package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
    fun runningStatusDoesNotReturnRunFilePath() {
        val result = TrackingStatus(
            state = TrackingRunState.RUNNING,
            runId = "run-1",
            filePath = "/data/runs/run-1.jsonl",
        ).toControlMap()
        assertFalse(result.containsKey("filePath"))
    }
}
