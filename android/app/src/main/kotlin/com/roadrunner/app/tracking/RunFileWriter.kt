package com.roadrunner.app.tracking

import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.UUID

enum class RunFileState(val wireValue: String) {
    PAUSED("paused"),
    RUNNING("running"),
}

/**
 * Writes the v1 JSONL run format into app-private storage.
 *
 * Pass context.filesDir as appFilesDir. Use this writer from one service
 * worker thread so disk I/O does not hold up the UI.
 */
class RunFileWriter(
    appFilesDir: File,
    runId: UUID,
    startedAtUtcMs: Long,
) : Closeable {
    val file: File

    private val output: FileOutputStream
    private var nextSeq = 0
    private var pointsSinceSync = 0
    private var closed = false

    init {
        require(startedAtUtcMs > 0)

        val runsDir = File(appFilesDir, "runs")
        check(runsDir.isDirectory || runsDir.mkdirs()) {
            "Could not create runs directory"
        }

        file = File(runsDir, "$runId.jsonl")
        check(file.createNewFile()) {
            "Run file already exists: ${file.name}"
        }

        output = FileOutputStream(file, true)

        try {
            writeLine(
                """{"v":1,"runId":"$runId","startedAtUtcMs":$startedAtUtcMs}"""
            )
            sync()
        } catch (error: Exception) {
            output.close()
            file.delete()
            throw error
        }
    }

    @Synchronized
    fun appendPoint(fix: GpsFix, decision: FilterDecision) {
        ensureOpen()
        require(fix.tUtcMs > 0)
        require(fix.lat.isFinite() && fix.lon.isFinite())
        require(fix.accM.isFinite())
        require(fix.speedMps == null || fix.speedMps.isFinite())
        require(fix.altM == null || fix.altM.isFinite())

        val line = buildString {
            append("""{"k":"p","seq":""")
            append(nextSeq)
            append(""","t":""")
            append(fix.tUtcMs)
            append(""","lat":""")
            append(fix.lat)
            append(""","lon":""")
            append(fix.lon)
            append(""","acc":""")
            append(fix.accM)
            append(""","spd":""")
            append(fix.speedMps ?: "null")
            append(""","alt":""")
            append(fix.altM ?: "null")
            append(""","ok":""")
            append(decision.accepted)
            append('}')
        }

        writeLine(line)
        nextSeq++
        pointsSinceSync++

        // Each line is written immediately. Sync to storage every five fixes.
        if (pointsSinceSync >= 5) {
            sync()
        }
    }

    @Synchronized
    fun appendState(state: RunFileState, atUtcMs: Long) {
        ensureOpen()
        require(atUtcMs > 0)

        writeLine(
            """{"k":"s","t":$atUtcMs,"state":"${state.wireValue}"}"""
        )
        sync()
    }

    @Synchronized
    fun finish(endedAtUtcMs: Long) {
        ensureOpen()
        require(endedAtUtcMs > 0)

        writeLine("""{"k":"end","t":$endedAtUtcMs}""")
        close()
    }

    /**
     * Closing without finish() leaves an unfinished file for recovery.
     */
    @Synchronized
    override fun close() {
        if (closed) return

        try {
            sync()
        } finally {
            closed = true
            output.close()
        }
    }

    private fun ensureOpen() {
        check(!closed) { "Run file is closed" }
    }

    private fun writeLine(line: String) {
        output.write((line + "\n").toByteArray(StandardCharsets.UTF_8))
    }

    private fun sync() {
        output.fd.sync()
        pointsSinceSync = 0
    }
}   