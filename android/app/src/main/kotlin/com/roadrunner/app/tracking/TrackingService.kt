package com.roadrunner.app.tracking

import android.Manifest
import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import com.roadrunner.app.notification.TrackingNotificationManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

class TrackingService : Service() {
    private var recorder: FusedGpsRecorder? = null
    private var stopping = false
    private var activeRunId: UUID? = null

    private var notificationUi: TrackingNotificationManager? = null
    private val notificationScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var notificationJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (intent?.action == ACTION_PAUSE || intent?.action == ACTION_RESUME) {
            val requestedRunId = intent.getStringExtra(EXTRA_RUN_ID)
            if (
                requestedRunId != null &&
                requestedRunId != activeRunId?.toString()
            ) {
                return START_NOT_STICKY
            }
        }

        when (intent?.action) {
            ACTION_START -> startRun(startId, intent)
            ACTION_STOP -> stopRun()
            ACTION_PAUSE -> pauseRun()
            ACTION_RESUME -> resumeRun()
            else -> stopSelf(startId)
        }

        // A killed service must not silently restart a run.
        return START_NOT_STICKY
    }

    private fun startRun(startId: Int, intent: Intent?) {
        if (recorder != null || stopping) return

        try {
            check(hasFineLocationPermission()) {
                "Precise location permission is required"
            }
            check(isGpsEnabled()) {
                "Location is turned off"
            }

            val runId = UUID.fromString(
                requireNotNull(intent?.getStringExtra(EXTRA_RUN_ID)) {
                    "Missing run ID"
                }
            )
            activeRunId = runId
            val ui = TrackingNotificationManager(this)
            notificationUi = ui
            val notification = ui.buildInitialNotification(runId.toString())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    TrackingNotificationManager.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(
                    TrackingNotificationManager.NOTIFICATION_ID,
                    notification,
                )
            }

            recorder = FusedGpsRecorder(
                context = this,
                runId = runId,
                startedAtUtcMs = System.currentTimeMillis(),
                startedAtMonotonicMs = SystemClock.elapsedRealtime(),
                onFatalError = { error ->
                    Log.e(TAG, "Run stopped after GPS failure", error)
                    reportFailure(error)
                    TrackingApi.publishState(
                        TrackingRunState.STOPPED,
                        activeRunId?.toString(),
                        activeRunFilePath(),
                    )
                    stopping = true
                    recorder = null
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                },
                onAutoPaused = { code ->
                    if (!stopping) {
                        Log.w(TAG, "Run paused because of $code")
                        TrackingApi.publishState(
                            TrackingRunState.PAUSED,
                            activeRunId?.toString(),
                        )
                    }
                },
            ).also { it.start() }

            TrackingApi.publishState(
                TrackingRunState.RUNNING,
                runId.toString(),
                activeRunFilePath(),
            )
            observeNotification()
            pendingRunId = null

            Log.i(TAG, "Started run $runId")
        } catch (error: Exception) {
            Log.e(TAG, "Could not start tracking", error)
            recorder?.stop(finish = false) { _, _, _ -> }
            recorder = null
            notificationJob?.cancel()
            notificationJob = null
            notificationUi?.cancel()
            notificationUi = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            reportFailure(error)
            TrackingApi.publishState(TrackingRunState.IDLE, null)
            activeRunId = null
            pendingRunId = null
            stopSelf(startId)
        }
    }

    private fun observeNotification() {
        notificationJob?.cancel()
        notificationJob = notificationScope.launch {
            TrackingApi.status.collect { status ->
                if (status.runId != activeRunId?.toString()) return@collect
                val snapshot = status.snapshot
                when (status.state) {
                    TrackingRunState.RUNNING -> snapshot?.let {
                        notificationUi?.updateLiveMetrics(
                            movingMs = it.movingMs,
                            distanceM = it.distanceM,
                            speedMps = it.speedMps,
                            paceSecPerKm = it.paceSecPerKm,
                        )
                    }
                    TrackingRunState.PAUSED -> notificationUi?.updatePaused(
                        movingMs = snapshot?.movingMs ?: 0L,
                        distanceM = snapshot?.distanceM ?: 0.0,
                    )
                    else -> Unit
                }
            }
        }
    }

    private fun pauseRun() {
        if (stopping) return

        val activeRecorder = recorder ?: run {
            stopSelf()
            return
        }

        activeRecorder.pause { error ->
            if (error != null) {
                Log.e(TAG, "Could not pause run", error)
            } else if (!stopping) {
                TrackingApi.publishState(
                    TrackingRunState.PAUSED,
                    activeRunId?.toString(),
                )
            }
        }
    }

    private fun resumeRun() {
        if (stopping) return

        val activeRecorder = recorder ?: run {
            stopSelf()
            return
        }

        if (!hasFineLocationPermission() || !isGpsEnabled()) {
            Log.w(TAG, "Cannot resume without precise location and GPS")
            TrackingApi.publishError(
                if (!hasFineLocationPermission()) {
                    TrackingErrorCode.PERMISSION_DENIED
                } else {
                    TrackingErrorCode.LOCATION_OFF
                },
                "Precise location and GPS are required to resume",
            )
            return
        }

        activeRecorder.resume { error ->
            if (error != null) {
                Log.e(TAG, "Could not resume run", error)
            } else if (!stopping) {
                TrackingApi.publishState(
                    TrackingRunState.RUNNING,
                    activeRunId?.toString(),
                )
            }
        }
    }

    private fun stopRun() {
        if (stopping) return
        stopping = true

        val activeRecorder = recorder
        if (activeRecorder == null) {
            finishService()
            return
        }

        activeRecorder.stop(finish = true) { error, distanceM, runTime ->
            if (error != null) {
                Log.e(TAG, "Could not finish run file", error)
            }
            Log.i(
                TAG,
                "Stopped at $distanceM meters, moving for ${runTime.movingMs} ms",
            )
            if (error != null) reportFailure(error)
            TrackingApi.publishState(
                TrackingRunState.STOPPED,
                activeRunId?.toString(),
                activeRunFilePath(),
            )
            finishService()
        }
    }

    private fun finishService() {
        notificationJob?.cancel()
        notificationJob = null
        notificationUi?.cancel()
        notificationUi = null
        recorder = null
        activeRunId = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (!stopping) {
            stopping = true
            recorder?.stop(finish = false) { _, _, _ -> }
        }

        notificationJob?.cancel()
        notificationJob = null
        notificationScope.cancel()
        notificationUi?.cancel()
        notificationUi = null

        recorder = null
        activeRunId = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun hasFineLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun isGpsEnabled(): Boolean {
        val manager = getSystemService(Context.LOCATION_SERVICE)
            as LocationManager
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }

    private fun activeRunFilePath(): String? =
        activeRunId?.let { id ->
            File(File(filesDir, "runs"), "$id.jsonl").absolutePath
        }

    private fun reportFailure(error: Exception) {
        val code = when {
            !hasFineLocationPermission() ->
                TrackingErrorCode.PERMISSION_DENIED
            !isGpsEnabled() ->
                TrackingErrorCode.LOCATION_OFF
            else ->
                TrackingErrorCode.SERVICE_FAILED
        }

        TrackingApi.publishError(
            code,
            error.message ?: "Tracking failed",
        )
    }

    companion object {
        private const val TAG = "TrackingService"
        private const val ACTION_START = "com.roadrunner.app.tracking.START"
        private const val ACTION_STOP = "com.roadrunner.app.tracking.STOP"
        internal const val ACTION_PAUSE = "com.roadrunner.app.tracking.PAUSE"
        internal const val ACTION_RESUME = "com.roadrunner.app.tracking.RESUME"
        internal const val EXTRA_RUN_ID =
            "com.roadrunner.app.tracking.RUN_ID"

        @Volatile
        private var pendingRunId: UUID? = null

        /**
         * Call from the visible Flutter Activity after precise-location
         * permission is granted. Returns the ID used by the service.
         */
        @Synchronized
        fun startFromVisibleActivity(activity: Activity): String {
            check(
                activity.checkSelfPermission(
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                "Precise location permission is required"
            }

            val locationManager =
                activity.getSystemService(Context.LOCATION_SERVICE)
                    as LocationManager
            check(locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                "Phone location is turned off"
            }

            val current = TrackingApi.status.value
            if (
                current.state == TrackingRunState.RUNNING ||
                current.state == TrackingRunState.PAUSED
            ) {
                return checkNotNull(current.runId)
            }

            pendingRunId?.let { return it.toString() }

            val runId = UUID.randomUUID()
            pendingRunId = runId

            try {
                activity.startForegroundService(
                    Intent(activity, TrackingService::class.java)
                        .setAction(ACTION_START)
                        .putExtra(EXTRA_RUN_ID, runId.toString())
                )
            } catch (error: Exception) {
                pendingRunId = null
                throw error
            }

            return runId.toString()
        }

        fun stopFromVisibleActivity(activity: Activity) {
            activity.startService(
                Intent(activity, TrackingService::class.java)
                    .setAction(ACTION_STOP)
            )
        }

        fun pauseFromVisibleActivity(activity: Activity) {
            activity.startService(
                Intent(activity, TrackingService::class.java)
                    .setAction(ACTION_PAUSE)
            )
        }

        fun resumeFromVisibleActivity(activity: Activity) {
            activity.startService(
                Intent(activity, TrackingService::class.java)
                    .setAction(ACTION_RESUME)
            )
        }
    }
}
