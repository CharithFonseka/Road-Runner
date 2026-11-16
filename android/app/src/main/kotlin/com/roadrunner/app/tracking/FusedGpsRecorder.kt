package com.roadrunner.app.tracking

import android.content.Context
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.location.LocationManager
import com.google.android.gms.location.LocationAvailability

class FusedGpsRecorder(
    context: Context,
    private val runId: UUID,
    private val startedAtUtcMs: Long,
    startedAtMonotonicMs: Long,
    private val onFatalError: (Exception) -> Unit,
    private val onAutoPaused: (TrackingErrorCode) -> Unit,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerThread = HandlerThread("RoadRunnerGps").apply { start() }
    private val worker = Handler(workerThread.looper)
    private val locationClient =
        LocationServices.getFusedLocationProviderClient(appContext)
    private val filter = GpsFilter(
        allowMockLocations =
            (appContext.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0,
    )
    private val speedSmoother = LiveSpeedSmoother()
    private val clock = RunClock(startedAtMonotonicMs)
    private val stopping = AtomicBoolean(false)

    private val wakeLock =
        (appContext.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "com.roadrunner.app:tracking",
            ).apply {
                setReferenceCounted(false)
            }

    private val request = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY,
        1_000L,
    )
        .setMinUpdateIntervalMillis(1_000L)
        .setMaxUpdateAgeMillis(0L)
        .setMaxUpdateDelayMillis(0L)
        .build()

    // These values are changed only on the worker thread.
    private var writer: RunFileWriter? = null
    private var distanceM = 0.0

    private val snapshotTick = object : Runnable {
        override fun run() {
            if (stopping.get() || clock.state != RunClockState.RUNNING) return

            try {
                val problem = environmentProblem()
                if (problem != null) {
                    pauseForProblem(problem)
                    return
                }

                publishSnapshot()
                worker.postDelayed(this, 1_000L)
            } catch (error: Exception) {
                fail(error)
            }
        }
    }

    // Registration completion may run on the main thread.
    @Volatile
    private var activeCallback: LocationCallback? = null

    fun start() {
        worker.post {
            if (stopping.get()) return@post

            try {
                writer = RunFileWriter(
                    appFilesDir = appContext.filesDir,
                    runId = runId,
                    startedAtUtcMs = startedAtUtcMs,
                )
                acquireWakeLock()
                requestUpdates()
                TrackingApi.publishGps(GpsQuality.SEARCHING)
                worker.post(snapshotTick)
            } catch (error: Exception) {
                fail(error)
            }
        }
    }

    fun pause(onPaused: (Exception?) -> Unit) {
        worker.post {
            if (stopping.get() || clock.state != RunClockState.RUNNING) {
                mainHandler.post {
                    onPaused(IllegalStateException("Run is not running"))
                }
                return@post
            }

            try {
                pauseOnWorker()
                mainHandler.post { onPaused(null) }
            } catch (error: Exception) {
                mainHandler.post { onPaused(error) }
                fail(error)
            }
        }
    }

    private fun pauseOnWorker() {
        val atUtcMs = System.currentTimeMillis()
        val atMonotonicMs = SystemClock.elapsedRealtime()

        removeUpdates()
        writer?.appendState(RunFileState.PAUSED, atUtcMs)
        clock.pause(atMonotonicMs)
        worker.removeCallbacks(snapshotTick)
        publishSnapshot()
        releaseWakeLock()
    }

    private fun environmentProblem(): TrackingErrorCode? {
        val hasFineLocation =
            appContext.checkSelfPermission(
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

        if (!hasFineLocation) {
            return TrackingErrorCode.PERMISSION_DENIED
        }

        val manager = appContext.getSystemService(Context.LOCATION_SERVICE)
            as LocationManager
        val gpsEnabled =
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER)

        return trackingProblem(hasFineLocation, gpsEnabled)
    }

    private fun pauseForProblem(code: TrackingErrorCode) {
        if (stopping.get() || clock.state != RunClockState.RUNNING) return

        try {
            pauseOnWorker()

            val message = when (code) {
                TrackingErrorCode.PERMISSION_DENIED ->
                    "Precise location permission was removed"
                TrackingErrorCode.LOCATION_OFF ->
                    "Phone location was turned off"
                TrackingErrorCode.SERVICE_FAILED ->
                    "Tracking service failed"
            }
            TrackingApi.publishError(code, message)

            mainHandler.post { onAutoPaused(code) }
        } catch (error: Exception) {
            fail(error)
        }
    }

    fun resume(onResumed: (Exception?) -> Unit) {
        worker.post {
            if (stopping.get() || clock.state != RunClockState.PAUSED) {
                mainHandler.post {
                    onResumed(IllegalStateException("Run is not paused"))
                }
                return@post
            }

            try {
                val atUtcMs = System.currentTimeMillis()
                val atMonotonicMs = SystemClock.elapsedRealtime()

                // The first accepted fix after this must add zero distance.
                filter.markResumed()
                speedSmoother.reset()
                writer?.appendState(RunFileState.RUNNING, atUtcMs)
                clock.resume(atMonotonicMs)
                acquireWakeLock()
                requestUpdates()
                TrackingApi.publishGps(GpsQuality.SEARCHING)
                worker.post(snapshotTick)

                mainHandler.post { onResumed(null) }
            } catch (error: Exception) {
                mainHandler.post { onResumed(error) }
                fail(error)
            }
        }
    }

    /**
     * finish=true writes an end record. finish=false leaves an unfinished
     * run file. The callback runs on the main thread.
     */
    fun stop(
        finish: Boolean,
        onStopped: (Exception?, Double, RunTime) -> Unit,
    ) {
        if (!stopping.compareAndSet(false, true)) return

        worker.post {
            var failure: Exception? = null

            try {
                removeUpdates()
                worker.removeCallbacks(snapshotTick)
                clock.stop(SystemClock.elapsedRealtime())
                publishSnapshot()

                if (finish) {
                    writer?.finish(System.currentTimeMillis())
                } else {
                    writer?.close()
                }
            } catch (error: Exception) {
                failure = error
                runCatching { writer?.close() }
            } finally {
                releaseWakeLock()
                writer = null
                workerThread.quitSafely()

                val finalDistanceM = distanceM
                val finalTime = clock.snapshot(SystemClock.elapsedRealtime())
                mainHandler.post {
                    onStopped(failure, finalDistanceM, finalTime)
                }
            }
        }
    }

    private fun requestUpdates() {
        val callback = object : LocationCallback() {
            override fun onLocationAvailability(
                availability: LocationAvailability,
            ) {
                if (
                    !stopping.get() &&
                    activeCallback === this &&
                    !availability.isLocationAvailable
                ) {
                    TrackingApi.publishGps(GpsQuality.SEARCHING)
                }
            }

            override fun onLocationResult(result: LocationResult) {
                if (stopping.get() || activeCallback !== this) return

                val problem = environmentProblem()
                if (problem != null) {
                    pauseForProblem(problem)
                    return
                }

                try {
                    for (location in result.locations) {
                        record(location)
                    }
                } catch (error: Exception) {
                    val problem = environmentProblem()
                    if (problem != null) {
                        pauseForProblem(problem)
                    } else {
                        fail(error)
                    }
                }
            }
        }
        activeCallback = callback

        if (
            appContext.checkSelfPermission(
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pauseForProblem(TrackingErrorCode.PERMISSION_DENIED)
            return
        }

        locationClient
            .requestLocationUpdates(request, callback, workerThread.looper)
            .addOnSuccessListener {
                // Pause or stop might have happened during registration.
                if (stopping.get() || activeCallback !== callback) {
                    locationClient.removeLocationUpdates(callback)
                }
            }
            .addOnFailureListener { error ->
                if (!stopping.get() && activeCallback === callback) {
                    val problem = environmentProblem()
                    if (problem != null) {
                        worker.post { pauseForProblem(problem) }
                    } else {
                        fail(error)
                    }
                }
            }
    }

    private fun removeUpdates() {
        val callback = activeCallback
        activeCallback = null
        callback?.let { locationClient.removeLocationUpdates(it) }
    }

    private fun acquireWakeLock() {
        if (!wakeLock.isHeld) {
            // The prototype's required screen-off test is 60 minutes.
            wakeLock.acquire(65L * 60L * 1_000L)
        }
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock.isHeld) wakeLock.release()
        }.onFailure { error ->
            Log.e(TAG, "Could not release wake lock", error)
        }
    }

    private fun record(location: Location) {
        if (clock.state != RunClockState.RUNNING) return

        if (
            location.time <= 0 ||
            !location.latitude.isFinite() ||
            !location.longitude.isFinite()
        ) {
            Log.w(TAG, "Skipping unusable location fix")
            return
        }

        val accuracyM =
            if (location.hasAccuracy() && location.accuracy.isFinite()) {
                location.accuracy.toDouble()
            } else {
                -1.0
            }
        val speedMps =
            if (location.hasSpeed() && location.speed.isFinite()) {
                location.speed.toDouble()
            } else {
                null
            }
        val altitudeM =
            if (location.hasAltitude() && location.altitude.isFinite()) {
                location.altitude
            } else {
                null
            }

        val fix = GpsFix(
            tUtcMs = location.time,
            lat = location.latitude,
            lon = location.longitude,
            accM = accuracyM,
            speedMps = speedMps,
            altM = altitudeM,
            isMock = isMock(location),
        )

        val decision = filter.evaluate(fix)
        writer?.appendPoint(fix, decision)
        distanceM += decision.addedDistanceM

        TrackingApi.publishGps(
            if (fix.accM >= 0.0 &&
                fix.accM < FilterConfig.FIRST_FIX_MAX_ACCURACY_M
            ) {
                GpsQuality.GOOD
            } else {
                GpsQuality.WEAK
            }
        )

        if (decision.accepted) {
            speedSmoother.accepted(
                addedDistanceM = decision.addedDistanceM,
                fixUtcMs = fix.tUtcMs,
                nowMonotonicMs = SystemClock.elapsedRealtime(),
            )
        }
    }

    private fun publishSnapshot() {
        val nowMonotonicMs = SystemClock.elapsedRealtime()
        val time = clock.snapshot(nowMonotonicMs)
        val speedMps =
            if (clock.state == RunClockState.RUNNING) {
                speedSmoother.speedMps(nowMonotonicMs)
            } else {
                0.0
            }

        TrackingApi.publishSnapshot(
            LiveSnapshot(
                elapsedMs = time.elapsedMs,
                movingMs = time.movingMs,
                distanceM = distanceM,
                speedMps = speedMps,
                paceSecPerKm =
                    LiveSpeedSmoother.paceSecPerKm(speedMps),
            )
        )
    }

    private fun fail(error: Exception) {
        Log.e(TAG, "GPS recording failed", error)
        stop(finish = false) { _, _, _ ->
            onFatalError(error)
        }
    }

    @Suppress("DEPRECATION")
    private fun isMock(location: Location): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            location.isFromMockProvider
        }

    companion object {
        private const val TAG = "FusedGpsRecorder"
    }
}