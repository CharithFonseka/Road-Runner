package com.roadrunner.app.tracking

import java.nio.file.Files
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RunFileWriterTest {
    @Test
    fun writesHeaderPointsStatesAndEndInOrder() {
        val appFilesDir = Files.createTempDirectory("road-runner-test").toFile()
        try {
            val runId = UUID.fromString(
                "123e4567-e89b-12d3-a456-426614174000"
            )
            val writer = RunFileWriter(appFilesDir, runId, 1_000)

            val fix = GpsFix(
                tUtcMs = 2_000,
                lat = 6.9271,
                lon = 79.8612,
                accM = 8.0,
                speedMps = null,
                altM = null,
                isMock = false,
            )

            val acceptedSeq = writer.appendPoint(fix, FilterDecision(accepted = true))
            val rejectedSeq = writer.appendPoint(
                fix.copy(tUtcMs = 3_000),
                FilterDecision(
                    accepted = false,
                    reason = RejectionReason.STATIONARY_JITTER,
                ),
            )
            writer.appendState(RunFileState.PAUSED, 4_000)
            writer.appendState(RunFileState.RUNNING, 5_000)
            writer.finish(6_000)

            assertEquals(0, acceptedSeq)
            assertEquals(1, rejectedSeq)

            val lines = writer.file.readLines()
            assertEquals(6, lines.size)
            assertEquals(
                """{"v":1,"runId":"$runId","startedAtUtcMs":1000}""",
                lines[0],
            )
            assertTrue(lines[1].contains(""""seq":0"""))
            assertTrue(lines[1].contains(""""spd":null"""))
            assertTrue(lines[1].contains(""""ok":true"""))
            assertTrue(lines[2].contains(""""seq":1"""))
            assertTrue(lines[2].contains(""""ok":false"""))
            assertEquals(
                """{"k":"s","t":4000,"state":"paused"}""",
                lines[3],
            )
            assertEquals(
                """{"k":"s","t":5000,"state":"running"}""",
                lines[4],
            )
            assertEquals("""{"k":"end","t":6000}""", lines[5])
        } finally {
            appFilesDir.deleteRecursively()
        }
    }

    @Test
    fun closeWithoutFinishLeavesUnfinishedRun() {
        val appFilesDir = Files.createTempDirectory("road-runner-test").toFile()
        try {
            val writer = RunFileWriter(
                appFilesDir,
                UUID.randomUUID(),
                1_000,
            )
            writer.close()

            val lines = writer.file.readLines()
            assertEquals(1, lines.size)
            assertFalse(lines.last().contains(""""k":"end""""))
        } finally {
            appFilesDir.deleteRecursively()
        }
    }
}
