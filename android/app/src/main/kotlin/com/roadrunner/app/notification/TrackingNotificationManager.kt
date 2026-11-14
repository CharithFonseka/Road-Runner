package com.roadrunner.app.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import com.roadrunner.app.MainActivity

/**
 * Manages the lock-screen ongoing notification for live run tracking.
 * Owner: Aadila
 * SRS Reference: Section 5.4 (FR-30 to FR-35), Section 8.3
 *
 * Rules:
 * - Channel ID: "run_tracking", low importance (no sound)
 * - Visibility: VISIBILITY_PUBLIC (shows on lock screen)
 * - Ongoing: true, alert only once
 * - Timer: Uses system chronometer (setUsesChronometer). Does NOT rebuild every second (Battery rule C10).
 * - Speed text: Throttled to update at most every 3 seconds.
 */
class TrackingNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "run_tracking"
        const val CHANNEL_NAME = "Active Run"
        const val NOTIFICATION_ID = 1001

        const val ACTION_PAUSE = "com.roadrunner.app.ACTION_PAUSE"
        const val ACTION_RESUME = "com.roadrunner.app.ACTION_RESUME"

        private const val MIN_SPEED_UPDATE_INTERVAL_MS = 3000L
    }

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private var lastSpeedUpdateTimeMs: Long = 0L
    private var lastFormattedSpeed: String = "0.0 km/h"

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active run timer and speed on the lock screen"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Builds the initial ongoing notification when tracking begins.
     */
    fun buildInitialNotification(runId: String): Notification {
        lastSpeedUpdateTimeMs = SystemClock.elapsedRealtime()
        lastFormattedSpeed = "0.0 km/h"
        return createNotification(
            isRunning = true,
            elapsedRealtimeBase = SystemClock.elapsedRealtime(),
            speedText = lastFormattedSpeed,
            distanceText = "0.00 km"
        )
    }

    /**
     * Updates notification when live metrics change.
     * Throttles speed updates to at most once every 3 seconds per battery rule (C10 / FR-31).
     */
    fun updateLiveMetrics(movingMs: Long, distanceM: Double, speedMps: Double) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastSpeedUpdateTimeMs >= MIN_SPEED_UPDATE_INTERVAL_MS) {
            lastSpeedUpdateTimeMs = now
            val speedKmh = speedMps * 3.6
            lastFormattedSpeed = String.format("%.1f km/h", speedKmh)
            val distanceKm = distanceM / 1000.0
            val distanceText = String.format("%.2f km", distanceKm)

            val baseTime = now - movingMs
            val notification = createNotification(
                isRunning = true,
                elapsedRealtimeBase = baseTime,
                speedText = lastFormattedSpeed,
                distanceText = distanceText
            )
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    /**
     * Updates notification to show Paused state clearly.
     * Stops the chronometer and displays "Paused" (FR-34).
     */
    fun updatePaused(movingMs: Long, distanceM: Double) {
        val distanceKm = distanceM / 1000.0
        val distanceText = String.format("%.2f km", distanceKm)
        val movingSec = (movingMs / 1000) % 60
        val movingMin = (movingMs / (1000 * 60))
        val timeText = String.format("%02d:%02d", movingMin, movingSec)

        val contentText = "Paused • $distanceText • Time: $timeText"
        val notification = createNotification(
            isRunning = false,
            elapsedRealtimeBase = null,
            speedText = null,
            distanceText = contentText
        )
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    /**
     * Cancels the ongoing notification on run stop/discard.
     */
    fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
    }

    private fun createNotification(
        isRunning: Boolean,
        elapsedRealtimeBase: Long?,
        speedText: String?,
        distanceText: String?
    ): Notification {
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/run")
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play) // Original icon can be swapped
            .setContentTitle(if (isRunning) "Running — Road Runner" else "Run Paused")
            .setContentIntent(tapPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)

        if (isRunning && elapsedRealtimeBase != null) {
            builder.setUsesChronometer(true)
            builder.setWhen(elapsedRealtimeBase)
            builder.setContentText("${distanceText ?: "0.00 km"} • Speed: ${speedText ?: "0.0 km/h"}")
        } else {
            builder.setUsesChronometer(false)
            builder.setContentText(distanceText ?: "Paused")
        }

        // Pause / Resume action button (FR-33)
        if (isRunning) {
            val pauseIntent = Intent(ACTION_PAUSE).setPackage(context.packageName)
            val pausePending = PendingIntent.getBroadcast(
                context,
                1,
                pauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pausePending)
        } else {
            val resumeIntent = Intent(ACTION_RESUME).setPackage(context.packageName)
            val resumePending = PendingIntent.getBroadcast(
                context,
                2,
                resumeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_play, "Resume", resumePending)
        }

        return builder.build()
    }
}
