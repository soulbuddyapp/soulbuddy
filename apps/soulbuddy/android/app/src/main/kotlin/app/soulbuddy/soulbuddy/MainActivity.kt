package app.soulbuddy.soulbuddy

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.soulbuddy/screen_awake",
        ).setMethodCallHandler { call, result ->
            if (call.method == "setEnabled") {
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.soulbuddy/prayer_audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentRoute" -> result.success(currentRoute())
                "interruptionsAllowed" -> result.success(interruptionsAllowed())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.soulbuddy/sacred_hour_notification",
        ).setMethodCallHandler { call, result ->
            val serviceIntent = Intent(this, SacredHourPlaybackService::class.java)
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    serviceIntent.action = SacredHourPlaybackService.ACTION_START
                    serviceIntent.putExtra(SacredHourPlaybackService.EXTRA_TITLE, args?.get("title") as? String)
                    serviceIntent.putExtra(SacredHourPlaybackService.EXTRA_STARTED_AT, (args?.get("startedAtMillis") as? Number)?.toLong() ?: System.currentTimeMillis())
                    serviceIntent.putExtra(SacredHourPlaybackService.EXTRA_DURATION, (args?.get("durationMillis") as? Number)?.toLong() ?: 0L)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(serviceIntent) else startService(serviceIntent)
                    result.success(null)
                }
                "pause" -> {
                    serviceIntent.action = SacredHourPlaybackService.ACTION_PAUSE
                    startService(serviceIntent)
                    result.success(null)
                }
                "resume" -> {
                    serviceIntent.action = SacredHourPlaybackService.ACTION_RESUME
                    startService(serviceIntent)
                    result.success(null)
                }
                "stop" -> {
                    stopService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun currentRoute(): String {
        if (!interruptionsAllowed()) return "doNotDisturb"
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return "silent"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val headphones = devices.any { device ->
                device.type in setOf(
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                )
            }
            if (headphones) return "headphones"
        }
        return "speaker"
    }

    private fun interruptionsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notifications.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL
    }
}
