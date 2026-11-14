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
    private var clock: RunClock? = null
    private var writer: RunFileWriter? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_START -> startRun(startId)
            ACTION_STOP -> stopRun()
            else -> stopSelf(startId)
        }

        // A killed service must not silently restart a run.
        return START_NOT_STICKY
    }

    private fun startRun(startId: Int) {
        if (writer != null) return

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
            val newWriter = RunFileWriter(
                appFilesDir = filesDir,
                runId = runId,
                startedAtUtcMs = System.currentTimeMillis(),
            )

            writer = newWriter
            clock = RunClock(SystemClock.elapsedRealtime())
            Log.i(TAG, "Started run $runId")
        } catch (error: Exception) {
            Log.e(TAG, "Could not start tracking", error)
            cleanUp()
            stopSelf(startId)
        }
    }

    private fun stopRun() {
        try {
            val activeClock = clock
            val activeWriter = writer

            if (activeClock != null && activeWriter != null) {
                activeClock.stop(SystemClock.elapsedRealtime())
                activeWriter.finish(System.currentTimeMillis())
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not finish run file", error)
        } finally {
            cleanUp()
            stopSelf()
        }
    }

    override fun onDestroy() {
        // If Android kills the service, close without an end record.
        // The unfinished file can be offered for recovery later.
        cleanUp()
        super.onDestroy()
    }

    private fun cleanUp() {
        try {
            writer?.close()
        } catch (error: Exception) {
            Log.e(TAG, "Could not close run file", error)
        } finally {
            writer = null
            clock = null
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
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

    private fun buildStartingNotification(): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Road Runner")
            .setContentText("Preparing your run")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()

    companion object {
        private const val TAG = "TrackingService"
        private const val CHANNEL_ID = "run_tracking"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.roadrunner.app.tracking.START"
        private const val ACTION_STOP = "com.roadrunner.app.tracking.STOP"

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
    }
}