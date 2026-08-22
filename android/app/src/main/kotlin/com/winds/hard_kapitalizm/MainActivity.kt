package com.winds.hard_kapitalizm

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.winds.hard_kapitalizm/vibration"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = (call.argument<Int>("duration") ?: 150).toLong()
                    val amplitude = call.argument<Int>("amplitude") ?: -1
                    triggerVibration(duration, amplitude)
                    result.success(true)
                }
                "hasVibrator" -> {
                    result.success(hasVibrator())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getVibratorService(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator ?: (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun triggerVibration(durationMs: Long, amplitude: Int) {
        try {
            val vibrator = getVibratorService() ?: return

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val hasAmp = try { vibrator.hasAmplitudeControl() } catch (e: Exception) { false }
                val effectAmplitude = if (hasAmp && amplitude in 1..255) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
                val effect = VibrationEffect.createOneShot(durationMs, effectAmplitude)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    vibrator.vibrate(effect, audioAttributes)
                } else {
                    vibrator.vibrate(effect)
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (e: Exception) {
            try {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)?.vibrate(durationMs)
            } catch (_: Exception) {}
        }
    }

    private fun hasVibrator(): Boolean {
        return try {
            getVibratorService()?.hasVibrator() == true
        } catch (e: Exception) {
            false
        }
    }
}
