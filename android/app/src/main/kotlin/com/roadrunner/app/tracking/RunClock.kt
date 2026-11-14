package com.roadrunner.app.tracking

enum class RunClockState {
    RUNNING,
    PAUSED,
    STOPPED,
}

data class RunTime(
    val elapsedMs: Long,
    val movingMs: Long,
)

class RunClock(private val startedMonotonicMs: Long) {
    init {
        require(startedMonotonicMs >= 0)
    }

    var state: RunClockState = RunClockState.RUNNING
        private set

    private var lastTransitionMs = startedMonotonicMs
    private var completedMovingMs = 0L
    private var stoppedMonotonicMs: Long? = null

    fun pause(nowMonotonicMs: Long) {
        check(state == RunClockState.RUNNING)
        require(nowMonotonicMs >= lastTransitionMs)

        completedMovingMs += nowMonotonicMs - lastTransitionMs
        lastTransitionMs = nowMonotonicMs
        state = RunClockState.PAUSED
    }

    fun resume(nowMonotonicMs: Long) {
        check(state == RunClockState.PAUSED)
        require(nowMonotonicMs >= lastTransitionMs)

        lastTransitionMs = nowMonotonicMs
        state = RunClockState.RUNNING
    }

    fun stop(nowMonotonicMs: Long) {
        check(state != RunClockState.STOPPED)
        require(nowMonotonicMs >= lastTransitionMs)

        if (state == RunClockState.RUNNING) {
            completedMovingMs += nowMonotonicMs - lastTransitionMs
        }

        stoppedMonotonicMs = nowMonotonicMs
        lastTransitionMs = nowMonotonicMs
        state = RunClockState.STOPPED
    }

    fun snapshot(nowMonotonicMs: Long): RunTime {
        val observedMs = stoppedMonotonicMs ?: nowMonotonicMs
        require(observedMs >= lastTransitionMs)

        val currentMovingMs =
            if (state == RunClockState.RUNNING) {
                observedMs - lastTransitionMs
            } else {
                0L
            }

        return RunTime(
            elapsedMs = observedMs - startedMonotonicMs,
            movingMs = completedMovingMs + currentMovingMs,
        )
    }
}