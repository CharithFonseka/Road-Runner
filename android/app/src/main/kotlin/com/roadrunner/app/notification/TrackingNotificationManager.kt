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
import com.roadrunner.app.tracking.TrackingService
import java.util.Locale
import kotlin.math.roundToInt

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

        private const val MIN_SPEED_UPDATE_INTERVAL_MS = 3000L
    }

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private var currentRunId: String? = null
    private var lastSpeedUpdateTimeMs: Long = 0L

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
        currentRunId = runId
        lastSpeedUpdateTimeMs = SystemClock.elapsedRealtime()
        return createNotification(
            isRunning = true,
            movingMs = 0L,
            distanceM = 0.0,
            speedMps = 0.0,
            paceSecPerKm = null,
        )
    }

    /**
     * Updates notification when live metrics change.
     * Throttles speed updates to at most once every 3 seconds per battery rule (C10 / FR-31).
     */
    fun updateLiveMetrics(
        movingMs: Long,
        distanceM: Double,
        speedMps: Double,
        paceSecPerKm: Double? = null,
    ) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastSpeedUpdateTimeMs >= MIN_SPEED_UPDATE_INTERVAL_MS) {
            lastSpeedUpdateTimeMs = now
            val notification = createNotification(
                isRunning = true,
                movingMs = movingMs,
                distanceM = distanceM,
                speedMps = speedMps,
                paceSecPerKm = paceSecPerKm,
            )
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    /**
     * Updates notification to show Paused state clearly.
     * Stops the chronometer and displays "Paused" (FR-34).
     */
    fun updatePaused(movingMs: Long, distanceM: Double) {
        lastSpeedUpdateTimeMs = 0L
        val distanceKm = distanceM / 1000.0
        val distanceText = String.format(Locale.US, "%.2f km", distanceKm)
        val movingSec = (movingMs / 1000) % 60
        val movingMin = (movingMs / (1000 * 60))
        val timeText = String.format(Locale.US, "%02d:%02d", movingMin, movingSec)

        val contentText = "Paused • $distanceText • Time: $timeText"
        val notification = createNotification(
            isRunning = false,
            pausedText = contentText,
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
        movingMs: Long = 0L,
        distanceM: Double = 0.0,
        speedMps: Double = 0.0,
        paceSecPerKm: Double? = null,
        pausedText: String? = null,
    ): Notification {
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
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

        if (isRunning) {
            val whenUtcMs = System.currentTimeMillis() - movingMs
            val speedText = String.format(Locale.US, "%.1f km/h", speedMps * 3.6)
            val distanceText = String.format(Locale.US, "%.2f km", distanceM / 1000.0)
            val paceText = paceSecPerKm
                ?.takeIf { it.isFinite() && it > 0.0 }
                ?.let {
                    val seconds = it.roundToInt()
                    String.format(Locale.US, "%d:%02d/km", seconds / 60, seconds % 60)
                } ?: "--:--/km"

            builder
                .setWhen(whenUtcMs)
                .setUsesChronometer(true)
                .setContentText("$distanceText • $speedText • $paceText")
        } else {
            builder
                .setUsesChronometer(false)
                .setContentText(pausedText ?: "Paused")
        }

        // Pause / Resume action button (FR-33)
        val actionIntent = Intent(context, TrackingService::class.java).apply {
            action = if (isRunning) {
                TrackingService.ACTION_PAUSE
            } else {
                TrackingService.ACTION_RESUME
            }
            putExtra(TrackingService.EXTRA_RUN_ID, currentRunId)
        }
        val actionPendingIntent = PendingIntent.getService(
            context,
            if (isRunning) 1 else 2,
            actionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        builder.addAction(
            if (isRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isRunning) "Pause" else "Resume",
            actionPendingIntent,
        )

        return builder.build()
    }
}
