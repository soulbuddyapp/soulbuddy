package app.soulbuddy.soulbuddy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.session.MediaSession
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock

class SacredHourPlaybackService : Service() {
    companion object {
        const val ACTION_START = "app.soulbuddy.sacred_hour.START"
        const val ACTION_PAUSE = "app.soulbuddy.sacred_hour.PAUSE"
        const val ACTION_RESUME = "app.soulbuddy.sacred_hour.RESUME"
        const val ACTION_STOP = "app.soulbuddy.sacred_hour.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_STARTED_AT = "startedAtMillis"
        const val EXTRA_DURATION = "durationMillis"
        const val EXTRA_ROUTE = "route"
        private const val CHANNEL_ID = "sacred_hour_playback"
        private const val NOTIFICATION_ID = 7301
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var mediaSession: MediaSession
    private var title = "Sacred Hour"
    private var durationMillis = 0L
    private var elapsedMillis = 0L
    private var runningSinceElapsed = 0L
    private var paused = false

    private val ticker = object : Runnable {
        override fun run() {
            if (!paused && remainingMillis() <= 0L) {
                stopSelf()
                return
            }
            notifyNow()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        mediaSession = MediaSession(this, "SacredHour")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> start(intent)
            ACTION_PAUSE -> pause()
            ACTION_RESUME -> resume()
            ACTION_STOP -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun start(intent: Intent) {
        title = intent.getStringExtra(EXTRA_TITLE) ?: title
        durationMillis = intent.getLongExtra(EXTRA_DURATION, 0L)
        val startedAt = intent.getLongExtra(EXTRA_STARTED_AT, System.currentTimeMillis())
        elapsedMillis = (System.currentTimeMillis() - startedAt).coerceIn(0L, durationMillis)
        runningSinceElapsed = SystemClock.elapsedRealtime()
        paused = false
        startForeground(NOTIFICATION_ID, notification())
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    private fun pause() {
        if (paused) return
        elapsedMillis += SystemClock.elapsedRealtime() - runningSinceElapsed
        paused = true
        notifyNow()
    }

    private fun resume() {
        if (!paused) return
        runningSinceElapsed = SystemClock.elapsedRealtime()
        paused = false
        notifyNow()
    }

    private fun remainingMillis(): Long {
        val currentElapsed = if (paused) elapsedMillis else elapsedMillis +
            (SystemClock.elapsedRealtime() - runningSinceElapsed)
        return (durationMillis - currentElapsed).coerceAtLeast(0L)
    }

    private fun notification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val pauseOrResume = if (paused) ACTION_RESUME else ACTION_PAUSE
        val pauseLabel = if (paused) "Resume" else "Pause"
        val pauseIcon = if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause
        val actionIntent = PendingIntent.getService(
            this, 1, Intent(this, SacredHourPlaybackService::class.java).setAction(pauseOrResume),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val finishIntent = PendingIntent.getService(
            this, 2, Intent(this, SacredHourPlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        mediaSession.setPlaybackState(
            android.media.session.PlaybackState.Builder()
                .setState(
                    if (paused) android.media.session.PlaybackState.STATE_PAUSED
                    else android.media.session.PlaybackState.STATE_PLAYING,
                    elapsedMillis,
                    if (paused) 0f else 1f,
                )
                .setActions(
                    android.media.session.PlaybackState.ACTION_PLAY or
                        android.media.session.PlaybackState.ACTION_PAUSE or
                        android.media.session.PlaybackState.ACTION_STOP,
                )
                .build(),
        )
        mediaSession.isActive = true
        val minutes = ((remainingMillis() + 59_999) / 60_000).coerceAtLeast(1)
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("$minutes min remaining")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setStyle(Notification.MediaStyle().setMediaSession(mediaSession.sessionToken).setShowActionsInCompactView(0, 1))
            .addAction(Notification.Action.Builder(pauseIcon, pauseLabel, actionIntent).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Complete", finishIntent).build())
            .build()
    }

    private fun notifyNow() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification())
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Sacred Hour", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        mediaSession.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
