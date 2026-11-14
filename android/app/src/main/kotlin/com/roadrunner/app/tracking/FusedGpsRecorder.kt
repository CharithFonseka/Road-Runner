package com.roadrunner.app.tracking

import android.content.Context
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Owns GPS callbacks, filtering, and run-file writes on one worker thread.
 */
class FusedGpsRecorder(
    context: Context,
    private val runId: UUID,
    private val startedAtUtcMs: Long,
    private val onFatalError: (Exception) -> Unit,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerThread = HandlerThread("RoadRunnerGps").apply { start() }
    private val worker = Handler(workerThread.looper)
    private val locationClient =
        LocationServices.getFusedLocationProviderClient(appContext)
    private val filter = GpsFilter()
    private val stopping = AtomicBoolean(false)

    // Access these only on the worker thread.
    private var writer: RunFileWriter? = null
    private var locationCallback: LocationCallback? = null
    private var distanceM = 0.0

    fun start() {
        worker.post {
            if (stopping.get()) return@post

            try {
                writer = RunFileWriter(
                    appFilesDir = appContext.filesDir,
                    runId = runId,
                    startedAtUtcMs = startedAtUtcMs,
                )

                val request = LocationRequest.Builder(
                    Priority.PRIORITY_HIGH_ACCURACY,
                    1_000L,
                )
                    .setMinUpdateIntervalMillis(1_000L)
                    .setMaxUpdateAgeMillis(0L)
                    .setMaxUpdateDelayMillis(0L)
                    .build()

                val callback = object : LocationCallback() {
                    override fun onLocationResult(result: LocationResult) {
                        if (stopping.get()) return

                        try {
                            for (location in result.locations) {
                                record(location)
                            }
                        } catch (error: Exception) {
                            fail(error)
                        }
                    }
                }
                locationCallback = callback

                locationClient
                    .requestLocationUpdates(
                        request,
                        callback,
                        workerThread.looper,
                    )
                    .addOnSuccessListener {
                        // Stop may have been requested before registration
                        // finished. Remove that late registration too.
                        if (stopping.get()) {
                            locationClient.removeLocationUpdates(callback)
                        }
                    }
                    .addOnFailureListener { error ->
                        fail(error)
                    }
            } catch (error: Exception) {
                fail(error)
            }
        }
    }

    /**
     * finish=true writes an end record. finish=false leaves a recoverable
     * unfinished file. onStopped runs on the main thread.
     */
    fun stop(
        finish: Boolean,
        onStopped: (Exception?, Double) -> Unit,
    ) {
        if (!stopping.compareAndSet(false, true)) return

        worker.post {
            var failure: Exception? = null

            try {
                locationCallback?.let {
                    locationClient.removeLocationUpdates(it)
                }

                if (finish) {
                    writer?.finish(System.currentTimeMillis())
                } else {
                    writer?.close()
                }
            } catch (error: Exception) {
                failure = error
                runCatching { writer?.close() }
            } finally {
                writer = null
                locationCallback = null
                workerThread.quitSafely()

                val finalDistanceM = distanceM
                mainHandler.post {
                    onStopped(failure, finalDistanceM)
                }
            }
        }
    }

    private fun record(location: Location) {
        // These values cannot be represented as a valid point in the v1 file.
        if (
            location.time <= 0 ||
            !location.latitude.isFinite() ||
            !location.longitude.isFinite()
        ) {
            Log.w(TAG, "Skipping unusable location fix")
            return
        }

        // Missing accuracy becomes an invalid fix. The filter rejects it,
        // while the run file still records the raw reading.
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
    }

    private fun fail(error: Exception) {
        Log.e(TAG, "GPS recording failed", error)
        stop(finish = false) { _, _ ->
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