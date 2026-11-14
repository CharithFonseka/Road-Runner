package com.roadrunner.app.tracking

import java.io.File
import java.io.RandomAccessFile
import java.nio.charset.StandardCharsets
import java.util.UUID

data class UnfinishedRun(
    val runId: String,
    val filePath: String,
) {
    fun toControlMap(): Map<String, String> = mapOf(
        "runId" to runId,
        "filePath" to filePath,
    )
}

object RunRecovery {
    private val endLine =
        Regex("""\{"k":"end","t":[1-9][0-9]*\}""")

    /**
     * Returns the newest valid v1 file without an end record.
     * Call from a background thread, since this reads files.
     */
    fun findLatest(appFilesDir: File): UnfinishedRun? {
        val runsDir = File(appFilesDir, "runs").canonicalFile
        if (!runsDir.isDirectory) return null

        val activeRunId = activeRunId()
        val files = runsDir.listFiles { file ->
            file.isFile && file.extension == "jsonl"
        } ?: return null

        return files
            .sortedWith(
                compareByDescending<File> { it.lastModified() }
                    .thenByDescending { it.name }
            )
            .firstNotNullOfOrNull { file ->
                val runId = canonicalRunId(file.nameWithoutExtension)
                    ?: return@firstNotNullOfOrNull null

                if (runId == activeRunId) {
                    return@firstNotNullOfOrNull null
                }

                val safeFile = runCatching { file.canonicalFile }
                    .getOrNull()
                    ?: return@firstNotNullOfOrNull null

                if (safeFile.parentFile != runsDir) {
                    return@firstNotNullOfOrNull null
                }

                val unfinished =
                    runCatching { isUnfinished(safeFile, runId) }
                        .getOrDefault(false)

                if (unfinished) {
                    UnfinishedRun(runId, safeFile.absolutePath)
                } else {
                    null
                }
            }
    }

    /**
     * Deletes only a valid unfinished file. Completed runs and the
     * currently active run cannot be deleted through this method.
     */
    fun discardUnfinished(
        appFilesDir: File,
        runId: String,
    ): Boolean {
        val canonicalId = canonicalRunId(runId) ?: return false
        if (canonicalId == activeRunId()) return false

        val runsDir = File(appFilesDir, "runs").canonicalFile
        val file = File(runsDir, "$canonicalId.jsonl").canonicalFile

        if (file.parentFile != runsDir) return false

        val unfinished =
            runCatching { isUnfinished(file, canonicalId) }
                .getOrDefault(false)
        if (!unfinished) return false

        return file.delete()
    }

    private fun activeRunId(): String? {
        val current = TrackingApi.status.value
        return when (current.state) {
            TrackingRunState.RUNNING,
            TrackingRunState.PAUSED -> current.runId
            else -> null
        }
    }

    private fun canonicalRunId(text: String): String? {
        val parsed = runCatching { UUID.fromString(text).toString() }
            .getOrNull()
        return parsed?.takeIf { it == text }
    }

    private fun isUnfinished(
        file: File,
        runId: String,
    ): Boolean {
        if (!file.isFile) return false

        val header =
            file.bufferedReader(StandardCharsets.UTF_8).use {
                it.readLine()
            } ?: return false

        val prefix =
            """{"v":1,"runId":"$runId","startedAtUtcMs":"""
        if (!header.startsWith(prefix) || !header.endsWith("}")) {
            return false
        }

        val startedAt =
            header.substring(prefix.length, header.length - 1)
                .toLongOrNull()
        if (startedAt == null || startedAt <= 0) return false

        val last = lastLine(file) ?: return false
        return !endLine.matches(last)
    }

    /**
     * Reads only the tail instead of loading a long run into memory.
     * A partial final line still counts as unfinished.
     */
    private fun lastLine(file: File): String? =
        RandomAccessFile(file, "r").use { input ->
            var end = input.length()

            while (end > 0) {
                input.seek(end - 1)
                val byte = input.read()
                if (byte == '\n'.code || byte == '\r'.code) {
                    end--
                } else {
                    break
                }
            }
            if (end == 0L) return@use null

            var start = end
            while (start > 0) {
                input.seek(start - 1)
                if (input.read() == '\n'.code) break
                start--
            }

            val length = end - start
            if (length > 8_192L) return@use null

            val bytes = ByteArray(length.toInt())
            input.seek(start)
            input.readFully(bytes)
            String(bytes, StandardCharsets.UTF_8).trimEnd('\r')
        }
}