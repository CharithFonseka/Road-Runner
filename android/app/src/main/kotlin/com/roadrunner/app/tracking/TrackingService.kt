package com.roadrunner.app.tracking

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import java.util.UUID

class TrackingService : Service() {
    private var recorder: FusedGpsRecorder? = null
    private var stopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_START -> startRun(startId)
            ACTION_STOP -> stopRun()
            ACTION_PAUSE -> pauseRun()
            ACTION_RESUME -> resumeRun()
            else -> stopSelf(startId)
        }

        // A killed service must not silently restart a run.
        return START_NOT_STICKY
    }

    private fun startRun(startId: Int) {
        if (recorder != null || stopping) return

        try {
            check(hasFineLocationPermission()) {
                "Precise location permission is required"
            }
            check(isGpsEnabled()) {
                "Location is turned off"
            }

            // Promote immediately, before file work or future GPS setup.
            createNotificationChannel()
            val notification = buildStartingNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            val runId = UUID.randomUUID()

            recorder = FusedGpsRecorder(
                context = this,
                runId = runId,
                startedAtUtcMs = System.currentTimeMillis(),
                startedAtMonotonicMs = SystemClock.elapsedRealtime(),
                onFatalError = { error ->
                    Log.e(TAG, "Run stopped after GPS failure", error)
                    stopping = true
                    recorder = null
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                },
            ).also { it.start() }

            Log.i(TAG, "Started run $runId")
        } catch (error: Exception) {
            Log.e(TAG, "Could not start tracking", error)
            recorder?.stop(finish = false) { _, _, _ -> }
            recorder = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf(startId)
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
                updateNotification("Paused")
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
            return
        }

        activeRecorder.resume { error ->
            if (error != null) {
                Log.e(TAG, "Could not resume run", error)
            } else if (!stopping) {
                updateNotification("Tracking run")
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
            finishService()
        }
    }

    private fun finishService() {
        recorder = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (!stopping) {
            stopping = true
            recorder?.stop(finish = false) { _, _, _ -> }
        }

        recorder = null
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

    private fun createNotificationChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Run tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannel(channel)
    }

    private fun buildStartingNotification(
        status: String = "Preparing your run",
    ): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Road Runner")
            .setContentText(status)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()

    private fun updateNotification(status: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        manager.notify(NOTIFICATION_ID, buildStartingNotification(status))
    }

    companion object {
        private const val TAG = "TrackingService"
        private const val CHANNEL_ID = "run_tracking"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.roadrunner.app.tracking.START"
        private const val ACTION_STOP = "com.roadrunner.app.tracking.STOP"
        private const val ACTION_PAUSE = "com.roadrunner.app.tracking.PAUSE"
        private const val ACTION_RESUME = "com.roadrunner.app.tracking.RESUME"

        /**
         * Aadila's bridge should call this only from a visible Activity,
         * after the permission flow has granted precise location.
         */
        fun startFromVisibleActivity(activity: Activity) {
            check(
                activity.checkSelfPermission(
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                "Precise location permission is required"
            }

            activity.startForegroundService(
                Intent(activity, TrackingService::class.java)
                    .setAction(ACTION_START)
            )
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