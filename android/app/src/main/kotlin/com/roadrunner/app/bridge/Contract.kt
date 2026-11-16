package com.roadrunner.app.bridge

// Road Runner — Core Contract (Kotlin side)
// Owner: Praveen
// SRS reference: Section 4.3 – 4.7
//
// DO NOT EDIT without opening a CCR (SRS §4.8).
// Every constant here must have an identical mirror in
// lib/core/contract/contract.dart.
// CI runs `bash scripts/check_contract.sh` to compare both files.

object Contract {

    // ─── Channels (SRS §4.5) ──────────────────────────────────────────────────

    const val CONTROL_CHANNEL = "roadrunner/control"
    const val EVENTS_CHANNEL = "roadrunner/events"

    // ─── MethodChannel method names (SRS §4.5) ────────────────────────────────

    const val METHOD_START_RUN = "startRun"
    const val METHOD_PAUSE_RUN = "pauseRun"
    const val METHOD_RESUME_RUN = "resumeRun"
    const val METHOD_STOP_RUN = "stopRun"
    const val METHOD_GET_STATE = "getState"
    const val METHOD_GET_UNFINISHED_RUN = "getUnfinishedRun"
    const val METHOD_DISCARD_RUN = "discardRun"

    const val BRIDGE_CONTRACT_VERSION = 2

    // ─── Run states (SRS §4.2, §4.3, §4.5) ────────────────────────────────────

    const val STATE_IDLE = "idle"
    const val STATE_RUNNING = "running"
    const val STATE_PAUSED = "paused"
    const val STATE_STOPPED = "stopped"
    const val STATE_SAVED = "saved"

    // ─── EventChannel event types (SRS §4.5) ──────────────────────────────────

    const val EVENT_TYPE_STATE = "state"
    const val EVENT_TYPE_GPS = "gps"
    const val EVENT_TYPE_SNAPSHOT = "snapshot"
    const val EVENT_TYPE_POINT = "point"
    const val EVENT_TYPE_ERROR = "error"

    // ─── GPS quality values (SRS §4.5) ────────────────────────────────────────

    const val GPS_SEARCHING = "searching"
    const val GPS_WEAK = "weak"
    const val GPS_GOOD = "good"

    // ─── Error codes (SRS §4.5) ───────────────────────────────────────────────

    const val ERROR_LOCATION_OFF = "LOCATION_OFF"
    const val ERROR_PERMISSION_DENIED = "PERMISSION_DENIED"
    const val ERROR_SERVICE_FAILED = "SERVICE_FAILED"

    // ─── Bridge payload field keys (SRS §4.5) ─────────────────────────────────

    const val KEY_TYPE = "type"
    const val KEY_STATE = "state"
    const val KEY_RUN_ID = "runId"
    const val KEY_FILE_PATH = "filePath"
    const val KEY_SNAPSHOT = "snapshot"
    const val KEY_QUALITY = "quality"
    const val KEY_ELAPSED_MS = "elapsedMs"
    const val KEY_MOVING_MS = "movingMs"
    const val KEY_DISTANCE_M = "distanceM"
    const val KEY_SPEED_MPS = "speedMps"
    const val KEY_PACE_SEC_PER_KM = "paceSecPerKm"
    const val KEY_LAT = "lat"
    const val KEY_LON = "lon"
    const val KEY_SEQ = "seq"
    const val KEY_CODE = "code"
    const val KEY_MESSAGE = "message"

    // ─── Run file format v1 (SRS §4.4) ────────────────────────────────────────

    const val RUN_FILE_VERSION = 1
    const val RUN_FILE_KIND_POINT = "p"
    const val RUN_FILE_KIND_STATE = "s"
    const val RUN_FILE_KIND_END = "end"

    const val RUN_FILE_KEY_VERSION = "v"
    const val RUN_FILE_KEY_KIND = "k"
    const val RUN_FILE_KEY_STARTED_AT_UTC_MS = "startedAtUtcMs"
    const val RUN_FILE_KEY_SEQ = "seq"
    const val RUN_FILE_KEY_TIME = "t"
    const val RUN_FILE_KEY_LAT = "lat"
    const val RUN_FILE_KEY_LON = "lon"
    const val RUN_FILE_KEY_ACC = "acc"
    const val RUN_FILE_KEY_SPEED = "spd"
    const val RUN_FILE_KEY_ALT = "alt"
    const val RUN_FILE_KEY_ACCEPTED = "ok"

    // ─── GPS filter config (SRS §4.6) ─────────────────────────────────────────

    const val MAX_ACCURACY_M = 25.0
    const val FIRST_FIX_MAX_ACCURACY_M = 20.0
    const val MAX_IMPLIED_SPEED_MPS = 12.0
    const val STATIONARY_SPEED_MPS = 0.5
    const val TINY_MOVE_M = 2.0
    const val MAX_GAP_SECONDS = 10
    const val EARTH_RADIUS_M = 6371000.0

    // ─── Calculation constants (SRS §4.7) ─────────────────────────────────────

    const val MIN_DISTANCE_FOR_PACE_M = 50.0
    const val MIN_SPEED_FOR_PACE_MPS = 0.5
    const val MAX_PACE_SEC_PER_KM = 1200.0
    const val SPLIT_DISTANCE_M = 1000.0
    const val SPEED_SMOOTHING_WINDOW_S = 5
}
