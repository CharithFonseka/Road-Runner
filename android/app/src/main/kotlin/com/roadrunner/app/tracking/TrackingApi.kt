package com.roadrunner.app.tracking

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

enum class TrackingRunState(val wireValue: String) {
    IDLE("idle"),
    RUNNING("running"),
    PAUSED("paused"),
    STOPPED("stopped"),
}

enum class GpsQuality(val wireValue: String) {
    SEARCHING("searching"),
    WEAK("weak"),
    GOOD("good"),
}

enum class TrackingErrorCode {
    LOCATION_OFF,
    PERMISSION_DENIED,
    SERVICE_FAILED,
}

data class LiveSnapshot(
    val elapsedMs: Long,
    val movingMs: Long,
    val distanceM: Double,
    val speedMps: Double,
    val paceSecPerKm: Double?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "elapsedMs" to elapsedMs,
        "movingMs" to movingMs,
        "distanceM" to distanceM,
        "speedMps" to speedMps,
        "paceSecPerKm" to paceSecPerKm,
    )
}

data class TrackingStatus(
    val state: TrackingRunState = TrackingRunState.IDLE,
    val runId: String? = null,
    val snapshot: LiveSnapshot? = null,
    val filePath: String? = null,
) {
    // Shape required by the getState() MethodChannel call.
    fun toControlMap(): Map<String, Any?> = buildMap {
        put("state", state.wireValue)
        runId?.let { put("runId", it) }
        snapshot?.let { put("snapshot", it.toMap()) }
    }
}

/**
 * Aadila's EventChannel can collect events.
 * getState() can read status.value when Flutter reconnects.
 */
object TrackingApi {
    private val mutableEvents =
        MutableSharedFlow<Map<String, Any?>>(
            extraBufferCapacity = 64,
            onBufferOverflow = BufferOverflow.DROP_OLDEST,
        )

    val events: SharedFlow<Map<String, Any?>> =
        mutableEvents.asSharedFlow()

    private val mutableStatus = MutableStateFlow(TrackingStatus())
    val status: StateFlow<TrackingStatus> =
        mutableStatus.asStateFlow()

    fun publishState(
        state: TrackingRunState,
        runId: String?,
        filePath: String? = null,
    ) {
        mutableStatus.update { previous ->
            TrackingStatus(
                state = state,
                runId = runId,
                snapshot =
                    if (runId == previous.runId) previous.snapshot else null,
                filePath = filePath,
            )
        }

        val event = mutableMapOf<String, Any?>(
            "type" to "state",
            "state" to state.wireValue,
        )
        runId?.let { event["runId"] = it }
        mutableEvents.tryEmit(event)
    }

    fun publishGps(quality: GpsQuality) {
        mutableEvents.tryEmit(
            mapOf(
                "type" to "gps",
                "quality" to quality.wireValue,
            )
        )
    }

    fun publishSnapshot(snapshot: LiveSnapshot) {
        mutableStatus.update { it.copy(snapshot = snapshot) }

        val event = mutableMapOf<String, Any?>(
            "type" to "snapshot",
        )
        event.putAll(snapshot.toMap())
        mutableEvents.tryEmit(event)
    }

    fun publishError(code: TrackingErrorCode, message: String) {
        mutableEvents.tryEmit(
            mapOf(
                "type" to "error",
                "code" to code.name,
                "message" to message,
            )
        )
    }
}   