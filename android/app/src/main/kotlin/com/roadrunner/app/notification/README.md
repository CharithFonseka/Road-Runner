# notification

Owner: Aadila  
SRS reference: Section 8.3, FR-30 to FR-35

Kotlin code for the lock-screen notification.

## Rules

- Notification channel ID: `run_tracking`, low importance (no sound).
- Visibility: `VISIBILITY_PUBLIC` so it appears on the lock screen.
- Set `ongoing = true`, alert only once.
- Timer: use the system chronometer (`setChronometer`). Do NOT update the notification every second (C10).
- Speed text: update at most every 3 seconds.
- On pause: show "Paused", stop the chronometer.
- Tap action: deep-link to the Run screen.
- Pause/Resume action button: Should (FR-33).

## ⚠️ Battery rule

Do not rebuild the notification every second. The system will throttle it and it drains the battery.  
Use `setChronometer` for the timer — the OS handles the ticking.
