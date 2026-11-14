package com.roadrunner.app.tracking

import java.nio.file.Files
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RunRecoveryTest {
    private val appFilesDir =
        Files.createTempDirectory("road-runner-recovery").toFile()

    @Before
    fun resetState() {
        TrackingApi.publishState(TrackingRunState.IDLE, null)
    }

    @After
    fun cleanUp() {
        TrackingApi.publishState(TrackingRunState.IDLE, null)
        appFilesDir.deleteRecursively()
    }

    @Test
    fun closedWithoutEndIsFound() {
        val runId = UUID.randomUUID()
        val writer = RunFileWriter(appFilesDir, runId, 1_000)
        writer.close()

        val unfinished = RunRecovery.findLatest(appFilesDir)

        assertEquals(runId.toString(), unfinished?.runId)
        assertEquals(writer.file.canonicalPath, unfinished?.filePath)
    }

    @Test
    fun completedRunIsNotOffered() {
        val writer = RunFileWriter(
            appFilesDir,
            UUID.randomUUID(),
            1_000,
        )
        writer.finish(2_000)

        assertNull(RunRecovery.findLatest(appFilesDir))
    }

    @Test
    fun activeRunCannotBeRecoveredOrDiscarded() {
        val runId = UUID.randomUUID()
        val writer = RunFileWriter(appFilesDir, runId, 1_000)
        TrackingApi.publishState(
            TrackingRunState.RUNNING,
            runId.toString(),
        )

        assertNull(RunRecovery.findLatest(appFilesDir))
        assertFalse(
            RunRecovery.discardUnfinished(
                appFilesDir,
                runId.toString(),
            )
        )

        writer.close()
    }

    @Test
    fun unfinishedFileCanBeDiscarded() {
        val runId = UUID.randomUUID()
        val writer = RunFileWriter(appFilesDir, runId, 1_000)
        writer.close()

        assertTrue(
            RunRecovery.discardUnfinished(
                appFilesDir,
                runId.toString(),
            )
        )
        assertFalse(writer.file.exists())
    }

    @Test
    fun partialLastLineStillCountsAsUnfinished() {
        val runId = UUID.randomUUID()
        val writer = RunFileWriter(appFilesDir, runId, 1_000)
        writer.close()
        writer.file.appendText("""{"k":"p","seq":1""")

        assertEquals(
            runId.toString(),
            RunRecovery.findLatest(appFilesDir)?.runId,
        )
    }
}