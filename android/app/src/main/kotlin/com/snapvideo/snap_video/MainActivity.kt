package com.snapvideo.snap_video

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val PIP_CHANNEL = "com.snapvideo.snapdown/pip"
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val width = call.argument<Int>("width") ?: 16
                            val height = call.argument<Int>("height") ?: 9
                            val rational = Rational(width.coerceAtLeast(1), height.coerceAtLeast(1))
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                builder.setAutoEnterEnabled(true)
                            }
                            val success = enterPictureInPictureMode(builder.build())
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android 8.0+", null)
                    }
                }
                "setAutoPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            val width = call.argument<Int>("width") ?: 16
                            val height = call.argument<Int>("height") ?: 9
                            val rational = Rational(width.coerceAtLeast(1), height.coerceAtLeast(1))
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                                .setAutoEnterEnabled(enabled)
                                .build()
                            setPictureInPictureParams(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    result.success(supported)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
